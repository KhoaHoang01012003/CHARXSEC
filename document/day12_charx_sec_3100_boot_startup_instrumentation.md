# Ngày 12 - Boot and startup instrumentation

Tài liệu này dựa trên timeline trong `courses.txt`, tài liệu chính thức, advisories và rootfs `V190`. Cấu trúc được chuẩn hóa theo dạng `Question -> Answer -> Evidence`.

Ngày 12 tập trung vào boot/startup order: service nào chạy trước, firewall lên lúc nào, update service sẵn sàng lúc nào, WBM login sẵn sàng lúc nào, và có cửa sổ thời gian nào cần kiểm tra thêm không.

## Nguồn tài liệu và artifact dùng cho Ngày 12

- [courses.txt](/d:/CHARXSEC/document/courses.txt)
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html)
- [PCSA-2024-00003_SECURITY_ADVISORY.pdf](/d:/CHARXSEC/document/PCSA-2024-00003_SECURITY_ADVISORY.pdf)
- [day8_charx_sec_3100_firmware_unpacking_filesystem_inventory.md](/d:/CHARXSEC/document/day8_charx_sec_3100_firmware_unpacking_filesystem_inventory.md)
- [day9_charx_sec_3100_service_graph_call_chain_reconstruction.md](/d:/CHARXSEC/document/day9_charx_sec_3100_service_graph_call_chain_reconstruction.md)
- [root.ext4](/d:/CHARXSEC/work/firmware_v190_bundle/root.ext4)
- `/etc/rc5.d` trong rootfs `V190`
- `/etc/init.d` trong rootfs `V190`

## Câu hỏi 1

### Question

Day 12 cần tạo output gì?

### Answer

Timeline yêu cầu:

- quan sát service start order
- định vị thời điểm firewall, update và auth state thay đổi
- instrument boot logs
- instrument service start sequence
- instrument port binds
- instrument file access during startup
- ghi lại windows như before firewall up, before login ready, before update service complete

Output gồm:

- boot timeline chi tiết
- danh sách race-window cần kiểm tra thêm

Day 12 không khẳng định có race condition. Nó tạo kế hoạch đo và baseline từ SysV init order.

### Evidence

- [courses.txt](/d:/CHARXSEC/document/courses.txt) ghi Day 12 là `Boot and startup instrumentation`.
- [PCSA-2024-00003_SECURITY_ADVISORY.pdf](/d:/CHARXSEC/document/PCSA-2024-00003_SECURITY_ADVISORY.pdf) mô tả issue lịch sử liên quan firewall service start sequence.

## Câu hỏi 2

### Question

Boot order baseline từ `rc5.d` là gì?

### Answer

Runlevel `rc5.d` trong rootfs `V190` cho thấy thứ tự khởi động chính:

| Order | Service |
|---|---|
| `S04` | `charx-hw-init` |
| `S05` | `charx-network-restore` |
| `S10` | `charx-qca`, `openvpn` |
| `S12` | `charx-system-configure` |
| `S30` | `charx-firewall-configure` |
| `S50` | `charx-system-config-manager` |
| `S60` | `charx-update-agent` |
| `S92` | `nginx` |
| `S97` | `charx-system-init` |
| `S98` | `charx-can-init`, `charx-cellular-network`, `mosquitto` |
| `S99` | `charx-controller-agent`, `charx-jupicore`, `charx-loadmanagement`, `charx-modbus-agent`, `charx-modbus-server`, `charx-modem-on`, `charx-ocpp16-agent`, `charx-system-monitor`, `charx-website` |

Điểm đáng chú ý:

- firewall configure chạy ở `S30`
- System Config Manager chạy ở `S50`
- Update Agent chạy ở `S60`
- nginx chạy ở `S92`
- MQTT broker `mosquitto` chạy ở `S98`
- Website backend chạy ở `S99`

Vì nhiều service CHARX chính chạy sau nginx, cần đo chính xác lúc nào `/api` thật sự sẵn sàng.

### Evidence

- `/etc/rc5.d` trong [root.ext4](/d:/CHARXSEC/work/firmware_v190_bundle/root.ext4) chứa các symlink `S04charx-hw-init`, `S30charx-firewall-configure`, `S50charx-system-config-manager`, `S60charx-update-agent`, `S92nginx`, `S98mosquitto`, `S99charx-website`.
- [day8_charx_sec_3100_firmware_unpacking_filesystem_inventory.md](/d:/CHARXSEC/document/day8_charx_sec_3100_firmware_unpacking_filesystem_inventory.md) đã inventory SysV init scripts.

## Câu hỏi 3

### Question

Firewall window cần kiểm tra như thế nào?

### Answer

Từ boot order, firewall configure là `S30`. Các service mạng quan trọng chạy sau đó, nhưng cần đo runtime để xác nhận không có port nào mở trước khi firewall policy sẵn sàng.

Checklist đo:

| Mốc | Việc cần đo |
|---|---|
| trước `S30` | interface nào đã up, port nào đã bind |
| trong lúc `S30` chạy | firewall rules thay đổi ra sao |
| sau `S30` trước `S50` | service nào đã reachable |
| trước nginx `S92` | port 80/443 đã bind chưa |
| trước Website `S99` | `/api` trả gì |
| sau Website `S99` | route permission/auth ready chưa |

Advisory 2024 từng có pattern firewall/startup sequence, nên đây là control point lịch sử cần đo lại trên firmware lab.

### Evidence

- [PCSA-2024-00003_SECURITY_ADVISORY.pdf](/d:/CHARXSEC/document/PCSA-2024-00003_SECURITY_ADVISORY.pdf) mô tả vulnerability lịch sử liên quan firewall service start sequence.
- `/etc/rc5.d` trong rootfs đặt `charx-firewall-configure` ở `S30`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `Network/Port Sharing` cho phép block incoming ports.

