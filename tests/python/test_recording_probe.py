"""GoPro MP4/GPMF data-structure contracts; independent of fish accuracy."""
import importlib.util
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "inst" / "python" / "aqt_probe_recording.py"
spec = importlib.util.spec_from_file_location("aqt_probe_recording", PATH)
assert spec and spec.loader
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


def klv(key, type_number, item_size, repeats, payload):
    assert len(key) == 4 and len(payload) == item_size * repeats
    extra = b"\x00" * (-len(payload) % 4)
    return (key.encode("ascii") + bytes([type_number, item_size])
            + struct.pack(">H", repeats) + payload + extra)


class RecordingProbeContracts(unittest.TestCase):
    def test_genuine_gopro_klv_shape_synthetic_values(self):
        # Follows the observed GoPro HERO5 .raw sample KLV field layout;
        # this byte fixture is synthetic, not copied video or telemetry.
        samples = klv("ACCL", ord("s"), 6, 2,
                      struct.pack(">6h", 1, 2, 3, 4, 5, 6))
        tsmp = klv("TSMP", ord("L"), 4, 1, struct.pack(">L", 2))
        stream = klv("STRM", 0, 1, len(tsmp + samples), tsmp + samples)
        device_id = klv("DVID", ord("L"), 4, 1, struct.pack(">L", 1))
        data = klv("DEVC", 0, 1,
                   len(device_id + stream), device_id + stream)
        report = probe.inspect_gpmf_payload(data)
        self.assertEqual(report["root_keys"], ["DEVC"])
        rows = {x["path"]: x for x in report["entries"]}
        self.assertEqual(rows["DEVC/STRM/ACCL"]["repeat"], 2)
        self.assertEqual(rows["DEVC/STRM/ACCL"]["structure_size"], 6)
        self.assertEqual(rows["DEVC/STRM/ACCL"]["type"], "s")
        self.assertFalse(report["physical_camera_clock_synchronized"])
        self.assertFalse(report["sensor_value_decoding_performed"])

    def test_gpmf_bad_size_or_padding_rejected(self):
        good = klv("DEVC", 0, 1, 12,
                   klv("TICK", ord("L"), 4, 1, b"\x00\x00\x00\x01"))
        with self.assertRaisesRegex(ValueError, "outside"):
            probe.inspect_gpmf_payload(
                good[:6] + struct.pack(">H", 200) + good[8:])
        with self.assertRaisesRegex(ValueError, "Expected GoPro DEVC"):
            probe.inspect_gpmf_payload(
                klv("STRM", 0, 1, 12,
                    klv("TICK", ord("L"), 4, 1, b"\x00\x00\x00\x01")))
        bad_padding = bytearray(klv("DEVC", 0, 1, 12,
                             klv("NAME", ord("c"), 1, 3, b"abc")))
        # corrupt actual nested padding, not its header
        bad_padding[8 + 8 + 3] = 1
        with self.assertRaisesRegex(ValueError, "padding"):
            probe.inspect_gpmf_payload(bytes(bad_padding))
        with self.assertRaises(ValueError):
            probe.inspect_gpmf_payload(b"abc")

    def test_mp4_stream_types_and_pts_irregularity(self):
        container = {
            "format": {"format_name": "mov,mp4,m4a,3gp,3g2,mj2"},
            "streams": [
                {"index": 0, "codec_type": "video",
                 "codec_name": "h264", "time_base": "1/90000",
                 "avg_frame_rate": "30000/1001",
                 "r_frame_rate": "30/1",
                 "width": 1920, "height": 1080},
                {"index": 1, "codec_type": "audio",
                 "codec_name": "aac"},
                {"index": 2, "codec_type": "data",
                 "codec_tag_string": "gpmd",
                 "tags": {"handler_name": "GoPro MET"}},
            ],
        }
        frames = {"frames": [
            {"best_effort_timestamp_time": "3.200000"},
            {"best_effort_timestamp_time": "3.233366"},
            {"best_effort_timestamp_time": "3.365000"},
        ]}
        out = probe.summarise_ffprobe(container, frames)
        self.assertTrue(out["gpmf_stream_detected"])
        self.assertEqual(out["stream_count"], 3)
        self.assertEqual(out["scanned_frame_rows"], 3)
        self.assertAlmostEqual(out["relative_sampled_pts_s"][-1], .165)
        self.assertAlmostEqual(out["sampled_delta_max_s"], .131634)
        self.assertFalse(out["sampled_frame_count_is_total_video_count"])
        self.assertFalse(out["camera_exposure_clock_synchronized"])
        self.assertFalse(out["underwater_intrinsic_extrinsic_refraction_calibrated"])
        self.assertEqual(out["streams"][2]["codec_tag_string"], "gpmd")

    def test_missing_sampled_pts_and_duplicate_timestamps(self):
        container = {"streams": [
            {"index": 0, "codec_type": "video", "codec_name": "h264"}]}
        x = probe.summarise_ffprobe(
            container, {"frames": [
                {"best_effort_timestamp_time": "0.0"},
                {"best_effort_timestamp_time": "N/A"},
                {"pts_time": "0.1"}]})
        self.assertEqual(x["missing_frame_pts_rows"], 1)
        self.assertEqual(x["finite_frame_pts_rows"], 2)
        self.assertFalse(x["gpmf_stream_detected"])
        with self.assertRaisesRegex(ValueError,
                                    "not strictly increasing"):
            probe.summarise_ffprobe(
                container, {"frames": [
                    {"best_effort_timestamp_time": "1.5"},
                    {"best_effort_timestamp_time": "1.5"}]})
        with self.assertRaisesRegex(ValueError, "video stream"):
            probe.summarise_ffprobe({"streams": []})
        with self.assertRaisesRegex(ValueError, "streams array"):
            probe.summarise_ffprobe({})


if __name__ == "__main__":
    unittest.main()
