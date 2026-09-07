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

    def arguments(self, command, stop_age=5_000_000_000, effect="simulationRootsQuiesced"):
        args = [str(BINARY), command, "--heartbeat", str(self.directory / "heartbeat.json"),
                "--stop-request", str(self.directory / "stop.json"), "--expected-process", PROCESS,
                "--max-age-ns", "1000000000", "--max-progress-age-ns", "2000000000", "--poll-ns", "1000000"]
        if command == "supervise":
            args += ["--acknowledgement", str(self.directory / "ack.json"), "--expected-enforcer", ENFORCER,
                     "--required-effect", effect, "--max-stop-age-ns", str(stop_age)]
        return args

    def publish(self, name, value):
        temporary = self.directory / (name + ".tmp")
        temporary.write_text(json.dumps(value), encoding="utf-8")
        os.replace(temporary, self.directory / name)

    def heartbeat(self):
        return dict(processInstance=PROCESS, sequence=1, monotonicNanoseconds=time.monotonic_ns(),
                    publicGeneration=1, transactionFingerprint=70)

    def supervise_report(self, transform=None, effect="simulationRootsQuiesced"):
        process = subprocess.Popen(self.arguments("supervise", effect=effect), text=True,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            stop = self.directory / "stop.json"
            deadline = time.monotonic() + 5
            while not stop.exists():
                if process.poll() is not None or time.monotonic() > deadline:
                    stdout, stderr = process.communicate(timeout=1)
                    self.fail(f"supervisor failed before stop publication: {stdout} {stderr}")
                time.sleep(0.001)
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


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]], verbosity=2)
