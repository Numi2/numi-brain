#!/usr/bin/env python3
"""Process/file protocol checks only: no native physics or physical stop claim."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

BINARY = Path(sys.argv[1]).resolve(strict=True)
PROCESS = "00000000-0000-4000-8000-000000000001"
ENFORCER = "00000000-0000-4000-8000-000000000002"


class WatchdogCLITests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(dir=os.path.realpath(tempfile.gettempdir()))
        self.directory = Path(self.temporary.name)
        self.addCleanup(self.temporary.cleanup)

    def arguments(self, command, stop_age=5_000_000_000, effect="simulationRootsQuiesced",
                  ready_age=1_000_000_000):
        args = [str(BINARY), command, "--heartbeat", str(self.directory / "heartbeat.json"),
                "--stop-request", str(self.directory / "stop.json"), "--expected-process", PROCESS,
                "--max-age-ns", "1000000000", "--max-progress-age-ns", "2000000000", "--poll-ns", "1000000"]
        if command in ("supervise", "supervise-lifecycle"):
            args += ["--acknowledgement", str(self.directory / "ack.json"), "--expected-enforcer", ENFORCER,
                     "--required-effect", effect, "--max-stop-age-ns", str(stop_age)]
        if command == "supervise-lifecycle":
            args += ["--arm", str(self.directory / "arm.json"), "--ready", str(self.directory / "ready.json"),
                     "--completion", str(self.directory / "complete.json"), "--max-ready-age-ns", str(ready_age)]
        return args

    def publish(self, name, value):
        temporary = self.directory / (name + ".tmp")
        temporary.write_text(json.dumps(value), encoding="utf-8")
        os.replace(temporary, self.directory / name)

    def heartbeat(self, sequence=1, generation=1, fingerprint=70):
        return dict(processInstance=PROCESS, sequence=sequence, monotonicNanoseconds=time.monotonic_ns(),
                    publicGeneration=generation, transactionFingerprint=fingerprint)

    def wait_file(self, process, name, timeout=5):
        path = self.directory / name
        deadline = time.monotonic() + timeout
        while not path.exists():
            if process.poll() is not None or time.monotonic() > deadline:
                stdout, stderr = process.communicate(timeout=1)
                self.fail(f"process ended before {name}: {stdout} {stderr}")
            time.sleep(0.001)
        return path

    def supervise_report(self, transform=None, effect="simulationRootsQuiesced"):
        process = subprocess.Popen(self.arguments("supervise", effect=effect), text=True,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            stop = self.wait_file(process, "stop.json")
            request = json.loads(stop.read_text(encoding="utf-8"))
            heartbeat = self.heartbeat()
            report = dict(formatVersion=1, request=request, enforcerInstance=ENFORCER,
                          effect="simulationRootsQuiesced", settledHeartbeat=heartbeat,
                          acknowledgedMonotonicNanoseconds=time.monotonic_ns(),
                          terminalEvidenceArtifactSHA256="a" * 64)
            self.publish("ack.json", transform(report) if transform else report)
            stdout, stderr = process.communicate(timeout=8)
            return process.returncode, json.loads(stdout), stderr
        finally:
            if process.poll() is None:
                process.terminate()
                process.communicate(timeout=2)

    def test_healthy_check(self):
        self.publish("heartbeat.json", self.heartbeat())
        result = subprocess.run(self.arguments("check"), capture_output=True, text=True, timeout=3)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(json.loads(result.stdout)["mustRequestSafeState"])

    def test_missing_heartbeat_check_retains_stop(self):
        result = subprocess.run(self.arguments("check"), capture_output=True, text=True, timeout=3)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertTrue((self.directory / "stop.json").is_file())

    def test_missing_acknowledgement_escalates(self):
        result = subprocess.run(self.arguments("supervise", stop_age=20_000_000),
                                capture_output=True, text=True, timeout=3)
        self.assertEqual(result.returncode, 2, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report["status"], "deadlineExceeded")
        self.assertTrue(report["mustKeepStopped"])
        self.assertTrue(report["requiresEscalation"])
        self.assertFalse(report["physicalStopVerified"])

    def test_matching_report_never_resumes_or_claims_physical_verification(self):
        code, report, stderr = self.supervise_report()
        self.assertEqual(code, 1, stderr)
        self.assertEqual(report["status"], "acknowledgedReport")
        self.assertTrue(report["mustKeepStopped"])
        self.assertFalse(report["physicalStopVerified"])
        self.assertTrue((self.directory / "stop.json").is_file())

    def test_foreign_enforcer_escalates(self):
        code, report, stderr = self.supervise_report(lambda value: dict(value, enforcerInstance=PROCESS))
        self.assertEqual(code, 2, stderr)
        self.assertEqual(report["status"], "invalidAcknowledgement")

    def test_malformed_report_escalates(self):
        code, report, stderr = self.supervise_report(lambda _: {})
        self.assertEqual(code, 2, stderr)
        self.assertEqual(report["status"], "invalidAcknowledgement")

    def test_simulation_report_cannot_satisfy_external_actuator_stop(self):
        code, report, stderr = self.supervise_report(effect="externalActuatorsInhibited")
        self.assertEqual(code, 2, stderr)
        self.assertEqual(report["status"], "invalidAcknowledgement")

    def test_preexisting_incident_never_receives_fresh_deadline(self):
        first = subprocess.run(self.arguments("check"), capture_output=True, text=True, timeout=3)
        self.assertEqual(first.returncode, 1, first.stderr)
        stop = (self.directory / "stop.json").read_bytes()
        result = subprocess.run(self.arguments("supervise"), capture_output=True, text=True, timeout=3)
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn("deadline cannot be restarted", result.stderr)
        self.assertEqual((self.directory / "stop.json").read_bytes(), stop)

    def test_lifecycle_clean_completion_matches_exact_last_heartbeat(self):
        process = subprocess.Popen(self.arguments("supervise-lifecycle"), text=True,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            arm = json.loads(self.wait_file(process, "arm.json").read_text(encoding="utf-8"))
            ready = dict(formatVersion=1, arm=arm, processInstance=PROCESS, enforcerInstance=ENFORCER,
                         readyMonotonicNanoseconds=time.monotonic_ns())
            self.publish("ready.json", ready)
            heartbeat = self.heartbeat()
            self.publish("heartbeat.json", heartbeat)
            completion = dict(formatVersion=1, arm=arm, lastSettledHeartbeat=heartbeat,
                              completedMonotonicNanoseconds=max(time.monotonic_ns(), heartbeat["monotonicNanoseconds"]),
                              terminalEvidenceArtifactSHA256="b" * 64)
            self.publish("complete.json", completion)
            stdout, stderr = process.communicate(timeout=5)
            self.assertEqual(process.returncode, 0, stderr)
            report = json.loads(stdout)
            self.assertEqual(report["status"], "completedNormally")
            self.assertTrue(report["cleanCompletion"])
            self.assertFalse(report["physicalStopVerified"])
            self.assertFalse((self.directory / "stop.json").exists())
        finally:
            if process.poll() is None:
                process.terminate(); process.communicate(timeout=2)

    def test_lifecycle_startup_deadline_is_retained_and_requests_stop(self):
        result = subprocess.run(self.arguments("supervise-lifecycle", ready_age=20_000_000, stop_age=20_000_000),
                                capture_output=True, text=True, timeout=3)
        self.assertEqual(result.returncode, 2, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report["status"], "startupDeadlineExceeded")
        self.assertTrue((self.directory / "arm.json").exists())
        self.assertTrue((self.directory / "stop.json").exists())

    def test_lifecycle_mismatched_completion_escalates_and_retains_stop(self):
        process = subprocess.Popen(self.arguments("supervise-lifecycle", stop_age=20_000_000), text=True,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            arm = json.loads(self.wait_file(process, "arm.json").read_text(encoding="utf-8"))
            self.publish("ready.json", dict(formatVersion=1, arm=arm, processInstance=PROCESS,
                                            enforcerInstance=ENFORCER, readyMonotonicNanoseconds=time.monotonic_ns()))
            heartbeat = self.heartbeat()
            self.publish("heartbeat.json", heartbeat)
            wrong = dict(heartbeat, sequence=2, publicGeneration=2, transactionFingerprint=80,
                         monotonicNanoseconds=time.monotonic_ns())
            self.publish("complete.json", dict(formatVersion=1, arm=arm, lastSettledHeartbeat=wrong,
                                               completedMonotonicNanoseconds=time.monotonic_ns(),
                                               terminalEvidenceArtifactSHA256="c" * 64))
            stdout, stderr = process.communicate(timeout=5)
            self.assertEqual(process.returncode, 2, stderr)
            self.assertTrue((self.directory / "stop.json").exists())
            self.assertIn(json.loads(stdout)["status"], ("deadlineExceeded", "invalidAcknowledgement"))
        finally:
            if process.poll() is None:
                process.terminate(); process.communicate(timeout=2)


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]], verbosity=2)
