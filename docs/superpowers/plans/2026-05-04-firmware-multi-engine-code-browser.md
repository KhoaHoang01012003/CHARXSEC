# Firmware Multi-Engine Code Browser Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current grep-style `code-browser` helper with a reusable multi-engine firmware code browser that can analyze any extracted Linux firmware rootfs, beginning with CHARX SEC-3100 V190 as the feasibility target.

**Architecture:** Keep `emulation/charx_v190/pentest/scripts/code_browser.py` as the CLI entrypoint, but move logic into a product-neutral Python package named `firmware_browser`. The browser runs an engine chain over a user-supplied rootfs: inventory, config/routes, source-language detection, Semgrep, CodeQL, binary metadata, and skill-context export. Every engine emits structured JSON/JSONL findings and non-claiming evidence so Codex/Claude skills can consume the results without re-scanning large firmware trees.

**Tech Stack:** Python 3.11, dataclasses, pathlib, subprocess, jsonschema already in `requirements.txt`, optional Semgrep CLI, optional CodeQL CLI, optional `file`/`readelf`/`strings`, JSONL evidence, pytest.

---

## Design Constraints

- Product-neutral: no hardcoded CHARXSEC path, service name, route file, or vendor naming in the engine core.
- Rootfs-driven: every command accepts `--rootfs <path>` and treats it as the analysis boundary.
- Multi-language: detect source/script/config files by extension and path, then route supported files to Semgrep/CodeQL where available.
- Firmware-aware: ARM ELF binaries are first-class artifacts. CodeQL is one engine, not the whole browser.
- Skill-friendly: produce compact machine-readable outputs suitable for future Codex/Claude skills: `inventory.json`, `findings.jsonl`, and `skill_context.json`.
- Evidence discipline: static browser output is not firmware behavior truth. Use `label="unknown"` and `behavior_claim_allowed=false`.
- Optional tools must fail cleanly: missing Semgrep/CodeQL/Ghidra/readelf/strings must be recorded, not crash the whole scan.

## File Structure

- Modify: `emulation/charx_v190/pentest/scripts/code_browser.py`
  - Thin CLI wrapper that calls `firmware_browser.cli.main()`.
- Create: `emulation/charx_v190/pentest/firmware_browser/__init__.py`
  - Package marker and version.
- Create: `emulation/charx_v190/pentest/firmware_browser/models.py`
  - Shared dataclasses for context, findings, engine results, and tool availability.
- Create: `emulation/charx_v190/pentest/firmware_browser/paths.py`
  - Rootfs path resolution and containment checks.
- Create: `emulation/charx_v190/pentest/firmware_browser/evidence.py`
  - JSONL evidence/finding writer wrappers.
- Create: `emulation/charx_v190/pentest/firmware_browser/languages.py`
  - Product-neutral language catalog for CodeQL/Semgrep/source-like files.
- Create: `emulation/charx_v190/pentest/firmware_browser/engines/inventory.py`
  - File inventory and type summary.
- Create: `emulation/charx_v190/pentest/firmware_browser/engines/config_routes.py`
  - Generic parser for route/config/init/nginx-like metadata.
- Create: `emulation/charx_v190/pentest/firmware_browser/engines/binary.py`
  - ELF metadata, shared-object map, optional imports/symbols/strings excerpts.
- Create: `emulation/charx_v190/pentest/firmware_browser/engines/semgrep_engine.py`
  - Optional Semgrep runner over source/script/config subsets.
- Create: `emulation/charx_v190/pentest/firmware_browser/engines/codeql_engine.py`
  - Optional CodeQL version and source-language planning helpers for supported source languages. Database/analyze commands are a follow-up once the language plan proves useful on real firmware source assets.
- Create: `emulation/charx_v190/pentest/firmware_browser/orchestrator.py`
  - Engine ordering, output paths, and scan lifecycle.
- Create: `emulation/charx_v190/pentest/firmware_browser/skill_context.py`
  - Export compact skill context for future Codex/Claude auto-pentest skills.
- Create: `emulation/charx_v190/pentest/tests/test_firmware_browser_*.py`
  - Focused tests per unit.
- Modify: `document/charx_sec_3100_local_pentest_workstation_guide_vi.md`
  - Document multi-engine browser and explain CodeQL/Semgrep/Joern/Ghidra roles.
- Modify: `emulation/charx_v190/pentest/README.md`
  - Update command examples.

## CLI Shape

Target commands:

```powershell
.\emulation\charx_v190\charx-pentest.cmd code-browser scan --rootfs D:\path\rootfs --product-name generic-linux
.\emulation\charx_v190\charx-pentest.cmd code-browser inventory --rootfs D:\path\rootfs
.\emulation\charx_v190\charx-pentest.cmd code-browser routes --rootfs D:\path\rootfs
.\emulation\charx_v190\charx-pentest.cmd code-browser binary-map --rootfs D:\path\rootfs
.\emulation\charx_v190\charx-pentest.cmd code-browser semgrep --rootfs D:\path\rootfs --config auto
.\emulation\charx_v190\charx-pentest.cmd code-browser codeql-version
.\emulation\charx_v190\charx-pentest.cmd code-browser codeql-plan --rootfs D:\path\rootfs
.\emulation\charx_v190\charx-pentest.cmd code-browser skill-context --rootfs D:\path\rootfs
```

Legacy command policy:

- Remove `code-browser rg`, `code-browser strings`, and `code-browser readelf` from the primary CLI.
- Route old use cases through engines: source/config scan through `semgrep` or future `source-search`, ELF metadata/string triage through `binary-map`, CodeQL-supported source scan through `codeql-plan`.
- Do not use `rg` as the default browser workflow.

---

### Task 1: Package Scaffolding And Shared Models

**Files:**
- Create: `emulation/charx_v190/pentest/firmware_browser/__init__.py`
- Create: `emulation/charx_v190/pentest/firmware_browser/models.py`
- Create: `emulation/charx_v190/pentest/firmware_browser/paths.py`
- Test: `emulation/charx_v190/pentest/tests/test_firmware_browser_models.py`

- [ ] **Step 1: Write failing tests for path containment and model serialization**

Create `emulation/charx_v190/pentest/tests/test_firmware_browser_models.py`:

```python
from pathlib import Path

from firmware_browser.models import BrowserContext, Finding
from firmware_browser.paths import resolve_rootfs, require_inside_rootfs


def test_browser_context_uses_product_neutral_paths(tmp_path: Path) -> None:
    rootfs = tmp_path / "rootfs"
    rootfs.mkdir()
    out = tmp_path / "out"

    context = BrowserContext(rootfs=rootfs, output_dir=out, product_name="generic-linux")

    assert context.product_name == "generic-linux"
    assert context.findings_path == out / "findings.jsonl"
    assert context.inventory_path == out / "inventory.json"
    assert context.skill_context_path == out / "skill_context.json"


def test_finding_serializes_without_behavior_claim(tmp_path: Path) -> None:
    finding = Finding(
        engine="inventory",
        category="file",
        path="etc/passwd",
        summary="text file",
        details={"kind": "text"},
    )

    row = finding.to_event(component="firmware_browser")

    assert row["label"] == "unknown"
    assert row["behavior_claim_allowed"] is False
    assert row["details"]["engine"] == "inventory"


def test_resolve_rootfs_requires_existing_directory(tmp_path: Path) -> None:
    rootfs = tmp_path / "rootfs"
    rootfs.mkdir()

    assert resolve_rootfs(str(rootfs)) == rootfs.resolve()


def test_require_inside_rootfs_rejects_escape(tmp_path: Path) -> None:
    rootfs = tmp_path / "rootfs"
    rootfs.mkdir()
    outside = tmp_path / "outside.txt"
    outside.write_text("x", encoding="utf-8")

    try:
        require_inside_rootfs(rootfs, outside)
    except ValueError as exc:
        assert "outside rootfs" in str(exc)
    else:
        raise AssertionError("outside path was accepted")
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
cd /mnt/d/CHARXSEC/.worktrees/charx-pentest-workstation/emulation/charx_v190/pentest
. .venv/bin/activate
PYTHONPATH=. pytest tests/test_firmware_browser_models.py -q
```

