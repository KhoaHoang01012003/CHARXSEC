# CHARX SEC-3100 V190 - Service Status và Next Steps Emulation

Ngày kiểm tra: `2026-04-24`

Tài liệu này tổng hợp trạng thái service replay hiện tại của firmware CHARX SEC-3100 V190, đặc biệt là WBM. Kết luận chỉ dựa trên artifact local V190, scripts lab, và runtime evidence đã capture trong WSL. Không dùng dữ liệu public để bịa behavior.

## Evidence chính

Run WBM core:

- [20260424T094800Z service status](/d:/CHARXSEC/emulation/charx_v190/evidence/20260424T094800Z/probes/wbm_probe_services.jsonl)
- [20260424T094800Z port snapshots](/d:/CHARXSEC/emulation/charx_v190/evidence/20260424T094800Z/probes/wbm_probe_ports.txt)
- [20260424T094800Z HTTP probes](/d:/CHARXSEC/emulation/charx_v190/evidence/20260424T094800Z/probes/wbm_http_probes.jsonl)

Run mở rộng:

- [20260424T095100Z service status](/d:/CHARXSEC/emulation/charx_v190/evidence/20260424T095100Z/probes/wbm_probe_services.jsonl)
- [20260424T095100Z port snapshots](/d:/CHARXSEC/emulation/charx_v190/evidence/20260424T095100Z/probes/wbm_probe_ports.txt)
- [20260424T095100Z HTTP probes](/d:/CHARXSEC/emulation/charx_v190/evidence/20260424T095100Z/probes/wbm_http_probes.jsonl)
- [20260424T095100Z processes](/d:/CHARXSEC/emulation/charx_v190/evidence/20260424T095100Z/probes/wbm_probe_processes.txt)

Scripts:

- [run_wbm_probe.sh](/d:/CHARXSEC/emulation/charx_v190/scripts/run_wbm_probe.sh)
- [run_isolated_smoke.sh](/d:/CHARXSEC/emulation/charx_v190/scripts/run_isolated_smoke.sh)

## Deviation đã dùng trong WBM probe

Các deviation dưới đây là lab scaffolding, không phải production truth:

| Deviation | Lý do | Nhãn đúng |
|---|---|---|
| UTS hostname `ev3000` | `manifest.raucm` và RAUC system config ghi `compatible=ev3000`; mosquitto template có `ev3000` | `inferred_from_config` |
| Synthetic `/etc/machine-id` | init script mosquitto cần machine-id để sinh config | `mocked_behavior` / `synthetic_lab_identity` |
| Tạo `/run/nginx`, `/var/log/nginx` | service replay không chạy full SysV boot/syslog trước đó | `modified-runtime behavior` |
| Tạo `/data/user-app/website` | nginx có virtual host port `81` trỏ vào path này | `modified-runtime behavior` |
| Self-signed cert trong `/data/.ssl` | nginx init script tự sinh nếu cert/key chưa tồn tại | `observed_runtime`, nhưng không phải production cert |

## WBM hiện chạy được đến đâu?

WBM hiện đã chạy được ở mức frontend + backend process + core local services.

| Thành phần WBM | Evidence | Kết luận |
|---|---|---|
| `nginx` HTTP `80` | HTTP root trả `301` sang HTTPS | chạy được |
| `nginx` HTTPS `443` | HTTPS root trả `200` và HTML app `Phoenix Contact - CHARX` | WBM frontend static chạy được |
| custom website port `81` | `nginx` bind `0.0.0.0:81` | port chạy, chưa kiểm nội dung vì `/data/user-app/website` synthetic/empty |
| `CharxWebsite` REST `5000` | bind `0.0.0.0:5000` | backend process chạy |
| `CharxWebsite` WebSocket `4999` | bind `0.0.0.0:4999` | websocket server chạy |
| `CharxSystemConfigManager` `5001/5002` | bind `0.0.0.0:5001`, `0.0.0.0:5002` | SCM chạy |
| `CharxJupiCore` `5555` | bind `0.0.0.0:5555` | JupiCore REST chạy |
| MQTT broker `1883` | `mosquitto` bind `0.0.0.0:1883`; nhiều CHARX clients connect thành công | MQTT local chạy |

