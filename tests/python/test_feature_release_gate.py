"""Fail-closed release inventory, actual-test contracts and scientific embargo."""
import json
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"inst/python"))
import aqt_feature_release_gate as m

def source_repo(root,all_files=False):
    (root/"DESCRIPTION").write_text(
        "Package: aquaTrajectories\nVersion: 0.0.35.9000\n")
    (root/"NAMESPACE").write_text("# authored fixture\n")
    (root/"LICENSE").write_text("MIT source fixture")
    if all_files:
        for feature in m.FEATURES.values():
            for rel in feature["files"]:
                p=root/rel;p.parent.mkdir(parents=True,exist_ok=True)
                p.write_text("synthetic exact source-only test artifact")
    return root

class ScientificEngineeringGate(unittest.TestCase):
    def test_strict_package_check_uses_built_tarball_and_rejects_notes(self):
        # The raw-source 'R CMD check .' differs from the standard
        # build-then-check pipeline. Capture the actual command used.
        with tempfile.TemporaryDirectory() as td:
            root=source_repo(Path(td),all_files=True)
            calls=[]
            def fake_run(cmd,repo,timeout=180):
                calls.append(cmd)
                if "--mode" in cmd and "scientific_release" in cmd:
                    return {"status":"failed","returncode":2}
                return {"status":"passed","returncode":0}
            with patch.object(m,"_run",side_effect=fake_run),patch.object(
                m,"_native_roundtrip",return_value={"status":"passed"}):
                report=m.audit(root,run_tests=True,strict=True)
            checks=[x for x in calls if "rcmdcheck::rcmdcheck" in " ".join(x)]
            self.assertEqual(len(checks),1)
            self.assertEqual(checks[0][:3],["Rscript","--vanilla","-e"])
            self.assertIn("--no-manual",checks[0][3])
            self.assertIn("notes=length(x$notes)",checks[0][3])
            self.assertIn("if(any(n>0L))",checks[0][3])
            self.assertTrue(report["all_six_engineering_features_qualified"])
            self.assertEqual(report["package_R_CMD_check"]["status"],"passed")

    def test_windows_legacy_codepage_cannot_crash_subprocess_evidence(self):
        # On Greek Windows cp1253, byte 0x9f is not decodable by the
        # subprocess default text codec. Valid UTF-8 output must also survive.
        for exit_code in (0, 7):
            with self.subTest(exit_code=exit_code):
                child = (
                    "import sys; "
                    "sys.stdout.buffer.write(bytes([0xe2,0x9c,0x93,0x9f])); "
                    "sys.stderr.buffer.write(bytes([0x9f])); "
                    f"sys.exit({exit_code})"
                )
                outcome = m._run([sys.executable, "-c", child], ROOT, 20)
                self.assertEqual(outcome["returncode"], exit_code)
                self.assertEqual(outcome["status"],
                                 "passed" if exit_code == 0 else "failed")
                self.assertIn("\u2713", outcome["stdout_tail"])
                self.assertIn("\ufffd", outcome["stdout_tail"])
                self.assertIn("\ufffd", outcome["stderr_tail"])

    def test_all_required_features_incomplete_when_source_or_tests_missing(self):
        with tempfile.TemporaryDirectory() as td:
            root=source_repo(Path(td))
            report=m.audit(root,run_tests=False)
            self.assertEqual(report["n_required_software_features"],6)
            self.assertEqual(report["n_qualified_software_features"],0)
            self.assertFalse(report["all_six_engineering_features_qualified"])
            self.assertTrue(report["missing_software_source_files"])
            self.assertFalse(report["scientific_release_permitted"])
            self.assertTrue(all(v is False for v in
                report["all_independent_scientific_certifications"].values()))

    def test_real_source_plus_real_test_success_required_for_feature_complete(self):
        with tempfile.TemporaryDirectory() as td:
            root=source_repo(Path(td),all_files=True)
            fake={"status":"passed","returncode":0,"stdout_tail":"","stderr_tail":""}
            good={"status":"passed","synthetic_3d_xyz_software_verified":True,
                  "original_physical_xyz_accuracy_verified":False}
            def qualified(cmd,repo,timeout=180):
                if "--mode" in cmd and "scientific_release" in cmd:
                    return {"status":"failed","returncode":2}
                return fake
            with patch.object(m,"_run",side_effect=qualified),patch.object(
                m,"_native_roundtrip",return_value=good):
                report=m.audit(root,run_tests=True,strict=True)
            self.assertEqual(report["n_qualified_software_features"],6)
            self.assertTrue(report["all_six_engineering_features_qualified"])
            self.assertEqual(report["package_R_CMD_check"]["status"],"passed")
            self.assertFalse(report["scientific_release_permitted"])

    def test_scientific_gate_must_fail_exactly_exit2_not_fake_green(self):
        with tempfile.TemporaryDirectory() as td:
            root=source_repo(Path(td),all_files=True)
            normal={"status":"passed","returncode":0}
            with patch.object(m,"_run",return_value=normal),patch.object(
                m,"_native_roundtrip",return_value={"status":"passed"}):
                report=m.audit(root,run_tests=True)
            self.assertFalse(report["features"][
                "end_to_end_feature_release_qualification"]["engineering_feature_qualified"])
            def real_fail(cmd,repo,timeout=180):
                if "--mode" in cmd and "scientific_release" in cmd:
                    return {"status":"failed","returncode":2}
                return {"status":"passed","returncode":0}
            with patch.object(m,"_run",side_effect=real_fail),patch.object(
                m,"_native_roundtrip",return_value={"status":"passed"}):
                repaired=m.audit(root,run_tests=True)
            self.assertTrue(repaired["features"][
                "end_to_end_feature_release_qualification"]["engineering_feature_qualified"])
            self.assertFalse(repaired["scientific_release_permitted"])

    def test_six_features_are_not_claimed_without_actual_test_execution(self):
        with tempfile.TemporaryDirectory() as td:
            root=source_repo(Path(td),all_files=True)
            out=root/"audit.json"
            code=m.main(["--repo",str(root),"--mode","feature_release",
                         "--no-tests","--report",str(out)])
            self.assertEqual(code,3)
            report=json.loads(out.read_text())
            self.assertEqual(report["n_qualified_software_features"],0)
            self.assertEqual(report["package_R_CMD_check"]["status"],"blocked")
            with self.assertRaisesRegex(FileExistsError,"overwrite"):
                m.main(["--repo",str(root),"--mode","inventory",
                        "--no-tests","--report",str(out)])
            self.assertEqual(m.main(["--repo",str(root),
                "--mode","scientific_release","--no-tests"]),2)

    def test_engineering_release_archive_cannot_include_data_or_secrets(self):
        with tempfile.TemporaryDirectory() as td:
            root=source_repo(Path(td),all_files=True)
            user_data=root/"original_secret_fish.mp4"
            user_data.write_bytes(b"Not to be copied into release")
            source_files={rel:m.hash_file(root/rel)
                          for v in m.FEATURES.values() for rel in v["files"]}
            report={"all_six_engineering_features_qualified":True,
                    "required_source_sha256":source_files}
            archive=root/"source_release.tar.gz"
            sha=m.make_archive(root,archive,report)
            self.assertEqual(sha,m.hash_file(archive))
            with tarfile.open(archive) as t:
                names=t.getnames()
            self.assertTrue(all(x.startswith("aquaTrajectories/") for x in names))
            self.assertFalse(any("secret" in name or name.endswith(".mp4")
                                 for name in names))
            self.assertTrue(any(x.startswith("aquaTrajectories/R/")
                                for x in names))
            self.assertTrue(any(x.startswith("aquaTrajectories/man/")
                                for x in names))
            with self.assertRaisesRegex(FileExistsError,"overwrite"):
                m.make_archive(root,archive,report)

if __name__=="__main__":
    unittest.main()
