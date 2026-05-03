# Ngày 13 - Update pipeline và config import/export

Tài liệu này dựa trên timeline trong `courses.txt`, tài liệu chính thức, advisories và firmware/rootfs `V190`. Cấu trúc được chuẩn hóa theo dạng `Question -> Answer -> Evidence`.

Ngày 13 tập trung vào firmware update, application update, system update, OCPP update path, package verification, rollback/A-B slot behavior và config import/export. Đây là một trong những ngày quan trọng nhất cho security research vì update và config đều là boundary giữa dữ liệu bên ngoài và trạng thái hệ thống có quyền cao.

## Nguồn tài liệu và artifact dùng cho Ngày 13

- [courses.txt](/d:/CHARXSEC/document/courses.txt)
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html)
- [Maintenance_repair_and_disposal.html](/d:/CHARXSEC/document/Maintenance_repair_and_disposal.html)
- [PCSA-2024-00003_SECURITY_ADVISORY.pdf](/d:/CHARXSEC/document/PCSA-2024-00003_SECURITY_ADVISORY.pdf)
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt)
- [manifest.raucm](/d:/CHARXSEC/work/firmware_v190_bundle/manifest.raucm)
- [hook](/d:/CHARXSEC/work/firmware_v190_bundle/hook)
- [system.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/rauc/system.conf)
- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json)
- [charx-update-agent](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/init.d/charx-update-agent)

## Câu hỏi 1

### Question

Day 13 cần phân tích những luồng nào?

### Answer

Timeline yêu cầu phân tích:

- firmware update
- application update
- system update
- client propagation
- package verification
- rollback behavior
- config import/export
- downgrade policy
- password reset behavior on update

Trong firmware `V190`, các lớp liên quan gồm:

- WBM routes `/web/update*`, `/web/import`, `/web/export`
- Update Agent
- OCPP firmware update module
- RAUC manifest/hook/system.conf
- System Config Manager import/export
- helper scripts và sudoers

### Evidence

- [courses.txt](/d:/CHARXSEC/document/courses.txt) ghi Day 13 là `Update pipeline and config import/export`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `System Control/Software`.
- [Maintenance_repair_and_disposal.html](/d:/CHARXSEC/document/Maintenance_repair_and_disposal.html) nêu update có thể thực hiện local qua WBM hoặc qua backend bằng OCPP.
- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json) chứa update/import/export routes.

## Câu hỏi 2

### Question

Update entry points trong firmware là gì?

### Answer

Update entry points:

| Entry point | Evidence | Ý nghĩa |
|---|---|---|
| WBM update | `/web/update`, `/web/update2-upload`, `/web/update2-install` | local update qua Web UI |
| OCPP backend update | `ocpp_firmware_update.so` | update qua backend OCPP |
| Update Agent | `/usr/lib/charx-update-agent/*`, `/etc/init.d/charx-update-agent` | service runtime quản lý update |
| RAUC bundle | `manifest.raucm`, `hook`, `root.ext4`, `bootimg.vfat` | package/system update framework |
| RAUC system config | `/etc/rauc/system.conf`, `/etc/rauc/root-ca.crt` | trust/slot configuration |
| Manual/WBM | `System Control/Software` | documented operation |

Manual nói có thể update individual application programs, charging controller firmware hoặc entire system. Firmware cho thấy ít nhất system update path dùng RAUC bundle.

### Evidence

- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json) chứa `/web/update`, `/web/update2-upload`, `/web/update2-upload-stream`, `/web/update2-install`.
- `/usr/lib/charx-ocpp16-agent` trong rootfs chứa `ocpp_firmware_update.so`.
- `/usr/lib/charx-update-agent` trong rootfs chứa `CharxUpdateAgent`, `client.so`, `server.so`.
- [manifest.raucm](/d:/CHARXSEC/work/firmware_v190_bundle/manifest.raucm) mô tả RAUC images.

## Câu hỏi 3

### Question

Package verification trong RAUC bundle thể hiện ra sao?

### Answer

Các dấu hiệu verification/trust:

| Thành phần | Ý nghĩa |
|---|---|
| `manifest.raucm` | chứa `sha256` cho rootfs và kernel image |
| `[update] compatible=ev3000` | target compatibility |
| `hook install-check` | kiểm tra `RAUC_MF_COMPATIBLE` với `RAUC_SYSTEM_COMPATIBLE` |
| `/etc/rauc/system.conf` | system compatible, bootloader, slots |
| `/etc/rauc/root-ca.crt` | keyring path cho RAUC trust |

