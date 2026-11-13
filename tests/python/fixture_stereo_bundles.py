#!/usr/bin/env python3
"""Create 2 synthetic known-XYZ original-source-like video bundles for R e2e.

This file fabricates test fixtures only: no real fish video, hardware exposure,
source YOLO detections, external calibration or physical accuracy is implied.
"""
from pathlib import Path
import csv
import hashlib
import json
import sys

def _sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def fixtures(directory,three_cameras=False,no_fish=False):
    root=Path(directory)
    root.mkdir(parents=True,exist_ok=True)
    session="synthetic_session"
    source=[]
    cameras=[("TOP","top",0.,0.),("SIDE","side",1.,0.)]
    if three_cameras and no_fish:
        raise ValueError("Use separate 3-camera and empty-tank software fixtures")
    if three_cameras:
        cameras.append(("DIAG","diag",0.,1.))
    for camera_id,prefix,cx,cy in cameras:
        folder=root/prefix;folder.mkdir()
        names={"frames":f"{prefix}.frames.csv",
               "mot":f"{prefix}.mot.txt",
               "classes":f"{prefix}.classes.csv",
               "metadata":f"{prefix}.run.json"}
        frames=[]
        mot=[]
        classes=[]
        for frame in range(3):
            t=frame*.1
            frames.append([session,camera_id,frame,format(t,".17g"),1920,1080])
            for track,xyz in (() if no_fish else
                              ((1,(.2,0,5)),(2,(.4,1,5)))):
                x,y,z=xyz
                u=960+(x-cx)/z*100
                v=540+(y-cy)/z*100
                ident=track if camera_id=="TOP" else track+100
                mot.append([frame+1,ident,u-1,v-1,2,2,.99,-1,-1,-1])
                classes.append([frame,ident,0])
        for part,head,rows in [
            ("frames",["session_id","camera_id","frame_id","time_s",
                       "width_px","height_px"],frames),
            ("mot",None,mot),
            ("classes",["frame_id","track_id","class_id"],classes)]:
            with (folder/names[part]).open("w",newline="") as f:
                w=csv.writer(f)
                if head is not None:w.writerow(head)
                w.writerows(rows)
        manifest={
            "schema_version":"1.1",
            "session_id":session,"camera_id":camera_id,
            "video_sha256":"0"*64,
            "weights_sha256":"1"*64,
            "time_source":"decoded_video_frame_pts_from_same_buffer_as_model_input",
            "time_s_relative_to_first_frame":True,
            "frame_origin_in_mot":1,
            "n_decoded_frames":len(frames),
            "n_tracked_box_rows":len(mot),
            "outputs":names,
            "output_sha256":{p:_sha(folder/names[p])
                              for p in ("frames","mot","classes")},
            "fish_model_training_audited":False,
            "fish_identity_accuracy_certified":False,
            "hardware_exposure_synchronization_certified":False,
            "underwater_3d_calibration_certified":False}
        (folder/names["metadata"]).write_text(
            json.dumps(manifest,indent=2,sort_keys=True)+"\n")
        cal={
            "model":"single_interface","units":"cm",
            "K":[[100.,0.,960.],[0.,100.,540.],[0.,0.,1.]],
            "R_c2w":[[1.,0.,0.],[0.,1.,0.],[0.,0.,1.]],
            "center":[cx,cy,0.],
            "plane_point":[0.,0.,1.],
            "plane_normal":[0.,0.,1.],
            "n_before":1.,"n_after":1.}
        source.append({"camera_id":camera_id,"prefix":prefix,
                       "bundle_dir":str(folder.resolve()),
                       "calibration":cal,
                       "clock":{"source":"unverified_relative_pts",
                                "offset_s":0.,"scale":1.}})
    config={"schema_version":"1.0","session_id":session,
            "cameras":source,"max_skew_s":.01,
            "max_ray_separation":.01,
            "min_support":3,
            "ambiguity_margin":.005}
    destination=root/"synthetic_video_3d_config.json"
    destination.write_text(json.dumps(config,indent=2,sort_keys=True)+"\n")
    return destination

if __name__=="__main__":
    if len(sys.argv) not in (2,3) or (
        len(sys.argv)==3 and sys.argv[2] not in ("--three-cameras","--no-fish")):
        raise SystemExit("Usage: fixture_stereo_bundles.py OUT [--three-cameras|--no-fish]")
    mode=sys.argv[2] if len(sys.argv)==3 else None
    print(fixtures(sys.argv[1],three_cameras=(mode=="--three-cameras"),
                   no_fish=(mode=="--no-fish")))
