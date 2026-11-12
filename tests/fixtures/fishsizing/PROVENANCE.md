# External camera calibration fixture provenance

These are unmodified, **real published** ROS camera calibration YAML files
for the FishSizing study, originally published at:

- https://github.com/Caterina1996/fish_sizing/blob/paper/paper/paper_dataset/dataset_to_zenodo/calibrations/dataset_1/2024_11_12/left.yaml
- https://github.com/Caterina1996/fish_sizing/blob/paper/paper/paper_dataset/dataset_to_zenodo/calibrations/dataset_1/2024_11_12/right.yaml

The source code repository describes MIT licensing. Respect the dataset's
terms and cite the FishSizing authors when using the calibration files.
Upstream Git blob SHAs inspected:
left d7640e5f97b5e7782584e77ac78d7648e33be3ef
right db5688f3812d81962caf2b64b2cb6f46ecdc7cb7

These are **camera calibration metadata**, not actual independent underwater
XYZ truth or real GoPro parameters. The reported stereo P translation does not
declare translation units. The files do not establish whether a physically
correct refraction model was fitted. No fish video/ROS bag image data copied.


Additional independently measured fish body-length reference fixture:
- fish_gt_measures.csv
- Upstream file: https://github.com/Caterina1996/fish_sizing/blob/paper/paper/paper_dataset/dataset_to_zenodo/gt_annotations_and_samples/fish_gt_measures.csv
- Byte-identical source Git blob: bcfef613e281a2c30f9858e1701624884e49423b
- Nine manually reported specimen total lengths, in cm, including decimal-comma values.
- Measurements provide BODY LENGTH reference only, not true fish XYZ,
  swimming trajectories or exposure-camera synchronization.
