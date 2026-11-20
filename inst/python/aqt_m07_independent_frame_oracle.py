#!/usr/bin/env python3
"""Independent Python numerical oracle for R's M07 frame-indexed reporting.

Consumes authenticated M07 handoff, never invents timestamps or identities.
Computes frame coverage, adjacent-frame pixel displacement and within-frame
geometry from recorded fish-centre observations. This is diagnostic evidence
of the R numerical contract, not independent animal annotation truth.
"""
from __future__ import annotations
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path
from collections import defaultdict


def sha256(p):
    h=hashlib.sha256()
    with Path(p).open('rb') as f:
        for b in iter(lambda:f.read(1<<20),b''):h.update(b)
    return h.hexdigest()


def read_csv(p):
    with Path(p).open(newline='',encoding='utf-8') as f:return list(csv.DictReader(f))


def write_csv(p,rows,fields):
    with Path(p).open('w',newline='',encoding='utf-8') as f:
        w=csv.DictWriter(f,fieldnames=fields,lineterminator='\n')
        w.writeheader();w.writerows(rows)


def analyze(input_dir):
    root=Path(input_dir)
    pr=json.loads((root/'M07_PROVENANCE.json').read_text())
    if pr['schema']!='AQT_M07_BRACKISH_REAL_FRAME_INDEX_DUAL_PATH_V1':raise ValueError('Not M07 input')
    for name,sha in pr['input_shas'].items():
        if sha256(root/name)!=sha:raise ValueError('M07 input checksum mismatch: '+name)
    frames=read_csv(root/'M07_FRAMES.csv')
    obs=read_csv(root/'M07_OBSERVATIONS.csv')
    if any(r['time_s'] for r in frames):raise ValueError('Measured clock unexpectedly supplied')
    if len(frames)!=1736 or len(obs)!=9451:raise ValueError('Inconsistent M07 source denominator')
    fs=defaultdict(dict); ts=defaultdict(list); frame_obs=defaultdict(list)
    for f in frames:
        scope=(f['data_path'],f['session_id'],f['camera_id'])
        n=int(f['frame_id'])
        if n in fs[scope]:raise ValueError('Duplicate source frame')
        fs[scope][n]=f
    for scope,m in fs.items():
        if set(m)!=set(range(len(m))):raise ValueError('Incomplete frame manifest')
    for r in obs:
        scope=(r['data_path'],r['session_id'],r['camera_id'])
        frame=int(r['frame_id']); identity=r['track_id']
        if frame not in fs[scope]:raise ValueError('Missing scoped source frame')
        ts[(scope,identity)].append(r)
        frame_obs[(scope,frame)].append(r)
    gap_rows=[];group_rows=[];summary=[];occupancy=[]
    for scope,m in sorted(fs.items()):
        path,seq,cam=scope
        all_rows=[r for (k,_),rr in frame_obs.items() if k==scope for r in rr]
        count_steps=0;gap_count=0;path_sum=0.
        for (s,identity),items in ts.items():
            if s!=scope:continue
            items=sorted(items,key=lambda r:int(r['frame_id']))
            if len({int(r['frame_id']) for r in items})!=len(items):raise ValueError('Duplicate frame identity')
            for a,b in zip(items,items[1:]):
                fa=int(a['frame_id']);fb=int(b['frame_id'])
                if fb-fa!=1:
                    gap_count+=1
                    gap_rows.append(dict(data_path=path,session_id=seq,track_id=identity,from_frame=fa,to_frame=fb,gap_frames=fb-fa-1))
                    continue
                d=math.hypot(float(b['x'])-float(a['x']),float(b['y'])-float(a['y']))
                path_sum+=d; count_steps+=1
        n_with=0;n_multi=0
        bins=defaultdict(int)
        for f in range(len(m)):
            these=frame_obs[(scope,f)]
            if these:n_with+=1
            if len(these)>=2:n_multi+=1
            if these:
                xy=[(float(z['x']),float(z['y'])) for z in these]
                cx=sum(z[0] for z in xy)/len(xy);cy=sum(z[1] for z in xy)/len(xy)
                rg=(sum((x-cx)**2+(y-cy)**2 for x,y in xy)/len(xy))**.5 if len(xy)>1 else None
                nn=(sum(min(math.hypot(x-xx,y-yy) for j,(xx,yy) in enumerate(xy) if j!=i)
                        for i,(x,y) in enumerate(xy))/len(xy)) if len(xy)>1 else None
                group_rows.append(dict(data_path=path,session_id=seq,camera_id=cam,
                    frame_id=f,n_visible=len(these),centroid_x_px=cx,centroid_y_px=cy,
                    radius_of_gyration_px=rg,mean_nearest_neighbor_px=nn))
                w=int(m[f]['width_px']);h=int(m[f]['height_px'])
                for x,y in xy:
                    ix=min(7,int(x/w*8));iy=min(7,int(y/h*8))
                    bins[(ix,iy)]+=1
        summary.append(dict(data_path=path,session_id=seq,camera_id=cam,
            n_recorded_frames=len(m),n_frames_with_observations=n_with,
            n_frames_without_observations=len(m)-n_with,
            n_observations=len(all_rows),n_local_track_labels=len({r['track_id'] for r in all_rows}),
            n_adjacent_frame_steps=count_steps,n_unbridged_within_track_gaps=gap_count,
            observed_path_sum_px=path_sum,n_frames_with_pair_geometry=n_multi))
        for (bx,by),n in bins.items():occupancy.append(dict(data_path=path,session_id=seq,camera_id=cam,
            bin_x=bx,bin_y=by,n_observations=n))
    if sum(z['n_observations'] for z in summary)!=9451 or sum(z['n_recorded_frames'] for z in summary)!=1736:
        raise ValueError('Source accounting failure')
    return {'source_input_provenance_sha256':sha256(root/'M07_PROVENANCE.json'),
        'summary':summary,'group_geometry':group_rows,'occupancy':occupancy,'gaps':gap_rows,
        'scientific_limitations':[
            'All image coordinates are pixels. Physical cm or cm/s unsupported.',
            'Recorded frame indices are not measured elapsed time. Adjacent-frame displacement is not physical speed.',
            'Published source fish identities are not independently human readjudicated.',
            'Predicted local tracker IDs are not aligned with source identity labels.',
            'Group observations and detected occupancy are biased by substantial detection misses.',
            'No independent tanks, treatments, feeding events, physiological stress or animal-welfare inference.']}


