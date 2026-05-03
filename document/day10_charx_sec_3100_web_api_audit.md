# Ngày 10 - Web/API audit

Tài liệu này dựa trên timeline trong `courses.txt`, các tài liệu chính thức trong `document`, và firmware/rootfs đã unpack ở Day 8. Cấu trúc được chuẩn hóa theo dạng `Question -> Answer -> Evidence`.

Timeline Day 10 nhắc tới `charx-api-catalog.json` và route permissions. Tại thời điểm viết tài liệu này, workspace không có `work/charx-api-catalog.json`; nguồn API chính đang có là [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json). Vì vậy Day 10 tạo API audit baseline từ route permissions và module firmware. Khi có catalog JSON, bước tiếp theo là merge catalog đó vào bảng này.

## Nguồn tài liệu và artifact dùng cho Ngày 10

- [courses.txt](/d:/CHARXSEC/document/courses.txt)
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html)
- [day9_charx_sec_3100_service_graph_call_chain_reconstruction.md](/d:/CHARXSEC/document/day9_charx_sec_3100_service_graph_call_chain_reconstruction.md)
- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json)
- [charx-website.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-website.conf)
- [charx-system-config-manager.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-system-config-manager.conf)
- [default_server](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/nginx/sites-available/default_server)
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt)

## Câu hỏi 1

### Question

Day 10 cần audit Web/API theo hướng nào?

### Answer

Day 10 tập trung vào REST surface của WBM và các backend service liên quan. Mục tiêu không phải fuzz bừa API, mà là tạo inventory có phân nhóm:

- endpoint domain
- HTTP method
- role yêu cầu
- backend module có khả năng xử lý
- hành động đặc quyền
- file/config/service bị tác động
- câu hỏi cần review sâu

Với firmware `V190`, API audit bắt đầu từ ba nơi:

- nginx proxy `/api` tới `CharxWebsite:5000`
- `routePermissions.json` map route/method sang role
- module `/usr/lib/charx-website/api_*.so` và `/usr/lib/charx-system-config-manager/*.so`

### Evidence

- [courses.txt](/d:/CHARXSEC/document/courses.txt) nêu Day 10 tập trung vào web backend và REST surface.
- [default_server](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/nginx/sites-available/default_server) proxy `/api` tới `http://0.0.0.0:5000`.
- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json) chứa route/method/role mapping.
- `/usr/lib/charx-website` trong rootfs chứa nhiều module `api_*.so`.

## Câu hỏi 2

### Question

`routePermissions.json` cho thấy mô hình role nào?

### Answer

Trong firmware `V190`, `routePermissions.json` có 70 route pattern. Các role quan sát được:

| Role | Số lần xuất hiện trong method permissions | Ý nghĩa audit |
|---|---:|---|
| `guest` | 12 | endpoint không cần login hoặc chỉ cần trạng thái guest |
| `user` | 33 | quyền thấp sau login |
| `operator` | 56 | quyền vận hành/cấu hình đáng kể |
| `manufacturer` | 17 | quyền cao nhất trong mapping quan sát được |

Điểm cần chú ý là CVE-2025-41699 liên quan `low privileged remote attacker with an account for the Web-based management`. Vì vậy audit không chỉ nhìn endpoint `guest`; các endpoint role `user` cũng cần xem kỹ nếu chúng chạm vào system configuration, file, import/export, certificate, logs hoặc service control.

### Evidence

- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json) chứa 70 route pattern.
- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json) sử dụng role `guest`, `user`, `operator`, `manufacturer`.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) mô tả CVE-2025-41699 liên quan low-privileged WBM account và system configuration.

## Câu hỏi 3

### Question

API inventory nên được nhóm theo domain nào?

### Answer

API inventory baseline:

| Domain | Route examples | Module gợi ý | Risk câu hỏi |
|---|---|---|---|
| Auth/user | `/web/login`, `/web/user/change-password`, `/web/users-active` | `api_auth_resource.so`, `api_user.so`, `user_management.so` | session, password change, role boundary |
| Linux user | `/web/linux-user/*`, `/web/linux-user-permissions` | `api_linux_user_permissions.so` | privilege and default-password handling |
| File/log | `/web/download/logs`, `/web/download/licenses`, `/web/public-key` | `api_file.so`, `api_certificates.so` | information disclosure, file path control |
| Import/export | `/web/import`, `/web/export` | `api_import.so`, `api_export.so` | config injection, sensitive export |
| Update | `/web/update`, `/web/update2-upload`, `/web/update2-install` | `api_file.so`, Update Agent modules | package validation, upload handling |
| Network/firewall | `/web/network`, `/web/firewall`, `/web/routing_table`, `/web/wifi` | `api_network.so`, `api_firewall.so`, `api_routing_table.so`, `api_wifi_settings.so` | command/config boundary |
| VPN/cert | `/web/openvpn`, `/web/openvpn_credentials`, `/web/OCPPCertificate` | `api_openvpn.so`, `openvpn_manager.so`, `api_certificates.so` | certificate and credential lifecycle |
| Modem | `/web/modem`, `/web/modem-ping` | `api_modem.so` | AT commands, network state |
| Service control | `/web/restart-app`, `/web/stop-app`, `/web/start-app`, `/web/reboot-all` | `api_internal.so` | privileged operation |
| OCPP | `/ocpp16/config/*`, `/ocpp16/diagnostic/*` | `api_ocpp.so`, OCPP agent modules | backend config, diagnostics |
| Charging | `/charging-points/*`, `/charging-controllers/*` | JupiCore API modules | runtime charging control |
| System config | `/system-config-manager/config`, `/system-config-manager/remove-file` | SCM modules | config apply and file operation |

