#!/usr/bin/env python3
"""M08 -- source-locked real underwater fish measurement error audit.

Input is M07 validated published GT and FROZEN YOLO/ByteTrack observations.
Only this scoring stage accesses publisher labels. Matching is evaluation-only.
No inferred timestamps, physical units, biologically certified IDs, or events.
"""
from __future__ import annotations
import argparse
import csv
import hashlib
import html
import json
import math
from pathlib import Path
from collections import defaultdict

import numpy as np
from scipy.optimize import linear_sum_assignment

SCHEMA = "AQT_M08_REFERENCE_CONDITIONAL_MEASUREMENT_V1"
SOURCE_SCHEMA = "AQT_M07_BRACKISH_REAL_FRAME_INDEX_DUAL_PATH_V1"
SEQUENCES = {
    "brackishMOT-23":121,"brackishMOT-55":256,"brackishMOT-74":111,
    "brackishMOT-93":150,"brackishMOT-98":230,
}
MATCH_FIELDS = ["session_id","camera_id","frame_id","reference_track_id",
    "model_track_id","reference_source_row","model_source_row",
    "reference_x_px","reference_y_px","model_x_px","model_y_px",
    "reference_area_px2","model_area_px2","iou","position_error_px",
    "position_error_image_diagonal_fraction"]
STEP_FIELDS = ["session_id","camera_id","reference_track_id","frame_start",
    "frame_end","status","reference_step_px","model_step_px",
    "signed_step_bias_px","absolute_step_error_px","vector_error_px",
    "heading_error_deg","model_track_id"]
GEOM_FIELDS = ["session_id","camera_id","frame_id","n_reference",
    "n_model","n_matched","reference_full_rg_px","reference_matched_rg_px",
    "model_matched_rg_px","reference_matched_nn_px","model_matched_nn_px",
    "matched_rg_bias_px","selection_rg_bias_px","matched_nn_bias_px"]


def sha(path):
    h=hashlib.sha256()
    with open(path,"rb") as f:
        for b in iter(lambda:f.read(1024*1024),b""):h.update(b)
    return h.hexdigest()


def read_csv(path):
    with open(path,encoding="utf-8-sig",newline="") as f:
        reader=csv.DictReader(f)
        if reader.fieldnames is None:raise ValueError("CSV lacks header: "+str(path))
        rows=list(reader)
        if any(None in r or None in r.values() for r in rows):
            raise ValueError("Malformed source rows: "+str(path))
    return rows


def write_csv(path,headers,rows):
    with open(path,"w",encoding="utf-8",newline="") as f:
        w=csv.DictWriter(f,fieldnames=headers,extrasaction="ignore",lineterminator="\n")
        w.writeheader();w.writerows(rows)


def iou_matrix(g,p):
    if not g or not p:return np.zeros((len(g),len(p)),dtype=float)
    a=np.asarray([[float(r["bbox_left"]),float(r["bbox_top"]),
                   float(r["bbox_width"]),float(r["bbox_height"])] for r in g],dtype=float)
    b=np.asarray([[float(r["bbox_left"]),float(r["bbox_top"]),
                   float(r["bbox_width"]),float(r["bbox_height"])] for r in p],dtype=float)
    ax2=a[:,0]+a[:,2];ay2=a[:,1]+a[:,3]
    bx2=b[:,0]+b[:,2];by2=b[:,1]+b[:,3]
    ix=np.maximum(0,np.minimum(ax2[:,None],bx2[None,:])-np.maximum(a[:,0,None],b[None,:,0]))
    iy=np.maximum(0,np.minimum(ay2[:,None],by2[None,:])-np.maximum(a[:,1,None],b[None,:,1]))
    inter=ix*iy
    union=(a[:,2]*a[:,3])[:,None]+(b[:,2]*b[:,3])[None,:]-inter
    return np.divide(inter,union,out=np.zeros_like(inter),where=union>0)


def assign(g,p,threshold=0.5):
    """Maximum-cardinality then maximum-IoU one-to-one matching, deterministic order."""
    if not 0<threshold<=1:raise ValueError("Invalid IoU threshold")
    if not g or not p:return []
    matrix=iou_matrix(g,p)
    m,n=matrix.shape
    # A maximum-cardinality assignment is always preferred over any smaller
    # assignment even when doing so changes the IoUs of many other pairs.
    # With m source boxes, all valid IoU costs sum to at most m. A dummy
    # costs m+1; invalid edges cost 2*(m+1). Within cardinality the optimum
    # maximizes total IoU. This is stronger than a constant 2 dummy penalty.
    penalty=float(m+1)
    costs=np.full((m,n+m),penalty,dtype=float)
    costs[:,:n]=np.where(matrix>=threshold,1.0-matrix,2*penalty)
    costs[:,:n]+=np.arange(n,dtype=float)[None,:]*1e-12
    row,col=linear_sum_assignment(costs)
    result=[(int(i),int(j),float(matrix[i,j])) for i,j in zip(row,col)
            if j<n and matrix[i,j]>=threshold]
    return sorted(result)


