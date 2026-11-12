#!/usr/bin/env python3
"""Write mock-decoder, exact-Python-runner bundles for cross-language CI.

These are software interoperability fixtures, never actual fish videos
or independently annotated biological datasets.
"""
from __future__ import annotations

import importlib.util
from pathlib import Path
import sys
import types


ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / "inst" / "python" / "aqt_track_video.py"
spec = importlib.util.spec_from_file_location("aqt_track_video", RUNNER)
if spec is None or spec.loader is None:
    raise RuntimeError("Missing runner source")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class Tensor:
    def __init__(self, xs):
        self.xs = xs

    def cpu(self):
        return self

    def tolist(self):
        return self.xs


class Boxes:
    def __init__(self, xyxy, ids):
        self.xyxy = Tensor(xyxy)
        self.id = Tensor(ids) if ids is not None else None
        self.conf = Tensor([.9] * len(xyxy))
        self.cls = Tensor([0] * len(xyxy))


class Frame:
    def __init__(self, seconds):
        self.time = seconds

    def to_ndarray(self, format):
        if format != "bgr24":
            raise RuntimeError("Wrong decoded frame format")
        return types.SimpleNamespace(shape=(80, 100, 3))


class Container:
    streams = types.SimpleNamespace(video=["VIDEO"])

    def __init__(self, filename):
        self.empty = filename.endswith("empty.mp4")

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def decode(self, stream):
        if stream != "VIDEO":
            raise RuntimeError("Wrong stream")
        return [Frame(32.), Frame(32.055)] if self.empty else \
               [Frame(32.), Frame(32.055), Frame(32.17)]


class YOLO:
    def __init__(self, filename):
        self.empty = filename.endswith("empty.pt")
        self.num = 0

    def track(self, **kwargs):
        if kwargs.get("tracker") != "bytetrack.yaml" or \
                not kwargs.get("persist"):
            raise RuntimeError("Not persistent ByteTrack")
        self.num += 1
        if self.empty or self.num == 3:
            boxes = Boxes([], None)
        elif self.num == 1:
            boxes = Boxes([[10, 20, 20, 30]], [7])
        else:
            boxes = Boxes([[11, 20, 21, 30]], [7])
        return [types.SimpleNamespace(boxes=boxes)]


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: generator.py output_directory")
    base = Path(sys.argv[1])
    base.mkdir(parents=True,exist_ok=True)
    av = types.ModuleType("av")
    av.__version__ = "mock-ci"
    av.open = lambda p: Container(str(p))
    ultra = types.ModuleType("ultralytics")
    ultra.__version__ = "mock-ci"
    ultra.YOLO = YOLO
    sys.modules["av"] = av
    sys.modules["ultralytics"] = ultra
    for name in ("tracked","empty"):
        video = base / f"{name}.mp4"
        weights = base / f"{name}.pt"
        video.write_bytes(f"MOCK-{name}-video".encode())
        weights.write_bytes(f"MOCK-{name}-weights".encode())
        info = runner.run_video(
            video,weights,base,name,
            session_id="S1" if name=="tracked" else "S2",
            camera_id="TOP" if name=="tracked" else "SIDE")
        if info["n_decoded_frames"]!=(3 if name=="tracked" else 2):
            raise RuntimeError("Mock decoded-frame count mismatch")
        if info["n_tracked_box_rows"]!=(2 if name=="tracked" else 0):
            raise RuntimeError("Mock tracked-box count mismatch")
    print("Python mock video runner emitted both checked bundle layouts")


if __name__=="__main__":
    main()
