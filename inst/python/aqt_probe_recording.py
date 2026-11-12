#!/usr/bin/env python3
"""Read-only GoPro/MP4 structural probe for AquaTrajectories.

Inspect real video streams and measured presentation timestamps with ffprobe,
optionally parse an extracted GoPro GPMF .raw payload (KLV headers only).
Never infer camera hardware synchronization, underwater calibration,
fish identities, or fish presence from MP4/GPMF metadata.

No video frames are decoded by this tool, and its timing sample is an
inspection sample, NOT an alternate clock for the PyAV model runner.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
from typing import Any


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for block in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def inspect_gpmf_payload(data: bytes, *, max_depth: int = 5) -> dict[str, Any]:
    """Inspect genuine GPMF KLV key/type/sample structure without sensor values.

    GPMF KLV: 4 ASCII key bytes, 1 type byte (0 denotes nested KLV),
    1 structure-size byte, 2 big-endian repeat-count bytes, then
    size*repeat payload bytes padded to a multiple of four bytes.
    """
    if not isinstance(data, bytes) or len(data) < 8:
        raise ValueError("A GPMF raw payload requires at least eight bytes")
    if len(data) > 64 * 1024 * 1024:
        raise ValueError("GPMF raw payload exceeds 64 MiB inspection limit")
    if not isinstance(max_depth, int) or not 1 <= max_depth <= 10:
        raise ValueError("max_depth must be an integer in [1,10]")

    def parse(begin: int, end: int, depth: int) -> list[dict[str, Any]]:
        cursor = begin
        result: list[dict[str, Any]] = []
        while cursor < end:
            if end - cursor < 8:
                # Only all-zero alignment tail is permitted.
                if any(data[cursor:end]):
                    raise ValueError("Truncated or nonzero GPMF KLV header")
                break
            key_bytes = data[cursor:cursor + 4]
            if not all(32 <= c <= 126 for c in key_bytes):
                raise ValueError("GPMF key must be four printable ASCII bytes")
            key = key_bytes.decode("ascii")
            type_number = data[cursor + 4]
            item_size = data[cursor + 5]
            repeats = int.from_bytes(data[cursor + 6:cursor + 8], "big")
            payload_size = item_size * repeats
            padded_size = ((payload_size + 3) // 4) * 4
            after = cursor + 8 + padded_size
            if after > end:
                raise ValueError("GPMF KLV size extends outside containing payload")
            if payload_size and any(data[cursor + 8 + payload_size:after]):
                raise ValueError("GPMF padding must be zero")
            entry: dict[str, Any] = {
                "key": key,
                "type": "nested" if type_number == 0 else chr(type_number),
                "structure_size": item_size,
                "repeat": repeats,
                "payload_size_bytes": payload_size,
                "offset_bytes": cursor,
            }
            if type_number == 0 and payload_size and depth < max_depth:
                entry["children"] = parse(
                    cursor + 8, cursor + 8 + payload_size, depth + 1)
            result.append(entry)
            cursor = after
        return result

    nodes = parse(0, len(data), 0)
    if not nodes or nodes[0]["key"] != "DEVC":
        raise ValueError("Expected GoPro DEVC GPMF payload at the root")
    flat: list[dict[str, Any]] = []
    def walk(items: list[dict[str, Any]], prefix: str = "") -> None:
        for entry in items:
            label = f"{prefix}/{entry['key']}" if prefix else entry["key"]
            flat.append({
                "path": label, "type": entry["type"],
                "structure_size": entry["structure_size"],
                "repeat": entry["repeat"],
            })
            walk(entry.get("children", []), label)
    walk(nodes)
    return {
        "format": "gopro_gpmf_raw_klv",
        "bytes": len(data),
        "root_keys": [x["key"] for x in nodes],
        "entries": flat,
        "physical_camera_clock_synchronized": False,
        "sensor_value_decoding_performed": False,
    }


def summarise_ffprobe(
    container: dict[str, Any], frames: dict[str, Any] | None = None
) -> dict[str, Any]:
    """Validate FFprobe JSON and label sampled PTS as camera-local only."""
    if not isinstance(container, dict):
        raise ValueError("FFprobe container must be a JSON object")
    streams = container.get("streams")
    if not isinstance(streams, list):
        raise ValueError("FFprobe container must have a streams array")
    v = [s for s in streams if isinstance(s, dict) and
         s.get("codec_type") == "video"]
    if not v:
        raise ValueError("Input MP4 does not contain an identified video stream")
    details: list[dict[str, Any]] = []
    for stream in streams:
        if not isinstance(stream, dict):
            raise ValueError("FFprobe stream must be an object")
        tags = stream.get("tags") or {}
        if not isinstance(tags, dict):
            tags = {}
        tag = stream.get("codec_tag_string") or ""
        name = tags.get("handler_name") or ""
        details.append({
            "index": stream.get("index"),
            "codec_type": stream.get("codec_type"),
            "codec_name": stream.get("codec_name"),
            "codec_tag_string": tag,
            "handler_name": name,
            "time_base": stream.get("time_base"),
            "avg_frame_rate": stream.get("avg_frame_rate"),
            "r_frame_rate": stream.get("r_frame_rate"),
            "duration": stream.get("duration"),
            "width": stream.get("width"),
            "height": stream.get("height"),
            "candidate_gpmf": tag == "gpmd",
        })
    pts: list[float] = []
    missing_pts = 0
    if frames is not None:
        if not isinstance(frames, dict) or not isinstance(
                frames.get("frames"), list):
            raise ValueError("FFprobe frame scan requires a frames array")
        for f in frames["frames"]:
            if not isinstance(f, dict):
                raise ValueError("FFprobe frame row must be an object")
            raw = f.get("best_effort_timestamp_time",
                        f.get("pts_time"))
            try:
                number = float(raw)
            except (TypeError, ValueError):
                missing_pts += 1
                continue
            if not math.isfinite(number):
                missing_pts += 1
            else:
                pts.append(number)
        if any(b <= a for a, b in zip(pts, pts[1:])):
            raise ValueError("FFprobe decoded frame PTS not strictly increasing")
    local = [x - pts[0] for x in pts] if pts else []
    gaps = [b - a for a, b in zip(pts, pts[1:])]
    return {
        "file_format": (container.get("format") or {}).get("format_name"),
        "stream_count": len(streams),
        "streams": details,
        "gpmf_stream_detected": any(d["candidate_gpmf"] for d in details),
        "gpmf_note": (
            "gpmd track presence does not decode IMU data, "
            "prove exposure phase, or synchronize separate cameras"),
        "scanned_frame_rows": (
            None if frames is None else len(frames["frames"])),
        "finite_frame_pts_rows": len(pts),
        "missing_frame_pts_rows": missing_pts,
        "first_sampled_pts_s": pts[0] if pts else None,
        "last_sampled_pts_s": pts[-1] if pts else None,
        "relative_sampled_pts_s": local,
        "sampled_delta_min_s": min(gaps) if gaps else None,
        "sampled_delta_max_s": max(gaps) if gaps else None,
        "sampled_frame_count_is_total_video_count": False,
        "camera_exposure_clock_synchronized": False,
        "underwater_intrinsic_extrinsic_refraction_calibrated": False,
    }


def _run_ffprobe(video: Path, *, ffprobe: str, scan_frames: int) -> dict:
    if not video.is_file():
        raise FileNotFoundError(f"No input video file: {video}")
    if not isinstance(scan_frames, int) or not 0 <= scan_frames <= 100000:
        raise ValueError("scan_frames must be an integer in [0,100000]")
    base = [ffprobe, "-v", "error"]
    def invoke(args: list[str]) -> dict:
        try:
            result = subprocess.run(
                base + args + ["-of", "json", str(video)],
                check=True, capture_output=True, text=True)
        except (FileNotFoundError, subprocess.CalledProcessError) as exc:
            raise RuntimeError(
                "FFprobe missing, failed or unable to read video container"
                ) from exc
        try:
            return json.loads(result.stdout)
        except json.JSONDecodeError as exc:
            raise ValueError("FFprobe returned malformed JSON") from exc

    container = invoke(["-show_format", "-show_streams"])
    frames = None
    if scan_frames:
        frames = invoke([
            "-select_streams", "v:0",
            "-read_intervals", f"%+#{scan_frames}",
            "-show_frames",
            "-show_entries",
            "frame=best_effort_timestamp_time,pts_time,width,height"])
    return summarise_ffprobe(container, frames)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--video", type=Path,
                        help="Existing MP4/other input to inspect with ffprobe")
    parser.add_argument("--gpmf-raw", type=Path,
                        help="GoPro exported .raw KLV payload for structure scan")
    parser.add_argument("--ffprobe", default="ffprobe")
    parser.add_argument("--scan-frames", type=int, default=50)
    parser.add_argument("--sha256-video", action="store_true")
    parser.add_argument("--output", type=Path,
                        help="Optional output report JSON path")
    args = parser.parse_args(argv)
    if args.video is None and args.gpmf_raw is None:
        parser.error("At least one of --video or --gpmf-raw is needed")
    summary: dict[str, Any] = {
        "schema_version": "1.0",
        "purpose": "read_only_external_recording_structure_inspection",
        "fish_tracking_accuracy_certified": False,
        "independent_xyz_ground_truth_verified": False,
    }
    if args.video is not None:
        summary["video"] = _run_ffprobe(
            args.video, ffprobe=args.ffprobe, scan_frames=args.scan_frames)
        summary["video_path"] = str(args.video.resolve())
        if args.sha256_video:
            summary["video_sha256"] = sha256_file(args.video)
    if args.gpmf_raw is not None:
        if not args.gpmf_raw.is_file():
            raise FileNotFoundError("GoPro GPMF raw payload file missing")
        summary["gpmf"] = inspect_gpmf_payload(
            args.gpmf_raw.read_bytes())
        summary["gpmf_raw_sha256"] = sha256_file(args.gpmf_raw)
    result = json.dumps(summary, indent=2, sort_keys=True) + "\n"
    if args.output is not None:
        args.output.write_text(result, encoding="utf-8")
    else:
        print(result, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
