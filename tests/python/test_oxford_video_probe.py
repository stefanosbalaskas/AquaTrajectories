"""Wave 12B: Oxford source ZIP and camera-local PTS qualification contracts."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    "aqt_oxford_video_probe", ROOT/"inst/python/aqt_oxford_video_probe.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class OxfordRealVideoContracts(unittest.TestCase):
    def make_zip(self, temp, name="eval/recording.mp4"):
        path = Path(temp)/"eval.zip"
        with zipfile.ZipFile(path, "w") as z:
            z.writestr(name, b"\x00" * 512, compress_type=zipfile.ZIP_DEFLATED)
        return path

    def test_safe_archive_and_source_members(self):
        with tempfile.TemporaryDirectory() as temp:
            archive = self.make_zip(temp)
            self.assertEqual(mod.video_members(archive), ["eval/recording.mp4"])
        with tempfile.TemporaryDirectory() as temp:
            archive = self.make_zip(temp, name="../escape.mov")
            with self.assertRaisesRegex(ValueError, "Unsafe"):
                mod.video_members(archive)

    def test_exact_decode_clock_and_refuse_guessed_fps(self):
        streams = {"streams":[{"codec_name":"h264","width":1920,"height":1080,
                               "time_base":"1/90000","avg_frame_rate":"30/1"}]}
        frames = {"frames":[{"best_effort_timestamp_time":"120.001"},
                            {"best_effort_timestamp_time":"120.033"},
                            {"best_effort_timestamp_time":"120.102"}]}
        info, pts = mod.parse_probe(streams, frames)
        self.assertEqual(pts[0],0)
        self.assertAlmostEqual(pts[-1],.101)
        self.assertEqual(info["stream_nominal_fps"],"30/1")
        self.assertEqual(info["n_decoded_frame_timestamps"],3)
        self.assertNotAlmostEqual(pts[2],2/30)
        with self.assertRaisesRegex(ValueError, "Non-increasing"):
            mod.parse_probe(streams,{"frames":[
                {"best_effort_timestamp_time":"1"},
                {"best_effort_timestamp_time":"1"}]})
        with self.assertRaisesRegex(ValueError,"No decoded timestamp"):
            mod.parse_probe(streams,{"frames":[{}]})
        with self.assertRaisesRegex(ValueError,"Invalid original video"):
            mod.parse_probe({"streams":[{"codec_name":"h264","width":0,
                                       "height":100}]},frames)

    def test_source_to_csv_and_sha_mock_decoder_is_not_real_accuracy(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            archive=self.make_zip(temp)
            output=root/"result"
            expected=([0, .033, .074])
            def fake_probe(path):
                return dict(codec="h264",width_px=200,height_px=100,
                            stream_time_base="1/90000",stream_nominal_fps="30/1",
                            n_decoded_frame_timestamps=3,
                            first_original_pts_seconds=4,
                            last_original_pts_seconds=4.074),expected
            with patch.object(mod,"run_ffprobe",side_effect=fake_probe):
                with patch.object(mod,"decode_one_real_frame") as decode:
                    report=mod.record_one(archive,output)
                    decode.assert_called_once()
            self.assertTrue((output/"audit.json").is_file())
            self.assertEqual(report["frame_count"],3)
            self.assertEqual(report["source_archive_video_members"],1)
            self.assertFalse(report["fish_detection_or_track_identity_accuracy_certified"])
            self.assertEqual(mod.digest(output/"frames.csv"),report["frame_manifest_sha256"])
            import csv
            with (output/"frames.csv").open(newline="") as f:
                rows=list(csv.DictReader(f))
            self.assertEqual(len(rows),3)
            self.assertEqual([int(row["frame_id"]) for row in rows],[0,1,2])
            self.assertEqual([float(row["time_s"]) for row in rows],expected)
            with self.assertRaises(FileExistsError):
                mod.record_one(archive,output)

    def test_ffprobe_json_and_first_frame_decode_invocations(self):
        with tempfile.TemporaryDirectory() as temp:
            input_path=Path(temp)/"clip.mp4"
            input_path.write_bytes(b"\0"*256)
            def mock_run(args, **kwargs):
                if args[0] == "ffmpeg":
                    return subprocess.CompletedProcess(args,0,b"",b"")
                if "-show_frames" in args:
                    out={"frames":[{"best_effort_timestamp_time":"0"},
                                   {"best_effort_timestamp_time":"0.042"}]}
                else:
                    out={"streams":[{"codec_name":"h264","width":200,
                                     "height":100,"avg_frame_rate":"24/1",
                                     "time_base":"1/90000"}]}
                return subprocess.CompletedProcess(args,0,json.dumps(out),"")
            with patch.object(mod.subprocess,"run",side_effect=mock_run) as run:
                info, clock=mod.run_ffprobe(input_path)
                mod.decode_one_real_frame(input_path)
            self.assertEqual(run.call_count,3)
            self.assertEqual(clock,[0,.042])
            self.assertEqual(info["codec"],"h264")


if __name__ == "__main__":
    unittest.main()
