#!/usr/bin/env python3
"""Export independently generated fish-centre tracks to native AquaTrajectories R CSV.

Uses recorded per-frame presentation timestamps, not nominal FPS. This is a
lossless (for valid observed centres) format bridge, not identity certification.
"""
from __future__ import annotations
import argparse
import csv
from pathlib import Path
from aqt_priority_b_benchmark import centres, times_csv
from aqt_official_fish_trackeval import manifest,digest


def export(centres_csv,frame_manifest,timestamps_csv,output,
           session_id,camera_id):
    if output.exists():
        raise FileExistsError("Refuse replacing existing canonical R trajectory data")
    if not session_id or not camera_id or any(
       z in value for value in (session_id,camera_id) for z in (",","\r","\n")):
        raise ValueError("Session/camera identifiers must be CSV safe")
    n=manifest(frame_manifest)
    timestamp=times_csv(timestamps_csv,n)
    positions=centres(centres_csv,n)
    if not positions:
        raise ValueError("No real predicted fish centres supplied for R import")
    output.parent.mkdir(parents=True,exist_ok=True)
    with output.open("w",newline="",encoding="utf-8") as f:
        w=csv.writer(f)
        w.writerow(["session_id","camera_id","track_id","time_s","x","y","observed","frame"])
        for frame,track,x,y,score in sorted(positions,key=lambda v:(v[1],v[0])):
            w.writerow([session_id,camera_id,str(track),
                        format(timestamp[frame-1],".17g"),
                        format(x,".17g"),format(y,".17g"),"TRUE",frame])
    return {"canonical_r_csv_sha256":digest(output),
            "source_centres_sha256":digest(centres_csv),
            "original_frame_manifest_sha256":digest(frame_manifest),
            "original_timestamps_sha256":digest(timestamps_csv),
            "n_exported_observed_positions":len(positions),
            "units":"px","coordinate_system":"image",
            "missing_frames_not_synthetically_interpolated":True,
            "finite_max_gap_s_should_be_declared_at_downstream_analysis":True,
            "physical_units_validated":False}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--centres",type=Path,required=True)
    p.add_argument("--frames",type=Path,required=True)
    p.add_argument("--timestamps",type=Path,required=True)
    p.add_argument("--out",type=Path,required=True)
    p.add_argument("--session-id",required=True)
    p.add_argument("--camera-id",required=True)
    a=p.parse_args()
    import json
    print(json.dumps(export(a.centres,a.frames,a.timestamps,a.out,
                            a.session_id,a.camera_id),indent=2,sort_keys=True))

if __name__=="__main__":main()
