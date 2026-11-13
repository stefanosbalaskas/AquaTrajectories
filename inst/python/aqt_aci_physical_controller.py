#!/usr/bin/env python3
"""AquaTrajectories opt-in real ACI device bridge with fail-closed interlocks.

Hardware mode is NEVER enabled by default. Requires a user-provided
AQT1 JSON-lines serial firmware bridge with an INDEPENDENT HARDWIRED
normally-closed emergency stop, device-enforced pulse bound/watchdog and
actual actuator feedback. Python queries can CHECK reported states,
but CANNOT prove physical safety, emergency-stop wiring, animal-welfare
appropriateness, source fish identity or ethics certification.

An offline simulation adapter executes the same decision policy without
touching any device. No autonomous animal trial is undertaken here.
"""
from __future__ import annotations
import argparse
from collections import deque
import hashlib
import json
import math
from pathlib import Path
import re
import sys
import time
import uuid

HEX64=re.compile(r"[a-f0-9]{64}\Z")
ID=re.compile(r"[A-Za-z0-9_-]{1,80}\Z")
ALLOWED_CHANNELS={"light","feeder","acoustic_low"}
PROTOCOL="AQT1"
MAX_PULSE_MS=1000
MAX_PERMILLE=500
MAX_CUMULATIVE_MS=5000
MAX_EVENTS_PER_SESSION=20
MIN_COOLDOWN_S=5.
MAX_FEEDBACK_WAIT_S=.5
DEFAULT_MAX_EVENT_AGE_S=.25

def _number(v,name,minimum=None,maximum=None,integer=False):
    if type(v) not in (int,float) or not math.isfinite(v):
        raise ValueError("Nonfinite device source safety limit "+name)
    if integer and (type(v) is not int):
        raise ValueError("Device "+name+" must be a JSON integer")
    if minimum is not None and v<minimum:
        raise ValueError("Device "+name+" below safe profile bound")
    if maximum is not None and v>maximum:
        raise ValueError("Device "+name+" above hard safe bound")
    return v

def validate_profile(profile):
    if not isinstance(profile,dict) or profile.get("schema")!="aqt_aci_safety_profile_v1":
        raise ValueError("External approved ACI safety profile required")
    for key in ("session_id","tank_id","device_id","operator_id"):
        if not isinstance(profile.get(key),str) or not ID.fullmatch(profile[key]):
            raise ValueError("Incomplete ACI session/tank/device/operator scope")
    for key in ("firmware_sha256","physical_estop_test_record_sha256",
                "ethics_approval_record_sha256",
                "hardware_watchdog_test_record_sha256"):
        val=profile.get(key)
        if not isinstance(val,str) or not HEX64.fullmatch(val):
            raise ValueError("Original approved physical safety reference SHA-256 required")
    allowed=profile.get("allowed_channels")
    if not isinstance(allowed,list) or not allowed or (
        any(x not in ALLOWED_CHANNELS for x in allowed)) or (
        len(allowed)!=len(set(allowed))):
        raise ValueError("Approved device channels must be explicit")
    for key,low,high,is_int in (
        ("cooldown_s",MIN_COOLDOWN_S,None,False),
        ("max_session_commands",1,MAX_EVENTS_PER_SESSION,True),
        ("max_pulse_duration_ms",1,MAX_PULSE_MS,True),
        ("max_intensity_permille",1,MAX_PERMILLE,True),
        ("max_total_active_ms",1,MAX_CUMULATIVE_MS,True),
        ("max_feedback_wait_s",.001,MAX_FEEDBACK_WAIT_S,False),
        ("max_source_event_age_s",.001,DEFAULT_MAX_EVENT_AGE_S,False),
        ("min_source_confidence",0,1,False)):
        _number(profile.get(key),key,low,high,is_int)
    if (profile["max_total_active_ms"]<
        profile["max_pulse_duration_ms"]):
        raise ValueError("Maximum session cumulative exposure below one permitted pulse")
    if not isinstance(profile.get("approved_protocol_reference"),str) or (
        not profile["approved_protocol_reference"].strip()):
        raise ValueError("External animal ethics/study protocol reference required")
    return profile

