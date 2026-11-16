# How two camera rays become a 3D coordinate

Phase 3 · Research laboratory · transparent evidence boundaries

# How two camera rays become a 3D coordinate

An interactive 3D \*teaching\* reconstruction: two idealized cameras
**above** a planar air–water surface observe one known synthetic fish
position below it. The browser solves Snell's law at a **single
interface**, refracts perturbed incident rays and finds their
closest-point midpoint. This is not a fitted underwater GoPro
flat-port/glass camera calibration.

## Optical and camera inputs

Camera baseline (cm)

Height above water (cm)

Fish depth below surface (cm)

Fish X (cm)

Fish Y (cm)

Water refractive index

Illustrative image localization perturbation (px)

Effective focal scaling (px)

Reset scenario

## 3D ray geometry · rotatable projection

KNOWN SYNTHETIC TRUTH

![](data:image/svg+xml;base64,PHN2ZyBpZD0iZ2VvbWV0cnlTY2VuZSIgdmlld2JveD0iMCAwIDEwMDAgNjEwIiByb2xlPSJpbWciIGFyaWEtbGFiZWxsZWRieT0iZ2VvbWV0cnlUaXRsZSBnZW9tZXRyeURlc2NyaXB0aW9uIj48dGl0bGUgaWQ9Imdlb21ldHJ5VGl0bGUiPlJlZnJhY3RlZCB0d28tY2FtZXJhIGdlb21ldHJ5PC90aXRsZT4KPGRlc2MgaWQ9Imdlb21ldHJ5RGVzY3JpcHRpb24iPlR3byBhYm92ZS13YXRlciBjYW1lcmFzLCBhIHBsYW5hciB3YXRlciBpbnRlcmZhY2UsIGEga25vd24gc3ludGhldGljIHVuZGVyd2F0ZXIgZmlzaCwgdHdvIHJlZnJhY3RlZCByYXlzIGFuZCBhIHJlY29uc3RydWN0ZWQgcG9pbnQuPC9kZXNjPjxyZWN0IHg9IjAiIHk9IjAiIHdpZHRoPSIxMDAwIiBoZWlnaHQ9IjYxMCIgcng9IjE2IiBmaWxsPSIjMGIyODNkIiAvPjxnIGlkPSJnZW9tZXRyeUl0ZW1zIj48L2c+PC9zdmc+)

Viewing azimuth

Viewing elevation

Reconstructed X/Y/Z (cm)**—**

Ray separation (cm)**—**

Known synthetic XYZ error (cm)**—**

Ray geometry**—**

## What is physically specified?

n_air sin(θ_air) = n_water sin(θ_water)   •   rᵢ(λ) = oᵢ + λ dᵢ   •   X̂
= (r₁(λ\*) + r₂(μ\*))/2

The transmitted ray uses the tangential Snell component and a negative
vertical component. The estimator minimizes squared distance between the
two transmitted rays and abstains when they are nearly parallel or
intersect only behind the interface. The image perturbation is
deterministic and illustrative, not a calibrated detector
measurement-error distribution.

**Limits:** no thick glass, housing port, Brown lens distortion, real
GoPro intrinsics, physical survey, detector model or real cross-camera
identity matching. The synthetic XYZ error is calculated because the
synthetic truth is known; it is *not empirical underwater accuracy*.

[Released refractive triangulation
documentation](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_refractive_triangulate.md)
· [Multiview
workflow](https://stefanosbalaskas.github.io/AquaTrajectories/articles/multiview-3d.md)
· [Inspect multiview files
locally](https://stefanosbalaskas.github.io/AquaTrajectories/research-multiview.md)
