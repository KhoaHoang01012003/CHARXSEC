# Ngày 9 - Service graph và call-chain reconstruction

Tài liệu này dựa trên timeline trong `courses.txt`, các tài liệu chính thức trong thư mục `document`, và firmware bundle `CHARXSEC3XXXSoftwareBundleV190.raucb` đã được unpack ở Day 8. Cấu trúc được chuẩn hóa theo dạng `Question -> Answer -> Evidence`.

Ngày 9 chuyển inventory của Day 8 thành service graph: service nào gọi service nào, port nào là public, port nào là nội bộ, cấu hình nào là điểm nối giữa WBM, JupiCore, Controller Agent, OCPP, Modbus, Load Management, System Config Manager và Update Agent.

## Nguồn tài liệu và artifact dùng cho Ngày 9

- [courses.txt](/d:/CHARXSEC/document/courses.txt)
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html)
- [day8_charx_sec_3100_firmware_unpacking_filesystem_inventory.md](/d:/CHARXSEC/document/day8_charx_sec_3100_firmware_unpacking_filesystem_inventory.md)
- [root.ext4](/d:/CHARXSEC/work/firmware_v190_bundle/root.ext4)
- [charx-website.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-website.conf)
- [charx-jupicore.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-jupicore.conf)
- [charx-ocpp16-agent.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-ocpp16-agent.conf)
- [charx-modbus-server.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-modbus-server.conf)
- [charx-system-config-manager.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-system-config-manager.conf)
- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json)

## Câu hỏi 1

### Question

Theo timeline, Day 9 cần tạo ra output gì?

### Answer

Day 9 có mục tiêu là hiểu `ai gọi ai` trong firmware. Output cần có:

- service dependency graph
- sơ đồ `front-end request -> backend action`
- bảng hard-coded ports, hostnames, IPC patterns
- danh sách câu hỏi cần đưa sang Day 10 Web/API audit

Điểm quan trọng là service graph không chỉ là danh sách process. Nó phải nối được các lớp:

- nginx và static frontend
- Website backend
- JupiCore
- System Config Manager
- Controller Agent
- OCPP Agent
- Modbus Agent/Server
- Load Management
- MQTT broker local
- Update Agent

### Evidence

- [courses.txt](/d:/CHARXSEC/document/courses.txt) ghi Day 9 là `Service graph và call-chain reconstruction`.
- [courses.txt](/d:/CHARXSEC/document/courses.txt) yêu cầu dựng graph `nginx -> website backend`, `UI -> JupiCore`, `JupiCore -> controller agent / MQTT / OCPP`, `modbus agent/server`, `load management`, `system config manager`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) liệt kê các software services/applications trong `System Control/Status`.

## Câu hỏi 2

### Question

Service graph v1 của firmware `V190` trông như thế nào?

### Answer

Service graph v1 có thể mô tả như sau:

```text
Browser/WBM
  -> nginx :80/:443/:81
  -> /usr/lib/charx-website/dist
  -> proxy /api -> CharxWebsite :5000
  -> proxy /ws  -> websocket backend :4999

CharxWebsite :5000
  -> routePermissions.json
  -> MQTT local 127.0.0.1:1883
  -> upload folder /data/charx-website/upload
  -> website database /data/charx-website/website.db
  -> System Config Manager :5001
  -> JupiCore :5555
  -> Update Agent / upload-update path
  -> helper scripts through controlled service paths

JupiCore :5555
  -> Controller Agent 127.0.0.1:4444
  -> MQTT local 127.0.0.1:1883
  -> database /data/charx-jupicore/jupicore.db
  -> charging controller / charging point modules

OCPP 1.6J Agent :2106
  -> backend over eth0
  -> JupiCore 127.0.0.1:5555
  -> MQTT local 127.0.0.1:1883
  -> database /data/charx-ocpp16-agent/ocpp16.db

Modbus Server :502 and API :9555
  -> JupiCore 127.0.0.1:5555
  -> System Config Manager 127.0.0.1:5001
  -> MQTT local 127.0.0.1:1883

Load Management :1603
  -> JupiCore REST 127.0.0.1:5555
  -> MQTT local 127.0.0.1:1883
```

