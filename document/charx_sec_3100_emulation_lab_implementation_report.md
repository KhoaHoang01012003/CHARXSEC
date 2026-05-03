# CHARX SEC-3100 V190 - Emulation Lab Implementation Report

Ngày thực hiện: `2026-04-24`

Tài liệu này ghi lại trạng thái triển khai lab emulate firmware CHARX SEC-3100 V190 theo nguyên tắc không bịa hành vi, không patch binary gốc, và mọi mock/deviation phải có evidence.

## Kết luận nhanh

Lab runtime đã được dựng trong WSL ext4 tại:

- `/home/khoa/charx_labs/charx_v190`

Workspace Windows giữ scripts, ledger và evidence export tại:

- [emulation/charx_v190](/d:/CHARXSEC/emulation/charx_v190)

Run đầu tiên:

- `20260424T093036Z`

Trạng thái hiện tại:

| Hạng mục | Kết quả |
|---|---|
| Copy artifact vào WSL ext4 | Hoàn tất |
| SHA256 `root.ext4` theo manifest | PASS |
| SHA256 `bootimg.vfat` theo manifest | PASS |
| Extract `root.ext4` read-only sang `rootfs_ro` | Hoàn tất |
| Extract `bootimg.vfat` sang `boot/` | Hoàn tất |
| Tạo lab ext4 volumes `/data`, `/log`, `/identity` | Hoàn tất |
| Seed synthetic identity placeholder | Hoàn tất |
| QEMU ARM user-mode helper trong run copy | Hoàn tất |
| Static validation | Hoàn tất |
| WSL isolated service smoke replay | Hoàn tất |
| QEMU system boot | Chưa chạy, chỉ mới tìm bootargs candidates |

## Artifact và evidence

Các evidence đã export về workspace:

- [wsl_lab_status.md](/d:/CHARXSEC/emulation/charx_v190/evidence/wsl_lab_status.md)
- [validation_report.md](/d:/CHARXSEC/emulation/charx_v190/evidence/20260424T093036Z/validation_report.md)
- [observations.jsonl](/d:/CHARXSEC/emulation/charx_v190/evidence/20260424T093036Z/observations.jsonl)
- [service_replay.jsonl](/d:/CHARXSEC/emulation/charx_v190/evidence/20260424T093036Z/service_replay.jsonl)
- [isolated_network.txt](/d:/CHARXSEC/emulation/charx_v190/evidence/20260424T093036Z/isolated_network.txt)
- [isolated_runtime_snapshot.txt](/d:/CHARXSEC/emulation/charx_v190/evidence/20260424T093036Z/isolated_runtime_snapshot.txt)
- [mocks.jsonl](/d:/CHARXSEC/emulation/charx_v190/evidence/20260424T093036Z/mock_transcripts/mocks.jsonl)
- [integrity_report.md](/d:/CHARXSEC/emulation/charx_v190/evidence/artifacts/integrity_report.md)
- [bootargs_search.md](/d:/CHARXSEC/emulation/charx_v190/evidence/artifacts/bootargs_search.md)

## Service smoke replay

Smoke replay được chạy trong `unshare --net` single-session vì WSL không giữ named `ip netns` ổn định giữa các lần gọi `wsl.exe`.

Network trong smoke session:

- loopback enabled;
- không có default route;
- không có Internet outbound;
- mock services chỉ bind `127.0.0.1`.

Kết quả service:

| Service | Start status | Quan sát |
|---|---:|---|
| `mosquitto` | `1` | fail vì thiếu `/etc/machine-id` và missing hostname-specific template `mosquitto-template-Admin-PC.conf` |
| `charx-system-config-manager` | `0` | chạy được, port `5001` và `5002` được quan sát trong snapshot |
| `charx-website` | `0` | process launch được, tạo `/data/charx-website/*` và `/log/charx-website/charx-website.log`; port `5000` chưa thấy trong snapshot ngắn |
| `nginx` | `1` | fail vì thiếu `/var/log/nginx/error.log` và `/run/nginx/client_body_temp` trong smoke session |
| `charx-jupicore` | `0` | process launch được; port `5555` chưa thấy trong snapshot ngắn |

Mock services trong smoke:

| Mock | Port | Provenance |
|---|---:|---|
| OCPP WebSocket logger | `9000` | `manual_test_stub`, `Tier 4`, `behavior_claim_allowed=false` |
| Modbus register stub | `1502` | `manual_test_stub`, `Tier 4`, `behavior_claim_allowed=false` |
| MQTT remote logger | `1884` | `manual_test_stub`, `Tier 4`, `behavior_claim_allowed=false` |
| OpenVPN test peer logger | `1194` | `manual_test_stub`, `Tier 4`, `behavior_claim_allowed=false` |

