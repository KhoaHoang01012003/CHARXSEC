# Ngày 11 - Emulation planning

Tài liệu này dựa trên timeline trong `courses.txt`, tài liệu chính thức, và firmware/rootfs `V190` đã inventory ở Day 8 đến Day 10. Cấu trúc được chuẩn hóa theo dạng `Question -> Answer -> Evidence`.

Mục tiêu của Day 11 là chọn chiến lược emulate hợp lý cho firmware Linux-based embedded device. Với CHARX SEC-3100, ta không nên bắt đầu bằng mục tiêu chạy hoàn hảo toàn bộ charging controller. Cách thực tế hơn là dựng từng lớp: static analysis, chroot/QEMU user, service replay, mocked peers, rồi mới tiến tới system emulation nếu cần.

## Nguồn tài liệu và artifact dùng cho Ngày 11

- [courses.txt](/d:/CHARXSEC/document/courses.txt)
- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md)
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html)
- [day8_charx_sec_3100_firmware_unpacking_filesystem_inventory.md](/d:/CHARXSEC/document/day8_charx_sec_3100_firmware_unpacking_filesystem_inventory.md)
- [day9_charx_sec_3100_service_graph_call_chain_reconstruction.md](/d:/CHARXSEC/document/day9_charx_sec_3100_service_graph_call_chain_reconstruction.md)
- [root.ext4](/d:/CHARXSEC/work/firmware_v190_bundle/root.ext4)
- [charx-system-monitor.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-system-monitor.conf)
- [charx-controller-agent.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-controller-agent.conf)

## Câu hỏi 1

### Question

Day 11 cần ra quyết định gì?

### Answer

Day 11 cần chốt `Emulation architecture plan` và danh sách mock services. Timeline yêu cầu cân nhắc:

- chroot/emulated rootfs
- QEMU user/system emulation
- containerized service replay
- mocked network peers
- dependency khó như hardware drivers, CAN, RNDIS, Modbus devices, MQTT broker, OCPP backend

Kết luận thực tế cho firmware này là dùng chiến lược nhiều tầng:

| Tầng | Mục tiêu | Khi nào dùng |
|---|---|---|
| Static analysis | đọc file, configs, strings, imports, routes | luôn làm trước |
| QEMU user/chroot | chạy binary ARM đơn lẻ hoặc service nhỏ | khi cần observe process behavior |
| Service replay | chạy subset service với config đã chỉnh trong lab | khi cần test API/backend logic |
| Mocked peers | MQTT/OCPP/Modbus/OpenVPN giả lập | khi service cần peer để không treo |
| QEMU system | emulate boot/rootfs sâu hơn | khi cần boot order hoặc kernel/device behavior |

### Evidence

- [courses.txt](/d:/CHARXSEC/document/courses.txt) ghi Day 11 là `Emulation planning`.
- [courses.txt](/d:/CHARXSEC/document/courses.txt) yêu cầu chọn chiến lược chroot, QEMU, containerized service replay và mocked network peers.
- [day8_charx_sec_3100_firmware_unpacking_filesystem_inventory.md](/d:/CHARXSEC/document/day8_charx_sec_3100_firmware_unpacking_filesystem_inventory.md) xác định rootfs là Linux ext4 và binaries là ARM 32-bit.

## Câu hỏi 2

### Question

Target architecture và runtime baseline là gì?

### Answer

Baseline kỹ thuật từ firmware `V190`:

| Thuộc tính | Giá trị |
|---|---|
| OS | `CHARX control Embedded Linux 1.9.0 (kirkstone)` |
| Rootfs | ext4 |
| Init | SysV init scripts |
| CPU/userland | ARM 32-bit EABI5, dynamically linked |
| Dynamic linker | `/lib/ld-linux-armhf.so.3` |
| Update framework | RAUC |
| Main app layout | `/usr/sbin/Charx*`, `/usr/lib/charx-*/*.so` |
| Main config | `/etc/charx/*.conf` |

