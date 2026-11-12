#!/usr/bin/env python3
"""Qualified *execution smoke test* for Oxford frozen fish EfficientDet SavedModel.

Not an accuracy benchmark. The Oxford 2023 exported TF2 SavedModel may require
a historically compatible TensorFlow build. This program inspects the actual
serving signature and records a single real fish-video frame inference without
inventing bounding-box semantics or independent image-reference accuracy.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import time

SOURCE_COMMIT="0d57a17148f750ed7c327ba5d36ce587d3b7dcfe"
MODEL_BLOBS={
    "saved_model.pb":"a1bcfd8e2344a2e2680017bdf7e7bacd0a5bcd6f",
    "variables/variables.index":"420b256e96b2d2ce468b6a705659123df18184bb",
    "variables/variables.data-00000-of-00001":"804884ec04b8b5c4ead2030b650ecc074e8fd735"
}


def digest_file(path):
    h=hashlib.sha256()
    with Path(path).open("rb") as fh:
        for block in iter(lambda: fh.read(1 << 20),b""):
            h.update(block)
    return h.hexdigest()


def git_blob_hash(path):
    path=Path(path)
    h=hashlib.sha1()
    h.update(b"blob "+str(path.stat().st_size).encode()+b"\0")
    with path.open("rb") as fh:
        for block in iter(lambda: fh.read(1 << 20),b""):
            h.update(block)
    return h.hexdigest()


def check_frozen_model(model_dir):
    path=Path(model_dir)
    report={}
    for relative,expected in MODEL_BLOBS.items():
        file=path/relative
        if not file.is_file() or file.stat().st_size<1024:
            raise ValueError("Missing exported original fish model component: "+relative)
        actual=git_blob_hash(file)
        if actual!=expected:
            raise ValueError("Fish-specific frozen model blob mismatch: "+relative)
        report[relative]={
            "git_blob_sha1":actual,"sha256":digest_file(file),
            "bytes":file.stat().st_size}
    return report


def input_array(path, tensor_spec):
    """Prepare observed pixels with explicitly recorded transformation."""
    import numpy as np
    import tensorflow as tf
    from PIL import Image
    with Image.open(path) as image:
        original_width,original_height=image.size
        image=image.convert("RGB")
        shape=tensor_spec.shape.as_list()
        if len(shape)!=4 and tensor_spec.dtype!=tf.string:
            raise ValueError("Unknown EfficientDet SavedModel input rank")
        if tensor_spec.dtype==tf.string:
            tensor=tf.constant([Path(path).read_bytes()],dtype=tf.string)
            operation="unaltered_jpeg_bytes"
            target=[original_height,original_width]
        elif tensor_spec.dtype in (tf.uint8,tf.float32):
            target_h,target_w=shape[1],shape[2]
            if target_h is None: target_h=original_height
            if target_w is None: target_w=original_width
            if not (0<target_h<=4096 and 0<target_w<=4096):
                raise ValueError("Invalid SavedModel spatial input dimensions")
            operation="RGB_original_uint8"
            if (target_h,target_w)!=(original_height,original_width):
                image=image.resize((target_w,target_h),Image.Resampling.BILINEAR)
                operation="RGB_bilinear_resize_no_letterbox"
            pixels=np.asarray(image,dtype=np.uint8)
            if tensor_spec.dtype==tf.float32:
                pixels=pixels.astype("float32")
                operation+="_cast_float32_0_to_255"
            tensor=tf.convert_to_tensor(pixels[None,...],dtype=tensor_spec.dtype)
            target=[target_h,target_w]
        else:
            raise ValueError("Unsupported source model input dtype; no guessed inference")
    return tensor,{
        "input_dtype":tensor_spec.dtype.name,
        "original_width_px":original_width,
        "original_height_px":original_height,
        "model_input_height_width":target,
        "input_transform":operation}


def inspect_model_inference(model_dir,frame_path):
    import tensorflow as tf
    import numpy as np
    if not Path(frame_path).is_file():
        raise FileNotFoundError("Real decoded fish JPEG missing")
    start=time.monotonic()
    model=tf.saved_model.load(str(model_dir))
    signature_names=sorted(model.signatures)
    if not signature_names:
        raise RuntimeError("Original model exports no inspectable signature")
    name="serving_default" if "serving_default" in signature_names else signature_names[0]
    sig=model.signatures[name]
    _,inputs=sig.structured_input_signature
    if len(inputs)!=1:
        raise RuntimeError("Only known single-input SavedModel execution is allowed")
    key,spec=next(iter(inputs.items()))
    tensor,transform=input_array(frame_path,spec)
    output=sig(**{key:tensor})
    if not isinstance(output,dict) or not output:
        raise RuntimeError("Original frozen detector returned no inspectable tensors")
    signatures={}
    for k,value in output.items():
        array=np.asarray(value.numpy())
        if array.dtype.kind not in "ifub":
            raise RuntimeError("Original fish model output tensor is nonnumeric")
        if not np.isfinite(array).all():
            raise RuntimeError("Nonfinite fish model output")
        signatures[k]={"shape":list(array.shape),"dtype":str(array.dtype),
                       "n_numeric_elements":int(array.size)}
    return {
        "source": "Oxford published fish EfficientDet-D2 SavedModel v2",
        "source_commit":SOURCE_COMMIT,
        "runtime_tf_version":tf.__version__,
        "signature_name":name,
        "signature_input_key":key,
        "available_signatures":signature_names,
        "input":transform,
        "outputs":signatures,
        "inference_wall_time_seconds":time.monotonic()-start,
        "frozen_fish_model_actually_executed":True,
        "detection_boxes_scored_against_manual_ground_truth":False,
        "original_training_overlap_audited":False,
        "independently_adjudicated_reference_annotations":False,
        "tracker_id_hota_verified":False,
        "physical_xyz_accuracy_verified":False,
        "animal_welfare_validated":False,
        "note":"One source clip decoded JPEG and original model tensor forward pass. "
               "Output semantics/NMS and accuracy have NOT been established."
    }


def main(argv=None):
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--model-dir",type=Path,required=True)
    ap.add_argument("--frame-jpeg",type=Path,required=True)
    ap.add_argument("--out",type=Path,required=True)
    args=ap.parse_args(argv)
    if args.out.exists():
        raise FileExistsError("Refuse overwrite existing inference audit")
    manifest=check_frozen_model(args.model_dir)
    result=inspect_model_inference(args.model_dir,args.frame_jpeg)
    result["weights"]=manifest
    result["real_video_frame_sha256"]=digest_file(args.frame_jpeg)
    args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print(json.dumps({x:result[x] for x in (
        "frozen_fish_model_actually_executed","signature_name","outputs",
        "detection_boxes_scored_against_manual_ground_truth")},indent=2))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
