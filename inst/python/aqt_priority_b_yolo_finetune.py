#!/usr/bin/env python3
"""Train fish-specific YOLO ONLY on frozen disjoint train/validation recordings.

Training is opt-in and requires actual image bytes, YOLO labels and pretrained
weights. Held-out test frames NEVER enter the stage or the training data YAML.
The script does not create a trained model merely by being installed.
"""
from __future__ import annotations
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path
import shutil
import time
import re

from aqt_priority_b_splits import validate_split
from aqt_official_fish_trackeval import digest

COLUMNS=["split","source_video_sha256","frame",
         "image_path","label_path","image_sha256","label_sha256"]
SUFFIXES={".jpg",".jpeg",".png",".bmp"}

def source_file(root,name):
    p=Path(name)
    if not name or p.is_absolute() or ".." in p.parts or "\\" in name:
        raise ValueError("Image/label path must be safe relative path")
    resolved=(root/p).resolve()
    if not resolved.is_relative_to(root.resolve()) or not resolved.is_file():
        raise ValueError("Original image/label source not found under declared root")
    return resolved

def check_labels(path):
    text=path.read_text(encoding="utf-8")
    for line in text.splitlines():
        if not line.strip():continue
        fields=line.strip().split()
        if len(fields)!=5 or fields[0]!="0":
            raise ValueError("Only one fish class with five-column YOLO XYWH labels is accepted")
        try: v=[float(x) for x in fields[1:]]
        except ValueError as e:raise ValueError("Non-numeric fish YOLO annotations") from e
        if any(not math.isfinite(x) or x<0 or x>1 for x in v) or v[2]<=0 or v[3]<=0:
            raise ValueError("Invalid normalized fish rectangle or extent")

def validate_images(image_root,images_csv,split_audit):
    with images_csv.open(newline="",encoding="utf-8-sig") as f:
        reader=csv.DictReader(f)
        if reader.fieldnames!=COLUMNS:
            raise ValueError("Image manifest must declare split/source/frame/path/SHA for images and labels")
        records=list(reader)
    if not records:
        raise ValueError("No frozen fish training images")
    keys=set();by_split={"train":[],"val":[],"test":[]};sha_partition={}
    for r in records:
        split=r["split"]
        if split not in by_split:
            raise ValueError("Unexpected image split")
        if r["source_video_sha256"] not in set(split_audit[split+"_video_sha256"]):
            raise ValueError("Image has wrong source video group or split")
        try:frame=int(r["frame"])
        except ValueError as e:raise ValueError("Invalid source frame") from e
        key=(r["source_video_sha256"],frame)
        if key in keys or frame<0:
            raise ValueError("Duplicate source video/frame across image partitions")
        keys.add(key)
        im=source_file(image_root,r["image_path"])
        lab=source_file(image_root,r["label_path"])
        if im.suffix.lower() not in SUFFIXES or lab.suffix.lower()!=".txt":
            raise ValueError("Expect real image file and YOLO .txt label")
        if digest(im)!=r["image_sha256"] or digest(lab)!=r["label_sha256"]:
            raise ValueError("Frozen image or annotation byte hash mismatch")
        check_labels(lab)
        previous=sha_partition.setdefault(r["image_sha256"],split)
        if previous!=split:
            raise ValueError("Exact duplicate image across frozen partitions")
        by_split[split].append((im,lab))
    if not by_split["train"] or not by_split["val"]:
        raise ValueError("Nonempty train and validation fish images required")
    return by_split,{"n_images":{s:len(v) for s,v in by_split.items()},
      "image_manifest_sha256":digest(images_csv),
      "train_and_val_only_staged":True,
      "test_images_accessed_only_for_integrity_not_training":True}