Điều này làm QEMU user-mode trở thành lựa chọn hợp lý cho thử nghiệm binary/service theo từng phần. Nhưng vì firmware phụ thuộc nhiều device node, network interface và hardware bus, service replay cần mock hoặc chỉnh config.

### Evidence

- [root.ext4](/d:/CHARXSEC/work/firmware_v190_bundle/root.ext4) chứa `/usr/lib/os-release` với `CHARX control Embedded Linux 1.9.0 (kirkstone)`.
- `/usr/sbin/CharxControllerAgent` trong rootfs là ELF 32-bit ARM PIE executable, dynamically linked, stripped.
- `/usr/lib/charx-website/webserver.so` và nhiều module `.so` là ELF 32-bit ARM shared objects.
- [manifest.raucm](/d:/CHARXSEC/work/firmware_v190_bundle/manifest.raucm) cho thấy update bundle dùng rootfs `root.ext4` và kernel image `bootimg.vfat`.

## Câu hỏi 3

### Question

Những dependency nào khó emulate nhất?

### Answer

Các dependency khó:

| Dependency | Evidence | Cách xử lý trong lab |
|---|---|---|
| CAN | `CanNetworkInterfaceName=can0` | mock interface hoặc disable service khi test web |
| Remote device Ethernet | `RemoteDeviceNetworkInterfaceName=eth1` | tạo network namespace/interface giả |
| SECC/QCA/HomePlug context | `SeccNetworkInterfaceName=eth2`, QCA monitor | stub hoặc tách khỏi service replay ban đầu |
| Modem | `/dev/ttyMODEM2`, `/dev/cdc-wdm0` | mock device node hoặc disable monitor |
| RNDIS/USB-C | commissioning path | chỉ cần mô phỏng network peer trong lab |
| MQTT broker | nhiều service dùng `127.0.0.1:1883` | chạy Mosquitto local |
| OCPP backend | OCPP Agent cần backend URL/WebSocket | dựng mock backend |
| Modbus devices | Modbus Agent/Server cần device/config | dựng Modbus peer giả |
| OpenVPN server | OpenVPN config/test connection | mock server hoặc chỉ phân tích config |

Nguyên tắc là tách mục tiêu. Nếu mục tiêu Day 10 là audit WBM API, chưa cần emulate CAN, SECC hay Modbus physical layer. Nếu mục tiêu là Controller Agent, hardware dependency mới trở thành trung tâm.

### Evidence

- [charx-controller-agent.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-controller-agent.conf) ghi `can0`, `eth1`, `eth2`, SECC ports và cert paths.
- [charx-system-monitor.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-system-monitor.conf) ghi modem devices `/dev/ttyMODEM2`, `/dev/cdc-wdm0`, Ethernet interfaces `eth0,eth1,br0`, cellular `ppp0`, QCA interface `eth2`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả USB-C/RNDIS, OCPP, Modbus, MQTT Bridge, OpenVPN.

## Câu hỏi 4

### Question

Mock services cần viết hoặc dựng là gì?

### Answer

Mock list cho lab:

| Mock | Mục tiêu | Minimal behavior |
|---|---|---|
| MQTT broker | bus nội bộ cho Website/JupiCore/OCPP/Modbus/System Monitor | accept publish/subscribe, log topics |
| OCPP backend | quan sát OCPP Agent | WebSocket accept, log messages, trả response hợp lệ tối thiểu |
| Modbus peer | test Modbus Agent/Server | holding registers đơn giản, log request |
| JupiCore fake | khi chỉ test Website mà không chạy JupiCore thật | trả response REST tối thiểu ở `5555` |
| SCM fake | khi chỉ test Website import/export | trả response REST tối thiểu ở `5001` |
| OpenVPN server/test endpoint | kiểm tra config flow | chấp nhận test connection hoặc mock log |
| Device node stubs | modem/CAN/QCA | tạo placeholder hoặc chỉnh config để service không block |

Mock nên ghi log đầy đủ request, header, body size, timestamp và source. Không cần mô phỏng mọi logic sạc để trả lời câu hỏi Web/API.