## Câu hỏi 4

### Question

Update service startup cần instrument gì?

### Answer

Update Agent chạy ở `S60`, trước nginx và Website. Init script tạo các thư mục:

| Path | Quan sát |
|---|---|
| `/data/charx-update-agent` | data dir |
| `/data/charx-update-agent/download` | download dir |
| `/data/charx-update-agent/upload` | upload dir |
| `/log/charx-update-agent` | log dir |

Điểm cần đo:

- Update Agent bind port nào nếu có
- thư mục upload/download được tạo lúc nào
- permission thực tế sau boot là gì
- WBM update route có phụ thuộc Update Agent sẵn sàng không
- update service có log lỗi nếu RAUC/system state chưa sẵn sàng không

### Evidence

- `/etc/rc5.d` trong rootfs đặt `charx-update-agent` ở `S60`.
- [charx-update-agent](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/init.d/charx-update-agent) tạo `DATA_DIR`, `DOWNLOAD_DIR`, `UPLOAD_DIR`, `LOG_DIR`.
- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json) chứa `/web/update`, `/web/update2-upload`, `/web/update2-install`.

## Câu hỏi 5

### Question

Auth/login readiness cần đo ở đâu?

### Answer

WBM login readiness phụ thuộc nhiều lớp:

| Lớp | Mốc |
|---|---|
| nginx | `S92nginx`, port 80/443 |
| frontend files | `/usr/lib/charx-website/dist` |
| Website backend | `S99charx-website`, port `5000` |
| route permissions | `/etc/charx/routePermissions.json` |
| database | `/data/charx-website/website.db` |
| auth modules | `api_auth_resource.so`, `api_user.so`, `user_management.so` |

Instrumentation cần ghi:

- nginx trả HTTPS khi nào
- `/api/v1.0/web/login` trả trạng thái gì trước khi Website backend sẵn sàng
- role mapping được load khi nào
- login failure/success có log ở đâu
- sau reboot, session cũ còn hợp lệ không

### Evidence

- [default_server](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/nginx/sites-available/default_server) định nghĩa `/api/v1.0/web/login` và rate limit login.
- [charx-website.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-website.conf) ghi backend REST `0.0.0.0:5000` và database `/data/charx-website/website.db`.
- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json) chứa `/web/login`.

## Câu hỏi 6

### Question

File access during startup nên theo dõi file nào?

### Answer

Danh sách file/path cần theo dõi:

| Path | Lý do |
|---|---|
| `/etc/charx/*.conf` | service config baseline |
| `/data/charx-*` | writable runtime data |
| `/log/charx-*` | service log |
| `/etc/charx/routePermissions.json` | authz mapping |
| `/data/charx-website/upload` | upload WBM |
| `/data/charx-update-agent/upload` | update upload |
| `/data/charx-ocpp16-agent/update` | OCPP update data |
| `/data/charx-ocpp16-agent/cert` | OCPP certs |
| `/data/charx-controller-agent/cert` | SECC cert/key path |
| `/etc/nginx/*` | frontend/proxy/TLS |
| `/etc/rauc/*` | update trust |

Nếu dùng thiết bị thật hoặc emulation có hỗ trợ, nên log `open`, `read`, `write`, `rename`, `chmod`, `chown`, `execve` theo timestamp.

### Evidence

- Các init scripts `charx-*` tạo `/data` và `/log` tương ứng cho service.
- [charx-controller-agent.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-controller-agent.conf) tham chiếu certificate/key dưới `/data/charx-controller-agent/cert`.
- [charx-ocpp16-agent](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/init.d/charx-ocpp16-agent) tạo update/debug/archive/cert directories.
- [charx-update-agent](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/init.d/charx-update-agent) tạo upload/download directories.

## Câu hỏi 7

### Question

Race-window checklist sau Day 12 là gì?

### Answer

Checklist cần kiểm tra:

| Window | Hypothesis phòng thủ | Evidence cần thu |
|---|---|---|
| before firewall up | có port nào reachable trước `S30` không | packet capture, port timeline |
| before SCM ready | Website/API có gọi SCM trước khi SCM sẵn sàng không | logs, HTTP status |
| before Update Agent complete | update upload/install route phản ứng ra sao | route test, logs |
| nginx before Website | `/api` trả lỗi gì khi backend chưa sẵn sàng | nginx logs, status code |
| MQTT broker late start | service dùng MQTT trước khi mosquitto ready không | service logs |
| file permission setup | writable dirs có permission rộng bất thường không | stat timeline |
| service restart | restart app có tạo inconsistent state không | process/log timeline |

Các item này là hypothesis cần đo, không phải kết luận vulnerability.

### Evidence

- `/etc/rc5.d` trong rootfs cho thấy thứ tự `S30`, `S50`, `S60`, `S92`, `S98`, `S99`.
- [PCSA-2024-00003_SECURITY_ADVISORY.pdf](/d:/CHARXSEC/document/PCSA-2024-00003_SECURITY_ADVISORY.pdf) cung cấp pattern lịch sử về startup/firewall sequence.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả System Control/Status, Log Files và service restart.

## Kết luận Ngày 12

Day 12 tạo boot timeline baseline:

- firewall configure ở `S30`
- System Config Manager ở `S50`
- Update Agent ở `S60`
- nginx ở `S92`
- mosquitto ở `S98`
- các service CHARX chính ở `S99`

Output chính là checklist instrumentation: port binds, service start, file access, logs, auth readiness và update readiness. Day 13 sẽ dùng timeline này để phân tích sâu update pipeline và config import/export.