### Evidence

- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json) chứa các route domain nêu trên.
- `/usr/lib/charx-website` trong rootfs chứa `api_file.so`, `api_import.so`, `api_export.so`, `api_firewall.so`, `api_network.so`, `api_openvpn.so`, `api_modem.so`, `api_ocpp.so`.
- `/usr/lib/charx-system-config-manager` trong rootfs chứa `api_config.so`, `api_import.so`, `api_export.so`, `api_remove_file.so`.

## Câu hỏi 4

### Question

Những endpoint nào là privileged actions cần review sâu?

### Answer

Danh sách review ưu tiên:

| Endpoint/domain | Role quan sát | Vì sao nhạy cảm |
|---|---|---|
| `/web/update*` | `operator` | upload/install update package |
| `/web/import` | `operator` | đưa cấu hình bên ngoài vào hệ thống |
| `/web/export` | `operator` | có thể xuất dữ liệu nhạy cảm |
| `/web/firewall` POST | `operator` | thay đổi port exposure |
| `/web/network` POST | `operator` | thay đổi network config |
| `/web/routing_table` POST | `operator` | thay đổi routing |
| `/web/openvpn` POST | `operator` | thay đổi VPN config |
| `/web/openvpn_credentials` | `operator` | credential/cert boundary |
| `/web/OCPPCertificate` | `operator` | certificate handling |
| `/web/reboot-all` | `operator` | restart toàn hệ thống |
| `/web/start-app`, `/stop-app`, `/restart-app` | `operator` | lifecycle service |
| `/web/linux-reset-factory` | `manufacturer` | reset/factory action |
| `/web/linux-user-permissions` | `manufacturer` | quyền Linux user |
| `/system-config-manager/config` PUT | `manufacturer` | system configuration apply |
| `/system-config-manager/remove-file` POST | `manufacturer` | file removal |
| `/ocpp16/config/set-section-parameter` | `operator` | thay đổi OCPP config |

Audit nên xem input schema, authorization enforcement, backend call-chain, file path handling, service restart và logging. Không cần payload khai thác để làm phần này; cần xác định đường dữ liệu trước.

### Evidence

- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json) định nghĩa role cho các endpoint nêu trên.
- [charx-system-config-manager.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-system-config-manager.conf) cho thấy SCM expose REST `0.0.0.0:5001`.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) mô tả system configuration là vùng liên quan CVE-2025-41699.

## Câu hỏi 5

### Question

Auth/session handling cần kiểm tra gì?

### Answer

Các câu hỏi audit:

| Câu hỏi | Vì sao quan trọng |
|---|---|
| Login endpoint tạo session/token như thế nào? | xác định session boundary |
| Role được lấy từ đâu và cache ở đâu? | tránh role confusion |
| `guest` endpoint có trả dữ liệu nhạy cảm không? | information disclosure |
| `user` endpoint nào chạm vào file/config/action đặc quyền? | liên quan low-privileged account risk |
| Password change phân biệt WBM user và Linux `user-app` thế nào? | tránh nhầm identity boundary |
| `users-active` có lộ thông tin session không? | privacy/attack surface |
| nginx rate limit chỉ áp dụng login hay cả API khác? | brute-force/rate limiting boundary |

Không nên kết luận auth bypass chỉ từ route table. Cần đối chiếu module `api_auth_resource.so`, `api_user.so`, `user_management.so`, `routePermissions.json` và runtime behavior.

### Evidence

- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json) chứa `/web/login`, `/web/user/change-password`, `/web/linux-user/change-password`, `/web/users-active`.
- [default_server](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/nginx/sites-available/default_server) có rate limit riêng cho `/api/v1.0/web/login`.
- `/usr/lib/charx-website` trong rootfs chứa `api_auth_resource.so`, `api_user.so`, `user_management.so`.

## Câu hỏi 6

### Question

File upload/download surfaces gồm những gì?

### Answer

Các surface cần đưa vào API audit:

| Surface | Path hoặc endpoint | Câu hỏi cần kiểm tra |
|---|---|---|
| Firmware upload | `/web/update2-upload`, `/web/update2-upload-stream` | file type, size, storage path, verification |
| Firmware install | `/web/update2-install` | package selection, state machine, logging |
| Config import | `/web/import` | archive format, schema, rollback |
| Config export | `/web/export` | secret/cert/password leakage |
| Log download | `/web/download/logs` | log redaction, access control |
| License download | `/web/download/licenses` | path control |
| Public key | `/web/public-key` | key material lifecycle |
| OCPP certificate | `/web/OCPPCertificate` | upload/delete certificate |
| OpenVPN credentials | `/web/openvpn_credentials` | secret handling |

Website config cho thấy upload folder là `/data/charx-website/upload/`. Update Agent init script tạo `/data/charx-update-agent/upload` với permission `777` trong script quan sát được; đây là điểm cần review quyền file và service ownership.

### Evidence

- [charx-website.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-website.conf) ghi `UploadFolder=/data/charx-website/upload/`.
- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json) chứa các route update, import/export, log download, certificate và OpenVPN credentials.
- [charx-update-agent](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/init.d/charx-update-agent) tạo `UPLOAD_DIR=${DATA_DIR}/upload`.

## Câu hỏi 7

### Question

OCPP-related controls cần audit ở đâu?

### Answer

OCPP có hai lớp:

| Lớp | File/route | Nội dung audit |
|---|---|---|
| WBM API | `/ocpp16/config/*`, `/ocpp16/diagnostic/*`, `/web/OCPPCertificate` | auth, config validation, certificate handling |
| OCPP Agent | `/usr/lib/charx-ocpp16-agent/*.so`, `charx-ocpp16-agent.conf` | backend URL, websocket, firmware update, diagnostics |

Các module đáng chú ý:

- `ocpp_configuration.so`
- `ocpp_firmware_update.so`
- `ocpp_logic.so`
- `ocpp_req_payload.so`
- `ocpp_res_payload.so`
- `ocpp_security_event_handler.so`
- `websocket_handler.so`

Day 10 chỉ tạo inventory. Test sâu cần mock OCPP backend ở Day 11 và instrumentation ở Day 12.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả OCPP settings, OCPP messages và log files.
- [charx-ocpp16-agent.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-ocpp16-agent.conf) ghi backend URL, interface `eth0`, REST `0.0.0.0:2106`.
- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json) chứa `/ocpp16/config/*` và `/ocpp16/diagnostic/*`.
- `/usr/lib/charx-ocpp16-agent` trong rootfs chứa các module OCPP nêu trên.

## Câu hỏi 8

### Question

API audit backlog sau Day 10 nên gồm gì?

### Answer

Backlog ưu tiên:

| Ưu tiên | Nhóm endpoint | Việc cần làm tiếp |
|---:|---|---|
| 1 | system configuration/import/export | map route -> module -> SCM -> file/action |
| 2 | update upload/install | map WBM -> Update Agent -> RAUC |
| 3 | network/firewall/routing/OpenVPN | kiểm tra helper scripts và sudoers |
| 4 | auth/user/Linux user | phân biệt role WBM và Linux user |
| 5 | log/file/cert download/upload | kiểm tra path control và redaction |
| 6 | OCPP config/update/diagnostics | dựng backend mock |
| 7 | Modbus/loadmanagement runtime control | kiểm tra auth và network exposure |

Mỗi endpoint cần được ghi thành record:

| Field | Nội dung |
|---|---|
| Route | route pattern |
| Method | GET/POST/PUT/DELETE |
| Role | guest/user/operator/manufacturer |
| Module | module `.so` nghi xử lý |
| Backend service | Website, SCM, JupiCore, OCPP, Update Agent |
| Data sink | file, DB, helper, service restart, network |
| Question | điều cần kiểm chứng |
| Evidence | file/config/log chứng minh |

### Evidence

- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json) là source chính cho route/method/role.
- `/usr/lib/charx-website` và `/usr/lib/charx-system-config-manager` trong rootfs chứa module xử lý domain.
- [day9_charx_sec_3100_service_graph_call_chain_reconstruction.md](/d:/CHARXSEC/document/day9_charx_sec_3100_service_graph_call_chain_reconstruction.md) cung cấp service graph v1.

## Kết luận Ngày 10

Day 10 đã tạo API audit baseline:

- `routePermissions.json` có 70 route pattern với role `guest`, `user`, `operator`, `manufacturer`.
- Các endpoint update, import/export, network/firewall/routing, OpenVPN, certificate, log download, service control và system-config-manager là nhóm cần review sâu.
- `work/charx-api-catalog.json` hiện chưa có trong workspace, nên audit hiện dựa trên route permissions và firmware modules.
- Day 11 sẽ chuyển sang emulation planning để chạy/mô phỏng đủ backend cần thiết cho quan sát động.