### Evidence

- [charx-website.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-website.conf) cho thấy Website dùng MQTT local.
- [charx-jupicore.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-jupicore.conf) cho thấy JupiCore dùng MQTT và Controller Agent.
- [charx-ocpp16-agent.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-ocpp16-agent.conf) cho thấy OCPP Agent dùng backend URL, MQTT và JupiCore.
- [charx-modbus-server.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-modbus-server.conf) cho thấy Modbus Server dùng SCM, JupiCore và MQTT.

## Câu hỏi 5

### Question

Emulation architecture plan nên chọn như thế nào?

### Answer

Plan đề xuất:

| Phase | Mục tiêu | Output |
|---|---|---|
| Phase 1 | Static service graph | map service -> config -> port -> module |
| Phase 2 | QEMU user smoke test | chạy từng binary với `--help` hoặc mode an toàn nếu có |
| Phase 3 | Website-only replay | nginx/Website hoặc Website + mock SCM/JupiCore |
| Phase 4 | Core services replay | MQTT + JupiCore + Website + SCM |
| Phase 5 | Protocol mocks | thêm OCPP backend, Modbus peer, OpenVPN mock |
| Phase 6 | Boot instrumentation | chạy init order trong môi trường kiểm soát hoặc thiết bị lab |
| Phase 7 | CVE candidate validation | test hypothesis có bằng chứng và không chạm hạ tầng thật |

Với firmware này, Phase 3 và Phase 4 có giá trị cao nhất cho research ban đầu vì advisory 2025 xoay quanh WBM/system configuration.

### Evidence

- [day9_charx_sec_3100_service_graph_call_chain_reconstruction.md](/d:/CHARXSEC/document/day9_charx_sec_3100_service_graph_call_chain_reconstruction.md) xác định WBM, SCM, JupiCore, MQTT là đường dữ liệu trung tâm.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) mô tả CVE-2025-41699 liên quan WBM account và system configuration.
- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json) có nhiều route config/import/update/network cần kiểm tra qua WBM.

## Câu hỏi 6

### Question

Lab network nên được thiết kế thế nào?

### Answer

Lab nên tách biệt hoàn toàn khỏi mạng thật:

| Segment | Vai trò |
|---|---|
| `lab-mgmt` | máy researcher, browser, proxy, packet capture |
| `device-emulated` | rootfs/service replay |
| `mock-backend` | OCPP backend, MQTT remote, Modbus peers |
| `vpn-test` | OpenVPN mock hoặc route test |
| `no-internet` default | tránh service gọi backend thật ngoài ý muốn |

Các rule nên có:

- không route trực tiếp ra Internet khi chạy firmware service
- DNS được kiểm soát hoặc sinkhole
- packet capture ở mọi segment
- mọi mock service log request/response
- test update chỉ dùng artifact offline
- không kết nối lab vào charging hardware thật

### Evidence

- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) khuyến nghị thiết bị dùng trong closed industrial networks và protected by suitable firewall.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả thiết bị có local/remote management qua Ethernet, USB-C/RNDIS, OCPP, OpenVPN, MQTT, Modbus.
- [charx-ocpp16-agent.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-ocpp16-agent.conf) có backend URL template.

## Câu hỏi 7

### Question

Quan sát trong emulation cần log những gì?

### Answer

Checklist observability:

| Loại dữ liệu | Cách dùng |
|---|---|
| process start/exit | xác định service nào chạy được |
| port bind | xác nhận endpoint thực |
| file open/write | biết config/log/data sink |
| HTTP request/response | map API call-chain |
| MQTT topic | hiểu bus nội bộ |
| OCPP messages | hiểu backend flow |
| Modbus request | hiểu runtime control |
| helper invocation | phát hiện command/file boundary |
| log files | đối chiếu với WBM download logs |
| packet capture | xác nhận network path |