def verify_source(root,strict_real=True):
    root=Path(root)
    meta=json.loads((root/"M07_PROVENANCE.json").read_text(encoding="utf-8"))
    if meta.get("schema")!=SOURCE_SCHEMA:raise ValueError("Not M07 verified source")
    for filename,digest in meta.get("input_shas",{}).items():
        if filename not in {"M07_FRAMES.csv","M07_OBSERVATIONS.csv","M07_PER_SEQUENCE_SOURCE_COUNTS.csv"}:
            raise ValueError("Unexpected source manifest file")
        if sha(root/filename)!=digest:raise ValueError("Source tampering: "+filename)
    if len(meta.get("input_shas",{}))!=3:raise ValueError("Missing input digests")
    if meta.get("measured_frame_timestamps_supplied") is not False or meta.get("biological_identification_certified") is not False or meta.get("camera_calibration_supplied") is not False:
        raise ValueError("Contradictory source scientific evidence flags")
    f=read_csv(root/"M07_FRAMES.csv")
    o=read_csv(root/"M07_OBSERVATIONS.csv")
    if set(r["data_path"] for r in o)!={"reference","model"}:
        raise ValueError("Missing separate reference and real model paths")
    fset=set()
    for row in f:
        k=(row["data_path"],row["session_id"],row["camera_id"],int(row["frame_id"]))
        if k in fset:raise ValueError("Duplicate source frame")
        fset.add(k)
        if row["time_s"].strip():raise ValueError("Source timestamps are unknown; physical time prohibited")
    frame_groups=defaultdict(set)
    dims={}
    for key in fset:
        frame_groups[key[:3]].add(key[3])
    for row in f:
        key=(row["data_path"],row["session_id"],row["camera_id"])
        dim=(int(row["width_px"]),int(row["height_px"]))
        if key in dims and dims[key]!=dim:raise ValueError("Changing scene geometry")
        dims[key]=dim
    for scope,indices in frame_groups.items():
        if indices!=set(range(len(indices))):raise ValueError("Missing original acquisition frames")
    if strict_real:
        if len(f)!=1736 or len(o)!=9451 or {x[1] for x in fset}!=set(SEQUENCES):
            raise ValueError("Real-data source shape or sequence scope changed")
        for (path,seq,cam),indices in frame_groups.items():
            if len(indices)!=SEQUENCES[seq]:raise ValueError("Real source sequence drift")
    seen=set()
    for i,row in enumerate(o,1):
        scope=(row["data_path"],row["session_id"],row["camera_id"])
        k=(*scope,int(row["frame_id"]))
        if k not in fset:raise ValueError("Observation on missing acquisition frame")
        track_key=(*k,str(row["track_id"]))
        if track_key in seen:raise ValueError("Duplicate within-frame track identity")
        seen.add(track_key)
        d=dims[scope]
        x,y=float(row["x"]),float(row["y"])
        left,top=float(row["bbox_left"]),float(row["bbox_top"])
        w,h=float(row["bbox_width"]),float(row["bbox_height"])
        if not all(map(math.isfinite,(x,y,left,top,w,h))) or not (0<=left<left+w<=d[0]+1e-7 and 0<=top<top+h<=d[1]+1e-7):
            raise ValueError("Invalid observed box")
        if max(abs(x-(left+w/2)),abs(y-(top+h/2)))>1e-6:
            raise ValueError("Box-centre provenance mismatch")
        row["_source_row"]=i
    if strict_real and sum(r["data_path"]=="reference" for r in o)!=6621:raise ValueError("Reference count drift")
    if strict_real and sum(r["data_path"]=="model" for r in o)!=2830:raise ValueError("Model count drift")
    return meta,f,o,dims


