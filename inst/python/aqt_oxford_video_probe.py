#!/usr/bin/env python3
"""Original Oxford Picasso triggerfish video source-to-frame-clock audit.

Data: https://www.robots.ox.ac.uk/~vgg/research/fish/
Official evaluation ZIP: https://thor.robots.ox.ac.uk/~vgg/data/fish/fish-tank-obstacles-eval-15.zip
Source CC BY-NC 4.0; source fish video/annotations are not redistributed.
A decoded frame PTS is a VIDEO-LOCAL PRESENTATION CLOCK, not exposure UTC.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import shutil
import stat
import subprocess
import tempfile
import zipfile

EXTENSIONS = {".mp4", ".avi", ".mov", ".mkv", ".m4v", ".webm"}
SOURCE_URL = "https://www.robots.ox.ac.uk/~vgg/research/fish/"
SOURCE_LICENSE = "CC BY-NC 4.0"


def digest(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for data in iter(lambda: stream.read(1 << 20), b""):
            h.update(data)
    return h.hexdigest()


def video_members(archive):
    path = Path(archive)
    if not path.is_file() or path.stat().st_size > 1_000_000_000:
        raise ValueError("Missing/oversized source video archive")
    with zipfile.ZipFile(path) as z:
        entries = z.infolist()
        if len(entries) > 10000 or sum(f.file_size for f in entries) > 2_000_000_000:
            raise ValueError("Video archive exceeds conservative member limits")
        videos = []
        for x in entries:
            p = PurePosixPath(x.filename)
            mode = (x.external_attr >> 16) & 0xFFFF
            if (p.is_absolute() or ".." in p.parts or "\\" in x.filename or
                    "\0" in x.filename or stat.S_ISLNK(mode)):
                raise ValueError("Unsafe video archive member")
            if x.is_dir() or p.suffix.lower() not in EXTENSIONS:
                continue
            if x.file_size < 256 or x.file_size > 250_000_000:
                raise ValueError("Unexpected video source member size")
            if x.compress_size == 0 or x.file_size / x.compress_size > 2000:
                raise ValueError("Suspicious compressed video source member")
            videos.append(x.filename)
    if not videos:
        raise ValueError("No original video recordings found in ZIP")
    return sorted(videos)


def parse_probe(stream_json, frame_json):
    streams = stream_json.get("streams")
    if not isinstance(streams, list) or len(streams) != 1:
        raise ValueError("Exactly one selected video stream required")
    s = streams[0]
    width, height = s.get("width"), s.get("height")
    if (not isinstance(width, int) or isinstance(width, bool) or width <= 0 or
            not isinstance(height, int) or isinstance(height, bool) or height <= 0):
        raise ValueError("Invalid original video frame geometry")
    name = s.get("codec_name")
    if not isinstance(name, str) or not name:
        raise ValueError("Missing video codec metadata")
    samples = frame_json.get("frames")
    if not isinstance(samples, list) or not samples:
        raise ValueError("No real decoded frames/PRESENTATION timestamps")
    timestamps = []
    for i, frame in enumerate(samples):
        value = frame.get("best_effort_timestamp_time")
        if value is None:
            raise ValueError(f"No decoded timestamp for frame {i}")
        try:
            seconds = float(value)
        except (TypeError, ValueError) as e:
            raise ValueError("Invalid video PTS") from e
        if not math.isfinite(seconds):
            raise ValueError("Nonfinite video PTS")
        if timestamps and seconds <= timestamps[-1]:
            raise ValueError("Non-increasing video frame presentation timestamps")
        timestamps.append(seconds)
    relative = [v - timestamps[0] for v in timestamps]
    if relative[0] != 0 or any(
            b <= a for a, b in zip(relative, relative[1:])):
        raise ValueError("Non-increasing relative frame clock")
    return {
        "codec": name, "width_px": width, "height_px": height,
        "stream_time_base": s.get("time_base"),
        "stream_nominal_fps": s.get("avg_frame_rate"),
        "n_decoded_frame_timestamps": len(relative),
        "first_original_pts_seconds": timestamps[0],
        "last_original_pts_seconds": timestamps[-1],
    }, relative


def run_ffprobe(path):
    stream_cmd = ["ffprobe", "-v", "error", "-select_streams", "v:0",
                  "-show_entries",
                  "stream=codec_name,width,height,time_base,avg_frame_rate",
                  "-of", "json", str(path)]
    frame_cmd = ["ffprobe", "-v", "error", "-select_streams", "v:0",
                 "-show_frames",
                 "-show_entries", "frame=best_effort_timestamp_time",
                 "-of", "json", str(path)]
    def run(args):
        result = subprocess.run(args, check=True, capture_output=True,
                                text=True, timeout=180)
        return json.loads(result.stdout)
    streams = run(stream_cmd)
    frames = run(frame_cmd)
    return parse_probe(streams, frames)


def decode_one_real_frame(path):
    cmd = ["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error",
           "-i", str(path), "-map", "0:v:0", "-frames:v", "1", "-f", "null", "-"]
    subprocess.run(cmd, check=True, capture_output=True, timeout=120)


def record_one(archive, destination, *, member=None, session_id="oxford_eval",
               camera_id="video"):
    all_members = video_members(archive)
    chosen = all_members[0] if member is None else member
    if chosen not in all_members:
        raise ValueError("Video member is not present in verified archive")
    if not session_id or not camera_id or any(
            c in text for text in (session_id, camera_id)
            for c in ("\n", "\r", ",")):
        raise ValueError("Invalid recording scope")
    dest = Path(destination)
    if dest.exists() and (not dest.is_dir() or any(dest.iterdir())):
        raise FileExistsError("Refuse existing or nonempty audit output")
    with tempfile.TemporaryDirectory(prefix="aqt_oxford_") as temp:
        raw = Path(temp) / ("source" + Path(chosen).suffix.lower())
        with zipfile.ZipFile(archive) as z:
            with z.open(chosen) as source, raw.open("wb") as sink:
                shutil.copyfileobj(source, sink, length=1 << 20)
        video_hash = digest(raw)
        info, times = run_ffprobe(raw)
        decode_one_real_frame(raw)
    dest.mkdir(parents=True, exist_ok=True)
    frame_file = dest / "frames.csv"
    columns = ["session_id", "camera_id", "frame_id", "time_s",
               "width_px", "height_px"]
    with frame_file.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=columns)
        writer.writeheader()
        for frame, seconds in enumerate(times):
            writer.writerow(dict(session_id=session_id, camera_id=camera_id,
                                 frame_id=frame, time_s=format(seconds, ".15g"),
                                 width_px=info["width_px"],
                                 height_px=info["height_px"]))
    report = {
        "schema_version": "1.0",
        "dataset": "Oxford Detect+Track Picasso triggerfish",
        "source_webpage": SOURCE_URL,
        "source_license": SOURCE_LICENSE,
        "source_archive_sha256": digest(archive),
        "source_archive_video_members": len(all_members),
        "selected_video_member": chosen,
        "selected_video_sha256": video_hash,
        "first_original_frame_decoded_with_ffmpeg": True,
        "frame_manifest_sha256": digest(frame_file),
        "session_id": session_id, "camera_id": camera_id,
        "frame_count": len(times),
        "decoded_frame_clock_source": "ffprobe best_effort_timestamp_time",
        "clock_scope": "video_local_pts_not_hardware_exposure_utc",
        "camera_exposure_synchronization_certified": False,
        "fish_detection_or_track_identity_accuracy_certified": False,
        "original_human_annotation_completeness_verified": False,
        "independent_physical_xyz_certified": False,
        **info
    }
    (dest / "audit.json").write_text(
        json.dumps(report, indent=2, sort_keys=True)+"\n",encoding="utf-8")
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive",type=Path,required=True)
    parser.add_argument("--output-dir",type=Path,required=True)
    parser.add_argument("--member")
    parser.add_argument("--session-id",default="oxford_eval")
    parser.add_argument("--camera-id",default="video")
    args = parser.parse_args(argv)
    print(json.dumps(record_one(args.archive,args.output_dir,member=args.member,
                                session_id=args.session_id,camera_id=args.camera_id),
                     indent=2,sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