Output của emulation không phải “service chạy được 100%”. Output đủ tốt là trả lời được câu hỏi: request nào đi qua route nào, gọi module nào, chạm file nào, service nào restart và log ở đâu.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `DOWNLOAD LOGS` và OCPP `GetDiagnostics`.
- Các config `/etc/charx/*.conf` chứa `LogFilePath` cho Website, JupiCore, OCPP, Modbus, Load Management, System Monitor, System Config Manager.
- [day10_charx_sec_3100_web_api_audit.md](/d:/CHARXSEC/document/day10_charx_sec_3100_web_api_audit.md) xác định endpoint domains cần quan sát.

## Câu hỏi 8

### Question

Nguồn dữ liệu công khai trên Internet có thể giúp tăng fidelity của emulation không?

### Answer

Có, nhưng chỉ ở mức scaffolding và checklist nếu chưa có runtime trace thật. Track mới `Public Data Acquisition` được thêm vào plan để tìm, phân loại và kiểm soát cách dùng các nguồn public.

Tính đến `2026-04-24`, các nguồn public hữu ích gồm ONEKEY workshop, RET2 writeups, NCC/44CON slides và manual mirror. Tuy nhiên, chưa có nguồn nào trong số này được coi là full runtime truth cho firmware V190. Vì vậy, chúng không được dùng để bịa `/data`, `/log`, `/identity`, certificate, UID, password, OCPP backend production data hoặc sequence runtime cụ thể.

Trong lab, mọi mock sinh ra từ nguồn public phải có provenance:

| Trường | Ý nghĩa |
|---|---|
| `source_url` | URL nguồn public hoặc local artifact |
| `source_type` | `public_reference`, `public_runtime_snippet`, `public_emulation_scaffold`, hoặc `not_behavior_truth` |
| `evidence_tier` | `Tier 0` đến `Tier 4` |
| `confidence` | `high`, `medium`, `low` |
| `version_applicability` | nguồn có khớp V190 hay không |
| `behavior_claim_allowed` | có được dùng làm claim behavior không |

Quy tắc quan trọng: chỉ `Tier 0` và `Tier 1` được dùng làm behavior truth. `Tier 2` và `Tier 3` có thể giúp dựng lab tốt hơn, nhưng không làm tăng fidelity score nếu không có runtime evidence.

### Evidence

- [charx_sec_3100_public_data_acquisition.md](/d:/CHARXSEC/document/charx_sec_3100_public_data_acquisition.md) ghi track Public Data Acquisition.
- [sources.jsonl](/d:/CHARXSEC/emulation/charx_v190/public-data-ledger/sources.jsonl) lưu ledger nguồn public đã kiểm tra.
- [TRUST_TIERS.md](/d:/CHARXSEC/emulation/charx_v190/evidence/TRUST_TIERS.md) định nghĩa Tier 0 đến Tier 4.
- [ACCURACY_GATES.md](/d:/CHARXSEC/emulation/charx_v190/evidence/ACCURACY_GATES.md) định nghĩa gate kiểm tra nguồn public, mock provenance và accuracy claim.
- [mock_generation_policy.md](/d:/CHARXSEC/emulation/charx_v190/policies/mock_generation_policy.md) định nghĩa policy không bịa mock behavior.
- [mock_provenance_schema.json](/d:/CHARXSEC/emulation/charx_v190/provenance/mock_provenance_schema.json) định nghĩa schema provenance cho mock/fixture.

## Kết luận Ngày 11

Day 11 chốt emulation plan:

- bắt đầu từ static analysis và service graph
- dùng QEMU user/chroot cho binary ARM khi cần
- ưu tiên Website + SCM + JupiCore + MQTT trước
- mock OCPP backend, Modbus peers, OpenVPN và hardware dependencies theo từng mục tiêu
- thêm track `Public Data Acquisition` để tận dụng nguồn public mà không nhầm với runtime truth
- tách lab khỏi mạng thật
- ghi log request, port, file access, MQTT/OCPP/Modbus traffic và service lifecycle

Day 12 sẽ dùng plan này để thiết kế boot/startup instrumentation và xác định race-window cần kiểm tra.