def reference_step_rows(ref,matched_by_source):
    groups=defaultdict(list)
    for r in ref:groups[(r["session_id"],r["camera_id"],str(r["track_id"]))].append(r)
    out=[]
    for key,rows in sorted(groups.items()):
        rows.sort(key=lambda r:int(r["frame_id"]))
        for a,b in zip(rows,rows[1:]):
            f0,f1=int(a["frame_id"]),int(b["frame_id"])
            if f1!=f0+1:continue
            ax,ay=float(a["x"]),float(a["y"])
            bx,by=float(b["x"]),float(b["y"])
            ref_dx,ref_dy=bx-ax,by-ay
            ref_dist=math.hypot(ref_dx,ref_dy)
            m0=matched_by_source.get(a["_source_row"])
            m1=matched_by_source.get(b["_source_row"])
            status="matched_same_id"
            if m0 is None or m1 is None:status="unmatched_endpoint"
            elif m0["model_track_id"]!=m1["model_track_id"]:status="model_id_discontinuity"
            d={"session_id":key[0],"camera_id":key[1],"reference_track_id":key[2],
               "frame_start":f0,"frame_end":f1,"status":status,
               "reference_step_px":ref_dist,"model_step_px":"",
               "signed_step_bias_px":"","absolute_step_error_px":"",
               "vector_error_px":"","heading_error_deg":"","model_track_id":""}
            if status=="matched_same_id":
                mdx=float(m1["model_x_px"])-float(m0["model_x_px"])
                mdy=float(m1["model_y_px"])-float(m0["model_y_px"])
                model_len=math.hypot(mdx,mdy)
                d.update(model_step_px=model_len,
                    signed_step_bias_px=model_len-ref_dist,
                    absolute_step_error_px=abs(model_len-ref_dist),
                    vector_error_px=math.hypot(mdx-ref_dx,mdy-ref_dy),
                    heading_error_deg=math.degrees(abs(math.atan2(
                      math.sin(math.atan2(mdy,mdx)-math.atan2(ref_dy,ref_dx)),
                      math.cos(math.atan2(mdy,mdx)-math.atan2(ref_dy,ref_dx)))))
                      if ref_dist>1e-9 and model_len>1e-9 else "",
                    model_track_id=m0["model_track_id"])
            out.append(d)
    return out


def rg(points):
    if len(points)<2:return float("nan")
    m=np.asarray(points,dtype=float)
    return float(np.sqrt(((m-m.mean(axis=0))**2).sum(axis=1).mean()))


def nn(points):
    if len(points)<2:return float("nan")
    p=np.asarray(points,dtype=float)
    distances=np.sqrt(((p[:,None,:]-p[None,:,:])**2).sum(axis=2))
    np.fill_diagonal(distances,float("inf"))
    return float(distances.min(axis=1).mean())


def geometry_row(seq,cam,frame,g,p,m):
    g_all=[(float(r["x"]),float(r["y"])) for r in g]
    rsel=[(float(g[i]["x"]),float(g[i]["y"])) for i,j,_ in m]
    psel=[(float(p[j]["x"]),float(p[j]["y"])) for i,j,_ in m]
    a=rg(g_all);b=rg(rsel);c=rg(psel)
    rr=nn(rsel);pp=nn(psel)
    return {"session_id":seq,"camera_id":cam,"frame_id":frame,
        "n_reference":len(g),"n_model":len(p),"n_matched":len(m),
        "reference_full_rg_px":finite_str(a),"reference_matched_rg_px":finite_str(b),
        "model_matched_rg_px":finite_str(c),"reference_matched_nn_px":finite_str(rr),
        "model_matched_nn_px":finite_str(pp),"matched_rg_bias_px":finite_str(c-b),
        "selection_rg_bias_px":finite_str(b-a),"matched_nn_bias_px":finite_str(pp-rr)}


def finite_str(v):return v if math.isfinite(v) else ""


def percentile(vals,q):
    a=np.asarray(list(vals),dtype=float)
    a=a[np.isfinite(a)]
    return float(np.percentile(a,q)) if a.size else None


def mean(vals):
    a=np.asarray(list(vals),dtype=float)
    a=a[np.isfinite(a)]
    return float(a.mean()) if a.size else None


