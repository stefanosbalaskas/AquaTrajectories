# Wave 15E — executable six-feature engineering release qualification

The original nine-scientific-milestone
`inst/python/aqt_scientific_release_gate.py` remains deliberately
**fail-closed**: a passing R/Python package and source-code
inventory does not independently prove physical fish tracking
or animal welfare. That important protection is retained.

New `inst/python/aqt_feature_release_gate.py` adds a separate,
real **engineering software feature-completeness release**:
all six software features must exist **and pass actual tests**,
including the original two-source video-bundle → native R
geometric fish identity → refractive 3D known-truth integration
and a standard R package check.

## Exact six feature-completeness gates

| Gate | Executable evidence required |
|---|---|
| Automatic cross-camera fish identities | 3 exported native R geometrical fish association functions, .Rd manuals, ambiguity/track-ID known-truth R tests |
| Configured original-video to refractive 3D | Python PyAV/YOLO/ByteTrack wrapper, source SHA-verifying bundles, native R reconstruction, synthetic two-camera **actual CLI/R roundtrip** |
| Empirical joint uncertainty | Python linked detection/ID/clock/pixel/XYZ residuals, tank-blocked source conformal calculations, missing fish and holdout-leakage tests |
| Unified multiview interactive 3D explorer | Complete local HTML/JS application, Node original-clock, 3D trajectory, source-link and uncertainty tests |
| Opt-in ACI hardware bridge | pyserial AQT1 protocol, hard interlock/feedback/estop controller with virtual-device test suite; **no real device certification** |
| Scientific and engineering release gates | Current nine-science-category fail-closed evidence, explicit mandatory exit-2 scientific release rejection, full feature-gate regression tests |

The feature gate hashes every required **actual source file** from
the current checkout, checks each test's exit status and captures
its real output/return code; a source file's mere existence
can never qualify a feature. A missing Rscript, Node, runtime,
test failure or absent cross-language source bundle returns
`blocked`, `unavailable` or `failed`, not green.

For the two-camera end-to-end test it builds **two synthetic
camera-local video bundles** with original-style PTS and
SHA-256, calls the public Python CLI and the actual native
R triangulator, and requires both 3D fish trajectories to be
recovered at known 5 cm depth with no invented biological
identity certification.

## Modes

```bash
# Inspect available features; honestly mark tests unrun when specified.
python inst/python/aqt_feature_release_gate.py \
  --mode inventory --no-tests \
  --report /tmp/feature_inventory.json

# Qualify all real tests and require R CMD check before software archive.
python inst/python/aqt_feature_release_gate.py \
  --mode feature_release \
  --report /tmp/engineering_qualification.json \
  --archive /tmp/AquaTrajectories_engineering_source.tar.gz

# This must return exit code 2 until independent fish, physical XYZ,
# real hardware E-stop and animal welfare evidence exists.
python inst/python/aqt_feature_release_gate.py \
  --mode scientific_release --no-tests
```

The strict engineering release requires **six actual software
test successes**, real native R integration, and an actual
R CMD check. It refuses to create a source archive from
incomplete or unqualified features. Any source archive includes
an **explicit whitelist of package source code, manuals and
unit tests**; no user/source videos, fish detector weights,
tokens, original copyrighted annotations or actual live
ACI device events are bundled by this feature archive.

## Automated GitHub Actions contract

The new workflow on PR runs real release-gate software tests,
checks scientific-release rejection and publishes a truthful
inventory even while dependent Wave15 PRs have not merged.

On main when all six source modules are present, it runs
the **full strict engineering release and only publishes
an engineering source artifact after all real test steps pass**.
Until every dependency is merged/qualifies, it generates an
inventory with the missing features and **does not** publish
an engineering release or claim software feature completeness.

A source archive is not a formally reviewed CRAN release
or journal-ready biological/physical validation. Hardware
approval, shutter exposure timing, independently surveyed 3D
XYZ, detector/ID holdouts, fish ethology and real ACI animal
experiments remain external requirements. Issue #51 stays open.
