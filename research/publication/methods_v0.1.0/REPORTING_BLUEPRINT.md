# Manuscript results, figures and supplementary tables — empty reporting blueprint

**NO EMPIRICAL RESULT HAS BEEN ENTERED.** The following are publication layouts, not results. Every value must be derived from independently traceable records and reviewed before a journal submission.

## Table 1 — Software modules and validation level

| Module | Public API/contract | Software-qualified | Real-source probe | Independent empirical validation |
| --- | --- | --- | --- | --- |
| Source video + frame clock | Python bundle, frame PTS manifest | Yes (scope-specific tests) | Oxford source | **Pending** |
| Fish detector + camera-local track | External model/ByteTrack interface | Yes (scope-specific tests) | Oxford / Fraunhofer source | **Pending** |
| Independent identity metrics | Official TrackEval adapter | Yes (known-truth tests) | Real source labels / model | **Pending prediction-blind GT** |
| Multi-camera synchronization | Marker-based fit and heldout contract | Yes | Source structure only | **Pending physical pulses** |
| Refractive 3D | Calibrated camera / target benchmark | Yes | 3D-ZeF source-label formats | **Pending surveyed XYZ** |
| Joint sensitivity | Pixel, ID, timing and optics scenarios | Yes | Conditional scenarios | **Pending empirical coverage** |
| Event analysis / tank inference | R movement, event, statistical models | Yes | Synthetic studies | **Pending replicated tanks and biological labels** |
| ACI | Offline/dry-run safety contracts | Yes (simulated) | No certified hardware | **Pending physical safety and ethics** |

Use precise test/commit references when finalizing the table; "Yes" above refers only to software contract status described by repository docs and must not be represented as validation of outputs.

## Table 2 — End-to-end fish detection (DO NOT FILL FROM SOURCE LABEL ORACLES)

| Dataset and split | Independently reviewed? | Original video SHA | N frames (incl empty) | N GT fish boxes | TP | FP | FN | Precision | Recall | F1 | AP50 | AP75 | 95% recording-level CI |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [UNASSIGNED HELDOUT] | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |

Specify model/weights SHA and exact operating point. Original source-label agreement can be a **separate** explicitly qualified table.

## Table 3 — Tracking, same frozen detections

| Heldout recording | Source independent IDs? | Tracker | HOTA | DetA | AssA | IDF1 | MOTA | IDSW | Fragmentations | Full-frame coverage | Review caveat |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [UNASSIGNED] | PENDING | ByteTrack | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |
| [SAME RECORDING] | PENDING | IoU/Hungarian | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |

Clearly separate **model-produced boxes** from perfect-box oracle association. Report paired recording-level contrast.

## Table 4 — Physical exposure synchronization

| Camera session | Actual marker source | Fit pulses | Heldout pulses | Holdout RMSE (ms) | Max abs error (ms) | Estimated drift (ppm) | Unmatched pulse count | Clock limitations |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [UNMEASURED] | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |

Never report MP4 PTS as independent proof of simultaneous shutter exposures.

## Table 5 — Underwater physical XYZ accuracy

| Holdout target assembly | Camera rig / optical geometry | N eligible surveyed targets | N valid | Invalid fraction | Signed bias X/Y/Z (units) | RMSE X/Y/Z | 3D RMSE | 3D MAE | Error by depth / edge |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [NO SURVEYED DATA] | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |

For the paper, use a precise unit (cm, mm, m) and a blinded, separately surveyed target assembly. Ray separation is not physical XYZ RMSE.

## Table 6 — Calibrated uncertainty and downstream inference

| Heldout domain | True error source | Nominal interval | Observed coverage | Mean interval width | N independent trials | Measurement uncertainty propagated to | Limitations |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [NO HELDOUT TRUTH] | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |

If no independent calibration data, retain scenario-sensitivity results in a **different table** titled "Conditional sensitivity, not empirical interval coverage."

## Figure plan

**Figure 1** modular architecture and data/claim boundaries (from source contracts; can be drawn now).  
**Figure 2** actual frozen detector boxes versus prediction-blind human annotations on permitted source frames (requires rights and GT).  
**Figure 3** tracking HOTA/DetA/AssA/IDF1 and identity failure strata across heldout recordings (requires real independent multi-fish identity).  
**Figure 4** two-camera physical experiment, timestamp residuals and disjoint surveyed XYZ depth-error map (requires new rig data).  
**Figure 5** independent empirical coverage-versus-width and movement/event sensitivity (requires heldout measured errors).  
**Figure 6 (optional)** reproducible researcher GUI/reviewer trace (may show synthetic demonstration but must be labeled synthetic).

## Supplementary materials

- S1: original data acquisition/rights/frame/split manifests with hashes.
- S2: model weights/process settings and pinned TrackEval/ByteTrack versions.
- S3: fully enumerated evaluation-frame GT and annotation adjudication protocol.
- S4: calibration fit/holdout target board and verified exposure marker audit.
- S5: numerical error definitions and statistical implementation.
- S6: all result outputs and figure reproduction logs, with permitted source references.
- S7: environment, package, source, and review sign-offs; limitations and deviations log.
- S8: preregistration receipt or clearly stated non-preregistration if it was not done.

**Results must remain PENDING until actual evidence exists.**
