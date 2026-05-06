#!/usr/bin/env python3
import argparse
import json
import sys
from pathlib import Path


COMMON_REQUIRED = ["schema_version", "generated_at", "generated_by", "source_inputs", "warnings", "errors"]
ARTIFACT_REQUIRED = {
    "firmware_manifest": ["artifact_type", "firmware_files", "rootfs_candidates"],
    "model_research": ["artifact_type", "claims"],
    "rootfs_profile": ["artifact_type", "architecture", "service_candidates"],
    "runtime_profile": ["artifact_type", "runtime_profile", "rootfs_mode"],
    "service_readiness": ["artifact_type", "ready_for_pentest", "services"],
    "api_smoke_results": ["artifact_type", "results"],
    "skill_context": ["artifact_type", "scope", "target_components", "entries"],
    "code_browser_findings": ["artifact_type", "findings"],
    "reverse_queue": ["artifact_type", "queue"],
    "hook_plan": ["artifact_type", "target_service", "capture_lanes", "workload"],
    "debug_plan": ["artifact_type", "target_process", "attach_mode", "intrusive_actions"],
    "observation_record": [
        "schema_version",
        "timestamp_utc",
        "component",
        "event_type",
        "label",
        "behavior_claim_allowed",
        "source_artifact",
        "risk_notes",
        "artifact_sensitivity",
    ],
}
RUNTIME_PROFILES = {"qemu-user", "qemu-system", "native-container", "device-ssh", "static-only"}
ROOTFS_MODES = {"rootfs_rw", "rootfs_ro", "static-only"}
SERVICE_CLASSES = {"required", "optional", "hardware_blocked", "mocked", "known_broken"}
READINESS_VALUES = {"ready", "degraded", "blocked", "not_applicable"}
OBSERVATION_LABELS = {
    "planned_static_analysis",
    "planned_runtime_live_hook",
    "planned_runtime_live_debugger",
    "observed_static_artifact",
    "observed_runtime_qemu",
    "observed_runtime_live_hook",
    "observed_runtime_live_debugger",
    "observed_qiling_target",
    "qiling_hooked_behavior",
    "sandbox_generated",
    "mocked_behavior",
    "verified",
    "unverified",
    "blocked",
}
SENSITIVITY_VALUES = {
    "public_reference",
    "local_metadata",
    "local_sensitive",
    "secret_material",
    "firmware_proprietary",
}
NON_RUNTIME_TRUTH_LABELS = {
    "planned_static_analysis",
    "planned_runtime_live_hook",
    "planned_runtime_live_debugger",
    "observed_static_artifact",
    "observed_qiling_target",
    "qiling_hooked_behavior",
    "sandbox_generated",
    "mocked_behavior",
    "unverified",
    "blocked",
}
DEBUG_ATTACH_MODES = {
    "host-qemu-attach",
    "guest-gdbstub",
    "qemu-system-gdbstub",
    "gdbserver",
    "qiling-debugger",
    "static-blocked",
}


def fail(message: str) -> int:
    print(message, file=sys.stderr)
    return 1


def require_fields(data: dict, fields: list[str]) -> list[str]:
    return [field for field in fields if field not in data]


def load_jsonl(path: Path) -> tuple[list[dict], list[str]]:
    records: list[dict] = []
    errors: list[str] = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        try:
            value = json.loads(line)
        except json.JSONDecodeError as exc:
            errors.append(f"line {line_number}: invalid JSON: {exc}")
            continue
        if not isinstance(value, dict):
            errors.append(f"line {line_number}: record must be an object")
            continue
        records.append(value)
    if not records and not errors:
        errors.append("JSONL artifact has no records")
    return records, errors


def validate_observation_record(data: dict, prefix: str = "record") -> list[str]:
    errors: list[str] = []
    errors.extend(f"{prefix}.{field} is required" for field in require_fields(data, ARTIFACT_REQUIRED["observation_record"]))
    if data.get("schema_version") != "1.0.0":
        errors.append(f"{prefix}.schema_version must be 1.0.0")
    if data.get("label") not in OBSERVATION_LABELS:
        errors.append(f"{prefix}.label has invalid value")
    if data.get("artifact_sensitivity") not in SENSITIVITY_VALUES:
        errors.append(f"{prefix}.artifact_sensitivity has invalid value")
    if data.get("label") in NON_RUNTIME_TRUTH_LABELS and data.get("behavior_claim_allowed") is True:
        errors.append(f"{prefix}.behavior_claim_allowed must be false for {data.get('label')}")
    if not isinstance(data.get("risk_notes", []), list):
        errors.append(f"{prefix}.risk_notes must be a list")
    return errors


