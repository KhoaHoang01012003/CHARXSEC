# CHARX SEC-3100 V190 - Điều tra lỗi WBM OCPP, Load Management, Charging Stations và Modbus

Ngày thực hiện: 2026-04-24

Run evidence: `wbm-roles-20260424T150221Z`

## 1. Kết luận ngắn

Hiện tượng trong WBM được xác nhận:

- OCPP ban đầu trả `500` vì `CharxOcpp16Agent` chưa chạy/bind REST `2106`.
- Load Management ban đầu trả `500` vì `CharxControllerLoadmanagement` chưa chạy/bind REST `1603`.
- Modbus Client ban đầu trả `500` vì `CharxModbusAgent` chưa chạy/bind REST `9502`.
- Charging Stations không lỗi `500`, nhưng trả dữ liệu rỗng vì `JupiCore` không có charging point/controller nào trong runtime DB.

Sau khi start thêm service phụ:

- Load Management chuyển từ `500` sang `200`.
- Modbus Client chuyển từ `500` sang `200`.
- OCPP chuyển từ `500` sang `200` sau khi `CharxOcpp16Agent` hoàn tất khởi tạo DB và bind REST `2106`.
- Charging Stations vẫn rỗng vì thiếu topology thật từ ControllerAgent/hardware.

Không có dữ liệu nào được bịa để lấp topology. Các dữ liệu rỗng hiện tại là runtime truth của lab state.

## 2. API mà frontend WBM gọi

Từ frontend bundle `usr/lib/charx-website/dist/js/app.00387b72.js`, các module liên quan gọi các endpoint chính:

| Module WBM | Endpoint |
| --- | --- |
| Charging Stations | `/api/v1.0/charging-points`, `/api/v1.0/charging-controllers`, `/api/v1.0/coupled-clients` |
| OCPP Config/Status | `/api/v1.0/ocpp16/config/info`, `/api/v1.0/ocpp16/config/section-info`, `/api/v1.0/ocpp16/config/configuration-list`, `/api/v1.0/ocpp16/config/security-profiles` |
| OCPP Diagnostics | `/api/v1.0/ocpp16/diagnostic/chargingpoint-overview`, `/api/v1.0/ocpp16/diagnostic/ocpp-telegram-protocol` |
| Load Management | `/api/v1.0/loadmanagement/load_circuits` |
| Modbus Client | `/api/v1.0/modbus-client/devices` |

`routePermissions.json` xác nhận các endpoint này tồn tại trong permission model của firmware, ví dụ:

- `/api/[^/]*/charging-points`
- `/api/[^/]*/charging-controllers`
- `/api/[^/]*/ocpp16/config/*`
- `/api/[^/]*/ocpp16/diagnostic/*`
- `/api/[^/]*/loadmanagement/load_circuits`
- `/api/[^/]*/modbus-client/devices`

## 3. Baseline trước khi start service phụ

Ở baseline, WBM core đã chạy nhưng service phụ chưa chạy:

| Endpoint | Kết quả baseline |
| --- | --- |
| `/api/v1.0/charging-points` | `200`, body `{"charging_points":{}}` |
| `/api/v1.0/charging-controllers` | `200`, body `{}` |
| `/api/v1.0/ocpp16/config/info` | `500` |
| `/api/v1.0/ocpp16/config/section-info?section-name=AppSettings` | `500` |
| `/api/v1.0/ocpp16/config/configuration-list` | `500` |
| `/api/v1.0/ocpp16/config/security-profiles` | `500` |
| `/api/v1.0/ocpp16/diagnostic/chargingpoint-overview` | `500` |
| `/api/v1.0/ocpp16/diagnostic/ocpp-telegram-protocol` | `500` |
| `/api/v1.0/loadmanagement/load_circuits` | `500` |
| `/api/v1.0/modbus-client/devices` | `500` |

Port snapshot baseline chỉ có:

- `CharxWebsite`: `5000`
- `CharxJupiCore`: `5555`
- `mosquitto`: `1883`
- `nginx`: `80/81/443`

Nhãn nguyên nhân baseline:

- OCPP: `service_unavailable`
- Load Management: `service_unavailable`
- Modbus Client: `service_unavailable`
- Charging Stations: `missing_runtime_topology`, không phải service-down

## 4. Sau khi start service phụ

Đã start thêm:

- `charx-ocpp16-agent`
- `charx-modbus-server`
- `charx-modbus-agent`
- `charx-loadmanagement`
- `charx-controller-agent`

Port/process quan sát được:

| Port | Process | Ý nghĩa |
| --- | --- | --- |
| `2106` | `CharxOcpp16Agent` | OCPP REST API |
| `1603` | `CharxControllerLoadmanagement` | Load Management REST API |
| `9555` | `CharxModbusServer` | Modbus Server API |
| `9502` | `CharxModbusAgent` | Modbus Client/Agent API |
| `4444` | `CharxControllerAgent` | ControllerAgent TCP service |

Kết quả API sau khi service sẵn sàng:

| Endpoint | Kết quả sau start |
| --- | --- |
| `/api/v1.0/ocpp16/config/info` | `200`, trả OCPP app/config |
| `/api/v1.0/ocpp16/config/section-info?section-name=AppSettings` | `200` |
| `/api/v1.0/ocpp16/config/configuration-list?list_name=custom` | `200` |
| `/api/v1.0/ocpp16/config/security-profiles` | `200`, secret được mask |
| `/api/v1.0/ocpp16/diagnostic/chargingpoint-overview` | `200`, body `{"status_ocpp_chargepoints":[]}` |
| `/api/v1.0/ocpp16/diagnostic/ocpp-telegram-protocol` | `200`, body `{"message_log":[]}` |
| `/api/v1.0/loadmanagement/load_circuits` | `200`, trả default load circuit rỗng charging point |
| `/api/v1.0/modbus-client/devices` | `200`, body `{}` |
| `/api/v1.0/charging-points` | `200`, body `{"charging_points":{}}` |
| `/api/v1.0/charging-controllers` | `200`, body `{}` |

## 5. Root cause theo từng module

### 5.1. OCPP

Nguyên nhân `500` ban đầu:

- `CharxOcpp16Agent` chưa chạy/bind `2106`.
- WBM proxy tới `/api/v1.0/ocpp16/...` không có backend để forward.

Sau khi start service:

- OCPP DB được tạo tại `/data/charx-ocpp16-agent/ocpp16.db`.
- `table_configuration` có 93 row.
- REST API bind `0.0.0.0:2106`.
- API config trả `200`.

Giới hạn còn lại:

- OCPP diagnostics rỗng vì không có connector list từ JupiCore.
- Log OCPP lặp lại lỗi:

```text
Error at creating ocpp status collection. need more than 0 values to unpack
Read connector list from JupiCore. Count of retries: ...
```

Điều này không nên sửa bằng cách bịa connector. Muốn OCPP có charging point status thật, cần JupiCore có charging point/controller topology thật hoặc một topology fixture có provenance rõ.

### 5.2. Load Management

Nguyên nhân `500` ban đầu:

- `CharxControllerLoadmanagement` chưa chạy/bind `1603`.

Sau khi start service:

- API `/api/v1.0/loadmanagement/load_circuits` trả `200`.
- Service tự tạo config runtime từ default:
  - `/data/charx-loadmanagement-agent/charx-loadmanagement-agent.conf`
  - `/data/charx-loadmanagement-agent/charx-loadmanagement-load-circuit.conf`
  - `/data/charx-loadmanagement-agent/load-circuit-measure-device.json`
- Body trả default load circuit `LoadCircuit_1`, nhưng `charging_points` rỗng.

Nguyên nhân dữ liệu rỗng:

- Firmware default có `load-circuit-measure-device.json` với `charging_points: []`.
- Không có charging point từ JupiCore để Load Management gán vào circuit.

### 5.3. Modbus Client

Nguyên nhân `500` ban đầu:

- `CharxModbusAgent` chưa chạy/bind `9502`.

Sau khi start service:

- API `/api/v1.0/modbus-client/devices` trả `200`.
- Body `{}`.
- Log ghi: `Reading devices from device-config folder.`

Nguyên nhân dữ liệu rỗng:

- Config firmware chỉ ra device folder: `/data/charx-modbus-agent/devices/`.
- Folder tồn tại nhưng rỗng.
- Không có runtime device fixture thật từ thiết bị/lab.

Không nên tự tạo meter/device config nếu mục tiêu là fidelity thật. Có thể tạo fixture synthetic để test UI/API, nhưng phải gắn nhãn `mocked_behavior` hoặc `synthetic_fixture`.

### 5.4. Charging Stations

Nguyên nhân không có dữ liệu:

- `JupiCore` runtime DB `/data/charx-jupicore/jupicore.db` có bảng `charging-points`, nhưng hiện `0` row.
- API `/api/v1.0/charging-points` trả `{"charging_points":{}}`.
- API `/api/v1.0/charging-controllers` trả `{}`.
- `ControllerAgent` có thể start và bind `4444`, nhưng log cho thấy thiếu hardware/network interfaces:

```text
RemoteDeviceNetworkManager: Invalid interface name [name=eth1]
SeccCommunicationManager: Failed to load TPM provider
CANopenNetwork: Network interface not available [name=can0,error=No such device]
DeviceManager: Network[name=can0] initialization failed
```