def publish(input_dir,out):
    import base64
    import numpy as np
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.ticker import MaxNLocator
    r=analyze(input_dir)
    inp=Path(input_dir);out=Path(out)
    if out.exists():raise FileExistsError('New output directory required')
    if not out.parent.is_dir():raise FileNotFoundError('Output parent missing')
    out.mkdir();(out/'figures').mkdir();(out/'tables').mkdir()
    summaries=r['summary']
    fields=list(summaries[0]);write_csv(out/'tables'/'PER_SEQUENCE_FRAME_SCIENCE.csv',summaries,fields)
    write_csv(out/'tables'/'GROUP_GEOMETRY.csv',r['group_geometry'],list(r['group_geometry'][0]))
    write_csv(out/'tables'/'OBSERVATION_GAPS.csv',r['gaps'],
              ['data_path','session_id','track_id','from_frame','to_frame','gap_frames'])
    write_csv(out/'tables'/'OBSERVED_OCCUPANCY.csv',r['occupancy'],list(r['occupancy'][0]))
    obs=read_csv(inp/'M07_OBSERVATIONS.csv');frames=read_csv(inp/'M07_FRAMES.csv')
    per=defaultdict(list);occ=defaultdict(lambda:np.zeros((8,8)))
    for a in obs:per[(a['session_id'],a['data_path'])].append(a)
    for a in r['occupancy']:occ[(a['session_id'],a['data_path'])][int(a['bin_y']),int(a['bin_x'])]+=int(a['n_observations'])
    grp=defaultdict(list)
    for a in r['group_geometry']:grp[(a['session_id'],a['data_path'])].append(a)
    ff=defaultdict(list)
    for a in frames:ff[(a['session_id'],a['data_path'])].append(a)
    img_tags=[];catalog=[]
    for seq in sorted({s['session_id'] for s in summaries}):
        for kind in ('paths','coverage','group','occupancy'):
            fig,axs=plt.subplots(1,2,figsize=(13,5.2),layout='constrained')
            for ax,path in zip(axs,['reference','model']):
                rows=per[(seq,path)]; this=ff[(seq,path)]; gg=grp[(seq,path)]
                color='tab:blue' if path=='reference' else 'tab:orange'
                if kind=='paths':
                    by_id=defaultdict(list)
                    for t in rows:by_id[t['track_id']].append(t)
                    for identity,rr in by_id.items():
                        rr.sort(key=lambda t:int(t['frame_id']))
                        for a,b in zip(rr,rr[1:]):
                            if int(b['frame_id'])-int(a['frame_id'])==1:
                                ax.plot([float(a['x']),float(b['x'])],
                                        [float(a['y']),float(b['y'])],color=color,alpha=.32,lw=.7)
                    ax.scatter([float(t['x']) for t in rows],[float(t['y']) for t in rows],
                               s=3,alpha=.36,color=color,rasterized=True)
                    ax.set_xlim(0,1920);ax.set_ylim(1080,0)
                    ax.set_xlabel('Image x (px)');ax.set_ylabel('Image y (px)')
                    ax.set_aspect('equal')
                elif kind=='coverage':
                    c=defaultdict(int)
                    for x in rows:c[int(x['frame_id'])]+=1
                    ids=[int(x['frame_id']) for x in this]
                    ax.vlines(ids,0,[c.get(f,0) for f in ids],color=color,lw=.9)
                    ax.set_xlabel('Recorded frame (not seconds)');ax.set_ylabel('Observed tracks')
                elif kind=='group':
                    gg=sorted(gg,key=lambda t:t['frame_id'])
                    t=[float(g['radius_of_gyration_px']) if g['radius_of_gyration_px'] is not None else np.nan for g in gg]
                    ax.plot([g['frame_id'] for g in gg],t,lw=.9,color=color)
                    ax.set_xlabel('Recorded frame (not seconds)');ax.set_ylabel('Group radius of gyration (px)')
                elif kind=='occupancy':
                    ax.imshow(occ[(seq,path)],origin='upper',interpolation='nearest',cmap='YlOrRd')
                    ax.set_xlabel('Normalized x-bin');ax.set_ylabel('Normalized y-bin')
                ax.set_title(('Published reference' if path=='reference' else 'Actual model/ByteTrack')+f' — {seq}')
                ax.xaxis.set_major_locator(MaxNLocator(nbins=6))
            for ext in ('svg','pdf','png'):                target=out/'figures'/f'{seq}_{kind}.{ext}'
                fig.savefig(target,dpi=160)
            plt.close(fig)
            catalog.append({'sequence':seq,'family':kind,'files':f'figures/{seq}_{kind}.svg;figures/{seq}_{kind}.pdf;figures/{seq}_{kind}.png'})
            blob=(out/'figures'/f'{seq}_{kind}.png').read_bytes()
            img_tags.append(f'<section><h3>{seq} — {kind}</h3><img alt="{seq} {kind}" src="data:image/png;base64,{base64.b64encode(blob).decode()}" /></section>')
    write_csv(out/'FIGURE_CATALOG.csv',catalog,list(catalog[0]))
    import html
    tbl='<tr>'+''.join('<th>'+html.escape(x)+'</th>' for x in fields)+'</tr>'
    for s in summaries:tbl+='<tr>'+''.join('<td>'+html.escape(str(s[x]))+'</td>' for x in fields)+'</tr>'
    warn=''.join('<li>'+html.escape(x)+'</li>' for x in r['scientific_limitations'])
    report=f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><title>AquaTrajectories M07 Real BrackishMOT Scientific Demonstration</title><style>body{{font:15px/1.5 system-ui,sans-serif;margin:3rem auto;max-width:1200px;padding:0 1rem;color:#22343d}}th,td{{padding:.35rem;border-bottom:1px solid #ccd4d8;text-align:left}}table{{border-collapse:collapse;font-size:12px}}img{{width:100%;height:auto}}section{{break-before:page;padding:1rem 0;border-bottom:1px solid #ddd}}h1,h2{{color:#194d5f}}.warning{{border-left:4px solid #b65f3b;padding:1rem;background:#f8f4ee}}</style></head><body><h1>AquaTrajectories M07: Real BrackishMOT Dual-Path Analysis</h1><p class="warning">Real source labels and real model-generated trajectories, no synthetic results. Observational descriptive study without measured timing, calibration, treatment or independent biological identity certification.</p><h2>Source observations, QC and measurement support</h2><table>{tbl}</table><h2>Scientific restrictions</h2><ul>{warn}</ul><h2>Native R consistency target</h2><p>These independently calculated Python numerical oracles should match the native R <code>aqt_frame_index_analyze()</code> outputs when run on the same SHA-256-verified input tables.</p>'''+''.join(img_tags)+'''</body></html>'''
    (out/'REPORT.html').write_text(report,encoding='utf8')
    md=['# AquaTrajectories M07 real BrackishMOT dual-path audit','',
        '## Source and scope','','Published real source fish reference tracks and real NMFS model-generated ByteTrack tracks on exactly five real test sequences. No synthetic or oracle model predictions were used.','','## Analysis restrictions','']
    md += ['- '+x for x in r['scientific_limitations']]
    md += ['','## Reference versus model observation support','','| Path | Sequence | Frames | Observations | Frames with tracks | Adjacent-frame steps | Gaps | Observed pixel displacement sum |','|---|---|---:|---:|---:|---:|---:|---:|']
    for x in summaries:md.append(f'| {x["data_path"]} | {x["session_id"]} | {x["n_recorded_frames"]} | {x["n_observations"]} | {x["n_frames_with_observations"]} | {x["n_adjacent_frame_steps"]} | {x["n_unbridged_within_track_gaps"]} | {x["observed_path_sum_px"]:.1f} |')
    md += ['','## Generated scientific graphics','',f'{len(catalog)} paired real-data figure families, each as SVG, vector PDF and PNG.','',
           '## Reproducibility','','All output-file SHA-256 digests are in M07_INDEPENDENT_ORACLE_MANIFEST.json. Source input hashes are carried from the M07 handoff.']
    (out/'REPORT.md').write_text('\n'.join(md)+'\n',encoding='utf8')
    evidence={'schema':'AQT_M07_INDEPENDENT_FRAME_INDEX_NUMERICAL_ORACLE_V1',
              'source_input_provenance_sha256':r['source_input_provenance_sha256'],
              'n_figures':len(catalog),'summary':summaries,'scientific_limitations':r['scientific_limitations']}
    (out/'M07_NUMERICAL_ORACLE.json').write_text(json.dumps(evidence,indent=2)+'\n',encoding='utf8')
    files=sorted(p for p in out.rglob('*') if p.is_file())
    manifest={'schema':'AQT_M07_INDEPENDENT_ORACLE_OUTPUT_SHA256',
              'output_sha256':{str(p.relative_to(out)).replace('\\','/'):sha256(p) for p in files}}
    (out/'M07_INDEPENDENT_ORACLE_MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8')
    print('M07_INDEPENDENT_REAL_NUMERICAL_ORACLE_PASS',len(summaries),'scopes',len(catalog),'figure families')
    return evidence


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--input',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args()
    publish(a.input,a.out)

if __name__=='__main__':main()