Expected: fail with `ModuleNotFoundError: No module named 'firmware_browser'`.

- [ ] **Step 3: Create package and models**

Create `emulation/charx_v190/pentest/firmware_browser/__init__.py`:

```python
from __future__ import annotations

__version__ = "0.1.0"
```

Create `emulation/charx_v190/pentest/firmware_browser/models.py`:

```python
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class BrowserContext:
    rootfs: Path
    output_dir: Path
    product_name: str = "generic-firmware"

    @property
    def findings_path(self) -> Path:
        return self.output_dir / "findings.jsonl"

    @property
    def inventory_path(self) -> Path:
        return self.output_dir / "inventory.json"

    @property
    def skill_context_path(self) -> Path:
        return self.output_dir / "skill_context.json"


@dataclass(frozen=True)
class Finding:
    engine: str
    category: str
    path: str
    summary: str
    details: dict[str, Any] = field(default_factory=dict)

    def to_event(self, component: str) -> dict[str, Any]:
        return {
            "event_type": "firmware_browser_finding",
            "label": "unknown",
            "component": component,
            "summary": self.summary,
            "command": [],
            "exit_code": 0,
            "artifact_path": self.path,
            "behavior_claim_allowed": False,
            "details": {
                "engine": self.engine,
                "category": self.category,
                **self.details,
            },
        }


@dataclass(frozen=True)
class EngineResult:
    engine: str
    findings: list[Finding]
    exit_code: int = 0
    details: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class ToolStatus:
    name: str
    available: bool
    version: str = ""
    error: str = ""
```

Create `emulation/charx_v190/pentest/firmware_browser/paths.py`:

```python
from __future__ import annotations

from pathlib import Path


def resolve_rootfs(rootfs: str) -> Path:
    path = Path(rootfs).expanduser().resolve()
    if not path.is_dir():
        raise SystemExit(f"rootfs must be an existing directory: {path}")
    return path


def require_inside_rootfs(rootfs: Path, path: Path) -> Path:
    resolved = path.resolve()
    try:
        resolved.relative_to(rootfs.resolve())
    except ValueError as exc:
        raise ValueError(f"path is outside rootfs: {path}") from exc
    return resolved


def rootfs_relative(rootfs: Path, path: Path) -> str:
    return str(require_inside_rootfs(rootfs, path).relative_to(rootfs.resolve()))
```

- [ ] **Step 4: Run tests to verify pass**

Run:

```bash
PYTHONPATH=. pytest tests/test_firmware_browser_models.py -q
```

Expected: `4 passed`.

- [ ] **Step 5: Commit**

```bash
git add emulation/charx_v190/pentest/firmware_browser emulation/charx_v190/pentest/tests/test_firmware_browser_models.py
git commit -m "feat: scaffold firmware browser core"
```

### Task 2: Evidence Writers For Browser Findings

**Files:**
- Create: `emulation/charx_v190/pentest/firmware_browser/evidence.py`
- Test: `emulation/charx_v190/pentest/tests/test_firmware_browser_evidence.py`

- [ ] **Step 1: Write failing evidence writer tests**

Create `emulation/charx_v190/pentest/tests/test_firmware_browser_evidence.py`:

```python
import json
from pathlib import Path

from firmware_browser.evidence import write_finding_jsonl, write_json
from firmware_browser.models import Finding


def test_write_finding_jsonl_appends_non_claiming_event(tmp_path: Path) -> None:
    path = tmp_path / "findings.jsonl"
    finding = Finding("inventory", "config", "etc/app.conf", "config found")

    write_finding_jsonl(path, "firmware_browser", finding)

    row = json.loads(path.read_text(encoding="utf-8"))
    assert row["label"] == "unknown"
    assert row["behavior_claim_allowed"] is False
    assert row["details"]["engine"] == "inventory"


def test_write_json_creates_parent_directory(tmp_path: Path) -> None:
    path = tmp_path / "nested" / "inventory.json"

    write_json(path, {"total": 1})

    assert json.loads(path.read_text(encoding="utf-8")) == {"total": 1}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
PYTHONPATH=. pytest tests/test_firmware_browser_evidence.py -q
```

Expected: fail with missing `firmware_browser.evidence`.

- [ ] **Step 3: Implement evidence writer**

Create `emulation/charx_v190/pentest/firmware_browser/evidence.py`:

```python
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from state_store import utc_now

from .models import Finding


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def write_finding_jsonl(path: Path, component: str, finding: Finding) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    event = finding.to_event(component)
    event.setdefault("timestamp", utc_now())
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(event, ensure_ascii=False, sort_keys=True) + "\n")
```

- [ ] **Step 4: Run tests to verify pass**

Run:

```bash
PYTHONPATH=. pytest tests/test_firmware_browser_evidence.py -q
```

Expected: `2 passed`.

- [ ] **Step 5: Commit**

```bash
git add emulation/charx_v190/pentest/firmware_browser/evidence.py emulation/charx_v190/pentest/tests/test_firmware_browser_evidence.py
git commit -m "feat: add firmware browser evidence writers"
```

### Task 3: Product-Neutral Inventory Engine

**Files:**
- Create: `emulation/charx_v190/pentest/firmware_browser/engines/__init__.py`
- Create: `emulation/charx_v190/pentest/firmware_browser/engines/inventory.py`
- Test: `emulation/charx_v190/pentest/tests/test_firmware_browser_inventory.py`

- [ ] **Step 1: Write failing inventory tests**

Create `emulation/charx_v190/pentest/tests/test_firmware_browser_inventory.py`:

```python
from pathlib import Path

from firmware_browser.engines.inventory import inventory_rootfs


def test_inventory_classifies_common_firmware_file_types(tmp_path: Path) -> None:
    rootfs = tmp_path / "rootfs"
    (rootfs / "etc" / "init.d").mkdir(parents=True)
    (rootfs / "etc" / "charx").mkdir(parents=True)
    (rootfs / "usr" / "lib" / "app").mkdir(parents=True)
    (rootfs / "www").mkdir()
    (rootfs / "etc" / "init.d" / "app").write_text("#!/bin/sh\n", encoding="utf-8")
    (rootfs / "etc" / "charx" / "routePermissions.json").write_text("{}", encoding="utf-8")
    (rootfs / "usr" / "lib" / "app" / "module.so").write_bytes(b"\\x7fELF")
    (rootfs / "www" / "app.js").write_text("console.log(1)\n", encoding="utf-8")

    result = inventory_rootfs(rootfs)

    assert result.details["summary"]["total_files"] == 4
    assert result.details["summary"]["shared_objects"] == 1
    assert result.details["summary"]["json"] == 1
    assert result.details["summary"]["javascript"] == 1
    assert result.details["summary"]["shell_or_init"] == 1
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
PYTHONPATH=. pytest tests/test_firmware_browser_inventory.py -q
```

Expected: fail with missing `firmware_browser.engines.inventory`.

- [ ] **Step 3: Implement inventory engine**

Create `emulation/charx_v190/pentest/firmware_browser/engines/__init__.py`:

```python
from __future__ import annotations
```

Create `emulation/charx_v190/pentest/firmware_browser/engines/inventory.py`:

```python
from __future__ import annotations

from pathlib import Path

from firmware_browser.models import EngineResult, Finding
from firmware_browser.paths import rootfs_relative


def category_for(rootfs: Path, path: Path) -> str:
    rel = rootfs_relative(rootfs, path)
    suffix = path.suffix.lower()
    if suffix == ".so":
        return "shared_object"
    if suffix in {".js", ".mjs", ".map"}:
        return "javascript"
    if suffix in {".html", ".htm"}:
        return "html"
    if suffix == ".json":
        return "json"
    if suffix in {".conf", ".cfg", ".ini"} or rel.startswith("etc/"):
        return "config"
    if suffix == ".sh" or rel.startswith("etc/init.d/") or rel.startswith("usr/local/bin/"):
        return "shell_or_init"
    return "file"


def inventory_rootfs(rootfs: Path) -> EngineResult:
    counts = {
        "total_files": 0,
        "shared_objects": 0,
        "javascript": 0,
        "html": 0,
        "json": 0,
        "config": 0,
        "shell_or_init": 0,
    }
    findings: list[Finding] = []

    for path in sorted(rootfs.rglob("*")):
        if not path.is_file():
            continue
        counts["total_files"] += 1
        category = category_for(rootfs, path)
        if category == "shared_object":
            counts["shared_objects"] += 1
        elif category in counts:
            counts[category] += 1
        findings.append(
            Finding(
                engine="inventory",
                category=category,
                path=rootfs_relative(rootfs, path),
                summary=f"{category}: {rootfs_relative(rootfs, path)}",
                details={"size": path.stat().st_size},
            )
        )

    return EngineResult(
        engine="inventory",
        findings=findings,
        details={"summary": counts},
    )
```

- [ ] **Step 4: Run inventory tests**

Run:

```bash
PYTHONPATH=. pytest tests/test_firmware_browser_inventory.py -q
```

Expected: `1 passed`.

- [ ] **Step 5: Commit**

```bash
git add emulation/charx_v190/pentest/firmware_browser/engines emulation/charx_v190/pentest/tests/test_firmware_browser_inventory.py
git commit -m "feat: add firmware inventory engine"
```

### Task 4: Language Catalog For CodeQL And Semgrep Routing

**Files:**
- Create: `emulation/charx_v190/pentest/firmware_browser/languages.py`
- Test: `emulation/charx_v190/pentest/tests/test_firmware_browser_languages.py`

- [ ] **Step 1: Write failing language catalog tests**

Create `emulation/charx_v190/pentest/tests/test_firmware_browser_languages.py`:

```python
from firmware_browser.languages import detect_language, supported_codeql_languages, supported_semgrep_languages


def test_detect_language_for_common_firmware_source_assets() -> None:
    assert detect_language("usr/lib/app/dist/main.js") == "javascript"
    assert detect_language("etc/init.d/app") == "shell"
    assert detect_language("usr/local/bin/helper.py") == "python"
    assert detect_language("etc/app/config.json") == "json"
    assert detect_language("usr/lib/app/module.so") is None


def test_codeql_catalog_does_not_claim_binary_support() -> None:
    languages = supported_codeql_languages()

    assert "cpp" in languages
    assert "javascript-typescript" in languages
    assert "arm-elf" not in languages


def test_semgrep_catalog_covers_script_and_config_workflows() -> None:
    languages = supported_semgrep_languages()

    assert "javascript" in languages
    assert "python" in languages
    assert "generic" in languages
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
PYTHONPATH=. pytest tests/test_firmware_browser_languages.py -q
```

Expected: fail with missing `firmware_browser.languages`.

- [ ] **Step 3: Implement language catalog**

Create `emulation/charx_v190/pentest/firmware_browser/languages.py`:

```python
from __future__ import annotations

from pathlib import Path


CODEQL_LANGUAGES = {
    "cpp",
    "csharp",
    "go",
    "java-kotlin",
    "javascript-typescript",
    "python",
    "ruby",
    "rust",
    "swift",
}

SEMGREP_LANGUAGES = {
    "c",
    "cpp",
    "csharp",
    "go",
    "java",
    "javascript",
    "json",
    "kotlin",
    "php",
    "python",
    "ruby",
    "rust",
    "shell",
    "swift",
    "typescript",
    "yaml",
    "generic",
}

EXTENSION_LANGUAGE = {
    ".c": "cpp",
    ".cc": "cpp",
    ".cpp": "cpp",
    ".h": "cpp",
    ".hpp": "cpp",
    ".cs": "csharp",
    ".go": "go",
    ".java": "java",
    ".kt": "kotlin",
    ".js": "javascript",
    ".mjs": "javascript",
    ".ts": "typescript",
    ".py": "python",
    ".rb": "ruby",
    ".rs": "rust",
    ".swift": "swift",
    ".json": "json",
    ".yaml": "yaml",
    ".yml": "yaml",
    ".sh": "shell",
}


def detect_language(path: str) -> str | None:
    normalized = path.replace("\\", "/")
    if "/etc/init.d/" in normalized or "/usr/local/bin/" in normalized:
        if Path(normalized).suffix == ".py":
            return "python"
        return "shell"
    return EXTENSION_LANGUAGE.get(Path(normalized).suffix.lower())


def supported_codeql_languages() -> set[str]:
    return set(CODEQL_LANGUAGES)


def supported_semgrep_languages() -> set[str]:
    return set(SEMGREP_LANGUAGES)


def codeql_language_for_detected(language: str) -> str | None:
    if language in {"javascript", "typescript"}:
        return "javascript-typescript"
    if language == "java" or language == "kotlin":
        return "java-kotlin"
    if language in CODEQL_LANGUAGES:
        return language
    return None
```

- [ ] **Step 4: Run language tests**

Run:

```bash
PYTHONPATH=. pytest tests/test_firmware_browser_languages.py -q
```

Expected: `3 passed`.

- [ ] **Step 5: Commit**

```bash
git add emulation/charx_v190/pentest/firmware_browser/languages.py emulation/charx_v190/pentest/tests/test_firmware_browser_languages.py
git commit -m "feat: add firmware source language catalog"
```

### Task 5: Generic Config And Route Engine

**Files:**
- Create: `emulation/charx_v190/pentest/firmware_browser/engines/config_routes.py`
- Test: `emulation/charx_v190/pentest/tests/test_firmware_browser_config_routes.py`

- [ ] **Step 1: Write failing config/route tests**

Create `emulation/charx_v190/pentest/tests/test_firmware_browser_config_routes.py`:

```python
import json
from pathlib import Path

from firmware_browser.engines.config_routes import scan_config_routes


def test_route_permissions_like_json_is_parsed_generically(tmp_path: Path) -> None:
    rootfs = tmp_path / "rootfs"
    route_dir = rootfs / "etc" / "charx"
    route_dir.mkdir(parents=True)
    (route_dir / "routePermissions.json").write_text(
        json.dumps({"/api/example": ["user", "operator"]}),
        encoding="utf-8",
    )

    result = scan_config_routes(rootfs)

    route_findings = [finding for finding in result.findings if finding.category == "route"]
    assert route_findings[0].path == "etc/charx/routePermissions.json"
    assert route_findings[0].details["route"] == "/api/example"
    assert route_findings[0].details["roles"] == ["user", "operator"]


def test_service_conf_ports_are_extracted_without_product_name(tmp_path: Path) -> None:
    rootfs = tmp_path / "rootfs"
    conf_dir = rootfs / "etc" / "app"
    conf_dir.mkdir(parents=True)
    (conf_dir / "service.conf").write_text("RestPort=5000\\nPeer=127.0.0.1:1883\\n", encoding="utf-8")

    result = scan_config_routes(rootfs)

    ports = [finding for finding in result.findings if finding.category == "port_hint"]
    assert {finding.details["port"] for finding in ports} == {"5000", "1883"}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
PYTHONPATH=. pytest tests/test_firmware_browser_config_routes.py -q
```

