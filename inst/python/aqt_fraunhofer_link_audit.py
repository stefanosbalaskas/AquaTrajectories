#!/usr/bin/env python3
"""Read-only audit of original Fraunhofer HHI fish tracking download anchors.

The *HTML alone* cannot confirm a dataset was downloaded, annotated or run.
A candidate URL must be independently fetched and inspected before scientific
scores are calculated. Does not infer download URLs from text labels.
"""
from __future__ import annotations
import argparse
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
from urllib.parse import urljoin, urlparse

SOURCE="https://cvg.hhi.fraunhofer.de/FishTracking.htm"

class SourceLinks(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.links=[]
        self.text_history=""
        self.anchor=None
        self.title_text=""
    def handle_starttag(self,tag,attrs):
        attrs=dict(attrs)
        if tag.lower()=="a":
            self.anchor={"href":attrs.get("href",""),
                         "preceding":self.text_history[-350:], "text":""}
    def handle_data(self,data):
        self.text_history=(self.text_history+data)[-1000:]
        if self.anchor is not None:
            self.anchor["text"]+=data
    def handle_endtag(self,tag):
        if tag.lower()=="a" and self.anchor is not None:
            self.links.append(self.anchor)
            self.anchor=None

def inspect_html(blob,source_url=SOURCE):
    raw=blob.decode("utf-8-sig")
    parser=SourceLinks()
    parser.feed(raw)
    anchor=[]
    for link in parser.links:
        href=link["href"].strip()
        if not href or href.startswith(("#","javascript:","data:")):continue
        uri=urljoin(source_url,href)
        parsed=urlparse(uri)
        if parsed.scheme not in ("https","http") or not parsed.hostname:
            raise ValueError("Unsupported original dataset download URI")
        context=" ".join(link["preceding"].split())[-150:]
        anchor.append({"label":link["text"].strip(),
                       "href_original":href,
                       "url_original":uri,
                       "context":context})
    if not anchor:
        raise ValueError("No source HTML anchor links")
    dataset=[a for a in anchor if
             ("mot" in a["label"].lower() or
              "datumaro" in a["label"].lower() or
              "yolo" in a["label"].lower() or
              "video" in a["label"].lower() or
              "fish" in a["url_original"].lower())]
    if not dataset:
        raise ValueError("Original HHI HTML has no expected MOT/Datumaro link labels")
    return {"source":source_url,"original_html_sha256":hashlib.sha256(blob).hexdigest(),
            "n_all_links":len(anchor),"n_candidate_links":len(dataset),
            "candidate_links":dataset,
            "actual_annotation_bytes_downloaded":False,
            "consistent_fish_ids_verified":False,
            "official_HOTA_IDF1_computed":False,
            "physical_underwater_3d_accuracy_certified":False}

def main(argv=None):
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--html",type=Path,required=True)
    ap.add_argument("--out",type=Path,required=True)
    args=ap.parse_args(argv)
    if args.out.exists():raise FileExistsError("Refusing overwrite original link audit")
    if args.html.stat().st_size>5_000_000:
        raise ValueError("Oversized source HTML")
    record=inspect_html(args.html.read_bytes())
    args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(record,indent=2,sort_keys=True)+"\n")
    print(json.dumps(record,indent=2,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