Day 13 chưa kết luận signature implementation đầy đủ. Nó ghi nhận bằng chứng có manifest hash, compatible check và root CA. Bước lab tiếp theo là dùng RAUC tooling để verify bundle offline và quan sát failure mode với package sai trong môi trường hợp pháp.

### Evidence

- [manifest.raucm](/d:/CHARXSEC/work/firmware_v190_bundle/manifest.raucm) chứa `sha256` cho `root.ext4` và `bootimg.vfat`.
- [hook](/d:/CHARXSEC/work/firmware_v190_bundle/hook) có case `install-check` so sánh `RAUC_MF_COMPATIBLE` và `RAUC_SYSTEM_COMPATIBLE`.
- [system.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/rauc/system.conf) ghi `[keyring] path=root-ca.crt`.

## Câu hỏi 4

### Question

Rollback hoặc A/B slot model thể hiện thế nào?

### Answer

`/etc/rauc/system.conf` cho thấy hệ thống dùng hai slot set:

| Slot set | Kernel | Rootfs | Bootname |
|---|---|---|---|
| System0 | `/dev/mmcblk1p1` | `/dev/mmcblk1p2` | `system0` |
| System1 | `/dev/mmcblk1p3` | `/dev/mmcblk1p5` | `system1` |

Bootloader là `barebox`; rootfs slots là ext4, kernel slots là vfat. Đây là dấu hiệu A/B update model. Khi phân tích rollback, cần kiểm tra:

- RAUC mark-good/mark-bad flow
- slot selection sau reboot
- failure handling nếu rootfs boot lỗi
- config migration giữa slots
- dữ liệu `/data` và `/log` có nằm ngoài slot hay không

### Evidence

- [system.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/rauc/system.conf) ghi `bootloader=barebox`.
- [system.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/rauc/system.conf) định nghĩa `slot.kernel.0`, `slot.rootfs.0`, `slot.kernel.1`, `slot.rootfs.1`.
- `/etc/init.d` trong rootfs có script `rauc-mark-good`.

## Câu hỏi 5

### Question

RAUC hook làm những gì trong update lifecycle?

### Answer

`hook` có các phase:

| Phase | Hành động |
|---|---|
| `install-check` | kiểm tra compatible target |
| `slot-pre-install` | drop caches bằng `/proc/sys/vm/drop_caches` |
| `slot-post-install` | đọc `/etc/os-release`, xử lý rootfs install |
| workaround version `<1.5.0` | install System Config Manager mới trước khi update |
| `update_bootloader` | so sánh bootloader mới/cũ và ghi bootloader nếu khác |

Điểm nghiên cứu:

- hook gọi nhiều command hệ thống với quyền cao
- có thao tác copy System Config Manager
- có thao tác `dd` vào `/dev/mmcblk1`
- có log vào `bootloader_install.log`
- có compatibility check trước install

Đây là vùng cần review theo hướng integrity và failure handling, không phải nơi thử nghiệm trên thiết bị sản xuất.

### Evidence

- [hook](/d:/CHARXSEC/work/firmware_v190_bundle/hook) chứa `install_system_conifg_manager_to_current_system`.
- [hook](/d:/CHARXSEC/work/firmware_v190_bundle/hook) chứa `update_bootloader`.
- [hook](/d:/CHARXSEC/work/firmware_v190_bundle/hook) chứa case `install-check`, `slot-pre-install`, `slot-post-install`.

## Câu hỏi 6

### Question

Downgrade policy cần hiểu thế nào từ config?

### Answer

Trong `charx-controller-agent.conf`, có các trường:

| Field | Giá trị quan sát |
|---|---|
| `FirmwareUpdateEnabled` | `True` |
| `FirmwareDowngradeEnabled` | `True` |
| `FirmwareUpdateOnAgentStartup` | `True` |
| `FirmwareUpdateAtRuntime` | `True` |
| `FirmwareUpdateCheckInterval` | `180` |

Không nên vội kết luận thiết bị cho phép downgrade mọi trường hợp. Đây mới là config field ở Controller Agent. Cần xác nhận:

- field này áp dụng cho firmware nào: controller agent, charging controllers con, hay system image?
- Update Agent/RAUC có policy riêng không?
- WBM có chặn downgrade theo version không?
- OCPP firmware update có dùng cùng policy không?
- log ghi gì khi downgrade bị từ chối hoặc được chấp nhận?

### Evidence

- [charx-controller-agent.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-controller-agent.conf) ghi các trường firmware update/downgrade.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả firmware version có thể update qua `System Control/Software`.

## Câu hỏi 7

### Question

