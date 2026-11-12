"""Read-only ROS image-header timestamps and stereo pairing.

Optional rosbags.AnyReader extracts ROS1/ROS2 image header timestamps,
preserving archive receive timestamps independently. The pairer never uses
left/right row index equality, nominal FPS or inferred timecodes.
No assertion of shared hardware shutter exposure or 3D accuracy.
"""
from __future__ import annotations
import argparse
import csv
import hashlib
import json
from pathlib import Path


def integer(v, name, minimum=None):
    if isinstance(v, bool):
        raise ValueError(f"{name} is not integer")
    try:
        n = int(v)
        if str(v).strip() != str(n):
            raise ValueError()
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{name} must be exact integer") from exc
    if minimum is not None and n < minimum:
        raise ValueError(f"{name} below {minimum}")
    return n


def stamp_ns(stamp):
    second = next((getattr(stamp, key) for key in ("sec", "secs")
                   if hasattr(stamp, key)), None)
    nano = next((getattr(stamp, key) for key in ("nanosec", "nsec", "nsecs")
                 if hasattr(stamp, key)), None)
    s = integer(second, "header second", 0)
    ns = integer(nano, "header nanoseconds", 0)
    if ns >= 1_000_000_000:
        raise ValueError("header nanoseconds outside [0,1e9)")
    return s * 1_000_000_000 + ns


def extract_image_headers(bag_path, left_topic, right_topic):
    """Extract independent acquisition-header versus ROS bag arrival times."""
    try:
        from rosbags.highlevel import AnyReader
    except ImportError as exc:
        raise RuntimeError("Install optional rosbags for bag extraction") from exc
    if left_topic == right_topic:
        raise ValueError("Stereo topics must be distinct")
    rows = {left_topic: [], right_topic: []}
    with AnyReader([Path(bag_path)]) as reader:
        conns = [c for c in reader.connections if c.topic in rows]
        if {c.topic for c in conns} != {left_topic, right_topic}:
            raise ValueError("Both explicitly configured image topics must exist")
        for conn in conns:
            if conn.msgtype not in ("sensor_msgs/msg/Image",
                                    "sensor_msgs/msg/CompressedImage"):
                raise ValueError("Requested topic is not a ROS image")
        for conn, bag_time_ns, raw in reader.messages(connections=conns):
            msg = reader.deserialize(raw, conn.msgtype)
            if not hasattr(msg, "header") or not hasattr(msg.header, "stamp"):
                raise ValueError("ROS image lacks acquisition header stamp")
            index = len(rows[conn.topic])
            rows[conn.topic].append({
                "frame_index": index, "topic": conn.topic,
                "header_stamp_ns": stamp_ns(msg.header.stamp),
                "bag_time_ns": int(bag_time_ns),
                "optical_frame_id": str(getattr(msg.header, "frame_id", "")),
            })
    return rows[left_topic], rows[right_topic]


def read_timestamp_csv(path):
    with Path(path).open(newline="", encoding="utf-8-sig") as fh:
        reader = csv.DictReader(fh)
        keys = ("frame_index", "topic", "header_stamp_ns", "bag_time_ns")
        if not all(k in (reader.fieldnames or []) for k in keys):
            raise ValueError("Missing original ROS header timestamp columns")
        result = []
        for row in reader:
            result.append({
                "frame_index": integer(row["frame_index"], "frame_index", 0),
                "topic": row["topic"],
                "header_stamp_ns": integer(row["header_stamp_ns"],
                                            "header_stamp_ns", 0),
                "bag_time_ns": integer(row["bag_time_ns"],
                                       "bag_time_ns", 0),
                "optical_frame_id": row.get("optical_frame_id", ""),
            })
    return result