Graph này chưa phải dynamic trace. Nó là reconstruction từ config, init scripts và manual. Khi sang boot instrumentation, cần xác nhận bằng port bind, process list và logs.

### Evidence

- [charx-website.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-website.conf) ghi Website REST API ở `0.0.0.0:5000`, MQTT local `127.0.0.1:1883`.
- [charx-jupicore.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-jupicore.conf) ghi JupiCore REST API ở `0.0.0.0:5555`, Controller Agent `127.0.0.1:4444`, MQTT local `127.0.0.1:1883`.
- [charx-ocpp16-agent.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-ocpp16-agent.conf) ghi REST `0.0.0.0:2106`, JupiCore `127.0.0.1:5555`, MQTT `127.0.0.1:1883`.
- [charx-modbus-server.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-modbus-server.conf) ghi Server `0.0.0.0:502`, API `0.0.0.0:9555`, SCM `127.0.0.1:5001`, JupiCore `127.0.0.1:5555`.

## Câu hỏi 3

### Question

Nginx đứng ở đâu trong call-chain WBM?

### Answer

Nginx là front door cho WBM:

| Nginx surface | Vai trò |
|---|---|
| `listen 80` | HTTP default server, redirect sang HTTPS |
| `listen 443 ssl http2` | HTTPS WBM |
| `listen 81` | custom website tại `/data/user-app/website` |
| `/` | serve frontend từ `/usr/lib/charx-website/dist` |
| `/api` | proxy tới `http://0.0.0.0:5000` |
| `/api/v1.0/web/login` | proxy login tới `5000` với rate limit riêng |
| `/ws` | proxy websocket tới `http://0.0.0.0:4999` |

Vì vậy call-chain WBM cơ bản là:

```text
Browser -> nginx :443 -> CharxWebsite :5000 -> service/backend action
```

Điểm cần chú ý cho Day 10 là nginx không tự quyết định role của API. Role mapping nằm trong `routePermissions.json` và backend Website phải enforce nó.

### Evidence

- [nginx.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/nginx/nginx.conf) định nghĩa logging, gzip, rate limit zone `limit` và `limit_login`.
- [default_server](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/nginx/sites-available/default_server) ghi `listen 80`, redirect HTTPS, `listen 443 ssl http2`, root `/usr/lib/charx-website/dist`.
- [default_server](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/nginx/sites-available/default_server) proxy `/api` tới `http://0.0.0.0:5000` và `/ws` tới `http://0.0.0.0:4999`.

## Câu hỏi 4

### Question

Website backend nối tới những thành phần nào?

### Answer

Website backend là lớp trung gian giữa frontend và các service nội bộ. Nó có nhiều module API trong `/usr/lib/charx-website`, gồm:

| Module | Vai trò suy ra từ tên |
|---|---|
| `api_auth_resource.so`, `api_user.so` | auth/user management |
| `api_file.so` | file upload/download |
| `api_import.so`, `api_export.so` | import/export |
| `api_firewall.so`, `api_network.so`, `api_routing_table.so` | system/network settings |
| `api_openvpn.so`, `openvpn_manager.so` | OpenVPN |
| `api_certificates.so` | certificate handling |
| `api_ocpp.so` | OCPP-related web controls |
| `api_modem.so` | modem controls |
| `api_topics_forwarding.so`, `mqtt_bridge_manager.so` | MQTT Bridge/topic forwarding |
| `api_linux_user_permissions.so` | Linux user permission boundary |

Website config cho thấy nó dùng MQTT local, upload folder và database. Route permission JSON cho thấy nhiều route của WBM có role `user`, `operator`, `manufacturer` hoặc `guest`. Vì advisory 2025 liên quan WBM low-privileged account và system configuration, Website backend là một trọng tâm của Day 10.