## Fidelity boundary

Những gì đã đạt được là service replay infrastructure và runtime smoke evidence, không phải full hardware fidelity.

Không claim chính xác cho:

- Controller Agent behavior;
- charging state machine;
- CP/PP, contactor, locking actuator;
- OCPP backend production behavior;
- Modbus meter production behavior;
- OpenVPN production routing/cert lifecycle;
- device identity/provisioning.

Lý do: chưa có thiết bị lab thật, chưa có `/data`, `/log`, `/identity` production dump, chưa có hardware trace.

## Scripts đã triển khai

Scripts nằm tại:

- [scripts](/d:/CHARXSEC/emulation/charx_v190/scripts)

Các entrypoint chính:

| Script | Mục đích |
|---|---|
| `prepare_lab.sh` | chuẩn bị WSL lab, copy artifact, hash, extract rootfs/boot, tạo volumes |
| `new_run.sh` | tạo run copy writable và evidence folder |
| `mount_run.sh` / `umount_run.sh` | mount/unmount runtime filesystems cho run |
| `run_isolated_smoke.sh` | WSL-safe service replay bằng `unshare --net` |
| `run_service_replay.sh` | replay qua named `ip netns` cho Linux environment giữ được namespace |
| `start_mocks.py` | mock OCPP/Modbus/MQTT remote/OpenVPN test peer |
| `validate_lab.sh` | integrity/static/safety validation |
| `collect_evidence.sh` | collect process/port/file/diff evidence |
| `export_report.sh` | export evidence từ WSL về workspace |

## Lệnh tái chạy smoke run

Chạy từ PowerShell:

```powershell
wsl.exe -d Debian -u root -- bash -lc 'set -e; export CHARX_WORKSPACE=/mnt/d/CHARXSEC CHARX_LAB_USER=khoa CHARX_LAB_HOME=/home/khoa/charx_labs/charx_v190; RUN=$(bash /home/khoa/charx_labs/charx_v190/scripts/new_run.sh | tail -1); bash /home/khoa/charx_labs/charx_v190/scripts/mount_run.sh "$RUN"; bash /home/khoa/charx_labs/charx_v190/scripts/run_isolated_smoke.sh "$RUN" mosquitto charx-system-config-manager charx-website nginx charx-jupicore; bash /home/khoa/charx_labs/charx_v190/scripts/validate_lab.sh "$RUN"; bash /home/khoa/charx_labs/charx_v190/scripts/export_report.sh "$RUN"; bash /home/khoa/charx_labs/charx_v190/scripts/umount_run.sh "$RUN"'
```

Nếu smoke fail giữa chừng, chạy cleanup thủ công:

```powershell
wsl.exe -d Debian -u root -- bash -lc 'export CHARX_LAB_HOME=/home/khoa/charx_labs/charx_v190; mount | grep charx_v190; ps auxww | grep Charx | grep -v grep || true'
```

## Next technical steps

Các bước tiếp theo nên làm nếu muốn tăng fidelity:

1. Tạo preflight trong run để chuẩn bị `/run/nginx`, `/var/log/nginx`, `/etc/machine-id` synthetic có nhãn deviation, rồi retry `nginx` và `mosquitto`.
2. Chạy smoke lâu hơn cho `charx-website` và `charx-jupicore`, quan sát khi nào bind `5000` và `5555`.
3. Thêm local Mosquitto synthetic config thay vì hostname-specific template bị thiếu, nhưng phải ghi `modified-runtime behavior`.
4. Chỉ thử QEMU system boot sau khi phân tích kỹ `bootargs_search.md`; không tự bịa bootargs.

## Update 2026-04-24 - WBM và service status

Đã chạy thêm WBM probe và extended service probe. Kết quả chi tiết nằm tại:

- [charx_sec_3100_emulation_service_status_and_next_steps.md](/d:/CHARXSEC/document/charx_sec_3100_emulation_service_status_and_next_steps.md)

Kết luận cập nhật:

- WBM HTTPS frontend đã trả `200 OK`.
- Website backend bind `5000`, websocket bind `4999`.
- SCM bind `5001/5002`.
- JupiCore bind `5555`.
- Mosquitto bind `1883` khi dùng hostname lab `ev3000` và synthetic `/etc/machine-id`.
- Modbus Agent bind `9502`, Modbus Server API bind `9555`, Load Management bind `1603`.
- OCPP process start được nhưng chưa thấy REST `2106`; log cho thấy thiếu connector list từ JupiCore/ControllerAgent.