Expected: fail with missing module.

- [ ] **Step 3: Implement config/route engine**

Create `emulation/charx_v190/pentest/firmware_browser/engines/config_routes.py`:

```python
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from firmware_browser.models import EngineResult, Finding
from firmware_browser.paths import rootfs_relative


PORT_PATTERN = re.compile(r"(?<!\\d)([1-9][0-9]{1,4})(?!\\d)")


def route_entries(payload: Any) -> list[tuple[str, Any]]:
    if isinstance(payload, dict):
        return [(key, value) for key, value in payload.items() if isinstance(key, str) and key.startswith("/")]
    if isinstance(payload, list):
        entries: list[tuple[str, Any]] = []
        for item in payload:
            if isinstance(item, dict):
                route = item.get("route") or item.get("path") or item.get("pattern")
                if isinstance(route, str) and route.startswith("/"):
                    entries.append((route, item))
        return entries
    return []


def roles_from(value: Any) -> list[str]:
    if isinstance(value, list):
        return [str(item) for item in value]
    if isinstance(value, dict):
        roles = value.get("roles") or value.get("permissions") or value.get("allowed")
        if isinstance(roles, list):
            return [str(item) for item in roles]
    return []


def scan_json_routes(rootfs: Path, path: Path) -> list[Finding]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError, UnicodeDecodeError):
        return []
    findings: list[Finding] = []
    for route, value in route_entries(payload):
        findings.append(
            Finding(
                engine="config_routes",
                category="route",
                path=rootfs_relative(rootfs, path),
                summary=f"route {route}",
                details={"route": route, "roles": roles_from(value)},
            )
        )
    return findings


def scan_ports(rootfs: Path, path: Path) -> list[Finding]:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return []
    findings: list[Finding] = []
    for port in sorted(set(PORT_PATTERN.findall(text))):
        value = int(port)
        if 1 <= value <= 65535:
            findings.append(
                Finding(
                    engine="config_routes",
                    category="port_hint",
                    path=rootfs_relative(rootfs, path),
                    summary=f"port hint {port}",
                    details={"port": port},
                )
            )
    return findings


def scan_config_routes(rootfs: Path) -> EngineResult:
    findings: list[Finding] = []
    for path in sorted(rootfs.rglob("*")):
        if not path.is_file():
            continue
        rel = rootfs_relative(rootfs, path)
        suffix = path.suffix.lower()
        if suffix == ".json":
            findings.extend(scan_json_routes(rootfs, path))
        if suffix in {".conf", ".cfg", ".ini", ".json"} or rel.startswith("etc/"):
            findings.extend(scan_ports(rootfs, path))
    return EngineResult(engine="config_routes", findings=findings, details={"count": len(findings)})
```

- [ ] **Step 4: Run config/route tests**

Run:

```bash
PYTHONPATH=. pytest tests/test_firmware_browser_config_routes.py -q
```

Expected: `2 passed`.

- [ ] **Step 5: Commit**

```bash
git add emulation/charx_v190/pentest/firmware_browser/engines/config_routes.py emulation/charx_v190/pentest/tests/test_firmware_browser_config_routes.py
git commit -m "feat: add firmware config route engine"
```

### Task 6: Binary Metadata Engine

**Files:**
- Create: `emulation/charx_v190/pentest/firmware_browser/engines/binary.py`
- Test: `emulation/charx_v190/pentest/tests/test_firmware_browser_binary.py`

- [ ] **Step 1: Write failing binary tests**

Create `emulation/charx_v190/pentest/tests/test_firmware_browser_binary.py`:

```python
import subprocess
from pathlib import Path

from firmware_browser.engines.binary import binary_map


def test_binary_map_records_elf_and_shared_object(monkeypatch, tmp_path: Path) -> None:
    rootfs = tmp_path / "rootfs"
    lib = rootfs / "usr" / "lib" / "app"
    lib.mkdir(parents=True)
    binary = lib / "module.so"
    binary.write_bytes(b"not really elf")

    def fake_run(command, **kwargs):
        return subprocess.CompletedProcess(
            command,
            0,
            "ELF 32-bit LSB shared object, ARM, stripped\\n",
            "",
        )

    monkeypatch.setattr(subprocess, "run", fake_run)

    result = binary_map(rootfs)

    assert result.findings[0].category == "elf"
    assert result.findings[0].path == "usr/lib/app/module.so"
    assert result.findings[0].details["is_shared_object"] is True
    assert "ARM" in result.findings[0].details["file_output"]
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
PYTHONPATH=. pytest tests/test_firmware_browser_binary.py -q
```

Expected: fail with missing module.

- [ ] **Step 3: Implement binary metadata engine**

Create `emulation/charx_v190/pentest/firmware_browser/engines/binary.py`:

```python
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

from firmware_browser.models import EngineResult, Finding
from firmware_browser.paths import rootfs_relative


def file_output(path: Path) -> str:
    if shutil.which("file") is None:
        return ""
    completed = subprocess.run(
        ["file", "-b", str(path)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=10,
        check=False,
    )
    return (completed.stdout or completed.stderr).strip()


def binary_map(rootfs: Path) -> EngineResult:
    findings: list[Finding] = []
    for path in sorted(rootfs.rglob("*")):
        if not path.is_file():
            continue
        output = file_output(path)
        if "ELF" not in output and path.suffix != ".so":
            continue
        rel = rootfs_relative(rootfs, path)
        findings.append(
            Finding(
                engine="binary",
                category="elf",
                path=rel,
                summary=f"ELF artifact: {rel}",
                details={
                    "file_output": output,
                    "is_shared_object": path.suffix == ".so" or "shared object" in output,
                    "is_stripped": "stripped" in output,
                    "architecture_hint": "ARM" if "ARM" in output else "",
                    "size": path.stat().st_size,
                },
            )
        )
    return EngineResult(engine="binary", findings=findings, details={"count": len(findings)})
```

- [ ] **Step 4: Run binary tests**

Run:

```bash
PYTHONPATH=. pytest tests/test_firmware_browser_binary.py -q
```

Expected: `1 passed`.

- [ ] **Step 5: Commit**

```bash
git add emulation/charx_v190/pentest/firmware_browser/engines/binary.py emulation/charx_v190/pentest/tests/test_firmware_browser_binary.py
git commit -m "feat: add firmware binary metadata engine"
```

### Task 7: Semgrep Engine Wrapper

**Files:**
- Create: `emulation/charx_v190/pentest/firmware_browser/engines/semgrep_engine.py`
- Test: `emulation/charx_v190/pentest/tests/test_firmware_browser_semgrep.py`

- [ ] **Step 1: Write failing Semgrep tests**

Create `emulation/charx_v190/pentest/tests/test_firmware_browser_semgrep.py`:

```python
import subprocess
from pathlib import Path

from firmware_browser.engines.semgrep_engine import semgrep_scan


def test_semgrep_missing_tool_is_non_blocking(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setattr("shutil.which", lambda tool: None)
    rootfs = tmp_path / "rootfs"
    rootfs.mkdir()

    result = semgrep_scan(rootfs, config="auto")

    assert result.exit_code == 127
    assert result.findings[0].category == "missing_tool"


def test_semgrep_json_results_become_findings(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setattr("shutil.which", lambda tool: "/usr/bin/semgrep")
    rootfs = tmp_path / "rootfs"
    rootfs.mkdir()

    def fake_run(command, **kwargs):
        return subprocess.CompletedProcess(
            command,
            0,
            '{"results":[{"check_id":"rule.demo","path":"www/app.js","start":{"line":5},"extra":{"message":"demo"}}]}',
            "",
        )

    monkeypatch.setattr(subprocess, "run", fake_run)

    result = semgrep_scan(rootfs, config="auto")

    assert result.findings[0].category == "semgrep_result"
    assert result.findings[0].path == "www/app.js"
    assert result.findings[0].details["check_id"] == "rule.demo"
```

- [ ] **Step 2: Run tests to verify fail**

Run:

```bash
PYTHONPATH=. pytest tests/test_firmware_browser_semgrep.py -q
```

Expected: fail with missing module.

- [ ] **Step 3: Implement Semgrep engine**

Create `emulation/charx_v190/pentest/firmware_browser/engines/semgrep_engine.py`:

```python
from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

from firmware_browser.models import EngineResult, Finding


def semgrep_scan(rootfs: Path, config: str = "auto") -> EngineResult:
    command = ["semgrep", "scan", "--json", "--config", config, str(rootfs)]
    if shutil.which("semgrep") is None:
        return EngineResult(
            engine="semgrep",
            findings=[
                Finding(
                    engine="semgrep",
                    category="missing_tool",
                    path="",
                    summary="semgrep CLI is not installed",
                    details={"command": command},
                )
            ],
            exit_code=127,
        )

    completed = subprocess.run(
        command,
        cwd=rootfs,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=300,
        check=False,
    )
    findings: list[Finding] = []
    try:
        payload = json.loads(completed.stdout or "{}")
    except json.JSONDecodeError:
        payload = {"results": []}
    for row in payload.get("results", []):
        extra = row.get("extra", {})
        findings.append(
            Finding(
                engine="semgrep",
                category="semgrep_result",
                path=str(row.get("path", "")),
                summary=str(extra.get("message", row.get("check_id", "semgrep result"))),
                details={
                    "check_id": row.get("check_id"),
                    "line": row.get("start", {}).get("line"),
                    "stderr_excerpt": completed.stderr[:4000],
                },
            )
        )
    return EngineResult(engine="semgrep", findings=findings, exit_code=completed.returncode)
```

- [ ] **Step 4: Run Semgrep tests**

Run:

```bash
PYTHONPATH=. pytest tests/test_firmware_browser_semgrep.py -q
```

Expected: `2 passed`.

- [ ] **Step 5: Commit**

```bash
git add emulation/charx_v190/pentest/firmware_browser/engines/semgrep_engine.py emulation/charx_v190/pentest/tests/test_firmware_browser_semgrep.py
git commit -m "feat: add semgrep firmware browser engine"
```

### Task 8: CodeQL Engine Wrapper And Plan Mode

**Files:**
- Create: `emulation/charx_v190/pentest/firmware_browser/engines/codeql_engine.py`
- Test: `emulation/charx_v190/pentest/tests/test_firmware_browser_codeql.py`

- [ ] **Step 1: Write failing CodeQL tests**

Create `emulation/charx_v190/pentest/tests/test_firmware_browser_codeql.py`:

```python
from pathlib import Path

from firmware_browser.engines.codeql_engine import codeql_plan, codeql_version


def test_codeql_plan_detects_supported_source_languages(tmp_path: Path) -> None:
    rootfs = tmp_path / "rootfs"
    (rootfs / "www").mkdir(parents=True)
    (rootfs / "scripts").mkdir()
    (rootfs / "www" / "app.js").write_text("console.log(1)", encoding="utf-8")
    (rootfs / "scripts" / "probe.py").write_text("print(1)", encoding="utf-8")
    (rootfs / "lib.so").write_bytes(b"\\x7fELF")

    result = codeql_plan(rootfs)

    assert result.details["languages"] == ["javascript-typescript", "python"]
    assert result.findings[0].category == "codeql_plan"


def test_codeql_version_missing_is_non_blocking(monkeypatch) -> None:
    monkeypatch.setattr("shutil.which", lambda tool: None)

    result = codeql_version()

    assert result.exit_code == 127
    assert result.findings[0].category == "missing_tool"
```

- [ ] **Step 2: Run tests to verify fail**

Run:

```bash
PYTHONPATH=. pytest tests/test_firmware_browser_codeql.py -q
```

Expected: fail with missing module.

- [ ] **Step 3: Implement CodeQL engine**

Create `emulation/charx_v190/pentest/firmware_browser/engines/codeql_engine.py`:

```python
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

from firmware_browser.languages import codeql_language_for_detected, detect_language
from firmware_browser.models import EngineResult, Finding
from firmware_browser.paths import rootfs_relative


def codeql_version() -> EngineResult:
    command = ["codeql", "version"]
    if shutil.which("codeql") is None:
        return EngineResult(
            engine="codeql",
            findings=[
                Finding(
                    engine="codeql",
                    category="missing_tool",
                    path="",
                    summary="codeql CLI is not installed",
                    details={"command": command},
                )
            ],
            exit_code=127,
        )
    completed = subprocess.run(
        command,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=60,
        check=False,
    )
    return EngineResult(
        engine="codeql",
        findings=[
            Finding(
                engine="codeql",
                category="version",
                path="",
                summary="codeql version",
                details={"stdout_excerpt": completed.stdout[:4000], "stderr_excerpt": completed.stderr[:4000]},
            )
        ],
        exit_code=completed.returncode,
    )


def codeql_plan(rootfs: Path) -> EngineResult:
    language_paths: dict[str, list[str]] = {}
    for path in sorted(rootfs.rglob("*")):
        if not path.is_file():
            continue
        detected = detect_language(rootfs_relative(rootfs, path))
        if detected is None:
            continue
        codeql_language = codeql_language_for_detected(detected)
        if codeql_language is None:
            continue
        language_paths.setdefault(codeql_language, []).append(rootfs_relative(rootfs, path))

    languages = sorted(language_paths)
    return EngineResult(
        engine="codeql",
        findings=[
            Finding(
                engine="codeql",
                category="codeql_plan",
                path="",
                summary=f"CodeQL-supported languages: {', '.join(languages) if languages else 'none'}",
                details={"languages": languages, "sample_paths": {k: v[:20] for k, v in language_paths.items()}},
            )
        ],
        details={"languages": languages, "language_paths": language_paths},
    )
```

- [ ] **Step 4: Run CodeQL tests**

Run:

```bash
PYTHONPATH=. pytest tests/test_firmware_browser_codeql.py -q
```

Expected: `2 passed`.

- [ ] **Step 5: Commit**

```bash
git add emulation/charx_v190/pentest/firmware_browser/engines/codeql_engine.py emulation/charx_v190/pentest/tests/test_firmware_browser_codeql.py
git commit -m "feat: add codeql planning engine"
```

### Task 9: Orchestrator And Scan Outputs

**Files:**
- Create: `emulation/charx_v190/pentest/firmware_browser/orchestrator.py`
- Test: `emulation/charx_v190/pentest/tests/test_firmware_browser_orchestrator.py`

- [ ] **Step 1: Write failing orchestrator tests**

Create `emulation/charx_v190/pentest/tests/test_firmware_browser_orchestrator.py`:

```python
import json
from pathlib import Path

from firmware_browser.models import BrowserContext
from firmware_browser.orchestrator import run_scan


def test_run_scan_writes_inventory_and_findings(tmp_path: Path) -> None:
    rootfs = tmp_path / "rootfs"
    rootfs.mkdir()
    (rootfs / "etc").mkdir()
    (rootfs / "etc" / "app.conf").write_text("Port=5000\\n", encoding="utf-8")
    context = BrowserContext(rootfs=rootfs, output_dir=tmp_path / "out", product_name="demo")

    exit_code = run_scan(context, engines=["inventory", "config_routes", "codeql_plan"])

    assert exit_code == 0
    assert json.loads(context.inventory_path.read_text(encoding="utf-8"))["product_name"] == "demo"
    lines = context.findings_path.read_text(encoding="utf-8").splitlines()
    assert any('"engine": "inventory"' in line for line in lines)
    assert any('"engine": "config_routes"' in line for line in lines)
```

- [ ] **Step 2: Run tests to verify fail**

Run:

```bash
PYTHONPATH=. pytest tests/test_firmware_browser_orchestrator.py -q
```

Expected: fail with missing `orchestrator`.

- [ ] **Step 3: Implement orchestrator**

Create `emulation/charx_v190/pentest/firmware_browser/orchestrator.py`:

```python
from __future__ import annotations

from firmware_browser.engines.binary import binary_map
from firmware_browser.engines.codeql_engine import codeql_plan
from firmware_browser.engines.config_routes import scan_config_routes
from firmware_browser.engines.inventory import inventory_rootfs
from firmware_browser.engines.semgrep_engine import semgrep_scan
from firmware_browser.evidence import write_finding_jsonl, write_json
from firmware_browser.models import BrowserContext, EngineResult


ENGINE_ORDER = ["inventory", "config_routes", "binary", "codeql_plan", "semgrep"]


def run_engine(name: str, context: BrowserContext) -> EngineResult:
    if name == "inventory":
        return inventory_rootfs(context.rootfs)
    if name == "config_routes":
        return scan_config_routes(context.rootfs)
    if name == "binary":
        return binary_map(context.rootfs)
    if name == "codeql_plan":
        return codeql_plan(context.rootfs)
    if name == "semgrep":
        return semgrep_scan(context.rootfs, config="auto")
    raise SystemExit(f"unknown engine: {name}")


def run_scan(context: BrowserContext, engines: list[str] | None = None) -> int:
    selected = engines or ENGINE_ORDER
    context.output_dir.mkdir(parents=True, exist_ok=True)
    if context.findings_path.exists():
        context.findings_path.unlink()

    inventory_payload = {
        "product_name": context.product_name,
        "rootfs": str(context.rootfs),
        "engines": selected,
        "engine_results": {},
    }
    exit_code = 0
    for engine in selected:
        result = run_engine(engine, context)
        inventory_payload["engine_results"][engine] = {
            "finding_count": len(result.findings),
            "exit_code": result.exit_code,
            "details": result.details,
        }
        if result.exit_code not in (0, 1, 127):
            exit_code = result.exit_code
        for finding in result.findings:
            write_finding_jsonl(context.findings_path, "firmware_browser", finding)

    write_json(context.inventory_path, inventory_payload)
    return exit_code
```

- [ ] **Step 4: Run orchestrator tests**

Run:

```bash
PYTHONPATH=. pytest tests/test_firmware_browser_orchestrator.py -q
```

Expected: `1 passed`.

- [ ] **Step 5: Commit**

```bash
git add emulation/charx_v190/pentest/firmware_browser/orchestrator.py emulation/charx_v190/pentest/tests/test_firmware_browser_orchestrator.py
git commit -m "feat: add firmware browser engine orchestrator"
```

### Task 10: Skill Context Export

**Files:**
- Create: `emulation/charx_v190/pentest/firmware_browser/skill_context.py`
- Test: `emulation/charx_v190/pentest/tests/test_firmware_browser_skill_context.py`

- [ ] **Step 1: Write failing skill context tests**

Create `emulation/charx_v190/pentest/tests/test_firmware_browser_skill_context.py`:

```python
import json
from pathlib import Path

from firmware_browser.models import BrowserContext
from firmware_browser.skill_context import export_skill_context


def test_skill_context_summarizes_browser_outputs(tmp_path: Path) -> None:
    context = BrowserContext(rootfs=tmp_path / "rootfs", output_dir=tmp_path / "out", product_name="demo")
    context.rootfs.mkdir()
    context.output_dir.mkdir()
    context.inventory_path.write_text(
        json.dumps({"engine_results": {"binary": {"finding_count": 2}}}),
        encoding="utf-8",
    )
    context.findings_path.write_text(
        '{"artifact_path":"usr/lib/app/api.so","details":{"engine":"binary","category":"elf"}}\\n',
        encoding="utf-8",
    )

    export_skill_context(context)

    payload = json.loads(context.skill_context_path.read_text(encoding="utf-8"))
    assert payload["product_name"] == "demo"
    assert payload["suggested_skill_use"][0] == "Use binary findings for reverse-engineering triage."
    assert payload["sample_findings"][0]["artifact_path"] == "usr/lib/app/api.so"
```

- [ ] **Step 2: Run tests to verify fail**

Run:

```bash
PYTHONPATH=. pytest tests/test_firmware_browser_skill_context.py -q
```

Expected: fail with missing `skill_context`.

- [ ] **Step 3: Implement skill context exporter**

Create `emulation/charx_v190/pentest/firmware_browser/skill_context.py`:

```python
from __future__ import annotations

import json

from firmware_browser.evidence import write_json
from firmware_browser.models import BrowserContext


def export_skill_context(context: BrowserContext, sample_limit: int = 50) -> None:
    inventory = {}
    if context.inventory_path.exists():
        inventory = json.loads(context.inventory_path.read_text(encoding="utf-8"))
    samples = []
    if context.findings_path.exists():
        with context.findings_path.open("r", encoding="utf-8") as handle:
            for line in handle:
                if line.strip():
                    samples.append(json.loads(line))
                if len(samples) >= sample_limit:
                    break
    write_json(
        context.skill_context_path,
        {
            "product_name": context.product_name,
            "rootfs": str(context.rootfs),
            "inventory_path": str(context.inventory_path),
            "findings_path": str(context.findings_path),
            "engine_results": inventory.get("engine_results", {}),
            "sample_findings": samples,
            "suggested_skill_use": [
                "Use binary findings for reverse-engineering triage.",
                "Use route/config findings to choose authorized runtime probes.",
                "Use CodeQL/Semgrep findings only for supported source/script/config files.",
                "Do not convert static findings into verified firmware behavior without reproduction.",
            ],
        },
    )
```

- [ ] **Step 4: Run skill context tests**

Run:

```bash
PYTHONPATH=. pytest tests/test_firmware_browser_skill_context.py -q
```

Expected: `1 passed`.

- [ ] **Step 5: Commit**

```bash
git add emulation/charx_v190/pentest/firmware_browser/skill_context.py emulation/charx_v190/pentest/tests/test_firmware_browser_skill_context.py
git commit -m "feat: export firmware browser skill context"
```

### Task 11: CLI Migration

**Files:**
- Modify: `emulation/charx_v190/pentest/scripts/code_browser.py`
- Create: `emulation/charx_v190/pentest/firmware_browser/cli.py`
- Test: `emulation/charx_v190/pentest/tests/test_firmware_browser_cli.py`

- [ ] **Step 1: Write failing CLI tests**

Create `emulation/charx_v190/pentest/tests/test_firmware_browser_cli.py`:

```python
import json
from pathlib import Path

from firmware_browser.cli import main


def test_inventory_command_writes_output(tmp_path: Path) -> None:
    rootfs = tmp_path / "rootfs"
    rootfs.mkdir()
    (rootfs / "etc").mkdir()
    (rootfs / "etc" / "app.conf").write_text("Port=5000\\n", encoding="utf-8")
    out = tmp_path / "out"

    assert main(["inventory", "--rootfs", str(rootfs), "--output-dir", str(out), "--product-name", "demo"]) == 0

    payload = json.loads((out / "inventory.json").read_text(encoding="utf-8"))
    assert payload["product_name"] == "demo"


def test_codeql_version_command_handles_missing_tool(monkeypatch) -> None:
    monkeypatch.setattr("shutil.which", lambda tool: None)

    assert main(["codeql-version"]) == 127
```

- [ ] **Step 2: Run CLI tests to verify fail**

Run:

```bash
PYTHONPATH=. pytest tests/test_firmware_browser_cli.py -q
```

Expected: fail with missing `firmware_browser.cli`.

- [ ] **Step 3: Implement CLI**

Create `emulation/charx_v190/pentest/firmware_browser/cli.py`:

```python
from __future__ import annotations

import argparse
from pathlib import Path

from firmware_browser.engines.codeql_engine import codeql_plan, codeql_version
from firmware_browser.models import BrowserContext
from firmware_browser.orchestrator import run_scan
from firmware_browser.paths import resolve_rootfs
from firmware_browser.skill_context import export_skill_context


PENTEST_DIR = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_DIR = PENTEST_DIR / "evidence" / "code_browser"


def context_from_args(args: argparse.Namespace) -> BrowserContext:
    return BrowserContext(
        rootfs=resolve_rootfs(args.rootfs),
        output_dir=Path(args.output_dir).resolve(),
        product_name=args.product_name,
    )


def add_rootfs_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--rootfs", required=True)
    parser.add_argument("--output-dir", default=str(DEFAULT_OUTPUT_DIR))
    parser.add_argument("--product-name", default="generic-firmware")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Multi-engine firmware code browser.")
    sub = parser.add_subparsers(dest="command", required=True)

    scan = sub.add_parser("scan")
    add_rootfs_args(scan)
    scan.add_argument("--engines", default="inventory,config_routes,binary,codeql_plan,semgrep")

    inventory = sub.add_parser("inventory")
    add_rootfs_args(inventory)

    routes = sub.add_parser("routes")
    add_rootfs_args(routes)

    binary = sub.add_parser("binary-map")
    add_rootfs_args(binary)

    semgrep = sub.add_parser("semgrep")
    add_rootfs_args(semgrep)
    semgrep.add_argument("--config", default="auto")

    codeql_plan_parser = sub.add_parser("codeql-plan")
    add_rootfs_args(codeql_plan_parser)

    sub.add_parser("codeql-version")

    skill_context = sub.add_parser("skill-context")
    add_rootfs_args(skill_context)

    args = parser.parse_args(argv)

    if args.command == "codeql-version":
        result = codeql_version()
        for finding in result.findings:
            print(finding.summary)
        return result.exit_code

    context = context_from_args(args)
    if args.command == "inventory":
        return run_scan(context, engines=["inventory"])
    if args.command == "routes":
        return run_scan(context, engines=["config_routes"])
    if args.command == "binary-map":
        return run_scan(context, engines=["binary"])
    if args.command == "codeql-plan":
        result = codeql_plan(context.rootfs)
        print(result.findings[0].summary)
        return result.exit_code
    if args.command == "skill-context":
        if not context.inventory_path.exists() or not context.findings_path.exists():
            run_scan(context)
        export_skill_context(context)
        print(context.skill_context_path)
        return 0
    if args.command == "semgrep":
        return run_scan(context, engines=["semgrep"])
    if args.command == "scan":
        engines = [engine.strip() for engine in args.engines.split(",") if engine.strip()]
        exit_code = run_scan(context, engines=engines)
        export_skill_context(context)
        print(context.inventory_path)
        print(context.findings_path)
        print(context.skill_context_path)
        return exit_code

    return 2
```

Replace `emulation/charx_v190/pentest/scripts/code_browser.py` with:

```python
#!/usr/bin/env python3
from __future__ import annotations

from firmware_browser.cli import main


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run CLI tests**

Run:

```bash
PYTHONPATH=. pytest tests/test_firmware_browser_cli.py -q
```

Expected: `2 passed`.

- [ ] **Step 5: Run full Python tests**

Run:

```bash
PYTHONPATH=. pytest -q
```

Expected: all tests pass. Existing tests for old `rg`/`strings`/`readelf` subcommands must be removed or rewritten against `scan`, `binary-map`, `semgrep`, and `codeql-plan`.

- [ ] **Step 6: Commit**

```bash
git add emulation/charx_v190/pentest/scripts/code_browser.py emulation/charx_v190/pentest/firmware_browser/cli.py emulation/charx_v190/pentest/tests/test_firmware_browser_cli.py
git commit -m "feat: migrate code browser to multi-engine CLI"
```

### Task 12: CHARX Feasibility Smoke Against Extracted Rootfs

**Files:**
- Modify only if smoke reveals a small path or quoting bug.

- [ ] **Step 1: Run inventory smoke on CHARX rootfs**

Run:

```powershell
.\emulation\charx_v190\charx-pentest.cmd code-browser inventory --rootfs D:\CHARXSEC\work\firmware_v190_rootfs --product-name charx-sec-3100-v190
```

Expected:

- Exit code `0`.
- Prints or writes `emulation/charx_v190/pentest/evidence/code_browser/inventory.json`.
- Inventory includes nonzero counts for shared objects, JavaScript, JSON, config, and shell/init files.

- [ ] **Step 2: Run route/config smoke**

Run:

```powershell
.\emulation\charx_v190\charx-pentest.cmd code-browser routes --rootfs D:\CHARXSEC\work\firmware_v190_rootfs --product-name charx-sec-3100-v190
```

Expected:

- Exit code `0`.
- Findings include `routePermissions.json` routes and port hints such as `5000`.

- [ ] **Step 3: Run binary map smoke**

Run:

```powershell
.\emulation\charx_v190\charx-pentest.cmd code-browser binary-map --rootfs D:\CHARXSEC\work\firmware_v190_rootfs --product-name charx-sec-3100-v190
```

Expected:

- Exit code `0`.
- Findings include ARM ELF shared objects such as `usr/lib/charx-website/api_import.so`.

- [ ] **Step 4: Run CodeQL/Semgrep availability smokes**

Run:

```powershell
.\emulation\charx_v190\charx-pentest.cmd code-browser codeql-version
.\emulation\charx_v190\charx-pentest.cmd code-browser codeql-plan --rootfs D:\CHARXSEC\work\firmware_v190_rootfs --product-name charx-sec-3100-v190
.\emulation\charx_v190\charx-pentest.cmd code-browser semgrep --rootfs D:\CHARXSEC\work\firmware_v190_rootfs --product-name charx-sec-3100-v190
```

Expected:

- Missing CodeQL or Semgrep is recorded as `missing_tool`, not a crash.
- `codeql-plan` lists supported source languages if JS/Python/etc are present.

- [ ] **Step 5: Commit smoke path fixes only if needed**

If smoke required code changes:

```bash
git add emulation/charx_v190/pentest
git commit -m "fix: harden firmware browser smoke paths"
```

If smoke generated only ignored evidence, do not create an empty commit.

### Task 13: Documentation Update

**Files:**
- Modify: `document/charx_sec_3100_local_pentest_workstation_guide_vi.md`
- Modify: `emulation/charx_v190/pentest/README.md`

- [ ] **Step 1: Update Vietnamese guide Code Browser section**

Replace the existing "Duyệt Code Và Firmware Artifact" section with:

```markdown
## Code Browser Đa Engine Cho Firmware