def analyze(f,o,dims,threshold):
    if threshold<=0 or threshold>1:raise ValueError("Threshold must be in (0,1]")
    by_frame=defaultdict(lambda:{"reference":[],"model":[]})
    for row in o:by_frame[(row["session_id"],row["camera_id"],int(row["frame_id"]))][row["data_path"]].append(row)
    matched=[];ref_ledger=[];model_ledger=[];geometries=[];look={}
    for seq,cam,frame in sorted(by_frame):
        z=by_frame[(seq,cam,frame)]
        g=sorted(z["reference"],key=lambda v:(str(v["track_id"]),v["_source_row"]))
        p=sorted(z["model"],key=lambda v:(str(v["track_id"]),v["_source_row"]))
        ma=assign(g,p,threshold)
        gmap={i:(j,score) for i,j,score in ma}
        pmap={j:(i,score) for i,j,score in ma}
        for i,r in enumerate(g):
            j,score=gmap.get(i,(-1,0))
            ref_ledger.append({"source_row":r["_source_row"],"session_id":seq,
                "camera_id":cam,"frame_id":frame,"reference_track_id":r["track_id"],
                "evaluation_status":"matched" if j>=0 else "unmatched_reference",
                "paired_model_source_row":p[j]["_source_row"] if j>=0 else "",
                "matched_iou":score if j>=0 else ""})
        for j,r in enumerate(p):
            i,score=pmap.get(j,(-1,0))
            model_ledger.append({"source_row":r["_source_row"],"session_id":seq,
                "camera_id":cam,"frame_id":frame,"model_track_id":r["track_id"],
                "evaluation_status":"matched" if i>=0 else "unmatched_model",
                "paired_reference_source_row":g[i]["_source_row"] if i>=0 else "",
                "matched_iou":score if i>=0 else ""})
        for i,j,score in ma:
            a,b=g[i],p[j]
            error=math.hypot(float(b["x"])-float(a["x"]),float(b["y"])-float(a["y"]))
            width,height=dims[("reference",seq,cam)]
            row={"session_id":seq,"camera_id":cam,"frame_id":frame,
                "reference_track_id":str(a["track_id"]),"model_track_id":str(b["track_id"]),
                "reference_source_row":a["_source_row"],"model_source_row":b["_source_row"],
                "reference_x_px":float(a["x"]),"reference_y_px":float(a["y"]),
                "model_x_px":float(b["x"]),"model_y_px":float(b["y"]),
                "reference_area_px2":float(a["bbox_width"])*float(a["bbox_height"]),
                "model_area_px2":float(b["bbox_width"])*float(b["bbox_height"]),
                "iou":score,"position_error_px":error,
                "position_error_image_diagonal_fraction":error/math.hypot(width,height)}
            if a["_source_row"] in look:raise AssertionError("GT used twice")
            look[a["_source_row"]]=row
            matched.append(row)
        geometries.append(geometry_row(seq,cam,frame,g,p,ma))
    ref=[z for z in o if z["data_path"]=="reference"]
    steps=reference_step_rows(ref,look)
    return matched,ref_ledger,model_ledger,steps,geometries


def safe_fraction(a,b):return float(a/b) if b else None


def summarize(o,matched,ref_ledger,model_ledger,steps,geometries,thr):
    from collections import Counter
    per_sequence=[]
    names=sorted(set(r["session_id"] for r in o))
    for seq in names:
        ref=[r for r in ref_ledger if r["session_id"]==seq]
        pred=[r for r in model_ledger if r["session_id"]==seq]
        m=[r for r in matched if r["session_id"]==seq]
        st=[r for r in steps if r["session_id"]==seq]
        good=[r for r in st if r["status"]=="matched_same_id"]
        gr=[r for r in geometries if r["session_id"]==seq]
        matching=len(m)
        s={"sequence":seq,"n_reference":len(ref),"n_model":len(pred),
           "n_matched":matching,"n_reference_unmatched":len(ref)-matching,
           "n_model_unmatched":len(pred)-matching,
           "track_output_reference_match_fraction":safe_fraction(matching,len(ref)),
           "track_output_model_match_fraction":safe_fraction(matching,len(pred)),
           "median_position_error_px":percentile((r["position_error_px"] for r in m),50),
           "p90_position_error_px":percentile((r["position_error_px"] for r in m),90),
           "median_iou":percentile((r["iou"] for r in m),50),
           "n_reference_adjacent_steps":len(st),
           "n_paired_same_id_steps":len(good),
           "n_two_endpoints_different_model_id":sum(r["status"]=="model_id_discontinuity" for r in st),
           "n_reference_steps_missing_match_endpoint":sum(r["status"]=="unmatched_endpoint" for r in st),
           "paired_step_coverage":safe_fraction(len(good),len(st)),
           "paired_step_MAE_px":mean(float(r["absolute_step_error_px"]) for r in good),
           "paired_step_signed_bias_px":mean(float(r["signed_step_bias_px"]) for r in good),
           "paired_step_vector_MAE_px":mean(float(r["vector_error_px"]) for r in good),
           "frames_with_two_or_more_matched":sum(r["n_matched"]>=2 for r in gr),
           "matched_group_rg_MAE_px":mean(abs(float(r["matched_rg_bias_px"])) for r in gr if r["matched_rg_bias_px"]!=""),
           "group_subset_selection_rg_MAE_px":mean(abs(float(r["selection_rg_bias_px"])) for r in gr if r["selection_rg_bias_px"]!=""),
           "matched_nearest_neighbor_MAE_px":mean(abs(float(r["matched_nn_bias_px"])) for r in gr if r["matched_nn_bias_px"]!="")}
        per_sequence.append(s)
    pooled={"n_reference":sum(r["n_reference"] for r in per_sequence),
       "n_model":sum(r["n_model"] for r in per_sequence),
       "n_matched":len(matched),"n_reference_adjacent_steps":len(steps),
       "n_paired_same_id_steps":sum(x["n_paired_same_id_steps"] for x in per_sequence),
       "n_reference_steps_missing_match_endpoint":sum(x["n_reference_steps_missing_match_endpoint"] for x in per_sequence),
       "n_two_endpoints_different_model_id":sum(x["n_two_endpoints_different_model_id"] for x in per_sequence),
       "match_fraction_reference":safe_fraction(len(matched),sum(r["n_reference"] for r in per_sequence)),
       "match_fraction_model":safe_fraction(len(matched),sum(r["n_model"] for r in per_sequence)),
       "paired_step_fraction_reference":safe_fraction(sum(x["n_paired_same_id_steps"] for x in per_sequence),len(steps)),
       "median_position_error_px":percentile((r["position_error_px"] for r in matched),50),
       "p90_position_error_px":percentile((r["position_error_px"] for r in matched),90),
       "paired_step_MAE_px":mean(float(r["absolute_step_error_px"]) for r in steps if r["status"]=="matched_same_id"),
       "matched_group_frames":sum(r["frames_with_two_or_more_matched"] for r in per_sequence)}
    return per_sequence,pooled