HTTP probe:

| Probe | Kết quả |
|---|---|
| `http://127.0.0.1/` | `301 Moved Permanently` sang HTTPS |
| `https://127.0.0.1/` | `200 OK`, trả WBM HTML app |
| `http://127.0.0.1:5000/` | `404`, nhưng chứng minh backend HTTP server sống |
| `http://127.0.0.1:5000/api/v1.0/web/test-auth-no-login` | `404` JSON `unknown prefix 'web'`; không coi là endpoint test thành công |
| `http://127.0.0.1:5001/` | `404`, nhưng chứng minh SCM HTTP server sống |
| `http://127.0.0.1:5555/` | `404`, nhưng chứng minh JupiCore HTTP server sống |

Kết luận WBM: có thể mở được frontend WBM qua HTTPS trong lab và backend Website đã bind. Tuy nhiên chưa claim “WBM full behavior” vì chưa có login/session hợp lệ, chưa test đầy đủ route thực tế, và một số helper gọi `sudo`/OpenVPN còn lỗi do môi trường service replay.

## Service matrix hiện tại

| Service | Start status | Port quan sát được | Mức khả dụng hiện tại |
|---|---:|---|---|
| `mosquitto` | `0` | `1883` | chạy được khi hostname `ev3000` + synthetic machine-id |
| `charx-system-config-manager` | `0` | `5001`, `5002` | chạy tốt cho config/API smoke |
| `charx-website` | `0` | `5000`, `4999` | chạy được WBM backend và websocket |
| `nginx` | `0` | `80`, `443`, `81` | chạy được WBM frontend |
| `charx-jupicore` | `0` | `5555` | chạy được REST, nhưng không có ControllerAgent/charging points |
| `charx-ocpp16-agent` | `0` | chưa thấy `2106` trong snapshot | process chạy, nhưng OCPP chưa operational vì JupiCore không có connector list |
| `charx-modbus-server` | `0` | `9555`; chưa thấy `502` | API chạy, Modbus TCP port `502` chưa xác nhận |
| `charx-modbus-agent` | `0` | `9502` | REST chạy, device config folder trống |
| `charx-loadmanagement` | `0` | `1603` | REST chạy, load circuit synthetic/default, không có charging point thật |
| `charx-system-monitor` | `0` | không có REST port public trong config | process chạy, báo lỗi thiếu modem/QCA/interface thật |
| `charx-update-agent` | `0` | chưa xác nhận port do config host `192.168.4.1` | process chạy, tạo key/cert lab, không test install/update |

## Những gì còn thiếu để service behavior đúng hơn

| Nhóm thiếu | Ảnh hưởng | Cách bổ sung không bịa hành vi |
|---|---|---|
| Runtime `/data`, `/log`, `/identity` thật | DB, cert, user/session, device identity, OCPP IDs có thể khác thiết bị thật | chỉ lấy từ thiết bị lab hợp pháp; hiện dùng synthetic volumes |
| ControllerAgent hoạt động | JupiCore không có charging point/controller topology; OCPP không có connector list | cần mock ControllerAgent có provenance hoặc hardware/CAN/QCA/SECC trace thật |
| CAN/QCA/HomePlug/SECC | charging state machine không chính xác | cần hardware-in-the-loop hoặc trace thật; không bịa CP/PP state |
| Modem device `/dev/ttyMODEM2`, `/dev/cdc-wdm0` | System Monitor báo modem unavailable | có thể tạo device stub để giảm lỗi, nhưng không claim modem behavior |
| Network interfaces `eth0`, `eth1`, `eth2`, `br0`, `ppp0` | System Monitor/Modbus/JupiCore có lỗi topology/network | tạo namespace/interface synthetic có nhãn; tốt hơn là capture `ip addr` từ thiết bị thật |
| OCPP backend thật hoặc trace | không validate được BootNotification/Heartbeat/GetDiagnostics/FirmwareUpdate behavior | dùng mock OCPP 1.6J tối thiểu có transcript; không claim production backend |
| Modbus meter/device config | Modbus Agent/Server chạy nhưng dữ liệu meter không thật | dùng fixture devices với provenance hoặc meter trace thật |
| OpenVPN runtime/certs | Website OpenVPN manager gọi helper/sudo lỗi trong service replay | mock OpenVPN test peer hoặc chạy privileged container; không dùng cert production |
| RAUC slot/boot env thật | QEMU system boot chưa có bootargs xác thực | trích barebox env/bootargs hoặc lấy từ device lab |