def train(output,split_csv,image_root,image_csv,initial_weights,
          *,epochs=80,imgsz=640,batch=8,seed=20261118,device="cpu",
          dry_run=True):
    audit=validate_split(split_csv)
    image_lists,source=validate_images(image_root,image_csv,audit)
    if not initial_weights.is_file() or initial_weights.suffix.lower()!=".pt":
        raise ValueError("An original local YOLO PyTorch checkpoint is required")
    if output.exists():
        raise FileExistsError("Refuse replacing prior trained model or validation evidence")
    if (not 1<=epochs<=1000 or not 64<=imgsz<=4096 or not 1<=batch<=256 or
        not 0<=seed<2**31):
        raise ValueError("Invalid frozen YOLO training hyperparameters")
    plan={"train_val_recording_split_sha256":audit["source_manifest_sha256"],
          "image_manifest_sha256":source["image_manifest_sha256"],
          "initial_weights_sha256":digest(initial_weights),
          "image_counts":source["n_images"],
          "epochs":epochs,"imgsz":imgsz,"batch":batch,"seed":seed,
          "device":device,"training_execution_performed":False,
          "no_test_images_or_labels_in_training_yaml":True,
          "model_selection_on_val_not_test":True}
    if dry_run:return plan
    stage=output/"stage"
    for split in ("train","val"):
        for subdir in ("images","labels"):
            (stage/subdir/split).mkdir(parents=True,exist_ok=True)
        for i,(im,lab) in enumerate(image_lists[split],1):
            stem=f"fish_{i:07d}"
            shutil.copy2(im,stage/"images"/split/(stem+im.suffix.lower()))
            shutil.copy2(lab,stage/"labels"/split/(stem+".txt"))
    # No 'test' entry whatsoever: no model-selection access to held-out test.
    data=output/"train_only_data.yaml"
    data.write_text("path: "+json.dumps(str(stage.resolve()))+"\n"+
                    "train: images/train\nval: images/val\n"+
                    "names: [fish]\nnc: 1\n",encoding="utf-8")
    started=time.perf_counter()
    try:
        from ultralytics import YOLO
        import ultralytics
    except ImportError as e:
        raise RuntimeError("Training requires a separately installed and audited Ultralytics runtime") from e
    detector=YOLO(str(initial_weights))
    detector.train(
        data=str(data),epochs=epochs,imgsz=imgsz,batch=batch,
        seed=seed,device=device,project=str(output/"runs"),name="fish",
        exist_ok=False)
    elapsed=time.perf_counter()-started
    trainer=getattr(detector,"trainer",None)
    if trainer is None or not getattr(trainer,"best",None):
        raise RuntimeError("Ultralytics returned no validation-selected best checkpoint")
    best=Path(trainer.best)
    if not best.is_file() or best.stat().st_size<10000:
        raise RuntimeError("Training did not produce a usable best validation checkpoint")
    provenance={
      "model_or_config_sha256":digest(best),
      "trained_model_path":str(best.resolve()),
      "initial_weights_sha256":plan["initial_weights_sha256"],
      "training_source_video_sha256":audit["train_video_sha256"],
      "model_selection_source_video_sha256":audit["val_video_sha256"],
      "source_split_manifest_sha256":audit["source_manifest_sha256"],
      "image_manifest_sha256":source["image_manifest_sha256"],
      "training_only_data_yaml_sha256":digest(data),
      "test_reference_labels_used_for_training_or_selection":False,
      "test_source_video_sha256_withheld_from_train_yaml":audit["test_video_sha256"],
      "trained_on_actual_images":True,
      "full_training_wall_seconds":elapsed,
      "model_selection": "Ultralytics best.pt on validation partition only",
      "algorithm":"YOLO fine-tuning",
      "ultralytics_version":ultralytics.__version__,
      "hyperparameters":{k:plan[k] for k in ("epochs","imgsz","batch","seed","device")},
      "true_independent_empirical_test_accuracy_certified":False}
    (output/"training_provenance.json").write_text(
        json.dumps(provenance,sort_keys=True,indent=2,allow_nan=False)+"\n")
    return provenance

def main():
    a=argparse.ArgumentParser(description=__doc__)
    a.add_argument("--split-csv",type=Path,required=True)
    a.add_argument("--image-root",type=Path,required=True)
    a.add_argument("--image-manifest",type=Path,required=True)
    a.add_argument("--initial-weights",type=Path,required=True)
    a.add_argument("--output",type=Path,required=True)
    a.add_argument("--epochs",type=int,default=80)
    a.add_argument("--imgsz",type=int,default=640)
    a.add_argument("--batch",type=int,default=8)
    a.add_argument("--seed",type=int,default=20261118)
    a.add_argument("--device",default="cpu")
    a.add_argument("--execute",action="store_true")
    x=a.parse_args()
    result=train(x.output,x.split_csv,x.image_root,x.image_manifest,
                 x.initial_weights,epochs=x.epochs,imgsz=x.imgsz,
                 batch=x.batch,seed=x.seed,device=x.device,
                 dry_run=not x.execute)
    print(json.dumps(result,sort_keys=True,indent=2))

if __name__=="__main__":main()
