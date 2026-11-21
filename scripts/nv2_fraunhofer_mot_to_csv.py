#!/usr/bin/env python3
"""Read official Fraunhofer MOT ground-truth rows from original archive only.

No image decoder, model training, tracker inference or biological validation.
The time_s CSV field is an ORDINAL FRAME PROXY, not measured seconds:
downstream benchmark is group geometry and compute cost ONLY. Security:
archive member counts, sizes, path traversal and decompression ratio checked.
"""
import argparse, csv, hashlib, io, json, math, sys, zipfile
from pathlib import Path, PurePosixPath

SOURCE_URLS={
 "A":"https://cvg.hhi.fraunhofer.de/FishTrackingData/video_a/mot_a.zip",
 "B":"https://cvg.hhi.fraunhofer.de/FishTrackingData/video_b/mot_b.zip",
}
def sha256(path):
    h=hashlib.sha256()
    with open(path,"rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""):
            h.update(chunk)
    return h.hexdigest()

def convert(zip_path,out_dir,sequence):
    if sequence not in SOURCE_URLS:raise ValueError("Unsupported sequence")
    if out_dir.exists():raise FileExistsError("Output folder must not exist")
    if not zip_path.is_file() or zip_path.stat().st_size>1_200_000_000:
        raise ValueError("Archive missing or oversized")
    with zipfile.ZipFile(zip_path) as archive:
        items=archive.infolist()
        if len(items)>30000:raise ValueError("Archive member count exceeded")
        for m in items:
            p=PurePosixPath(m.filename)
            if(p.is_absolute() or ".." in p.parts or "\\" in m.filename or
               m.file_size>500_000_000 or len(m.filename)>320 or
               (m.compress_size and m.file_size>200*m.compress_size)):
                raise ValueError("Unsafe source archive member")
        candidates=[m for m in items
          if m.filename.lower().endswith("/gt/gt.txt")
          or m.filename.lower() in ("gt.txt","gt/gt.txt")]
        if len(candidates)!=1 or candidates[0].file_size>40_000_000:
            raise ValueError("Expected exactly one readable native GT source")
        content=archive.read(candidates[0])
        native_hash=hashlib.sha256(content).hexdigest()
    rows=[];keys=set()
    for line,fields in enumerate(csv.reader(io.StringIO(content.decode("utf-8-sig"))),1):
        if not fields:continue
        if len(fields)<6:raise ValueError(f"Short MOT source row {line}")
        try:
            frame=int(fields[0]);fish=int(fields[1])
            left,top,width,height=map(float,fields[2:6])
        except (TypeError,ValueError) as exc:
            raise ValueError(f"Invalid GT row {line}") from exc
        if frame<0 or fish<0 or width<=0 or height<=0 or not all(
              math.isfinite(z) for z in (left,top,width,height)):
            raise ValueError(f"Invalid position/frame/size in row {line}")
        if (frame,fish) in keys:raise ValueError("Duplicate frame and fish ID")
        keys.add((frame,fish))
        rows.append((frame,str(fish),left+width/2,top+height/2,line))
    if not rows:raise ValueError("Native GT had no parseable tracks")
    low=min(r[0] for r in rows)
    rows.sort(key=lambda r:(r[0],r[1]))
    out_dir.mkdir(parents=True)
    target=out_dir/"SOURCE_FRAME_CENTER_TRACKS.csv"
    with target.open("w",newline="",encoding="utf-8") as f:
        writer=csv.writer(f)
        writer.writerow(["session_id","camera_id","track_id","frame_id",
          "time_s","x","y","observed","source_row"])
        for frame,fish,x,y,line in rows:
            # The placeholder time is an ordinal index only, NOT a real clock.
            writer.writerow([f"HHI_{sequence}","SOURCE",fish,frame,
               frame-low,format(x,".17g"),format(y,".17g"),"TRUE",line])
    frames={r[0] for r in rows}
    fish={r[1] for r in rows}
    meta=dict(
      schema="NV2_REAL_MOT_ANNOTATION_SOURCE_V1",
      dataset="Fraunhofer HHI Sulawesi ricefish",
      source_url=SOURCE_URLS[sequence],sequence=sequence,
      data_origin="original_downloaded_annotation_gt_NOT_tracker_predictions",
      origin_verified_by_independent_frozen_digest=False,
      transport_tls_peer_verified=False,
      source_zip_sha256=sha256(zip_path),
      native_gt_member=candidates[0].filename,
      native_gt_sha256=native_hash,
      conversion="bbox_center=(left+width/2,top+height/2)",
      coordinate_units="px",clock_status="ORDINAL_FRAME_PROXY_NOT_SECONDS",
      calibrated_position_accuracy=False,
      real_biological_identity_certified=False,
      n_tracks=len(fish),n_frames=len(frames),n_source_observations=len(rows),
      n_duplicate_frame_id_keys=0,
      min_frame=min(frames),max_frame=max(frames),
      csv_sha256=sha256(target))
    (out_dir/"SOURCE_PROVENANCE.json").write_text(
        json.dumps(meta,sort_keys=True,indent=2)+"\n",encoding="utf-8")
    print("NV2_REAL_GT_CONVERT",sequence,
       "frames",len(frames),"IDs",len(fish),"rows",len(rows),
       "SHA256",meta["source_zip_sha256"])
    return meta

def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zip",type=Path,required=True)
    parser.add_argument("--sequence",choices=("A","B"),required=True)
    parser.add_argument("--out",type=Path,required=True)
    a=parser.parse_args(argv)
    convert(a.zip,a.out,a.sequence)
    return 0
if __name__=="__main__":sys.exit(main())
