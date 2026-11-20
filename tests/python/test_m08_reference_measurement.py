#!/usr/bin/env python3
"""M08 source separation, exact cardinality, identity and result ledgers."""
from pathlib import Path
import unittest,sys,tempfile,csv,json,hashlib

sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'inst'/'python'))
# The repository also runs a standard-library-only suite. Optional numeric
# backends are tested in the dedicated M08 scientific-dependencies workflow.
try:
    from aqt_m08_reference_measurement import assign,run,SCHEMA
    SCIENTIFIC_BACKEND = True
except ModuleNotFoundError as exc:
    if exc.name not in ('numpy','scipy','matplotlib'):
        raise
    SCIENTIFIC_BACKEND = False

@unittest.skipUnless(SCIENTIFIC_BACKEND, 'M08 requires the dedicated NumPy/SciPy CI environment')
class ReferenceConditionalTest(unittest.TestCase):
    def box(self,identity,x,y,frame=0,path='reference'):
        return {'track_id':identity,'bbox_left':str(x-5),'bbox_top':str(y-5),
                'bbox_width':'10','bbox_height':'10','x':str(x),'y':str(y),
                'frame_id':str(frame),'data_path':path}

    def test_assignment_is_one_to_one_and_thresholded(self):
        r=[self.box('A',10,10),self.box('B',40,10)]
        p=[self.box('P',10.5,10),self.box('Q',12,10),self.box('R',40.5,10)]
        got=assign(r,p,.5)
        self.assertEqual(len(got),2)
        self.assertEqual(set(i for i,j,x in got),{0,1})
        self.assertEqual(set(j for i,j,x in got),{0,2})
        self.assertTrue(all(x>=.5 for i,j,x in got))
        self.assertEqual(assign(r,p,.999),[])

    def test_assignment_prefers_cardinality_over_iou(self):
        # Maximizing score before cardinality can lose one reference fish.
        r=[self.box('A',10,10),self.box('B',19,10)]
        p=[self.box('X',14,10),self.box('Y',8.5,10)]
        result=assign(r,p,.3)
        self.assertEqual(len(result),2)
        self.assertEqual(len(set(j for i,j,x in result)),2)

    def test_exact_real_contract_on_miniature_fixture(self):
        with tempfile.TemporaryDirectory() as root:
            source=Path(root)/'source';source.mkdir()
            records=[]
            for t,tid,x in [(0,'A',10),(1,'A',12),(2,'A',14)]:
                records.append(self.box(tid,x,10,t,'reference'))
            for t,tid,x in [(0,'X',10.5),(1,'X',12.5),(2,'Y',14.5)]:
                records.append(self.box(tid,x,10,t,'model'))
            for r in records:
                r.update(session_id='test-seq',camera_id='one',
                         detection_confidence='',annotation_status='published')
            frames=[dict(data_path=path,session_id='test-seq',camera_id='one',
                 frame_id=str(t),width_px='100',height_px='100',time_s='',source_frame_id=str(t+1))
                 for path in ('reference','model') for t in range(3)]
            def emit(name,rows):
                with open(source/name,'w',newline='',encoding='utf8') as f:
                    w=csv.DictWriter(f,fieldnames=list(rows[0]),lineterminator='\n')
                    w.writeheader();w.writerows(rows)
            emit('M07_FRAMES.csv',frames)
            emit('M07_OBSERVATIONS.csv',records)
            emit('M07_PER_SEQUENCE_SOURCE_COUNTS.csv',[dict(sequence='test-seq',n_frames='3',reference_rows='3',model_track_rows='3')])
            h={n:hashlib.sha256((source/n).read_bytes()).hexdigest() for n in ('M07_FRAMES.csv','M07_OBSERVATIONS.csv','M07_PER_SEQUENCE_SOURCE_COUNTS.csv')}
            (source/'M07_PROVENANCE.json').write_text(json.dumps(dict(schema='AQT_M07_BRACKISH_REAL_FRAME_INDEX_DUAL_PATH_V1',input_shas=h,measured_frame_timestamps_supplied=False,biological_identification_certified=False,camera_calibration_supplied=False)))
            out=Path(root)/'out'
            result=run(source,out,allow_fixture=True)
            self.assertEqual(result['pooled_descriptive']['n_matched'],3)
            self.assertEqual(result['pooled_descriptive']['n_reference_adjacent_steps'],2)
            self.assertEqual(result['pooled_descriptive']['n_paired_same_id_steps'],1)
            self.assertEqual(result['pooled_descriptive']['n_two_endpoints_different_model_id'],1)
            self.assertTrue(result['measurement_errors_conditional_on_IoU_matched_source_annotation'])
            self.assertTrue((out/'REPORT.html').read_text().count('<svg')>=7)
            m=json.loads((out/'M08_OUTPUT_MANIFEST.json').read_text())
            self.assertTrue(all(hashlib.sha256((out/n).read_bytes()).hexdigest()==x for n,x in m['output_sha256'].items()))
            self.assertEqual(len(list((out/'figures').glob('*.pdf'))),7)
            self.assertEqual(len(list((out/'figures').glob('*.png'))),7)
            self.assertEqual(len(list((out/'figures').glob('*.svg'))),7)
            # Every original observation is preserved in one reference/model ledger.
            with open(out/'tables/M08_REFERENCE_LEDGER.csv',newline='') as f:
                self.assertEqual(len(list(csv.DictReader(f))),3)
            with open(out/'tables/M08_MODEL_LEDGER.csv',newline='') as f:
                self.assertEqual(len(list(csv.DictReader(f))),3)
            # Tampering with original source must abort all new output.
            with open(source/'M07_OBSERVATIONS.csv','a') as f:f.write('broken\n')
            with self.assertRaisesRegex(ValueError,'tampering'):
                run(source,Path(root)/'after-tamper',allow_fixture=True)

if __name__=='__main__':unittest.main()