def validate(rows, name):
    if not rows:
        raise ValueError(f"{name} has no acquired image headers")
    topics = {x["topic"] for x in rows}
    if len(topics) != 1 or not next(iter(topics)):
        raise ValueError(f"{name} requires one nonempty physical topic")
    if [x["frame_index"] for x in rows] != list(range(len(rows))):
        raise ValueError(f"{name} frame indices must be contiguous in message order")
    ts = [x["header_stamp_ns"] for x in rows]
    if any(ts[i] >= ts[i + 1] for i in range(len(ts) - 1)):
        raise ValueError(f"{name} header stamps must increase strictly")
    return next(iter(topics))


def stereo_pair(left, right, tolerance_ns, right_to_left_offset_ns=0):
    topic_left = validate(left, "left")
    topic_right = validate(right, "right")
    if topic_left == topic_right:
        raise ValueError("Stereo topics must differ")
    tolerance = integer(tolerance_ns, "tolerance_ns", 0)
    offset = integer(right_to_left_offset_ns, "offset_ns")
    i = j = 0
    pairs, unleft, unright = [], [], []
    while i < len(left) and j < len(right):
        delta = (left[i]["header_stamp_ns"] -
                 (right[j]["header_stamp_ns"] + offset))
        if abs(delta) <= tolerance:
            pairs.append({
                "left_frame_index": i,
                "right_frame_index": j,
                "left_header_stamp_ns": left[i]["header_stamp_ns"],
                "right_header_stamp_ns": right[j]["header_stamp_ns"],
                "corrected_time_residual_ns": delta,
                "left_bag_delay_ns": (
                    left[i]["bag_time_ns"] - left[i]["header_stamp_ns"]),
                "right_bag_delay_ns": (
                    right[j]["bag_time_ns"] - right[j]["header_stamp_ns"]),
            })
            i += 1
            j += 1
        elif delta < 0:
            unleft.append(i)
            i += 1
        else:
            unright.append(j)
            j += 1
    unleft.extend(range(i, len(left)))
    unright.extend(range(j, len(right)))
    residuals = [abs(p["corrected_time_residual_ns"]) for p in pairs]
    audit = {
        "left_topic": topic_left,
        "right_topic": topic_right,
        "n_left": len(left), "n_right": len(right),
        "n_paired": len(pairs),
        "n_unpaired_left": len(unleft),
        "n_unpaired_right": len(unright),
        "matched_fraction_left": len(pairs) / len(left),
        "matched_fraction_right": len(pairs) / len(right),
        "max_abs_corrected_header_residual_ns": (
            max(residuals) if residuals else None),
        "tolerance_ns": tolerance, "right_to_left_offset_ns": offset,
        "matching_method":
            "one_to_one_chronological_greedy_with_explicit_offset",
        "header_stamp_is_verified_hardware_exposure": False,
        "shared_camera_clock_verified": False,
        "absolute_underwater_xyz_accuracy_certified": False,
    }
    return {"pairs": pairs,
            "unmatched_left_frame_indices": unleft,
            "unmatched_right_frame_indices": unright,
            "audit": audit}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--left-csv", type=Path, required=True)
    parser.add_argument("--right-csv", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--tolerance-ns", type=int, required=True)
    parser.add_argument("--right-to-left-offset-ns", type=int, default=0)
    args = parser.parse_args(argv)
    paired = stereo_pair(
        read_timestamp_csv(args.left_csv),
        read_timestamp_csv(args.right_csv),
        args.tolerance_ns, args.right_to_left_offset_ns)
    args.output.mkdir(parents=True, exist_ok=True)
    if any(args.output.iterdir()):
        raise FileExistsError("Refusing overwrite of existing stereo report")
    with (args.output / "stereo_pairs.csv").open("w", newline="") as f:
        fields = [
            "left_frame_index", "right_frame_index",
            "left_header_stamp_ns", "right_header_stamp_ns",
            "corrected_time_residual_ns",
            "left_bag_delay_ns", "right_bag_delay_ns",
        ]
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(paired["pairs"])
    paired["audit"]["source_sha256"] = {
        p.name: hashlib.sha256(p.read_bytes()).hexdigest()
        for p in (args.left_csv, args.right_csv)}
    (args.output / "stereo_pairing_audit.json").write_text(
        json.dumps(paired["audit"], indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
