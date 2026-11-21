#!/usr/bin/env python3
"""Fail-closed static API inventory, not an invented executed-coverage report.

Generated source matrix inventories every current exported R function, its
R definition(s), Rd aliases and the number of test files merely mentioning it.
A code/text mention is NEVER claimed as actual test execution. Optional
measured function-execution evidence may be supplied separately later.
"""
import argparse
import csv
import hashlib
import json
import re
from pathlib import Path

EXPORT = re.compile(r'^export\(([^()]+)\)$', re.MULTILINE)

def audit(root):
    root = Path(root)
    ns = (root / 'NAMESPACE').read_text(encoding='utf-8')
    exports = EXPORT.findall(ns)
    if not exports or len(exports) != len(set(exports)):
        raise ValueError('Missing/duplicate exported R APIs')
    sources = {p.relative_to(root).as_posix(): p.read_text(encoding='utf-8')
               for p in (root / 'R').glob('*.R')}
    tests = {p.name:p.read_text(encoding='utf-8')
             for p in (root / 'tests/testthat').glob('test-*.R')}
    manuals = {p.name:p.read_text(encoding='utf-8')
               for p in (root / 'man').glob('*.Rd')}
    rd_alias = {}
    for name, contents in manuals.items():
        for alias in re.findall(r'\\alias\{([^{}]+)\}', contents):
            rd_alias.setdefault(alias, []).append(name)
    rows = []
    for f in exports:
        pattern = re.compile(r'(?m)^\s*' + re.escape(f) +
                             r'\s*(?:<-|=)\s*function\s*\(')
        def_files = [name for name, text in sources.items() if pattern.search(text)]
        mention_files = [name for name, text in tests.items()
                         if re.search(r'\b' + re.escape(f) + r'\s*\(', text)]
        rows.append({
            'export':f,
            'source_definitions':';'.join(def_files),
            'n_defining_files':len(def_files),
            'rd_manuals':';'.join(rd_alias.get(f, [])),
            'has_rd_alias':bool(rd_alias.get(f)),
            'test_files_with_lexical_mentions':len(mention_files),
            'mention_files':';'.join(mention_files),
            'executed_code_coverage':'NOT_MEASURED',
            'independent_numerical_oracle':'NOT_ASSESSED_BY_THIS_AUDIT',
            'physical_biological_validation':'NOT_ASSESSED_BY_THIS_AUDIT',
        })
    return rows

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--root',default='.')
    ap.add_argument('--out',required=True)
    ap.add_argument('--strict',action='store_true')
    args=ap.parse_args()
    rows=audit(args.root)
    out=Path(args.out)
    if out.exists():raise SystemExit('Refusing to overwrite source audit')
    if not out.parent.exists():raise SystemExit('Audit parent missing')
    out.mkdir()
    with (out/'API_EVIDENCE_MATRIX.csv').open('w',encoding='utf-8',newline='') as fd:
        wr=csv.DictWriter(fd,fieldnames=list(rows[0]))
        wr.writeheader();wr.writerows(rows)
    deficits=[r['export'] for r in rows if not r['has_rd_alias'] or not r['n_defining_files']]
    manifest={'schema':'AQT_CORE2_API_AUDIT_V1','exports':len(rows),
              'defined_in_source':sum(bool(r['n_defining_files']) for r in rows),
              'documented_with_rd_alias':sum(r['has_rd_alias'] for r in rows),
              'mentioned_in_test_files_not_executed_coverage':sum(bool(r['test_files_with_lexical_mentions']) for r in rows),
              'execution_coverage_not_measured':True,
              'independent_oracle_status_not_inferred_from_mentions':True,
              'unresolved_source_or_manual':deficits}
    manifest['namespace_sha256']=hashlib.sha256((Path(args.root)/'NAMESPACE').read_bytes()).hexdigest()
    (out/'API_AUDIT_SUMMARY.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(manifest,indent=2))
    if args.strict and deficits:raise SystemExit('Missing source function definition or Rd alias: '+', '.join(deficits))

if __name__=='__main__':main()
