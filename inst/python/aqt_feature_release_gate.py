#!/usr/bin/env python3
"""Fail-closed AquaTrajectories six-feature ENGINEERING release gate.

Runs actual original R, Python and Node tests, verifies required source
files and their SHA256, performs synthetic two-camera bundle->native R
integration, and (for a strict engineering release) runs R CMD check.
A code inventory or a self-declared evidence JSON never substitutes for
actual test results, independent physical XYZ, approved ACI hardware,
animal-welfare studies or blinded fish identity annotation.

Scientific release remains blocked by the existing nine-milestone
external validation gate. No automatic flipping of scientific flags.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time

FEATURES={
 "automatic_cross_camera_identity":{
   "files":["R/automatic-crossview-refractive.R",
            "man/aqt_refractive_view_candidates.Rd",
            "man/aqt_crossview_auto_associate.Rd",
            "man/aqt_auto_refractive_pipeline.Rd",
            "tests/testthat/test-automatic-crossview-refractive.R"],
   "tests":["native_auto_crossview"],
   "claims":"automatic geometric candidate identity; independent biological re-ID pending"},
 "automatic_original_video_to_refractive_3d":{
   "files":["inst/python/aqt_video_to_3d.py",
            "inst/exec/aqt_video_to_3d_native.R",
            "tests/python/fixture_stereo_bundles.py",
            "tests/python/test_video_to_3d.py"],
   "tests":["video_cli_contract","native_2d_to_3d_roundtrip"],
   "claims":"configured fish-specific YOLO, PyAV, ByteTrack and native R 3D; hardware accuracy pending"},
 "empirical_joint_measurement_uncertainty":{
   "files":["inst/python/aqt_joint_empirical_uncertainty.py",
            "tests/python/test_joint_empirical_uncertainty.py"],
   "tests":["joint_uncertainty_contract"],
   "claims":"empirical calibration algorithm; external independently surveyed XYZ pending"},
 "unified_multiview_3d_explorer":{
   "files":["inst/explorer/multiview.html",
            "inst/explorer/multiview-core.mjs",
            "tests/js/test-multiview-explorer.mjs"],
   "tests":["interactive_multiview_contract"],
   "claims":"read-only local researcher interface; real usability evaluation pending"},
 "physical_ACI_failsafe_bridge":{
   "files":["inst/python/aqt_aci_physical_controller.py",
            "tests/python/test_aci_physical_controller.py"],
   "tests":["aci_safe_controller_contract"],
   "claims":"opt-in serial hardware interface tested only with virtual device; real physical hardware, ethics and welfare pending"},
 "end_to_end_feature_release_qualification":{
   "files":["inst/python/aqt_feature_release_gate.py",
            "tests/python/test_feature_release_gate.py",
            "inst/evidence/scientific-validation-gates.json",
            "inst/python/aqt_scientific_release_gate.py"],
   "tests":["release_gate_contract","scientific_release_still_blocked"],
   "claims":"software feature build/release gates; all nine independent scientific validation milestones still open"}
}
SCIENTIFIC_FIELDS=[
 "external_fish_identity_independently_validated",
 "hardware_exposure_synchronization_certified",
 "physical_underwater_xyz_accuracy_certified",
 "joint_empirical_coverage_on_blind_independent_tanks_certified",
 "biological_behaviour_and_welfare_validated",
 "physical_aci_safety_ethics_certified",
 "independent_scientific_release_approved"
]
MAX_OUTPUT=3500

def hash_file(path):
    h=hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda:f.read(1<<20),b""):
            h.update(chunk)
    return h.hexdigest()

def _run(cmd,repo,timeout=180):
    start=time.monotonic()
    try:
        proc=subprocess.run(cmd,cwd=repo,stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE,text=True,
                            timeout=timeout,check=False)
        status="passed" if proc.returncode==0 else "failed"
        return {
            "status":status,"returncode":proc.returncode,
            "duration_s":round(time.monotonic()-start,3),
            "stdout_tail":proc.stdout[-MAX_OUTPUT:],
            "stderr_tail":proc.stderr[-MAX_OUTPUT:]}
    except FileNotFoundError as e:
        return {"status":"unavailable","returncode":None,
                "duration_s":round(time.monotonic()-start,3),
                "reason":"Required test runtime not installed: "+str(e)}
    except subprocess.TimeoutExpired:
        return {"status":"timed_out","returncode":None,
                "duration_s":round(time.monotonic()-start,3),
                "reason":"Feature qualification timed out; no green test inferred"}

def _checks(repo):
    py=sys.executable
    return {
      "native_auto_crossview":[
        "Rscript","-e",
        "pkgload::load_all('.',quiet=TRUE);"
        "testthat::test_file('tests/testthat/"
        "test-automatic-crossview-refractive.R',reporter='stop')"],
      "video_cli_contract":[py,"-m","unittest","discover","-s",
          "tests/python","-p","test_video_to_3d.py","-v"],
      "joint_uncertainty_contract":[py,"-m","unittest","discover","-s",
          "tests/python","-p","test_joint_empirical_uncertainty.py","-v"],
      "interactive_multiview_contract":["node","--test",
          "tests/js/test-explorer-core.mjs",
          "tests/js/test-multiview-explorer.mjs"],
      "aci_safe_controller_contract":[py,"-m","unittest","discover","-s",
          "tests/python","-p","test_aci_physical_controller.py","-v"],
      "release_gate_contract":[py,"-m","unittest","discover","-s",
          "tests/python","-p","test_feature_release_gate.py","-v"],
      "scientific_release_still_blocked":[py,
          "inst/python/aqt_scientific_release_gate.py",
          "--manifest","inst/evidence/scientific-validation-gates.json",
          "--mode","scientific_release"]}

def _native_roundtrip(repo):
    with tempfile.TemporaryDirectory(prefix="aqt-gate-stereo-") as td:
        source=Path(td)/"synthetic_sources"
        fixture=_run([sys.executable,
           "tests/python/fixture_stereo_bundles.py",str(source)],repo,90)
        if fixture["status"]!="passed":return {
            "status":"failed","stage":"original_synthetic_source_fixture",
            "fixture":fixture}
        config=source/"synthetic_video_3d_config.json"
        output=Path(td)/"source_verified_stereo_3d"
        engine=_run([sys.executable,
            "inst/python/aqt_video_to_3d.py",
            "--config",str(config),"--mode","prepared",
            "--output-dir",str(output)],repo,360)
        if engine["status"]!="passed":return {
            "status":"failed","stage":"actual_native_R_stereo_integration",
            "runner":engine}
        try:
            result=json.loads((output/"stereo_audit.json").read_text())
            if (result["n_3d_rows"]!=6 or
                result["n_provisional_pair_ids"]!=2 or
                result["biological_identity_certified"] is not False or
                result["underwater_physical_xyz_accuracy_certified"] is not False):
                raise ValueError("Native stereo 3D failed known synthetic truth or scientific contract")
            import csv
            with (output/"fish_3d_tracks.csv").open(newline="") as f:
                points=list(csv.DictReader(f))
            if len(points)!=6 or max(abs(float(p["z"])-5)
                                      for p in points)>1e-5:
                raise ValueError("Known synthetic 3D XYZ ground-truth recovery failed")
            return {"status":"passed","synthetic_3d_xyz_software_verified":True,
                    "original_physical_xyz_accuracy_verified":False}
        except (ValueError,KeyError,FileNotFoundError,TypeError) as e:
            return {"status":"failed","reason":str(e),
                    "original_physical_xyz_accuracy_verified":False}

def audit(repo,strict=False,run_tests=True):
    repo=Path(repo).resolve()
    if not (repo/"DESCRIPTION").is_file() or not (repo/"NAMESPACE").is_file():
        raise ValueError("Must run inside real AquaTrajectories R package repository")
    version=re.search(r"(?m)^Version:\s*(\S+)",(repo/"DESCRIPTION").read_text())
    if not version:raise ValueError("Missing R package source version")
    needed=sorted({p for f in FEATURES.values() for p in f["files"]})
    hashes={p:hash_file(repo/p) for p in needed if (repo/p).is_file()}
    missing=[p for p in needed if p not in hashes]
    tests={}
    steps=_checks(repo)
    if run_tests:
        # Only run tests whose own source dependencies exist.
        for name,cmd in steps.items():
            owners=[f for f in FEATURES.values() if name in f["tests"]]
            if any(any(p not in hashes for p in owner["files"]) for owner in owners):
                tests[name]={"status":"blocked","reason":"Required feature source files missing"}
                continue
            tests[name]=_run(cmd,repo,240)
            if name=="scientific_release_still_blocked":
                # A mandatory rejection (exit 2) is the PASS condition.
                # An accidental exit 0 is a critical scientific-release bug.
                check=tests[name]
                if check.get("returncode")==2:
                    check["status"]="passed"
                    check["scientific_release_is_fail_closed"]=True
                else:
                    check["status"]="failed"
                    check["scientific_release_is_fail_closed"]=False
        if all((repo/p).is_file() for p in [
            "inst/python/aqt_video_to_3d.py",
            "tests/python/fixture_stereo_bundles.py",
            "inst/exec/aqt_video_to_3d_native.R",
            "R/automatic-crossview-refractive.R"]):
            tests["native_2d_to_3d_roundtrip"]=_native_roundtrip(repo)
        else:
            tests["native_2d_to_3d_roundtrip"]={"status":"blocked",
               "reason":"Source video-to-3D integration files not present"}
    else:
        tests={name:{"status":"not_run"} for name in steps}
        tests["native_2d_to_3d_roundtrip"]={"status":"not_run"}
    result={}
    for key,entry in FEATURES.items():
        source_ok=all(p in hashes for p in entry["files"])
        tested=all(tests.get(name,{}).get("status")=="passed"
                   for name in entry["tests"])
        result[key]={
            "all_required_source_files_present":source_ok,
            "actual_contract_tests_passed":tested,
            "engineering_feature_qualified":source_ok and tested,
            "scientific_limit":entry["claims"],
            "requirements":entry["files"],
            "tests":entry["tests"]}
    complete=all(e["engineering_feature_qualified"] for e in result.values())
    package_check={"status":"not_run"}
    if strict and complete:
        package_check=_run(["R","CMD","check","--no-manual","."],
                           repo,1200)
        complete=package_check["status"]=="passed"
    elif strict:package_check={"status":"blocked",
         "reason":"Feature source/tests do not all qualify; R CMD check not substitute"}
    return {
        "schema":"aqt_engineering_feature_release_v1",
        "package_version":version.group(1),
        "n_required_software_features":len(FEATURES),
        "n_qualified_software_features":sum(
            x["engineering_feature_qualified"] for x in result.values()),
        "all_six_engineering_features_qualified":complete,
        "source_tree_sha256":hashlib.sha256(
            "\n".join(f"{k}\t{v}" for k,v in sorted(hashes.items()))
            .encode()).hexdigest(),
        "required_source_sha256":hashes,
        "missing_software_source_files":missing,
        "source_verification_tests":tests,
        "package_R_CMD_check":package_check,
        "features":result,
        "all_independent_scientific_certifications":{
           key:False for key in SCIENTIFIC_FIELDS},
        "scientific_release_permitted":False,
        "engineering_CI_passing_does_not_prove_physical_fish_accuracy":True,
        "source_training_test_data_included":False,
        "original_video_weights_or_personal_metadata_included":False}

def make_archive(repo,output,report):
    if not report["all_six_engineering_features_qualified"]:
        raise RuntimeError("Cannot archive unqualified AquaTrajectories software")
    if output.exists():raise FileExistsError("Refuse overwrite engineering release")
    repo=Path(repo).resolve()
    allow=set(report["required_source_sha256"])
    allow.update(("DESCRIPTION","NAMESPACE","LICENSE"))
    # Source-only distribution, no data, video, model weights, GitHub
    # secrets or source images. Native R package itself retains a
    # separate R CMD check / licensing release process.
    output.parent.mkdir(parents=True,exist_ok=True)
    with tarfile.open(output,"w:gz") as tar:
        for path in sorted(allow):
            source=repo/path
            if not source.is_file() or source.is_symlink() or (
                not source.resolve().is_relative_to(repo)):
                raise ValueError("Unsafe release source path")
            tar.add(source,arcname="AquaTrajectories/"+path,recursive=False)
    return hash_file(output)

def main(argv=None):
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--repo",type=Path,default=Path(__file__).resolve().parents[2])
    ap.add_argument("--mode",
      choices=("inventory","feature_release","scientific_release"),
      default="inventory")
    ap.add_argument("--no-tests",action="store_true",
      help="Inventory without testing; NEVER qualifies engineering features")
    ap.add_argument("--report",type=Path)
    ap.add_argument("--archive",type=Path)
    args=ap.parse_args(argv)
    if args.report is not None and args.report.exists():
        raise FileExistsError("Never overwrite engineering feature qualification evidence")
    strict=args.mode=="feature_release"
    report=audit(args.repo,strict=strict,run_tests=not args.no_tests)
    if args.mode=="scientific_release":
        # The existing independent scientific gate rejects unaudited physical
        # or biological claims irrespective of software completeness.
        report["scientific_release_permitted"]=False
        report["reason_scientific_release_blocked"]=( 
           "No independent surveyed XYZ, true hardware exposure synchronization, "
           "blinded real fish IDs, welfare/ACI trials, or external certification.")
    if args.archive is not None:
        if not strict or not report["all_six_engineering_features_qualified"]:
            raise RuntimeError("An engineering release archive requires six ACTUAL passing features and R CMD check")
        report["engineering_source_archive_sha256"]=make_archive(
            args.repo,args.archive,report)
    if args.report:
        args.report.parent.mkdir(parents=True,exist_ok=True)
        args.report.write_text(json.dumps(report,indent=2,sort_keys=True)+"\n")
    else:
        print(json.dumps({
           "qualified_engineering_features":report["n_qualified_software_features"],
           "required_features":6,
           "all_six_qualified":report["all_six_engineering_features_qualified"],
           "scientific_release_permitted":False,
           "missing":report["missing_software_source_files"]},
           indent=2,sort_keys=True))
    if args.mode=="scientific_release":return 2
    if args.mode=="feature_release" and not report["all_six_engineering_features_qualified"]:
        return 3
    return 0

if __name__=="__main__":raise SystemExit(main())