## Phương án tiếp theo

### Phase A - Củng cố WBM/API lab

Mục tiêu: biến WBM thành target nghiên cứu ổn định.

- Chuẩn hóa `run_wbm_probe.sh` thành entrypoint chính cho WBM.
- Ghi machine-id synthetic và hostname `ev3000` vào `deviations.md` mỗi run.
- Thêm probe đúng route thực tế từ frontend/API catalog thay vì endpoint test giả.
- Thêm login/session test nếu có credential lab hợp lệ hoặc default test user từ tài liệu chính gốc. Nếu không có, chỉ test guest/no-auth route.
- Export thêm HTTP request/response summary cho `/`, `/api`, `/ws`.

### Phase B - Mock ControllerAgent tối thiểu, có provenance

Mục tiêu: giúp JupiCore/OCPP có connector topology tối thiểu mà không giả là hardware thật.

- Reverse giao tiếp JupiCore -> ControllerAgent tại `127.0.0.1:4444` từ binary/config/log.
- Chỉ mock những response đã quan sát từ code/static strings hoặc trace thật.
- Nếu chưa có trace, mock phải ghi `source_type=manual_test_stub`, `behavior_claim_allowed=false`.
- Kết quả mong đợi: JupiCore có charging point/controller list synthetic; OCPP có thể tiến xa hơn và bind REST `2106`.

### Phase C - Protocol service lab

Mục tiêu: chạy OCPP/Modbus/Load Management có kiểm soát.

- OCPP: dựng backend WebSocket mock `wss/ws` local, log BootNotification/Heartbeat nếu agent kết nối được.
- Modbus: tạo device config fixture trong `/data/charx-modbus-agent/devices/` với provenance; kiểm lại `502` và `9555`.
- Load Management: dùng topology synthetic từ Phase B để xem rule/circuit behavior, nhưng không claim charging current thật.
- System Monitor: tạo synthetic interfaces `eth0/eth1/eth2/br0/ppp0` trong namespace nếu kernel cho phép; không fake modem/QCA status là thật.

### Phase D - Giảm khác biệt môi trường service replay

Mục tiêu: giảm lỗi không liên quan firmware.

- Chạy lab trong privileged Linux VM/container thay vì WSL nếu cần named namespace persistent, suid/sudo behavior đúng hơn, và low port/capability ổn định hơn.
- Tách volumes per-run thay vì dùng global `data.img/log.img/identity.img` để tránh state lẫn giữa runs.
- Mount run rootfs không `nosuid` nếu muốn quan sát helper `sudo` sát hơn, nhưng vẫn không chạy lệnh nguy hiểm ra host.

### Phase E - Nâng fidelity bằng dữ liệu thật

Mục tiêu: nâng từ service replay lên gần behavior thiết bị.

- Khi có thiết bị lab: dump `/data`, `/log`, `/identity`; capture `ps`, `ip addr`, `ip route`, firewall rules, service logs.
- Capture MQTT topics, OCPP messages, Modbus traffic, OpenVPN route/cert lifecycle.
- Chỉ sau đó mới nâng fidelity claim cho ControllerAgent/OCPP/Modbus/Load Management.

## Kết luận

Hiện tại lab đã chạy được phần WBM ở mức đáng dùng cho nghiên cứu Web/API:

- WBM HTTPS frontend chạy.
- Website backend chạy.
- SCM chạy.
- MQTT/JupiCore chạy.
- Nhiều service phụ như Modbus Agent/Server, Load Management, System Monitor, Update Agent start được.

Nhưng phần charging behavior, ControllerAgent, connector topology, OCPP operational flow, Modbus meter data và hardware interfaces vẫn chưa đủ ground truth. Bước tiếp theo đúng nhất là dựng mock ControllerAgent/connector topology có provenance, đồng thời tiếp tục tách rõ mọi synthetic state khỏi behavior thật của thiết bị.