### Evidence

- [charx-website.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-website.conf) ghi `UploadFolder=/data/charx-website/upload/` và `DatabaseFilePath=/data/charx-website/website.db`.
- `/usr/lib/charx-website` trong [root.ext4](/d:/CHARXSEC/work/firmware_v190_bundle/root.ext4) chứa các module `api_file.so`, `api_import.so`, `api_export.so`, `api_firewall.so`, `api_openvpn.so`, `api_certificates.so`, `api_linux_user_permissions.so`.
- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json) chứa route/role mapping cho WBM API.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) mô tả CVE-2025-41699 liên quan WBM account và system configuration.

## Câu hỏi 5

### Question

JupiCore là hub của những luồng nào?

### Answer

JupiCore là hub dữ liệu và topology. Nó có REST API `5555`, MQTT local, kết nối Controller Agent, database riêng và nhiều module charging-related.

| Luồng | Bằng chứng |
|---|---|
| JupiCore REST | `Host=0.0.0.0`, `Port=5555` |
| JupiCore -> Controller Agent | `Host=127.0.0.1`, `Port=4444` |
| JupiCore -> MQTT local | `127.0.0.1:1883`, client ID `charx-jupicore` |
| JupiCore -> database | `/data/charx-jupicore/jupicore.db` |
| JupiCore -> charging modules | `charging_controller.so`, `charging_point.so`, `topology_manager.so` |

Manual mô tả JupiCore thu thập dữ liệu từ các charging point và forward tới MQTT broker, internal services, external services qua REST API. Firmware khớp với mô tả này.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả JupiCore là service thu thập dữ liệu từ connected charging points và forward tới MQTT broker, internal services, external services qua REST API.
- [charx-jupicore.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-jupicore.conf) ghi REST `0.0.0.0:5555`, MQTT `127.0.0.1:1883`, Controller Agent `127.0.0.1:4444`.
- `/usr/lib/charx-jupicore` trong rootfs chứa `charging_controller.so`, `charging_point.so`, `mqtt_connector.so`, `topology_manager.so`.

## Câu hỏi 6

### Question

OCPP, Modbus và Load Management kết nối với graph chính như thế nào?

### Answer

Ba service này nằm ở lớp runtime protocol:

| Service | Public/local port | Internal dependency | Ý nghĩa |
|---|---|---|---|
| OCPP 1.6J Agent | `0.0.0.0:2106` | JupiCore `127.0.0.1:5555`, MQTT `127.0.0.1:1883` | backend communication, firmware update path, diagnostics |
| Modbus Agent | `0.0.0.0:9502` | MQTT `127.0.0.1:1883` | config/agent cho Modbus devices |
| Modbus Server | `0.0.0.0:502`, API `0.0.0.0:9555` | SCM `127.0.0.1:5001`, JupiCore `127.0.0.1:5555`, MQTT `127.0.0.1:1883` | read/control charging data |
| Load Management | `0.0.0.0:1603` | JupiCore REST `127.0.0.1:5555`, MQTT `127.0.0.1:1883` | local load and charging management |

Điểm đáng chú ý là nhiều service dùng MQTT local như bus nội bộ, đồng thời expose REST/API hoặc protocol port ra `0.0.0.0`. Điều này cần được kiểm tra bằng port bind thật ở Day 12.

### Evidence

- [charx-ocpp16-agent.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-ocpp16-agent.conf) ghi OCPP REST `0.0.0.0:2106`.
- [charx-modbus-agent.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-modbus-agent.conf) ghi REST `0.0.0.0:9502`.
- [charx-modbus-server.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-modbus-server.conf) ghi Modbus Server `0.0.0.0:502` và API `0.0.0.0:9555`.
- [charx-loadmanagement-agent.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-loadmanagement-agent.conf) ghi LMGT REST `0.0.0.0:1603`.

## Câu hỏi 7

### Question

Những hard-coded ports, hostnames và IPC patterns nào cần ghi lại?

### Answer

