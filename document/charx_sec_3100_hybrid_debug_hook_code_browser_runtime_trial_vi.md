# CHARX SEC-3100 Hybrid Debug/Hook/Code-Browser Runtime Trial

Ngay 2026-05-05, workspace da duoc dung de thu nghiem end-to-end cac tool moi tren emulation hien tai.

## Pham Vi

- Firmware/lab: CHARX SEC-3100 V190.
- Full-service run id: `hybrid-tools-20260505T034013Z`.
- Runtime rootfs duoc yeu cau: active `rootfs_rw`.
- WBM state-change: workflow kich hoat role lab qua firmware API, gom forced manufacturer password change neu firmware yeu cau va `POST /api/v1.0/web/users-active` de bat `user`/`operator`.
- Evidence local: `document/evidence/hybrid-tools-20260505T034013Z/`.

Evidence trong thu muc tren la runtime output va da duoc ignore khoi Git. Khong dua raw runtime evidence, token, identity material hoac dump len remote repo.

## Ket Qua Chinh

| Hang muc | Ket qua | Evidence |
| --- | --- | --- |
| Emulation/WBM baseline | `https://localhost/` tra dashboard, `system-name` tra `"ev3000"` | `full_service_status.txt`, `wbm_system_name_guest.http`, `wbm_frontend_wait.png` |
| WBM state-change | Role activation workflow tao token cho `manufacturer`, `operator`, `user`; token chi ghi hash | `wbm_role_probe_summary.json`, `wbm_role_probe.jsonl` |
| Code browser | Chay tren `/home/khoa/charx_labs/charx_v190/runs/hybrid-tools-20260505T034013Z/rootfs_rw`, source `active-rootfs-rw`, khong co warning fallback | `code_browser/inventory.json`, `code_browser/skill_context.json`, `trial_summary.json` |
| Hook static-map | Thanh cong, exit `0`, map `charx-website` tren active runtime | `hook_static_map_stdout.txt`, `qiling_static_map_observations.jsonl`, `qiling_charx_website_static_map.json` |
| Hook instrumented-run | Qiling supervisor timeout co kiem soat, exit `124`; evidence label `observed_qiling_target` | `hook_instrumented_stdout.txt`, `qiling_hook_supervisor_timeout.json`, `qiling_hook_run_observations.jsonl` |
| Debug gdb path | `debug qiling-gdb` ghi `qiling_gdb_start`, Qiling ghi `debugger_enabled` va syscall trace; port `9999` chua mo trong cua so 20 giay truoc khi cleanup | `debug_qiling_gdb_summary.json`, `pentest_debug_observations.jsonl`, `qiling_debug_gdb_observations.jsonl` |

Luu y: Qiling evidence la `observed_qiling_target`, khong tu dong la behavior truth cua firmware. QEMU/full-service evidence moi la baseline de doi chieu hanh vi WBM/API.

## Cach Tu Thu Lai Bang Tay

### 1. Khoi Chay Lai Full-Service Runtime

```powershell
$runId = "manual-hybrid-" + (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
.\emulation\charx_v190\charx-full-service.cmd restart -RunId $runId -WaitSeconds 180 -NoOpen
.\emulation\charx_v190\charx-full-service.cmd status
```

Sau khi start, WBM mo tai:

```text
https://localhost/
```

Role probe mac dinh se kich hoat lab users. Credential lab sau activation:

```text
user / UserLab-20260424!
operator / OperatorLab-20260424!
manufacturer / ManufacturerLab-20260424!
```

Day la lab credential do firmware API tao trong runtime, khong coi la default credential cua san pham.

### 2. Kiem Tra WBM/API

```powershell
curl.exe -k -i https://localhost/api/v1.0/web/system-name
```

Neu muon chup screenshot WBM bang Edge headless:

```powershell
$out = "document\evidence\$runId"
New-Item -ItemType Directory -Force -Path $out | Out-Null
& "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" `
  --headless=new --disable-gpu --ignore-certificate-errors --allow-insecure-localhost `
  --window-size=1366,900 --virtual-time-budget=8000 `
  --screenshot="$out\wbm_frontend.png" https://localhost/
```

Neu Edge headless cho anh trang, Selenium/Edge co the render du JS hon.

### 3. Chay Code Browser Tren Active Runtime

`code-browser` hien dung `--run-id` de chon active full-service runtime:

```powershell
.\emulation\charx_v190\charx-pentest.cmd code-browser scan `
  --runtime active `
  --run-id $runId `
  --product-name charx-sec-3100-v190 `
  --output-dir "document\evidence\$runId\code_browser"
```

Kiem tra `inventory.json`:

```powershell
$inventory = "document\evidence\$runId\code_browser\inventory.json"
python -c "import json,sys; d=json.load(open(sys.argv[1], encoding='utf-8')); print(d['rootfs']); print(d['runtime'])" $inventory
```

Rootfs mong doi co dang:

```text
/home/<user>/charx_labs/charx_v190/runs/<runId>/rootfs_rw
```

### 4. Chay Hook Qiling Tren Active Runtime

Khac voi `code-browser`, Qiling wrapper dung `--runtime-run-id` de chon full-service runtime, con `--run-id` la evidence id cua Qiling.

Static-map:

```powershell
.\emulation\charx_v190\charx-pentest.cmd hook `
  --service charx-website `
  --mode static-map `
  --runtime active `
  --runtime-run-id $runId `
  --run-id "$runId-static-map"
```

Instrumented run:

```powershell
.\emulation\charx_v190\charx-pentest.cmd hook `
  --service charx-website `
  --mode run `
  --runtime active `
  --runtime-run-id $runId `
  --run-id "$runId-hook-run" `
  --timeout 5 `
  --hooks files,sockets,syscalls,blocks,memory
```

Neu instrumented run timeout, doc `supervisor_timeout.json`. Day la limitation/cleanup cua Qiling lane, khong phai firmware truth.

### 5. Thu Debug GDB Path

Interactive debugger co the treo terminal vi `--timeout 0` de cho attach. Chay trong mot terminal rieng:

```powershell
.\emulation\charx_v190\charx-pentest.cmd debug qiling-gdb `
  --service charx-website `
  --port 9999 `
  --runtime active `
  --runtime-run-id $runId `
  --run-id "$runId-debug-gdb"
```

Trong WSL terminal khac:

```bash
gdb-multiarch
(gdb) set architecture arm
(gdb) target remote localhost:9999
```

Trong trial nay, debugger path da ghi `qiling_gdb_start`, `debugger_enabled` va syscall trace, nhung port `9999` chua duoc quan sat mo trong cua so 20 giay truoc khi cleanup. Khi thu bang tay, hay de process chay lau hon va attach bang GDB neu port san sang.

### 6. Evidence Labels Can Nho

- `observed_runtime_qemu`: baseline runtime tu QEMU/full-service.
- `observed_qiling_target`: quan sat tu Qiling target.
- `qiling_hooked_behavior`: hanh vi co overlay/hook Qiling.
- `behavior_claim_allowed=false`: khong duoc claim firmware truth neu chua doi chieu/reproduce.

## Cleanup

Dung full-service stack:

```powershell
.\emulation\charx_v190\charx-full-service.cmd stop
```

Neu co Qiling/debug process con sot lai:

```powershell
wsl -d Debian -- bash -lc "pkill -f 'qiling_runner.py.*debugger' || true"
```