`code-browser` không còn là grep helper và cũng không phải CodeQL-only. Đây là orchestrator đa engine cho rootfs firmware đã extract.

Các engine:

- Inventory engine: phân loại file, ELF, `.so`, JS/HTML, JSON, config, init script và helper script.
- Config/route engine: parse route JSON, service config, nginx/init hints và port/service map.
- Binary engine: map ARM ELF, shared object, stripped status và metadata phục vụ reverse-engineering.
- Semgrep engine: scan JS/config/script/source-like files khi Semgrep có sẵn.
- CodeQL engine: lập kế hoạch hoặc chạy trên source language được CodeQL hỗ trợ; không dùng CodeQL để phân tích trực tiếp ARM ELF stripped.
- Skill context exporter: tạo `skill_context.json` để Codex/Claude skill đọc nhanh thay vì scan lại toàn bộ rootfs.

Ví dụ:

```powershell
.\emulation\charx_v190\charx-pentest.cmd code-browser scan --rootfs D:\CHARXSEC\work\firmware_v190_rootfs --product-name charx-sec-3100-v190
.\emulation\charx_v190\charx-pentest.cmd code-browser binary-map --rootfs D:\CHARXSEC\work\firmware_v190_rootfs
.\emulation\charx_v190\charx-pentest.cmd code-browser codeql-plan --rootfs D:\CHARXSEC\work\firmware_v190_rootfs
.\emulation\charx_v190\charx-pentest.cmd code-browser skill-context --rootfs D:\CHARXSEC\work\firmware_v190_rootfs
```

Trong CHARX SEC-3100 V190, phần backend quan trọng chủ yếu là ARM ELF stripped trong `/usr/lib/charx-*`. Vì vậy CodeQL/Semgrep chỉ là engine cho phần source/script/web/config parseable; binary engine, Ghidra/rizin/Joern pipeline và Qiling/debugger mới là hướng phù hợp cho module `.so`.
```

- [ ] **Step 2: Update pentest README CodeQL wording**

In `emulation/charx_v190/pentest/README.md`, replace the CodeQL-only wording with:

```markdown
## Code Browser Đa Engine

`code-browser` là firmware browser đa engine. CodeQL là một engine cho source language được hỗ trợ, không phải engine duy nhất.

```powershell
.\emulation\charx_v190\charx-pentest.cmd code-browser scan --rootfs D:\path\to\rootfs --product-name generic-firmware
```

Kết quả chính:

- `evidence/code_browser/inventory.json`
- `evidence/code_browser/findings.jsonl`
- `evidence/code_browser/skill_context.json`

Nếu thiếu CodeQL hoặc Semgrep, browser ghi `missing_tool` có kiểm soát. Với firmware binary stripped, dùng binary-map/Ghidra/rizin/Joern pipeline và verifier/runtime evidence thay vì giả định CodeQL có source-level view.
```

- [ ] **Step 3: Run markdown link/content checks**

Run:

```powershell
rg -n "Code Browser Đa Engine|skill_context|CodeQL là một engine|ARM ELF stripped" document/charx_sec_3100_local_pentest_workstation_guide_vi.md emulation/charx_v190/pentest/README.md
```

Expected: all key phrases are present.

- [ ] **Step 4: Commit docs**

```bash
git add document/charx_sec_3100_local_pentest_workstation_guide_vi.md emulation/charx_v190/pentest/README.md
git commit -m "docs: document multi-engine firmware code browser"
```

### Task 14: Final Verification

**Files:**
- Modify only if verification reveals a small bug.

- [ ] **Step 1: Run full Python tests**

Run:

```bash
cd /mnt/d/CHARXSEC/.worktrees/charx-pentest-workstation/emulation/charx_v190/pentest
. .venv/bin/activate
PYTHONPATH=. pytest -q
```

Expected: all tests pass.

- [ ] **Step 2: Run CLI help smoke**

Run:

```powershell
.\emulation\charx_v190\charx-pentest.cmd code-browser --help
.\emulation\charx_v190\charx-pentest.cmd code-browser scan --help
```

Expected: help lists multi-engine commands and rootfs arguments.

- [ ] **Step 3: Run generic toy rootfs smoke**

Run:

```powershell
$toy = Join-Path $env:TEMP "firmware-browser-toy-rootfs"
Remove-Item -Recurse -Force $toy -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force "$toy\etc\init.d", "$toy\www", "$toy\usr\lib\app" | Out-Null
Set-Content -Path "$toy\etc\init.d\app" -Value "#!/bin/sh"
Set-Content -Path "$toy\etc\app.conf" -Value "Port=8080"
Set-Content -Path "$toy\www\app.js" -Value "console.log(1)"
Set-Content -Path "$toy\usr\lib\app\module.so" -Value "fake"
.\emulation\charx_v190\charx-pentest.cmd code-browser scan --rootfs $toy --product-name toy-firmware
```

Expected:

- Exit code `0`.
- Browser writes inventory/findings/skill_context.
- No product-specific CHARX assumptions are required.

- [ ] **Step 4: Run CHARX rootfs smoke if rootfs exists**

Run:

```powershell
if (Test-Path D:\CHARXSEC\work\firmware_v190_rootfs) {
  .\emulation\charx_v190\charx-pentest.cmd code-browser scan --rootfs D:\CHARXSEC\work\firmware_v190_rootfs --product-name charx-sec-3100-v190
}
```

Expected:

- Exit code `0`.
- Missing optional tools are controlled.
- Inventory shows ARM ELF/backend module presence.

- [ ] **Step 5: Check ignored artifacts**

Run:

```powershell
git status --short
git check-ignore -v emulation/charx_v190/pentest/evidence/code_browser/findings.jsonl
git check-ignore -v emulation/charx_v190/pentest/evidence/code_browser/skill_context.json
```

Expected: generated evidence is ignored; no unexpected tracked artifacts.

- [ ] **Step 6: Final commit only if verification changed tracked files**

If changes were required:

```bash
git add emulation/charx_v190/pentest document docs
git commit -m "test: verify multi-engine firmware code browser"
```

If there are no tracked changes, do not create an empty commit.

## Execution Notes For Future Skill Development

- Future Codex/Claude firmware-pentest skills should start from `skill_context.json`, not raw rootfs scanning.
- A skill can choose next actions from engine output:
  - Many `route` findings -> build authorized HTTP probe plan.
  - Many ARM ELF findings -> prioritize Ghidra/rizin/Qiling reverse-engineering.
  - Semgrep/CodeQL findings -> inspect source-like assets only.
  - Binary modules with config route correlation -> pick target for dynamic hook/debug.
- Static findings remain non-claiming until reproduced through QEMU/Qiling/verifier.

## Self-Review

- Spec coverage: plan implements dynamic rootfs input, product-neutral engine chain, multi-source language detection, CodeQL/Semgrep optional engines, binary firmware engine, and skill-context export for Codex/Claude skills.
- Placeholder scan: no `TBD`, `TODO`, or undefined "write tests later" steps remain.
- Type consistency: `BrowserContext`, `Finding`, `EngineResult`, `ToolStatus`, `run_scan`, and engine function names are defined before later tasks use them.
- CHARX feasibility: CHARX appears only as a smoke target and documentation example, not as core engine logic.