def figures(dest,rows,matches,steps,geom,sensitivity):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import matplotlib.ticker as ticker
    dest.mkdir(parents=True,exist_ok=True)
    names=[x["sequence"].replace("brackishMOT-", "") for x in rows]
    def save(stem,fn):
        fig,ax=plt.subplots(figsize=(9,5.2))
        fn(fig,ax)
        fig.tight_layout()
        for ext in ("png","svg","pdf"):
            fig.savefig(dest/f"{stem}.{ext}",dpi=180,bbox_inches="tight")
        plt.close(fig)
    def f_coverage(fig,ax):
        x=np.arange(len(names))
        ref=np.array([r["track_output_reference_match_fraction"] for r in rows])*100
        paired=np.array([r["paired_step_coverage"] for r in rows])*100
        ax.bar(x-.2,ref,width=.4,label="Reference observations matched")
        ax.bar(x+.2,paired,width=.4,label="Reference steps eligible for paired error")
        ax.set_xticks(x,names);ax.set_ylim(0,100);ax.set_ylabel("Percent of published reference denominator")
        ax.set_xlabel("BrackishMOT sequence");ax.set_title("Measurement observability: loss before error estimation");ax.legend(fontsize=8)
    save("F01_match_and_step_coverage",f_coverage)
    def f_counts(fig,ax):
        x=np.arange(len(names));ax.bar(x-.22,[r["n_reference"] for r in rows],width=.28,label="Published fish boxes")
        ax.bar(x+.06,[r["n_model"] for r in rows],width=.28,label="Model-tracked boxes")
        ax.bar(x+.34,[r["n_matched"] for r in rows],width=.28,label="IoU-matched pairs")
        ax.set_xticks(x+.06,names);ax.set_ylabel("Observations");ax.set_xlabel("Sequence");ax.legend(fontsize=8)
        ax.set_title("Full observation denominators and actual match support")
    save("F02_observation_counts",f_counts)
    def f_pos(fig,ax):
        v=[np.asarray([r["position_error_px"] for r in matches if r["session_id"]=="brackishMOT-"+x]) for x in names]
        good=[a for a in v if len(a)];labels=[x for x,a in zip(names,v) if len(a)]
        if good:ax.boxplot(good,tick_labels=labels,showfliers=False)
        ax.set_ylabel("Matched fish-box centre error (image px)");ax.set_xlabel("Sequence")
        ax.set_title("Conditional localization error; unmatched fish excluded")
    save("F03_conditional_position_error",f_pos)
    def f_step(fig,ax):
        v=[np.asarray([float(r["absolute_step_error_px"]) for r in steps if r["session_id"]=="brackishMOT-"+x and r["status"]=="matched_same_id"]) for x in names]
        good=[a for a in v if len(a)];labels=[x for x,a in zip(names,v) if len(a)]
        if good:ax.boxplot(good,tick_labels=labels,showfliers=False)
        ax.set_ylabel("Absolute step-length error (image px)");ax.set_xlabel("Sequence")
        ax.set_title("Only adjacent source frames and continuous model IDs")
    save("F04_conditional_step_error",f_step)
    def f_group(fig,ax):
        a=[r for r in geom if r["matched_rg_bias_px"]!=""]
        vals=[(float(r["reference_matched_rg_px"]),float(r["model_matched_rg_px"])) for r in a]
        if vals:
            x,y=np.asarray(vals).T;ax.scatter(x,y,s=10,alpha=.6)
            lim=max(1,float(max(x.max(),y.max())));ax.plot([0,lim],[0,lim],linestyle="--",color="0.4")
        ax.set_xlabel("Radius of gyration, matched reference subset (px)")
        ax.set_ylabel("Radius of gyration, corresponding model subset (px)")
        ax.set_title("School geometry restricted to same matched fish; not full school")
    save("F05_matched_subset_group_geometry",f_group)
    def f_selection(fig,ax):
        vals=[(float(r["reference_full_rg_px"]),float(r["reference_matched_rg_px"])) for r in geom if r["selection_rg_bias_px"]!=""]
        if vals:
            x,y=np.asarray(vals).T;ax.scatter(x,y,s=10,alpha=.6)
            lim=max(1,float(max(x.max(),y.max())));ax.plot([0,lim],[0,lim],linestyle="--",color="0.4")
        ax.set_xlabel("Full publisher reference school RG (px)")
        ax.set_ylabel("Matched subset reference RG (px)")
        ax.set_title("Selection bias: fish missing from matched subsets")
    save("F06_group_subset_selection_bias",f_selection)
    def f_sens(fig,ax):
        x=[r["iou_threshold"] for r in sensitivity]
        ax.plot(x,[r["matched_fraction_reference"]*100 for r in sensitivity],marker="o",label="Matched reference boxes")
        ax.plot(x,[r["paired_step_fraction"]*100 for r in sensitivity],marker="s",label="Paired adjacent steps")
        ax.set_xticks(x);ax.set_xlabel("Evaluation IoU threshold")
        ax.set_ylim(bottom=0);ax.set_ylabel("Percent of full published reference denominator")
        ax.legend(fontsize=8);ax.set_title("Sensitivity analysis (not post-hoc benchmark replacement)")
    save("F07_threshold_sensitivity",f_sens)
    return 7