class SimulatedBridge:
    """No IO, no hardware claims. Software-only matching of real bridge contract."""
    physical_contacted=False
    def __init__(self,profile,*,estop_engaged=False,interlock_closed=True,
                 watchdog_enabled=True,welfare_interlock_clear=True):
        self.profile=profile
        self.estop_engaged=estop_engaged
        self.interlock_closed=interlock_closed
        self.watchdog_enabled=watchdog_enabled
        self.welfare_interlock_clear=welfare_interlock_clear
        self.output_on=False
        self.commands=[]
        self.fail_feedback=False
    def status(self):
        return {"protocol":PROTOCOL,"device_id":self.profile["device_id"],
            "firmware_sha256":self.profile["firmware_sha256"],
            "estop_engaged":self.estop_engaged,
            "hard_interlock_closed":self.interlock_closed,
            "watchdog_enabled":self.watchdog_enabled,
            "welfare_interlock_clear":self.welfare_interlock_clear}
    def off(self):
        self.output_on=False
        return {"protocol":PROTOCOL,"status":"off"}
    def actuate(self,command):
        if self.estop_engaged or not self.interlock_closed:
            raise RuntimeError("Simulated hard interlock/estop blocks command")
        self.output_on=True
        self.commands.append(command)
        return {"protocol":PROTOCOL,"status":"accepted","nonce":command["nonce"]}
    def feedback(self,nonce):
        if self.fail_feedback:
            raise TimeoutError("Missing device actuator confirmation")
        self.output_on=False
        return {"protocol":PROTOCOL,"status":"completed","nonce":nonce,
                "actuator_feedback_source":"SIMULATION_ONLY"}
    def close(self):
        self.off()

class SerialAQT1Bridge:
    """Optional serial USB bridge. Compatible firmware must be independently built/tested.

    Each command is one newline-terminated JSON object. Inbound JSON must
    have exact protocol AQT1 and bounded UTF-8 response size. Real physical
    E-stop, hardware watchdog, maximum pulse duration and actuators are
    *firmware/hardware* responsibilities, NOT guaranteed by this code.
    """
    physical_contacted=True
    def __init__(self,port,baudrate=115200,timeout_s=.25):
        if not isinstance(port,str) or not port or "\n" in port or "\r" in port:
            raise ValueError("Explicit safe physical serial port required")
        _number(baudrate,"serial baud",9600,921600,True)
        _number(timeout_s,"serial timeout",.01,MAX_FEEDBACK_WAIT_S)
        try:import serial
        except ImportError as e:
            raise RuntimeError("Real serial ACI requires optional pyserial") from e
        self.serial=serial.Serial(port=port,baudrate=baudrate,
                                  timeout=timeout_s,write_timeout=timeout_s)
    def exchange(self,request):
        request={"protocol":PROTOCOL,**request}
        msg=json.dumps(request,sort_keys=True,separators=(",",":"))
        if len(msg)>512:raise ValueError("Refuse oversized physical ACI command")
        self.serial.write((msg+"\n").encode("ascii"))
        self.serial.flush()
        response=self.serial.readline(513)
        if not response or len(response)>512 or not response.endswith(b"\n"):
            raise TimeoutError("Missing/oversized physical device feedback")
        try:result=json.loads(response)
        except (ValueError,UnicodeDecodeError) as e:
            raise ValueError("Malformed physical device JSON response") from e
        if not isinstance(result,dict) or result.get("protocol")!=PROTOCOL:
            raise ValueError("Device protocol is not qualified AQT1")
        return result
    def status(self):
        return self.exchange({"op":"status"})
    def off(self):
        return self.exchange({"op":"off"})
    def actuate(self,command):
        return self.exchange({"op":"actuate",**command})
    def feedback(self,nonce):
        return self.exchange({"op":"feedback","nonce":nonce})
    def close(self):
        try:self.off()
        finally:self.serial.close()