Config import/export pipeline gồm những lớp nào?

### Answer

Pipeline baseline:

```text
WBM /web/import or /web/export
  -> nginx /api proxy
  -> CharxWebsite :5000
  -> api_import.so / api_export.so
  -> System Config Manager :5001
  -> api_import.so / api_export.so / import_service.so / export_service.so
  -> system_config_file_manager.so
  -> /etc/charx, /data/charx-*, service restart/reload
```

Manual nói Import/Export có thể áp dụng nhiều domain:

- charging park
- RFID/NFC config
- whitelist
- load management
- OCPP
- system configuration gồm Ethernet, port sharing, modem
- MQTT bridge
- OpenVPN

Điều này làm import/export trở thành boundary rất lớn. Nó chạm network, modem, VPN, OCPP, MQTT và load management.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) liệt kê các sub-register được Import/Export.
- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json) chứa `/web/import` và `/web/export`.
- `/usr/lib/charx-website` chứa `api_import.so`, `api_export.so`.
- `/usr/lib/charx-system-config-manager` chứa `api_import.so`, `api_export.so`, `import_service.so`, `export_service.so`, `system_config_file_manager.so`.

## Câu hỏi 8

### Question

Password reset behavior on update cần kiểm tra gì?

### Answer

Advisory 2024 từng mô tả issue trong firmware update feature có thể reset password của user low-privileged `user-app` về default. Với firmware `V190`, cần kiểm tra phòng thủ:

| Câu hỏi | Evidence cần thu |
|---|---|
| update có chạm tới `/etc/passwd`, `/etc/shadow` hoặc user DB không? | file access trace |
| helper `charx_reset_passwords` được gọi khi nào? | exec trace, strings/call graph |
| Developer Mode password change/reset liên quan route nào? | WBM route/module trace |
| complete system update giữ hay reset password nào? | before/after state |
| log có ghi password reset event không? | `/log/*` |

Không dùng default credentials trong tài liệu như một kỹ thuật truy cập. Mục tiêu ở đây là xác nhận remediation và tránh regression.

### Evidence

- [PCSA-2024-00003_SECURITY_ADVISORY.pdf](/d:/CHARXSEC/document/PCSA-2024-00003_SECURITY_ADVISORY.pdf) mô tả CVE-2024-6788 liên quan reset password low-privileged `user-app`.
- `/usr/local/bin` trong rootfs có helper `charx_reset_passwords`.
- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json) chứa `/web/linux-reset-factory`, `/web/linux-user/change-password`, `/web/linux-user/check-default-password`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả Developer Mode và password behavior.

## Câu hỏi 9

### Question

Checklist secure update validation nên gồm gì?

### Answer

Checklist Day 13:

| Nhóm | Kiểm tra |
|---|---|
| Authenticity | RAUC signature/root CA, manifest, compatible target |
| Integrity | sha256 của rootfs/kernel, file size, tamper failure |
| Authorization | role nào upload/install update được |
| Storage | upload/download dirs, permission, cleanup |
| Version policy | downgrade/upgrade constraints |
| Failure handling | power loss, invalid package, wrong compatible |
| Rollback | A/B slot behavior, mark-good, boot fail |
| Config migration | `/data`, `/etc/charx`, imported configs |
| Secret retention | certs, passwords, OpenVPN, MQTT/OCPP credentials |
| Logging | WBM logs, Update Agent logs, RAUC logs |
| Client propagation | server/client charging controllers update behavior |

### Evidence

- [manifest.raucm](/d:/CHARXSEC/work/firmware_v190_bundle/manifest.raucm), [hook](/d:/CHARXSEC/work/firmware_v190_bundle/hook), [system.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/rauc/system.conf) cung cấp update framework evidence.
- [Maintenance_repair_and_disposal.html](/d:/CHARXSEC/document/Maintenance_repair_and_disposal.html) mô tả local WBM update và OCPP backend update.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả update tự động tới connected charging controllers và update duration.

## Kết luận Ngày 13

Day 13 đã chốt update/config model:

- WBM, OCPP, Update Agent và RAUC đều nằm trong update pipeline.
- RAUC manifest có hash cho rootfs/kernel và compatible target `ev3000`.
- RAUC system config dùng A/B slots với barebox.
- Hook có compatibility check, pre/post install và bootloader update.
- Import/export đi qua Website và System Config Manager, chạm nhiều domain cấu hình.
- Password reset behavior là regression/security checklist quan trọng vì advisory 2024 từng nêu pattern này.

Day 14 sẽ biến toàn bộ quan sát thành vulnerability research backlog có kỷ luật.