def md_table(rows,columns):
    def fmt(v):
        if v is None:return "NA"
        if isinstance(v,float):return f"{v:.5f}"
        return str(v)
    return "| "+" | ".join(columns)+" |\n| "+" | ".join("---" for _ in columns)+" |\n"+"\n".join("| "+" | ".join(fmt(r.get(c)) for c in columns)+" |" for r in rows)


def run(root,out,threshold=0.5,sensitivity=(0.3,0.5,0.7),allow_fixture=False):
    root=Path(root);out=Path(out)
    if out.exists():raise FileExistsError("Refuse overwriting existing measurement evidence")
    if not out.parent.is_dir():raise FileNotFoundError("Output parent does not exist")
    meta,frames,obs,dims=verify_source(root,strict_real=not allow_fixture)
    if not 0<threshold<=1 or threshold not in sensitivity:raise ValueError("Primary IoU threshold absent from declared sensitivity")
    studies={}
    for t in sensitivity:
        v=analyze(frames,obs,dims,t)
        sequence,pooled=summarize(obs,*v[:5],t)
        studies[t]=(v,sequence,pooled)
    (matches,ref_ledger,model_ledger,steps,geom),sequence,pooled=studies[threshold]
    if len(ref_ledger)+len(model_ledger)!=len(obs):raise AssertionError("Lost source observations")
    if len(matches)>min(len(ref_ledger),len(model_ledger)):raise AssertionError("Invalid matching")
    if sum(r["status"]=="matched_same_id" for r in steps)!=pooled["n_paired_same_id_steps"]:
        raise AssertionError("Incorrect paired steps")
    sens=[{"iou_threshold":t,"n_matched":q[2]["n_matched"],
           "matched_fraction_reference":q[2]["match_fraction_reference"],
           "paired_steps":q[2]["n_paired_same_id_steps"],
           "paired_step_fraction":q[2]["paired_step_fraction_reference"]} for t,q in sorted(studies.items())]
    out.mkdir();(out/"tables").mkdir();(out/"figures").mkdir()
    write_csv(out/"tables"/"M08_REFERENCE_LEDGER.csv",["source_row","session_id","camera_id","frame_id","reference_track_id","evaluation_status","paired_model_source_row","matched_iou"],ref_ledger)
    write_csv(out/"tables"/"M08_MODEL_LEDGER.csv",["source_row","session_id","camera_id","frame_id","model_track_id","evaluation_status","paired_reference_source_row","matched_iou"],model_ledger)
    write_csv(out/"tables"/"M08_MATCHED_OBSERVATIONS.csv",MATCH_FIELDS,matches)
    write_csv(out/"tables"/"M08_REFERENCE_ADJACENT_STEPS.csv",STEP_FIELDS,steps)
    write_csv(out/"tables"/"M08_FRAME_GROUP_GEOMETRY.csv",GEOM_FIELDS,geom)
    write_csv(out/"tables"/"M08_SEQUENCE_SUMMARIES.csv",list(sequence[0]),sequence)
    write_csv(out/"tables"/"M08_IOU_SENSITIVITY.csv",list(sens[0]),sens)
    result={"schema":SCHEMA,"primary_iou":threshold,
        "evaluation_matcher":"global_one_to_one_Hungarian_max_cardinality_then_IoU",
        "published_GT_used_only_at_evaluation":True,
        "original_model_track_outputs_changed":False,
        "human_identity_readjudication":False,
        "physical_calibration_available":False,
        "measured_timestamps_available":False,
        "feed_event_logs_available":False,
        "independent_external_XYZ_targets_available":False,
        "source_provenance_sha256":sha(root/"M07_PROVENANCE.json"),
        "source_input_sha256":meta["input_shas"],
        "upstream_reference_is_publisher_annotation":True,
        "pooled_descriptive":pooled,"by_sequence":sequence,
        "sensitivity":sens,
        "scientific_claims_blocked":["independent_human_verified_biological_fish_IDs",
            "physical_speed_px_per_second_or_cm_per_second","surveyed_3D_underwater_accuracy",
            "animal_stress_welfare_feeding_effect","causal_treatment_effect"],
        "measurement_errors_conditional_on_IoU_matched_source_annotation":True,
        "unmatched_reference_excluded_from_error_magnitude_not_denominator":True}
    (out/"M08_SCIENTIFIC_RESULTS.json").write_text(json.dumps(result,indent=2,sort_keys=True,allow_nan=False)+"\n",encoding="utf8")
    nfig=figures(out/"figures",sequence,matches,steps,geom,sens)
    cols=["sequence","n_reference","n_model","n_matched","n_reference_adjacent_steps","n_paired_same_id_steps","median_position_error_px","paired_step_MAE_px","frames_with_two_or_more_matched"]
    report=f"""# Milestone 08 — Reference-conditional measurement validation on real BrackishMOT

**Evidence source:** real previously frozen M07 BrackishMOT research inputs; published original fish annotations and actual external YOLO/ByteTrack outputs. This report is not an independent human reannotation of fish identities.

**Primary evaluation:** Hungarian maximum-cardinality one-to-one bbox matching at IoU {threshold:g}. Evaluation-only matching cannot correct the original detector or tracker. Sensitivity thresholds: {', '.join(f'{x:g}' for x in sensitivity)}.

## Full-denominator result

- Published reference fish observations: **{pooled['n_reference']:,}**; real model/ByteTrack observations: **{pooled['n_model']:,}**.
- Matched positions: **{pooled['n_matched']:,}** ({pooled['match_fraction_reference']:.2%} of the *complete* published fish reference denominator).
- Reference adjacent-frame steps: **{pooled['n_reference_adjacent_steps']:,}**; matched at both endpoints to the SAME model-local track ID: **{pooled['n_paired_same_id_steps']:,}** ({pooled['paired_step_fraction_reference']:.2%}).
- Conditional median position error: **{pooled['median_position_error_px'] if pooled['median_position_error_px'] is not None else 'NA'} px** (excludes every unmatched reference; selection-biased).
- Conditional paired-step mean absolute error: **{pooled['paired_step_MAE_px'] if pooled['paired_step_MAE_px'] is not None else 'NA'} px per adjacent recorded frame** (only identity-consistent matched steps).
- Matched reference-frame geometry available: **{pooled['matched_group_frames']:,}** frames with at least two matched animals.

## Sequence evidence

{md_table(sequence,cols)}

## IoU matching sensitivity (diagnostic)

{md_table(sens,list(sens[0]))}

## Interpretation

The poor track-to-reference match fraction and scarce identity-continuous, matched adjacent steps prevent treating model-derived path lengths and group statistics as accurate biological measurements. Even small errors among matched observations **would not establish overall accuracy**, because the majority of published reference fish positions are unavailable for model-error calculation. Position errors are conditional on successful IoU matching, and both publisher annotations and model outputs have source-specific limitations.

Group geometry is reported separately for matched reference subsets and the full publisher reference. Matched-subset comparison tests geometric localization conditional on fish selection; full-versus-subset comparison reveals which school measures are distorted merely by fish missing from the model. Neither is a calibrated measurement of an independently verified school.

No measured timestamps, independent surveyed underwater XYZ references, genuine cross-camera identity adjudication, feeding/event logs or independently replicated treatment tanks are present. Thus physical speed, stereo 3D error, biological ID, fish stress/welfare and treatment inference are deliberately **NOT VALIDATED** in this milestone.

## Reproducibility

Input CSV source SHA-256 hashes were checked against the untouched M07 provenance. Each reference row and model track row has a preserved one-to-one evaluation status; every original adjacent reference step is retained with its eligibility reason. No tracker state or prediction is modified. Tables, figures and report files are included in the output manifest.
"""
    (out/"REPORT.md").write_text(report,encoding="utf8")
    plots=''.join(f'<section><h3>{html.escape(stem.replace("_"," "))}</h3><img src="figures/{stem}.svg" loading="lazy" width="800" alt="{html.escape(stem)}"/></section>' for stem in [
       "F01_match_and_step_coverage","F02_observation_counts","F03_conditional_position_error",
       "F04_conditional_step_error","F05_matched_subset_group_geometry",
       "F06_group_subset_selection_bias","F07_threshold_sensitivity"])
    # Embed SVG images in standalone HTML after sanitizing generated matplotlib headers.
    for stem in ["F01_match_and_step_coverage","F02_observation_counts","F03_conditional_position_error","F04_conditional_step_error","F05_matched_subset_group_geometry","F06_group_subset_selection_bias","F07_threshold_sensitivity"]:
        fn=out/"figures"/(stem+".svg")
        svg=fn.read_text("utf8")
        svg=svg[svg.index("<svg"):]
        plots=plots.replace(f'<img src="figures/{stem}.svg" loading="lazy" width="800" alt="{html.escape(stem)}"/>',svg)
    body='<html lang="en"><head><meta charset="utf-8"><title>M08 real measurement validation</title><style>body{font:16px/1.5 system-ui,Arial;max-width:1100px;margin:auto;padding:24px;color:#243746;background:#fff}h1,h2,h3{color:#115e6d}section{border-top:1px solid #dce6e9;margin-top:28px;padding:12px 0}svg{max-width:100%;height:auto}pre{white-space:pre-wrap;background:#f2f7f8;padding:20px;border-radius:10px}strong{color:#144b56}</style></head><body><h1>Milestone 08: published-reference measurement validation</h1><p>Real fish video source. Conditional image-pixel measurements; no biological identity or physical 3D certification.</p><pre>'+html.escape(report)+'</pre>'+plots+'</body></html>'
    (out/"REPORT.html").write_text(body,encoding="utf8")
    evidence={"schema":"AQT_M08_MEASUREMENT_OUTPUT_SHA256_V1",
        "source_provenance_sha256":sha(root/"M07_PROVENANCE.json"),
        "n_figures":nfig,"n_reference_ledger":len(ref_ledger),
        "n_model_ledger":len(model_ledger),
        "n_adjacent_reference_steps":len(steps),
        "output_sha256":{str(p.relative_to(out)).replace('\\','/'):sha(p)
         for p in sorted(out.rglob('*')) if p.is_file()}}
    (out/"M08_OUTPUT_MANIFEST.json").write_text(json.dumps(evidence,indent=2,sort_keys=True)+"\n",encoding="utf8")
    print("M08_REAL_MEASUREMENT_AUDIT_PASS",json.dumps({"gt":pooled["n_reference"],"model":pooled["n_model"],"matched":len(matches),"paired_steps":pooled["n_paired_same_id_steps"],"figures":nfig},sort_keys=True))
    return result


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--input",required=True,type=Path)
    p.add_argument("--out",required=True,type=Path)
    p.add_argument("--primary-iou",default=0.5,type=float)
    a=p.parse_args()
    run(a.input,a.out,threshold=a.primary_iou)

if __name__=="__main__":main()
