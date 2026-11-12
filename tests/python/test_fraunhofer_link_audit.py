import hashlib
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[2]/"inst/python"))
import aqt_fraunhofer_link_audit as module

class OriginalFraunhoferLinks(unittest.TestCase):
    def test_link_href_never_guessed_from_anchor_label(self):
        html=b"""<h3>Video A:</h3><a href='/data/A_mot.zip'>MOT</a>
        <a href='/data/A_datumaro.zip'>Datumaro</a>
        <h3>Video B:</h3><a href='B_mot.zip'>MOT</a>
        <a href='/data/B_datumaro.zip'>Datumaro</a>"""
        a=module.inspect_html(html)
        self.assertEqual(a["n_candidate_links"],4)
        self.assertEqual(a["candidate_links"][0]["url_original"],
                         "https://cvg.hhi.fraunhofer.de/data/A_mot.zip")
        self.assertEqual(a["candidate_links"][2]["url_original"],
                         "https://cvg.hhi.fraunhofer.de/B_mot.zip")
        self.assertEqual(a["original_html_sha256"],hashlib.sha256(html).hexdigest())
        self.assertFalse(a["actual_annotation_bytes_downloaded"])
        self.assertFalse(a["official_HOTA_IDF1_computed"])

    def test_refuse_missing_anchors_and_misleading_scripts(self):
        with self.assertRaisesRegex(ValueError,"No source HTML"):
            module.inspect_html(b"<a>some text</a>")
        with self.assertRaisesRegex(ValueError,"no expected"):
            module.inspect_html(b"<a href='/privacy'>Contact</a>")

    def test_main_never_overwrites_evidence(self):
        with tempfile.TemporaryDirectory() as root:
            source=Path(root)/"page.html"
            output=Path(root)/"report.json"
            source.write_text("<a href='file.zip'>Video A MOT</a>")
            self.assertEqual(module.main(["--html",str(source),"--out",str(output)]),0)
            with self.assertRaises(FileExistsError):
                module.main(["--html",str(source),"--out",str(output)])

if __name__=="__main__":
    unittest.main()
