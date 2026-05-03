#!/usr/bin/env python3
import base64
import hashlib
import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


def b64url_decode(value):
    value += "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(value.encode()).decode(errors="replace")


def http_json(method, url, token=None, payload_marker=None, payload=None, timeout=10):
    data = None
    headers = {"Accept": "application/json"}
    if payload_marker == "json":
        data = json.dumps(payload).encode()
        headers["Content-Type"] = "application/json"
    elif payload_marker == "raw_json_string":
        data = json.dumps(payload).encode()
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, context=ssl._create_unverified_context(), timeout=timeout) as resp:
            body = resp.read().decode(errors="replace")
            return resp.status, resp.reason, body
    except urllib.error.HTTPError as exc:
        return exc.code, exc.reason, exc.read().decode(errors="replace")
    except Exception as exc:
        return 0, type(exc).__name__, str(exc)


def decode_token(token):
    parts = token.split(".")
    if len(parts) < 2:
        return {}
    try:
        return json.loads(b64url_decode(parts[1]))
    except Exception as exc:
        return {"decode_error": str(exc)}


def write_jsonl(path, obj):
    with open(path, "a", encoding="utf-8") as f:
        f.write(json.dumps(obj, ensure_ascii=False, sort_keys=True) + "\n")


def classify_status(status):
    if status in (200, 201):
        return "ok"
    if status == 401:
        return "unauthenticated"
    if status == 403:
        return "authz_or_inactive"
    if status == 404:
        return "missing_route_or_empty_backend"
    if status in (500, 502, 503):
        return "service_or_dependency_failure"
    if status == 0:
        return "request_failure"
    return "other"


def parse_token_from_body(body):
    try:
        return json.loads(body).get("access_token")
    except Exception:
        return None


