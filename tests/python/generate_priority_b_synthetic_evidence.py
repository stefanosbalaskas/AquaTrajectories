#!/usr/bin/env python3
"""Generate visibly synthetic three-method benchmark evidence for CI ONLY."""
import argparse
import json
from pathlib import Path
from test_priority_b_protocol import TestPriorityB
import aqt_priority_b_benchmark as b
import aqt_priority_b_report as tab

def main():
    p=argparse.ArgumentParser();p.add_argument("--output",type=Path,required=True)
    a=p.parse_args()
    if a.output.exists():raise FileExistsError("Refuse overwrite synthetic evidence")
    a.output.mkdir(parents=True)
    spec=TestPriorityB().build_fixture(a.output)
    (a.output/"protocol.json").write_text(json.dumps(spec,indent=2,sort_keys=True)+"\n")
    b.freeze(a.output,spec,a.output/"inputs.lock.json")
    report=b.compare(a.output,spec,json.loads((a.output/"inputs.lock.json").read_text()))
    report["source_kind"]="SYNTHETIC_KNOWN_TRUTH_ONLY"
    report["empirical_model_execution_performed"]=False
    report["training_performed"]=False
    (a.output/"SYNTHETIC_BENCHMARK_REPORT.json").write_text(
        json.dumps(report,indent=2,sort_keys=True,allow_nan=False)+"\n")
    info=tab.write_table(a.output/"SYNTHETIC_BENCHMARK_REPORT.json",
                         a.output/"SYNTHETIC_ONLY_COMPARATIVE_TABLE.csv")
    assert info["rows"]==3 and not info["independent_real_accuracy_certified"]
    print("SYNTHETIC THREE-METHOD SCORE CONTRACT PASS; NOT REAL TRACKER ACCURACY")

if __name__=="__main__":main()