Baseline hard-coded endpoint từ config:

| Component | Endpoint | Ghi chú |
|---|---|---|
| nginx HTTP | `80` | redirect sang HTTPS |
| nginx HTTPS | `443` | WBM frontend/API proxy |
| custom website | `81` | `/data/user-app/website` |
| Website backend | `0.0.0.0:5000` | WBM REST backend |
| Website websocket | `0.0.0.0:4999` | proxy từ `/ws` |
| System Config Manager | `0.0.0.0:5001` | system config REST |
| JupiCore | `0.0.0.0:5555` | REST/API hub |
| MQTT broker local | `127.0.0.1:1883` | shared internal bus |
| Controller Agent | `127.0.0.1:4444` | JupiCore dependency |
| OCPP Agent | `0.0.0.0:2106` | OCPP remote/API path |
| Modbus Server | `0.0.0.0:502` | Modbus/TCP |
| Modbus Server API | `0.0.0.0:9555` | service API |
| Modbus Agent | `0.0.0.0:9502` | config API |
| Load Management | `0.0.0.0:1603` | load management frame/API |
| OCPP backend template | `wss://phoenixcontact.com:8080/...` | default/template config |
| Controller Agent CAN | `can0` | CAN network |
| Controller Agent remote devices | `eth1` | client/server remote device network |
| Controller Agent SECC | `eth2`, ports `15118`, `49152` | SECC network config |

Các giá trị này không thay cho runtime scan. Chúng là baseline để Day 12 kiểm tra port bind thực tế.

### Evidence

- [charx-controller-agent.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-controller-agent.conf) ghi `can0`, `eth1`, `eth2`, `SeccNetworkDiscoveryPort=15118`, `SeccNetworkServerPort=49152`.
- [charx-website.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-website.conf), [charx-jupicore.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-jupicore.conf), [charx-ocpp16-agent.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-ocpp16-agent.conf), [charx-modbus-server.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-modbus-server.conf) chứa các endpoint nêu trên.
- [default_server](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/nginx/sites-available/default_server) ghi nginx `80`, `443`, `81`, `/api` proxy và `/ws` proxy.

## Câu hỏi 8

### Question

Sơ đồ `front-end request -> backend action` nên dùng cho Day 10 là gì?

### Answer

Sơ đồ baseline:

```text
1. Browser gọi HTTPS WBM
2. nginx serve frontend từ /usr/lib/charx-website/dist
3. frontend gọi /api/v1.0/...
4. nginx proxy /api tới CharxWebsite :5000
5. CharxWebsite kiểm tra routePermissions.json
6. CharxWebsite gọi module api_*.so tương ứng
7. Module Website gọi backend service hoặc helper path
8. Backend service ghi /data, /log, /etc/charx hoặc gọi service khác
9. Response quay lại frontend
```

Các domain cần Day 10 review sâu:

- auth/session
- file upload/download
- import/export
- update
- firewall/network/routing
- OpenVPN/certificate
- Linux user/password/permission
- OCPP config/diagnostics
- service restart/start/stop/reboot

### Evidence

- [default_server](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/nginx/sites-available/default_server) proxy `/api` tới `5000`.
- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json) chứa role mapping cho WBM, system-config-manager, OCPP, charging-point, loadmanagement và Modbus routes.
- `/usr/lib/charx-website` trong rootfs chứa các module `api_*.so` tương ứng với domain cần review.

## Kết luận Ngày 9

Day 9 đã dựng được service graph v1:

- nginx là front door cho WBM.
- CharxWebsite là API backend chính ở `5000`.
- JupiCore là data/topology hub ở `5555`.
- System Config Manager expose REST ở `5001`.
- OCPP, Modbus, Load Management nối vào JupiCore, MQTT local và một số service nội bộ.
- MQTT local `127.0.0.1:1883` là bus chung của nhiều service.
- Day 10 sẽ dùng `routePermissions.json` và module `api_*.so` để tạo API inventory và danh sách endpoint cần review sâu.
