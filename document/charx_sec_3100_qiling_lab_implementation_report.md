# Báo cáo triển khai Qiling lab cho CHARX SEC-3100 V190

## Kết luận nhanh

Qiling lab đã được triển khai như một lớp analysis/fuzzing/instrumentation bổ trợ cho QEMU/chroot full-service lab, không thay thế QEMU.

Các phần đã hoạt động:

- Bootstrap Qiling trong WSL Debian thành công.
- Tạo service matrix cho 10 target chính của firmware.
- Tạo static-map cho toàn bộ service matrix.
- Tạo seed corpus an toàn từ config/route evidence.
- Tạo runner có evidence JSONL, filesystem mapper, syscall hook, block hook, memory invalid hook, debugger switch và coverage switch.
- Tạo supervisor timeout để Qiling process không treo terminal khi service daemon hoặc loader không trả control.

Giới hạn hiện tại:

- `CharxWebsite` chạy dưới Qiling đã vào được loader/syscall tracing, nhưng chưa lên thành service ổn định.
- Qiling run hiện quan sát được dynamic loader path probing và basic block trace, sau đó cần supervisor kill vì `ql.emu_stop()` không trả control sạch trong case này.
- Đây được phân loại là `observed_qiling_target` / emulator limitation, không phải firmware behavior truth.

## File đã tạo

- `emulation/charx_v190/qiling/README.md`
- `emulation/charx_v190/qiling/requirements.txt`
- `emulation/charx_v190/qiling/service_matrix.json`
- `emulation/charx_v190/qiling/schemas/qiling_observation_schema.json`
- `emulation/charx_v190/qiling/scripts/bootstrap_qiling.sh`
- `emulation/charx_v190/qiling/scripts/qiling_lab.sh`
- `emulation/charx_v190/qiling/scripts/qiling_runner.py`
- `emulation/charx_v190/qiling/scripts/build_seeds.py`
- `emulation/charx_v190/charx-qiling.ps1`
- `emulation/charx_v190/charx-qiling.cmd`

## Môi trường đã bootstrap

Evidence bootstrap:

```text
emulation/charx_v190/qiling/evidence/qiling-bootstrap-20260429T082609Z/
```

Version đã ghi nhận:

- `qiling`: `1.4.6`
- `unicorn`: `2.1.4`
- `capstone`: `5.0.7`
- `python`: `3.11.2`
- venv: `/home/khoa/.charx_qiling_v190/qiling_venv`

Do WSL lab path `/home/khoa/charx_labs/charx_v190` đang thuộc `root:root`, script tự fallback evidence sang workspace:

```text
emulation/charx_v190/qiling/evidence/<run_id>/
```

## Service matrix

Tier A:

- `charx-website`
- `charx-system-config-manager`

Tier B:

- `charx-jupicore`
- `charx-ocpp16-agent`
- `charx-modbus-agent`
- `charx-modbus-server`
- `charx-loadmanagement`
- `charx-update-agent`

Tier C experimental:

- `charx-controller-agent`
- `charx-system-monitor`

Static-map toàn bộ matrix đã chạy và tạo 10 file static-map tại:

```text
emulation/charx_v190/qiling/evidence/qiling-20260429T083423Z/
```

## Seed corpus

Seed corpus đã được tạo tại:

```text
emulation/charx_v190/qiling/seeds/default/
```

Nguồn seed:

- `routePermissions.json`
- các file `/etc/charx/*.conf` an toàn
- sample JSON payload tối thiểu cho harness
- QEMU probe JSON nếu có

Các seed đều có `behavior_claim_allowed=false`, vì seed chỉ dùng cho harness/fuzzing, không phải device behavior truth.

## Lệnh sử dụng

Bootstrap:

```powershell
.\emulation\charx_v190\charx-qiling.cmd bootstrap
```

Xem matrix:

```powershell
.\emulation\charx_v190\charx-qiling.cmd matrix
```

Static-map một service:

```powershell
.\emulation\charx_v190\charx-qiling.cmd static-map --service charx-website
```

Static-map toàn bộ service:

```powershell
.\emulation\charx_v190\charx-qiling.cmd static-map --service all
```

Instrumented run:

```powershell
.\emulation\charx_v190\charx-qiling.cmd run --service charx-website --timeout 10 --coverage basic --hooks files,sockets,syscalls,blocks,memory
```

Fuzz harness seed replay:

```powershell
.\emulation\charx_v190\charx-qiling.cmd fuzz --service charx-website --timeout 5 --max-seeds 5
```

GDB-compatible debugger:

```powershell
.\emulation\charx_v190\charx-qiling.cmd run --service charx-website --debugger gdb --debug-port 9999 --timeout 0
```

## Evidence labels

Qiling lab dùng các nhãn:

- `observed_qiling_target`: quan sát khi binary chạy trong Qiling.
- `qiling_hooked_behavior`: hành vi do hook/filesystem mapper/seed replay tạo ra.
- `observed_runtime_qemu`: snapshot từ QEMU/chroot baseline.
- `mocked_behavior`: mock, nếu có.
- `unknown`: chưa đủ dữ kiện.

Không dùng Qiling-only output để claim full firmware behavior.

## Trạng thái `CharxWebsite`

Run kiểm thử:

```text
emulation/charx_v190/qiling/evidence/qiling-20260429T083312Z/
```

Quan sát:

- Qiling load được ELF target dạng host path resolved từ rootfs.
- Syscall hooks đã ghi nhận `openat` dynamic loader path probing.
- Basic block hook đã sinh trace.
- Service không lên ổn định trong Qiling-only mode.
- Supervisor timeout đã ghi:

```text
emulation/charx_v190/qiling/evidence/qiling-20260429T083312Z/supervisor_timeout.json
```

Phân loại:

- Đây là limitation của Qiling service replay hiện tại.
- Không được coi là hành vi thật của firmware.
- QEMU/chroot full-service vẫn là baseline cho WBM runtime.

## Hướng tiếp theo

Ưu tiên 1: tạo rootfs overlay riêng cho Qiling bằng `rsync` từ `rootfs_ro`, chạy với permission do user `khoa` sở hữu để kiểm tra liệu lỗi loader/library có giảm không. Overlay này vẫn phải read-only theo logic artifact và ghi deviation rõ.

Ưu tiên 2: thêm profile Qiling explicit cho ARM/Linux và kiểm tra từng binary nhỏ trước khi chạy daemon lớn.

Ưu tiên 3: tạo harness riêng cho thư viện/parser/module thay vì chạy nguyên daemon nếu dynamic loader hoặc thread model tiếp tục kẹt.

Ưu tiên 4: dùng QEMU evidence làm seed và oracle; chỉ dùng Qiling để trace code path, hook syscall và fuzz input surface đã xác định.

## Nguồn chính thức liên quan

- Qiling hook API: https://docs.qiling.io/en/latest/hook/
- Qiling remote debugger: https://docs.qiling.io/en/latest/debugger/
- Qiling coverage: https://docs.qiling.io/en/latest/coverage/
- Unicorn/QEMU relationship: https://www.unicorn-engine.org/docs/beyond_qemu.html