def validate_service_readiness(data: dict) -> list[str]:
    errors: list[str] = []
    services = data.get("services", [])
    if not isinstance(services, list):
        return ["services must be a list"]
    for index, service in enumerate(services):
        prefix = f"services[{index}]"
        service_missing = require_fields(
            service,
            [
                "service_name",
                "classification",
                "expected_process_patterns",
                "expected_ports",
                "expected_logs",
                "smoke_tests",
                "observed_processes",
                "observed_ports",
                "observed_log_signals",
                "smoke_result",
                "readiness",
            ],
        )
        errors.extend(f"{prefix}.{field} is required" for field in service_missing)
        if service.get("classification") not in SERVICE_CLASSES:
            errors.append(f"{prefix}.classification has invalid value")
        if service.get("readiness") not in READINESS_VALUES:
            errors.append(f"{prefix}.readiness has invalid value")
        if service.get("classification") == "required":
            for result in service.get("smoke_result", []):
                if result.get("status") == 500:
                    errors.append(f"{prefix} has unexplained HTTP 500 in smoke_result")
            if service.get("readiness") == "ready" and not service.get("observed_processes"):
                errors.append(f"{prefix} is ready without observed_processes")
            if service.get("readiness") == "ready" and not service.get("observed_ports"):
                errors.append(f"{prefix} is ready without observed_ports")
    if data.get("ready_for_pentest") is True and errors:
        errors.append("ready_for_pentest cannot be true while required readiness errors exist")
    return errors


def validate_common_artifact(data: dict, artifact_type: str) -> list[str]:
    errors: list[str] = []
    errors.extend(f"{field} is required" for field in require_fields(data, COMMON_REQUIRED))
    errors.extend(f"{field} is required" for field in require_fields(data, ARTIFACT_REQUIRED[artifact_type]))
    if data.get("schema_version") != "1.0.0":
        errors.append("schema_version must be 1.0.0")
    if data.get("artifact_type") != artifact_type:
        errors.append(f"artifact_type must be {artifact_type}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("artifact", type=Path)
    parser.add_argument("--artifact-type", required=True, choices=sorted(ARTIFACT_REQUIRED))
    parser.add_argument("--schema-dir", type=Path, required=True)
    parser.add_argument("--jsonl", action="store_true", help="Validate newline-delimited JSON records")
    args = parser.parse_args(argv)

    if not args.artifact.exists():
        return fail(f"artifact not found: {args.artifact}")
    schema_file = args.schema_dir / f"{args.artifact_type}.schema.json"
    if not schema_file.exists():
        return fail(f"schema file not found: {schema_file}")

    if args.jsonl:
        if args.artifact_type != "observation_record":
            return fail("--jsonl is only supported for observation_record")
        records, errors = load_jsonl(args.artifact)
        for index, record in enumerate(records):
            errors.extend(validate_observation_record(record, prefix=f"records[{index}]"))
        if errors:
            for error in errors:
                print(error, file=sys.stderr)
            return 1
        print(f"valid observation_record: {args.artifact}")
        return 0

    try:
        data = json.loads(args.artifact.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return fail(f"invalid JSON: {exc}")

    if args.artifact_type == "observation_record":
        errors = validate_observation_record(data)
    else:
        errors = validate_common_artifact(data, args.artifact_type)

    if args.artifact_type == "runtime_profile":
        if data.get("runtime_profile") not in RUNTIME_PROFILES:
            errors.append("runtime_profile has invalid value")
        if data.get("rootfs_mode") not in ROOTFS_MODES:
            errors.append("rootfs_mode has invalid value")
    if args.artifact_type == "service_readiness":
        errors.extend(validate_service_readiness(data))
    if args.artifact_type == "debug_plan" and data.get("attach_mode") not in DEBUG_ATTACH_MODES:
        errors.append("attach_mode has invalid value")

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print(f"valid {args.artifact_type}: {args.artifact}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
