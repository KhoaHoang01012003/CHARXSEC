# CHARX SEC-3100 V190 - Ghi Chú Truy Cập WBM Trong Lab

Ngày cập nhật: `2026-04-24`

## Câu hỏi

Vì sao tài liệu Day 2 nói WBM dùng để đăng nhập, xem dashboard, cấu hình charging park/network/modem, tải log, chuyển module mode và software update, nhưng kết quả emulation trước đó chỉ nói thấy title app?

## Trả lời

Hai ý này không mâu thuẫn, nhưng chúng đang ở hai mức bằng chứng khác nhau:

- Tài liệu Day 2 mô tả **vai trò WBM theo tài liệu chính gốc của vendor**.
- Kết quả probe emulation chỉ chứng minh được **mức đã quan sát trong lab**.

Khi probe trả `200 OK` và HTML có title `Phoenix Contact - CHARX`, điều đó chỉ chứng minh:

- nginx đã serve được WBM frontend,
- static web app đã load được shell ban đầu,
- backend service liên quan như `charx-website`, `charx-system-config-manager`, `charx-jupicore`, `mosquitto` có thể start và bind port.

Điều đó **chưa chứng minh** các chức năng sau đã hoạt động đầy đủ:

- đăng nhập thành công,
- dashboard có dữ liệu thật,
- cấu hình charging park hoạt động đúng với controller thật,
- cấu hình network/modem phản ánh hardware thật,
- tải log production thật,
- chuyển client/server mode đúng như thiết bị thật,
- software update end-to-end.

Các chức năng đó cần thêm session/auth hợp lệ, dữ liệu runtime trong `/data`, `/log`, `/identity`, topology từ ControllerAgent, hardware/network interfaces thật hoặc mock có provenance rõ ràng.

## Trạng thái truy cập hiện tại

Một WBM interactive session đã được khởi chạy trong WSL lab.

URL thử từ Windows:

```text
https://localhost/
```

Nếu `localhost` không forward đúng qua WSL, thử WSL IP hiện tại:

```text
https://172.21.12.48/
```

Trình duyệt sẽ cảnh báo certificate vì lab dùng self-signed cert được tạo trong runtime synthetic `/data/.ssl`. Đây không phải production certificate.

## Evidence hiện tại

Từ WSL:

```text
curl -k -I https://127.0.0.1/
HTTP/2 200
server: nginx/1.24.0
content-type: text/html
```

Từ Windows:

```text
curl.exe -k -I https://localhost/
HTTP/1.1 200 OK
Server: nginx/1.24.0
Content-Type: text/html
```

Các port đã thấy bind trong session:

```text
80    nginx HTTP
443   nginx HTTPS
1883  mosquitto
4999  CharxWebsite WebSocket
5000  CharxWebsite REST/backend
5001  CharxSystemConfigManager
5002  CharxSystemConfigManager
5555  CharxJupiCore
```

## Cách start/stop WBM session

Script start session:

```bash
/home/khoa/charx_labs/charx_v190/scripts/start_wbm_session.sh <run_id>
```

Script stop session:

```bash
/home/khoa/charx_labs/charx_v190/scripts/stop_wbm_session.sh <run_id>
```

Các script tương ứng trong workspace:

- `emulation/charx_v190/scripts/start_wbm_session.sh`
- `emulation/charx_v190/scripts/stop_wbm_session.sh`

## Ghi chú fidelity

Session này dùng shared network để browser Windows truy cập được WBM. Vì vậy đây là chế độ interactive lab, không phải chế độ network-isolated fidelity claim.

Không được dùng việc frontend load thành công để kết luận rằng toàn bộ WBM behavior đã đúng với thiết bị thật. Mọi chức năng sâu hơn phải được probe riêng và gắn nhãn evidence:

- `observed_runtime` nếu quan sát trực tiếp trong lab,
- `inferred_from_config` nếu suy ra từ config/rootfs,
- `mocked_behavior` nếu cần mock,
- `unknown` nếu chưa có bằng chứng.