def main():
    run_id = os.environ.get("RUN_ID") or (sys.argv[1] if len(sys.argv) > 1 else None)
    lab_home = Path(os.environ.get("CHARX_LAB_HOME", "/home/khoa/charx_labs/charx_v190"))
    if not run_id:
        state = lab_home / "state" / "wbm_session.env"
        if state.exists():
            for line in state.read_text(encoding="utf-8").splitlines():
                if line.startswith("RUN_ID="):
                    run_id = line.split("=", 1)[1].strip()
                    break
    if not run_id:
        raise SystemExit("Usage: probe_wbm_roles.py <run_id>")

    base_url = os.environ.get("CHARX_WBM_BASE_URL", "https://localhost")
    evidence = lab_home / "evidence" / run_id
    probe_dir = evidence / "probes"
    probe_dir.mkdir(parents=True, exist_ok=True)
    out = probe_dir / "wbm_role_probe.jsonl"
    summary_path = probe_dir / "wbm_role_probe_summary.json"
    token_hashes_path = probe_dir / "wbm_role_token_hashes.json"

    lab_passwords = {
        "manufacturer": os.environ.get("CHARX_WBM_MANUFACTURER_LAB_PASSWORD", "ManufacturerLab-20260424!"),
        "operator": os.environ.get("CHARX_WBM_OPERATOR_LAB_PASSWORD", "OperatorLab-20260424!"),
        "user": os.environ.get("CHARX_WBM_USER_LAB_PASSWORD", "UserLab-20260424!"),
    }

    tokens = {}
    token_hashes = {}

    def record(event, **kwargs):
        kwargs.update({"ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "event": event, "run_id": run_id})
        write_jsonl(out, kwargs)

    def login_role(role, password, event, attempts=8, delay_sec=2):
        last = None
        for attempt in range(1, attempts + 1):
            payload = {"username": role, "password": password, "role": ""}
            status, reason, body = http_json("POST", base_url + "/api/v1.0/web/login", payload_marker="json", payload=payload)
            token = parse_token_from_body(body)
            claims = decode_token(token) if token else {}
            token_hash = hashlib.sha256(token.encode()).hexdigest() if token else None
            last = (status, reason, body, token, claims, token_hash)
            if token or status not in (0, 502, 503):
                break
            time.sleep(delay_sec)
        status, reason, body, token, claims, token_hash = last
        if token:
            tokens[role] = token
            token_hashes[role] = token_hash
        record(
            event,
            label="observed_runtime",
            role=role,
            status=status,
            reason=reason,
            classification=classify_status(status),
            token_sha256=token_hash,
            jwt_claims=claims,
            body_preview=body[:240] if not token else "",
        )
        return token, claims, status

    safe_guest_paths = [
        "/api/v1.0/web/system-name",
        "/api/v1.0/web/date-time",
        "/api/v1.0/web/retained-data",
        "/api/v1.0/web/test-auth-no-login",
    ]
    for path in safe_guest_paths:
        status, reason, body = http_json("GET", base_url + path)
        record(
            "guest_probe",
            label="observed_runtime",
            role="guest",
            method="GET",
            path=path,
            status=status,
            reason=reason,
            classification=classify_status(status),
            body_preview=body[:240],
        )

    default_roles = ["manufacturer", "user", "operator"]
    for role in default_roles:
        login_role(role, role, "login_attempt", attempts=1)

    manufacturer_token = tokens.get("manufacturer")
    if not manufacturer_token:
        manufacturer_token, _, _ = login_role(
            "manufacturer",
            lab_passwords["manufacturer"],
            "login_attempt_existing_lab_password",
            attempts=8,
        )

    manufacturer_claims = decode_token(manufacturer_token) if manufacturer_token else {}
    if manufacturer_token and manufacturer_claims.get("passwordChanged") is False:
        change_payload = {
            "username": "manufacturer",
            "password": "manufacturer",
            "password_new": lab_passwords["manufacturer"],
            "role": "",
        }
        status, reason, body = http_json(
            "POST",
            base_url + "/api/v1.0/web/user/change-password",
            token=manufacturer_token,
            payload_marker="json",
            payload=change_payload,
        )
        record(
            "manufacturer_forced_password_change",
            label="observed_runtime_state_change",
            role="manufacturer",
            method="POST",
            path="/api/v1.0/web/user/change-password",
            status=status,
            reason=reason,
            classification=classify_status(status),
            password_source="lab_password_required_by_firmware_policy",
            body_preview=body[:240],
        )
        tokens.pop("manufacturer", None)
        time.sleep(3)

    login_role(
        "manufacturer",
        lab_passwords["manufacturer"],
        "login_attempt_after_password_change",
        attempts=10,
        delay_sec=3,
    )

    if "manufacturer" in tokens:
        status, reason, body = http_json("GET", base_url + "/api/v1.0/web/users-active", token=tokens["manufacturer"])
        record(
            "users_active_before",
            label="observed_runtime",
            role="manufacturer",
            method="GET",
            path="/api/v1.0/web/users-active",
            status=status,
            reason=reason,
            classification=classify_status(status),
            body_preview=body[:800],
        )

        activation_payload = {
            "user": {"loginAllowed": True, "password_new": lab_passwords["user"]},
            "operator": {"loginAllowed": True, "password_new": lab_passwords["operator"]},
            "manufacturer": {"loginAllowed": True},
        }
        status, reason, body = http_json(
            "POST",
            base_url + "/api/v1.0/web/users-active",
            token=tokens["manufacturer"],
            payload_marker="json",
            payload={"usersActivationStatus": activation_payload},
        )
        record(
            "users_active_enable_user_operator",
            label="observed_runtime_state_change",
            role="manufacturer",
            method="POST",
            path="/api/v1.0/web/users-active",
            status=status,
            reason=reason,
            classification=classify_status(status),
            payload_shape="usersActivationStatus_object_with_password_new",
            body_preview=body[:800],
        )

        for role in ["user", "operator", "manufacturer"]:
            login_role(
                role,
                lab_passwords[role],
                "login_attempt_after_activation",
                attempts=10,
                delay_sec=3,
            )

    rbac_paths = [
        ("GET", "/api/v1.0/web/test-auth-no-login", "guest"),
        ("GET", "/api/v1.0/web/test-auth-user", "user"),
        ("GET", "/api/v1.0/web/test-auth-operator", "operator"),
        ("GET", "/api/v1.0/web/test-auth-manufacturer", "manufacturer"),
        ("GET", "/api/v1.0/web/system-name", "guest"),
        ("GET", "/api/v1.0/web/users-active", "user"),
        ("GET", "/api/v1.0/web/security-config", "user"),
        ("GET", "/api/v1.0/web/network", "user"),
        ("GET", "/api/v1.0/web/linux-user-permissions", "manufacturer"),
    ]
    identities = [("guest", None)] + [(role, tokens.get(role)) for role in ["user", "operator", "manufacturer"]]
    for identity, token in identities:
        for method, path, required_role in rbac_paths:
            status, reason, body = http_json(method, base_url + path, token=token)
            record(
                "rbac_probe",
                label="observed_runtime",
                identity=identity,
                required_role=required_role,
                method=method,
                path=path,
                status=status,
                reason=reason,
                classification=classify_status(status),
                body_preview=body[:240],
            )

    summary = {
        "run_id": run_id,
        "base_url": base_url,
        "tokens_recorded_as_hash_only": True,
        "token_hashes": token_hashes,
        "roles_with_tokens": sorted(tokens),
        "guest_is_no_token": True,
        "lab_credentials": {
            role: {
                "username": role,
                "password_source": "lab_password_set_through_firmware_password_change_or_activation_flow",
            }
            for role in sorted(lab_passwords)
        },
        "evidence": str(out),
    }
    summary_path.write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    token_hashes_path.write_text(json.dumps(token_hashes, indent=2, sort_keys=True), encoding="utf-8")
    print(json.dumps(summary, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