class ACIController:
    """Single-controller fail-closed safe pulse manager, host-monotonic clock."""
    def __init__(self,profile,bridge,clock=time.monotonic,mode="simulation"):
        self.profile=validate_profile(profile)
        if mode not in ("simulation","hardware"):
            raise ValueError("Invalid controller mode")
        if mode=="simulation" and bridge.physical_contacted:
            raise ValueError("Never contact real devices under simulation mode")
        if mode=="hardware" and not bridge.physical_contacted:
            raise ValueError("Hardware mode requires a real serial device")
        self.bridge=bridge
        self.mode=mode
        self.clock=clock
        self.armed=False
        self.latched=False
        self.count=0
        self.total_ms=0
        self.last_command_at=-math.inf
        self.history=[]
        self.evidence=[]
        self.seen_event_ids=set()
    def _check_status(self):
        state=self.bridge.status()
        if (state.get("protocol")!=PROTOCOL or
            state.get("device_id")!=self.profile["device_id"] or
            state.get("firmware_sha256")!=self.profile["firmware_sha256"] or
            state.get("estop_engaged") is not False or
            state.get("hard_interlock_closed") is not True or
            state.get("watchdog_enabled") is not True or
            state.get("welfare_interlock_clear") is not True):
            raise RuntimeError("Physical ACI interlock, firmware or welfare status NOT clear")
        return state
    def arm(self,operator_approval):
        if self.latched:raise RuntimeError("Controller ESTOP latched; restart required")
        if operator_approval!=self.profile["operator_id"]:
            raise PermissionError("Actual operator identity confirmation required")
        try:
            self._check_status()
            off=self.bridge.off()
            if off.get("status")!="off" or off.get("protocol")!=PROTOCOL:
                raise RuntimeError("Device does not acknowledge safe OFF")
            self.armed=True
        except BaseException:
            self.emergency_stop()
            raise
        return {"armed":True,"mode":self.mode,
                "real_device_contacted":self.bridge.physical_contacted,
                "independent_device_hardware_safety_certified":False}
    def emergency_stop(self):
        self.armed=False
        self.latched=True
        try:self.bridge.off()
        except Exception:pass  # Actual hardware cutoff must be independent of Python
    def process(self,event):
        now=self.clock()
        if not self.armed or self.latched:
            return self._reject(event,"controller_unarmed_or_estop")
        if not isinstance(event,dict) or event.get("event_type")!="aci_choice_request":
            return self._reject(event,"not_approved_aci_action")
        eid=event.get("event_id")
        if not isinstance(eid,str) or not ID.fullmatch(eid):
            return self._reject(event,"missing_or_invalid_original_event_id")
        if eid in self.seen_event_ids:
            return self._reject(event,"duplicate_original_event_replay")
        self.seen_event_ids.add(eid)
        if (event.get("session_id")!=self.profile["session_id"] or
            event.get("tank_id")!=self.profile["tank_id"]):
            return self._reject(event,"source_tank_or_session_mismatch")
        observed=event.get("observed_at_monotonic_s")
        if type(observed) not in (float,int) or not math.isfinite(observed) or (
            observed>now or now-observed>self.profile["max_source_event_age_s"]):
            return self._reject(event,"stale_or_nonmonotonic_fish_event")
        if (event.get("validated_identity") is not True or
            event.get("validated_detection") is not True):
            return self._reject(event,"unvalidated_fish_detector_or_ID")
        conf=event.get("confidence")
        if type(conf) not in (float,int) or not math.isfinite(conf) or (
            conf<self.profile["min_source_confidence"] or conf>1):
            return self._reject(event,"invalid_detector_confidence")
        channel=event.get("channel")
        if channel not in self.profile["allowed_channels"]:
            return self._reject(event,"unapproved_physical_channel")
        duration=event.get("duration_ms")
        intensity=event.get("intensity_permille")
        if (type(duration) is not int or not 1<=duration<=
                self.profile["max_pulse_duration_ms"] or
            type(intensity) is not int or not 0<=intensity<=
                self.profile["max_intensity_permille"]):
            return self._reject(event,"physical_pulse_limit_exceeded")
        if now-self.last_command_at<self.profile["cooldown_s"]:
            return self._reject(event,"cooldown_not_elapsed")
        if self.count>=self.profile["max_session_commands"] or (
            self.total_ms+duration>self.profile["max_total_active_ms"]):
            return self._reject(event,"session_dose_limit_exceeded")
        self.history=deque(t for t in self.history if now-t<60)
        if len(self.history)>=min(self.profile["max_session_commands"],6):
            return self._reject(event,"minute_rate_limit_exceeded")
        nonce=uuid.uuid4().hex
        command={"channel":channel,"duration_ms":duration,
                 "intensity_permille":intensity,"nonce":nonce}
        started=self.clock()
        try:
            self._check_status()
            accepted=self.bridge.actuate(command)
            if accepted.get("status")!="accepted" or accepted.get("nonce")!=nonce:
                raise RuntimeError("No matching real physical command acknowledgement")
            feedback=self.bridge.feedback(nonce)
            if feedback.get("status")!="completed" or feedback.get("nonce")!=nonce:
                raise RuntimeError("No matching actual actuator feedback")
            finished=self.clock()
            if finished-started>self.profile["max_feedback_wait_s"]:
                raise TimeoutError("Physical actuator feedback exceeded watchdog time")
            off=self.bridge.off()
            if off.get("status")!="off":
                raise RuntimeError("Physical device failed safe OFF verification")
        except BaseException:
            self.emergency_stop()
            raise
        self.last_command_at=now
        self.total_ms+=duration
        self.count+=1
        self.history.append(now)
        result={"event_id":event.get("event_id"),
                "status":"simulated" if self.mode=="simulation" else "device_acknowledged",
                "channel":channel,"duration_ms":duration,
                "intensity_permille":intensity,
                "nonce":nonce,"host_command_monotonic_s":started,
                "host_feedback_monotonic_s":finished,
                "feedback_source":feedback.get("actuator_feedback_source","DEVICE_REPORTED"),
                "real_device_contacted":self.bridge.physical_contacted,
                "device_feedback_physically_independently_validated":False,
                "fish_welfare_biologically_certified":False,
                "scientific_ACI_hardware_safety_certified":False}
        self.evidence.append(result)
        return result
    def _reject(self,event,reason):
        result={"event_id":event.get("event_id") if isinstance(event,dict) else None,
                "status":"rejected","reason":reason,
                "real_device_contacted":self.bridge.physical_contacted,
                "physical_actuation_attempted":False}
        self.evidence.append(result)
        return result
    def close(self):
        self.armed=False
        self.bridge.close()

