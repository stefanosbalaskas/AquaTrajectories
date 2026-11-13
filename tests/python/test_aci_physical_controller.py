"""Fail-closed physical fish-device control API; NO actual hardware actuated."""
from pathlib import Path
import json
import tempfile
import sys
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[2]/"inst/python"))
import aqt_aci_physical_controller as m

def safety():
    return {
      "schema":"aqt_aci_safety_profile_v1",
      "session_id":"S1","tank_id":"TANK1","device_id":"AQT1UNIT",
      "operator_id":"RESEARCHER1",
      "firmware_sha256":"a"*64,
      "physical_estop_test_record_sha256":"b"*64,
      "ethics_approval_record_sha256":"c"*64,
      "hardware_watchdog_test_record_sha256":"d"*64,
      "allowed_channels":["light"],
      "cooldown_s":5.,"max_session_commands":2,
      "max_pulse_duration_ms":200,
      "max_intensity_permille":250,
      "max_total_active_ms":400,
      "max_feedback_wait_s":.1,
      "max_source_event_age_s":.1,
      "min_source_confidence":.95,
      "approved_protocol_reference":"APPROVED_STUDY_REFERENCE_TEST_FIXTURE"}

def event(now,event_id="E1"):
    return {"event_id":event_id,"event_type":"aci_choice_request",
            "session_id":"S1","tank_id":"TANK1",
            "observed_at_monotonic_s":now,
            "validated_identity":True,"validated_detection":True,
            "confidence":.99,"channel":"light",
            "duration_ms":150,"intensity_permille":100}

class PhysicalACIFailClosed(unittest.TestCase):
    def test_replay_controller_never_contacts_real_hardware(self):
        profile=safety();bridge=m.SimulatedBridge(profile)
        ticker=[100.]
        c=m.ACIController(profile,bridge,clock=lambda:ticker[0])
        self.assertFalse(c.arm("RESEARCHER1")["real_device_contacted"])
        first=c.process(event(ticker[0]))
        self.assertEqual(first["status"],"simulated")
        self.assertFalse(first["scientific_ACI_hardware_safety_certified"])
        self.assertEqual(len(bridge.commands),1)
        self.assertFalse(bridge.output_on)
        ticker[0]+=2
        rejected=c.process(event(ticker[0],"E2"))
        self.assertEqual(rejected["reason"],"cooldown_not_elapsed")
        ticker[0]+=5
        self.assertEqual(c.process(event(ticker[0],"E3"))["status"],"simulated")
        ticker[0]+=5
        self.assertEqual(c.process(event(ticker[0],"E4"))["reason"],
                         "session_dose_limit_exceeded")
        self.assertEqual(c.count,2)
        self.assertFalse(bridge.output_on)
        c.emergency_stop()
        self.assertEqual(c.process(event(ticker[0],"E5"))["status"],"rejected")
        self.assertTrue(c.latched)

    def test_software_claims_cannot_release_hardware_estop(self):
        profile=safety();bridge=m.SimulatedBridge(profile,estop_engaged=True)
        c=m.ACIController(profile,bridge,clock=lambda:100)
        with self.assertRaisesRegex(RuntimeError,"interlock"):
            c.arm("RESEARCHER1")
        self.assertTrue(c.latched)
        self.assertEqual(bridge.commands,[])
        with self.assertRaisesRegex(RuntimeError,"latched"):
            c.arm("RESEARCHER1")

    def test_stale_events_fish_id_and_welfare_policy_fail(self):
        profile=safety();bridge=m.SimulatedBridge(profile)
        c=m.ACIController(profile,bridge,clock=lambda:100)
        with self.assertRaises(PermissionError):
            c.arm("WRONG_OPERATOR")
        c.arm("RESEARCHER1")
        e=event(99.)
        self.assertEqual(c.process(e)["reason"],"stale_or_nonmonotonic_fish_event")
        e=event(100.,"E2");e["validated_identity"]=False
        self.assertEqual(c.process(e)["reason"],"unvalidated_fish_detector_or_ID")
        e=event(100.,"E3");e["channel"]="electric_shock"
        self.assertEqual(c.process(e)["reason"],"unapproved_physical_channel")
        e=event(100.,"E4");e["duration_ms"]=1000
        self.assertEqual(c.process(e)["reason"],"physical_pulse_limit_exceeded")
        self.assertEqual(bridge.commands,[])

    def test_communication_or_real_feedback_failure_emergency_latches(self):
        profile=safety();bridge=m.SimulatedBridge(profile)
        bridge.fail_feedback=True
        c=m.ACIController(profile,bridge,clock=lambda:100.)
        c.arm("RESEARCHER1")
        with self.assertRaisesRegex(TimeoutError,"confirmation"):
            c.process(event(100.))
        self.assertTrue(c.latched)
        self.assertFalse(c.armed)
        self.assertFalse(bridge.output_on)
        self.assertEqual(len(bridge.commands),1)
        self.assertEqual(c.count,0)

    def test_original_aci_event_replay_prevention_and_offline_simulation_cli(self):
        p=safety();bridge=m.SimulatedBridge(p)
        ticker=[100.]
        c=m.ACIController(p,bridge,clock=lambda:ticker[0])
        c.arm("RESEARCHER1")
        self.assertEqual(c.process(event(100.,"E1"))["status"],"simulated")
        ticker[0]=110.
        self.assertEqual(c.process(event(110.,"E1"))["reason"],
                         "duplicate_original_event_replay")
        self.assertEqual(len(bridge.commands),1)
        with tempfile.TemporaryDirectory() as td:
            root=Path(td)
            profile=root/"profile.json";profile.write_text(json.dumps(safety()))
            events=root/"events.jsonl"
            events.write_text("\n".join(json.dumps(event(t,uid))
                for t,uid in ((100.,"E1"),(102.,"E2"),(110.,"E3")))+"\n")
            out=root/"evidence.json"
            self.assertEqual(m.main(["--profile",str(profile),
                "--mode","simulation","--operator-id","RESEARCHER1",
                "--events-jsonl",str(events),"--out",str(out)]),0)
            evidence=json.loads(out.read_text())
            self.assertEqual(evidence["n_commands_accepted"],2)
            self.assertEqual(evidence["n_commands_rejected"],1)
            self.assertEqual(evidence["mode"],"simulation")
            self.assertFalse(evidence["physical_hardware_e_stop_independently_tested"])
            self.assertFalse(evidence["terminated_by_fault"])

    def test_safety_profile_rejects_invalid_limits_and_bad_hardware_mode(self):
        p=safety()
        p["cooldown_s"]=0.
        with self.assertRaisesRegex(ValueError,"safe profile"):
            m.validate_profile(p)
        p=safety()
        p["physical_estop_test_record_sha256"]="not-source-proof"
        with self.assertRaisesRegex(ValueError,"SHA-256"):
            m.validate_profile(p)
        p=safety()
        with self.assertRaisesRegex(ValueError,"real serial"):
            m.ACIController(p,m.SimulatedBridge(p),mode="hardware")
        p=safety()
        with self.assertRaisesRegex(ValueError,"above hard"):
            m._number(2000,"max_pulse_duration_ms",1,m.MAX_PULSE_MS,True)

if __name__=="__main__":
    unittest.main()
