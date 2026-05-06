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
}
RUNTIME_PROFILES = {"qemu-user", "qemu-system", "native-container", "device-ssh", "static-only"}
ROOTFS_MODES = {"rootfs_rw", "rootfs_ro", "static-only"}
SERVICE_CLASSES = {"required", "optional", "hardware_blocked", "mocked", "known_broken"}
READINESS_VALUES = {"ready", "degraded", "blocked", "not_applicable"}


def fail(message: str) -> int:
    print(message, file=sys.stderr)
    return 1


def require_fields(data: dict, fields: list[str]) -> list[str]:
    return [field for field in fields if field not in data]


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


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("artifact", type=Path)
    parser.add_argument("--artifact-type", required=True, choices=sorted(ARTIFACT_REQUIRED))
    parser.add_argument("--schema-dir", type=Path, required=True)
    args = parser.parse_args(argv)

    if not args.artifact.exists():
        return fail(f"artifact not found: {args.artifact}")
    schema_file = args.schema_dir / f"{args.artifact_type}.schema.json"
    if not schema_file.exists():
        return fail(f"schema file not found: {schema_file}")
    try:
        data = json.loads(args.artifact.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return fail(f"invalid JSON: {exc}")

    errors = []
    errors.extend(f"{field} is required" for field in require_fields(data, COMMON_REQUIRED))
    errors.extend(f"{field} is required" for field in require_fields(data, ARTIFACT_REQUIRED[args.artifact_type]))

    if data.get("schema_version") != "1.0.0":
        errors.append("schema_version must be 1.0.0")
    if data.get("artifact_type") != args.artifact_type:
        errors.append(f"artifact_type must be {args.artifact_type}")
    if args.artifact_type == "runtime_profile":
        if data.get("runtime_profile") not in RUNTIME_PROFILES:
            errors.append("runtime_profile has invalid value")
        if data.get("rootfs_mode") not in ROOTFS_MODES:
            errors.append("rootfs_mode has invalid value")
    if args.artifact_type == "service_readiness":
        errors.extend(validate_service_readiness(data))

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print(f"valid {args.artifact_type}: {args.artifact}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