def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--profile",required=True,type=Path)
    p.add_argument("--mode",choices=("simulation","hardware"),default="simulation")
    p.add_argument("--device-port",default=None)
    p.add_argument("--arm-hardware",action="store_true")
    p.add_argument("--operator-id",required=True)
    p.add_argument("--events-jsonl",type=Path,default=None,
      help="File events for SIMULATION only. Hardware uses live stdin JSONL.")
    p.add_argument("--out",required=True,type=Path)
    a=p.parse_args(argv)
    if a.out.exists():raise FileExistsError("Refuse overwrite original physical device log")
    profile=validate_profile(json.loads(a.profile.read_text()))
    if a.mode=="hardware":
        if not a.arm_hardware or not a.device_port or a.events_jsonl:
            raise ValueError("Hardware requires explicit --arm-hardware, physical serial port and live stdin events")
        bridge=SerialAQT1Bridge(a.device_port)
        stream=sys.stdin
    else:
        if a.device_port or a.arm_hardware:
            raise ValueError("Simulation must never receive physical output options")
        bridge=SimulatedBridge(profile)
        if not a.events_jsonl:
            raise ValueError("Simulation requires original replay JSONL events")
        stream=a.events_jsonl.open()
    simulated_clock=[0.]
    controller=ACIController(profile,bridge,
       clock=(lambda:simulated_clock[0]) if a.mode=="simulation" else time.monotonic,
       mode=a.mode)
    fault=None
    try:
        controller.arm(a.operator_id)
        for line in stream:
            if not line.strip():continue
            if len(line)>4000:raise ValueError("Oversized source fish event stream message")
            source=json.loads(line)
            if a.mode=="simulation":
                t=source.get("observed_at_monotonic_s")
                if (type(t) not in (int,float) or not math.isfinite(t) or
                    t<simulated_clock[0]):
                    raise ValueError("Source replay timestamps must be increasing")
                simulated_clock[0]=float(t)
            controller.process(source)
    except BaseException as e:
        fault={"type":type(e).__name__,
               "reason":"physical_device_or_source_failure_fail_closed"}
    finally:
        controller.emergency_stop()
        try:controller.close()
        except BaseException:
            fault={"type":"SafeOffFailure",
                   "reason":"unable_to_confirm_physical_off_device_manual_isolation_required"}
        if stream is not sys.stdin:stream.close()
    data={"schema":"aqt_aci_device_telemetry_v1",
          "source_safety_profile_sha256":hashlib.sha256(a.profile.read_bytes()).hexdigest(),
          "mode":a.mode,"n_commands_accepted":controller.count,
          "n_commands_rejected":sum(x["status"]=="rejected"
                                     for x in controller.evidence),
          "source_event_logs":controller.evidence,
          "terminated_by_fault":fault is not None,
          "fault":fault,
          "physical_hardware_e_stop_independently_tested":False,
          "animal_welfare_or_ethics_externally_certified":False,
          "independent_physical_actuator_feedback_verified":False,
          "device_left_software_unarmed":True}
    a.out.parent.mkdir(parents=True,exist_ok=True)
    a.out.write_text(json.dumps(data,indent=2,sort_keys=True)+"\n")
    if fault is not None:
        raise RuntimeError("ACI stopped fail-closed; audit persisted: "+str(a.out))
    print(json.dumps({"mode":a.mode,"accepted":controller.count,
                      "external_hardware_certified":False}))
    return 0

if __name__=="__main__":raise SystemExit(main())