Vì thiếu `can0`, `eth1`, `eth2`, TPM/cert/hardware bus, ControllerAgent không phát hiện/generate controller topology thật cho JupiCore.

## 6. Dữ liệu có sẵn trong firmware

### 6.1. Có sẵn

Firmware/rootfs có:

- Service binaries:
  - `CharxOcpp16Agent`
  - `CharxModbusAgent`
  - `CharxModbusServer`
  - `CharxControllerLoadmanagement`
  - `CharxControllerAgent`
  - `CharxJupiCore`
- Config default:
  - `/etc/charx/charx-ocpp16-agent.conf`
  - `/etc/charx/charx-loadmanagement-agent.conf`
  - `/etc/charx/charx-loadmanagement-load-circuite.conf`
  - `/etc/charx/load-circuit-measure-device.json`
  - `/etc/charx/charx-modbus-agent.conf`
  - `/etc/charx/charx-modbus-server.conf`
  - `/etc/charx/charx-controller-agent.conf`
- OCPP JSON schemas under `/usr/lib/charx-ocpp16-agent/schemas/`.
- DB schema runtime được service tự tạo:
  - `/data/charx-jupicore/jupicore.db`
  - `/data/charx-ocpp16-agent/ocpp16.db`

### 6.2. Không có sẵn trong firmware bundle

Chưa thấy trong firmware/rootfs:

- Runtime charging park configuration thật.
- Charging point configured row trong `jupicore.db`.
- Controller topology thật từ CAN/backplane/device network.
- Modbus meter config thật trong `/data/charx-modbus-agent/devices/`.
- OCPP message log thật trong `table_ocpp_messages`.
- OCPP backend trace thật.
- `/identity` production certificate/UID/private key.
- TPM-backed SECC material thật.

## 7. Nguồn Internet kiểm tra

### 7.1. Nguồn public hữu ích

- Phoenix Contact product page xác nhận CHARX SEC-3100 hỗ trợ OCPP 1.6J, Modbus/TCP, MQTT, HTTP/HTTPS, Ethernet, USB-C/RNDIS và energy meter/RFID/DC residual current detection.
- Phoenix Contact help/manual mô tả Charging Stations, OCPP log/diagnostics, Load Management, Modbus Client/Server và vai trò của JupiCore.
- ONEKEY BHEU23 firmware workshop hữu ích cho extraction/emulation workflow, QEMU/network/CAN setup và một số boot/service scaffolding.

### 7.2. Không tìm thấy runtime truth công khai

Tính đến lúc kiểm tra, chưa thấy nguồn public đáng tin cậy chứa:

- Full `/data`, `/log`, `/identity` dump của CHARX SEC-3100 V190.
- `jupicore.db` production/lab có charging point thật.
- `ocpp16.db` production/lab có OCPP telegram/message log thật.
- `/data/charx-modbus-agent/devices/` thật.
- Diagnostics archive thật có thể gắn version/model.
- OCPP/MQTT/Modbus packet trace đầy đủ gắn với CHARX SEC-3100 V190.

Vì vậy, Internet hiện chỉ nên dùng ở mức `public_reference` hoặc `public_emulation_scaffold`, không phải behavior truth.

Nguồn đã đối chiếu:

- Phoenix Contact product page: https://www.phoenixcontact.com/en-us/products/ac-charging-controller-charx-sec-3100-1139012
- Phoenix Contact help: https://www.phoenixcontact.com/charx-help/ctrl/ac/um/Section05/Sec_5_en.htm
- ONEKEY workshop: https://github.com/onekey-sec/BHEU23-firmware-workshop

## 8. Plan khắc phục theo fidelity

### Phase A - Khắc phục ngay lỗi 500 service-down

Mục tiêu: WBM không còn `500` do service chưa chạy.

Hành động:

1. Start fresh session với service list đầy đủ:

```bash
sudo /home/khoa/charx_labs/charx_v190/scripts/start_fresh_wbm_roles_session.sh \
  wbm-full-$(date -u +%Y%m%dT%H%M%SZ) \
  mosquitto \
  charx-system-config-manager \
  charx-website \
  nginx \
  charx-jupicore \
  charx-controller-agent \
  charx-ocpp16-agent \
  charx-modbus-server \
  charx-modbus-agent \
  charx-loadmanagement
```

2. Đợi `CharxOcpp16Agent` bind `2106` trước khi kết luận OCPP status.
3. Probe lại:
   - OCPP config/diagnostics.
   - Load Management load circuits.
   - Modbus Client devices.
   - Charging points/controllers.
4. Ghi mọi kết quả vào `evidence/<run_id>/probes/`.

Kết quả kỳ vọng:

- OCPP config trả `200`.
- Load Management trả `200`.
- Modbus Client trả `200`.
- Charging Stations có thể vẫn rỗng.

### Phase B - Không bịa, nhưng làm rõ empty state

Mục tiêu: WBM hiển thị đúng empty/default runtime state thay vì lỗi.

Hành động:

1. Lưu schema/count của `jupicore.db`.
2. Lưu schema/count của `ocpp16.db`.
3. Lưu listing `/data/charx-modbus-agent/devices/`.
4. Lưu listing `/data/charx-loadmanagement-agent/`.
5. Gắn nhãn:
   - `observed_runtime_empty_topology`
   - `observed_runtime_empty_modbus_devices`
   - `observed_runtime_default_load_circuit`
   - `observed_runtime_empty_ocpp_message_log`

Kết quả kỳ vọng:

- Ta có thể nói chính xác: “module không có dữ liệu vì runtime DB/folder rỗng”, không phải vì WBM/frontend hỏng.

### Phase C - Dựng topology fixture có provenance

Mục tiêu: giúp UI/flow tiến xa hơn, nhưng không claim hardware truth.

Chỉ làm nếu chấp nhận nhãn `synthetic_fixture`.

Hướng an toàn:

1. Dùng API firmware `POST /api/v1.0/charging-points` nếu có thể tạo charging point qua JupiCore, thay vì insert DB trực tiếp.
2. Nếu API yêu cầu controller UID thật, không bịa UID production.
3. Có thể tạo một fixture tối thiểu với nhãn:
   - `source_type=local_synthetic_fixture`
   - `evidence_tier=Tier 4`
   - `behavior_claim_allowed=false`
4. Sau mỗi fixture, export DB diff và API transcript.

Không được:

- Gán fixture là topology thật của CHARX SEC-3100.
- Tạo certificate/UID/password production.
- Dùng mock để claim charging state machine thật.

### Phase D - Hardware/network emulation sâu hơn

Mục tiêu: giảm lỗi ControllerAgent mà không sửa binary.

Hành động:

1. Tạo network interfaces lab có nhãn:
   - `can0` hoặc `vcan0` mapped nếu kernel hỗ trợ.
   - `eth1` synthetic veth.
   - `eth2` synthetic veth.
2. Chạy ControllerAgent lại và ghi log.
3. Nếu ControllerAgent tự tạo controller topology sau khi có interface, đó là `observed_runtime_under_synthetic_interfaces`, không phải hardware truth.
4. Không fake SECC certificate/TPM provider nếu không có material thật.

### Phase E - Nâng fidelity bằng dữ liệu thật

Để emulate chính xác hơn, cần lấy từ thiết bị lab hợp pháp:

- `/data/charx-jupicore/jupicore.db`
- `/data/charx-ocpp16-agent/ocpp16.db`
- `/data/charx-modbus-agent/devices/`
- `/data/charx-loadmanagement-agent/`
- `/log/*`
- `/identity/*` sau khi sanitize secret phù hợp
- `ip addr`, `ip route`, firewall rules
- `ps`, port snapshot
- OCPP/MQTT/Modbus packet capture
- ControllerAgent logs/CAN traces

Chỉ khi có các dữ liệu này mới nên nâng claim fidelity cho Charging Stations/OCPP diagnostics/Modbus/Load Management.

## 9. Evidence local

Evidence chính:

- `emulation/charx_v190/evidence/wbm-roles-20260424T150221Z/probes/module_api_baseline_before_extra_services.jsonl`
- `emulation/charx_v190/evidence/wbm-roles-20260424T150221Z/probes/module_debug_ports_processes_after_start.txt`
- `emulation/charx_v190/evidence/wbm-roles-20260424T150221Z/probes/module_api_after_extra_services.jsonl`
- `emulation/charx_v190/evidence/wbm-roles-20260424T150221Z/probes/module_api_after_ocpp_rest_ready.jsonl`
- `emulation/charx_v190/evidence/wbm-roles-20260424T150221Z/probes/module_api_after_controller_agent_start.jsonl`
- `emulation/charx_v190/evidence/wbm-roles-20260424T150221Z/logs/charx-ocpp16-agent.module_debug.start.log`
- `emulation/charx_v190/evidence/wbm-roles-20260424T150221Z/logs/charx-modbus-agent.module_debug.start.log`
- `emulation/charx_v190/evidence/wbm-roles-20260424T150221Z/logs/charx-modbus-server.module_debug.start.log`
- `emulation/charx_v190/evidence/wbm-roles-20260424T150221Z/logs/charx-loadmanagement.module_debug.start.log`
- `emulation/charx_v190/evidence/wbm-roles-20260424T150221Z/logs/charx-controller-agent.module_debug.start.log`

