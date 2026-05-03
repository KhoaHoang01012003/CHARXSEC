# CHARX SEC-3100 V190 - Báo cáo triển khai WBM Login, RBAC và hướng emulate tiếp theo

Ngày thực hiện: 2026-04-24

Run evidence chính: `wbm-roles-20260424T150221Z`

## 1. Kết luận ngắn

Đã dựng được một phiên WBM fresh từ `rootfs_ro` với `/data`, `/log`, `/identity` sạch theo từng run, không kế thừa state của run cũ `test-one`, không seed password thủ công vào `website.db`, và không sửa `routePermissions.json`.

Kết quả hiện tại:

- WBM frontend truy cập được tại `https://localhost/`.
- Guest/no-token truy cập được một số endpoint read-only như `system-name`, `date-time`, `retained-data`.
- `manufacturer/manufacturer` đăng nhập được trên fresh run bằng default credential có sẵn trong firmware DB, nhưng firmware đánh dấu `passwordChanged=false` và yêu cầu đổi mật khẩu trước khi gọi các API quản trị.
- `user/user` và `operator/operator` ban đầu bị từ chối với `403 User not activated`, khớp với cấu hình gốc `[ActiveLogins] active = manufacturer`.
- Sau khi đăng nhập manufacturer và đổi mật khẩu theo luồng firmware, dùng API `/api/v1.0/web/users-active` để bật `user` và `operator`.
- Sau activation, cả 3 role `user`, `operator`, `manufacturer` đều login thành công và nhận JWT role tương ứng.
- Token thật không được ghi vào tài liệu; evidence chỉ lưu SHA256 của token.

Điểm quan trọng: các password lab sau activation không phải default credential của sản phẩm. Đây là runtime state do chính API firmware tạo trong lab để vượt qua chính sách password/change-password của firmware.

## 2. Phạm vi đã triển khai

### 2.1. Workflow fresh WBM roles session

Đã bổ sung workflow tạo run mới cho WBM/RBAC:

- Stop session WBM cũ nếu còn state.
- Tạo run mới từ `rootfs_ro`.
- Mount fresh per-run `/data`, `/log`, `/identity`.
- Chỉ tạo placeholder `/identity/synthetic_lab_identity`, không tạo UID/cert/private key/password production.
- Start các service lõi: `mosquitto`, `charx-system-config-manager`, `charx-website`, `nginx`, `charx-jupicore`.
- Không sửa `website.db`.
- Không sửa `routePermissions.json`.
- Không seed/reset password.
- Hash `website.db` và `routePermissions.json` trước/sau khi service start.

Script liên quan:

- `emulation/charx_v190/scripts/mount_run_fresh_volumes.sh`
- `emulation/charx_v190/scripts/start_fresh_wbm_roles_session.sh`
- `emulation/charx_v190/scripts/probe_wbm_roles.py`

### 2.2. Integrity/provenance

Hash trước khi start service:

```text
73d4b56cb2f8c61a4397fd5daa6ab4b6a1899a132b04077a191802d5d58082aa  /etc/charx/website.db
894ca8a61f52439de8579d0a7a46ab0c6d2001c1a11b13333c93e3a3987a3940  /etc/charx/routePermissions.json
missing                                                        /data/charx-website/website.db
```

Hash sau khi start service:

```text
73d4b56cb2f8c61a4397fd5daa6ab4b6a1899a132b04077a191802d5d58082aa  /etc/charx/website.db
894ca8a61f52439de8579d0a7a46ab0c6d2001c1a11b13333c93e3a3987a3940  /etc/charx/routePermissions.json
73d4b56cb2f8c61a4397fd5daa6ab4b6a1899a132b04077a191802d5d58082aa  /data/charx-website/website.db
```

Điều này cho thấy runtime DB ban đầu được tạo/copy từ DB firmware gốc trước khi lab thực hiện password change và activation. Các thay đổi sau đó được ghi nhãn là `observed_runtime_state_change`, vì chúng được tạo qua API firmware chứ không patch DB trực tiếp.

## 3. WBM hiện đang chạy được gì?

Snapshot runtime sau khi probe cho thấy các process/port sau đang bind:

| Port | Service quan sát được | Ý nghĩa trong lab |
| --- | --- | --- |
| `1883` | `mosquitto` | MQTT local broker từ firmware/rootfs |
| `4999` | `CharxWebsite` | WebSocket/backend phụ của WBM |
| `5000` | `CharxWebsite` | WBM web backend |
| `5001` | `CharxSystemConfigManager` | System Config Manager |
| `5002` | `CharxSystemConfigManager` | Port phụ của SCM |
| `5555` | `CharxJupiCore` | JupiCore |
| `80` | `nginx` | HTTP frontend/proxy |
| `81` | `nginx` | HTTP frontend/proxy phụ |
| `443` | `nginx` | HTTPS frontend/proxy |

HTTP smoke test hiện tại:

- `GET https://localhost/` trả `200`.
- `GET https://localhost/api/v1.0/web/system-name` trả `200`.

## 4. Auth và role activation

### 4.1. Guest

Guest được xử lý là no-token/no-login. Firmware DB không có row `guest`, nên lab không tạo account guest.

Endpoint guest đã quan sát:

| Endpoint | Kết quả | Nhãn evidence |
| --- | --- | --- |
| `GET /api/v1.0/web/system-name` | `200`, body `"ev3000"` | `observed_runtime` |
| `GET /api/v1.0/web/date-time` | `200` | `observed_runtime` |
| `GET /api/v1.0/web/retained-data` | `200`, body `{}` | `observed_runtime` |

Khi Guest/no-token gọi endpoint cần quyền, firmware trả `403 No permission`, ví dụ:

- `GET /api/v1.0/web/users-active`
- `GET /api/v1.0/web/security-config`
- `GET /api/v1.0/web/network`
- `GET /api/v1.0/web/linux-user-permissions`

### 4.2. Manufacturer default login

Payload login quan sát được:

```json
{"username":"manufacturer","password":"manufacturer","role":""}
```

Kết quả:

- HTTP `200`.
- JWT có `user=manufacturer`.
- JWT có `role=manufacturer`.
- JWT có `passwordChanged=false`.

Sau đó firmware yêu cầu đổi mật khẩu trước khi dùng các API quản trị. Đây là hành vi runtime quan sát được, không phải lỗi emulation.

### 4.3. User và Operator ở trạng thái mặc định

Payload default:

```json
{"username":"user","password":"user","role":""}
{"username":"operator","password":"operator","role":""}
```

Kết quả ban đầu:

- `user/user` trả `403 User not activated`.
- `operator/operator` trả `403 User not activated`.

Điều này khớp với cấu hình firmware gốc: `[ActiveLogins] active = manufacturer`.

### 4.4. Đổi mật khẩu manufacturer theo policy firmware

Payload dùng trong lab:

```json
{
  "username": "manufacturer",
  "password": "manufacturer",
  "password_new": "ManufacturerLab-20260424!",
  "role": ""
}
```

Endpoint:

```text
POST /api/v1.0/web/user/change-password
```

Kết quả:

- HTTP `200`.
- Body: `{"message":"Password change successful"}`.
- Login lại bằng password lab trả JWT `passwordChanged=true`.

Nhãn evidence: `observed_runtime_state_change`.

### 4.5. Kích hoạt user/operator qua API firmware

Trước activation:

```json
{"active":"manufacturer"}
```

Payload activation thành công:

```json
{
  "usersActivationStatus": {
    "manufacturer": {"loginAllowed": true},
    "operator": {
      "loginAllowed": true,
      "password_new": "OperatorLab-20260424!"
    },
    "user": {
      "loginAllowed": true,
      "password_new": "UserLab-20260424!"
    }
  }
}
```

Endpoint:

```text
POST /api/v1.0/web/users-active
```

Kết quả:

- HTTP `200`.
- Body: `null`.
- Sau activation, `GET /api/v1.0/web/users-active` trả `{"active":"manufacturer,user,operator"}`.
- `user/UserLab-20260424!` login thành công, JWT `role=user`.
- `operator/OperatorLab-20260424!` login thành công, JWT `role=operator`.
- `manufacturer/ManufacturerLab-20260424!` login thành công, JWT `role=manufacturer`.

Nhãn evidence: `observed_runtime_state_change`.

## 5. Credential dùng trong phiên lab hiện tại

Default credential vendor được dùng để chứng minh state ban đầu:

| Role | Default credential | Kết quả fresh run |
| --- | --- | --- |
| Guest | Không login, `---/---` theo tài liệu | Guest/no-token hoạt động với route public |
| User | `user/user` | Bị chặn vì inactive |
| Operator | `operator/operator` | Bị chặn vì inactive |
| Manufacturer | `manufacturer/manufacturer` | Login được, nhưng phải đổi password |

Credential đang dùng trong run lab hiện tại, sau khi firmware bắt buộc đổi/khởi tạo password:

| Role | Username | Password lab hiện tại | Nguồn |
| --- | --- | --- | --- |
| User | `user` | `UserLab-20260424!` | Set qua `/users-active` |
| Operator | `operator` | `OperatorLab-20260424!` | Set qua `/users-active` |
| Manufacturer | `manufacturer` | `ManufacturerLab-20260424!` | Set qua `/user/change-password` |

Các password lab này chỉ có ý nghĩa cho run `wbm-roles-20260424T150221Z`. Chúng không được dùng để claim password production, và không được coi là dữ liệu thiết bị thật.

## 6. RBAC safe probe

Các endpoint đã probe đều là GET/read-only, tránh reboot, factory reset, update install, service restart thật.

Kết quả chính:

| Identity | Endpoint | Kết quả |
| --- | --- | --- |
| Guest | `/api/v1.0/web/system-name` | `200` |
| Guest | `/api/v1.0/web/users-active` | `403 No permission` |
| Guest | `/api/v1.0/web/security-config` | `403 No permission` |
| Guest | `/api/v1.0/web/network` | `403 No permission` |
| Guest | `/api/v1.0/web/linux-user-permissions` | `403 No permission` |
| User | `/api/v1.0/web/users-active` | `200` |
| User | `/api/v1.0/web/security-config` | `200` |
| User | `/api/v1.0/web/network` | `200` |
| User | `/api/v1.0/web/linux-user-permissions` | `403 No permission` |
| Operator | `/api/v1.0/web/users-active` | `200` |
| Operator | `/api/v1.0/web/security-config` | `200` |
| Operator | `/api/v1.0/web/network` | `200` |
| Operator | `/api/v1.0/web/linux-user-permissions` | `403 No permission` |
| Manufacturer | `/api/v1.0/web/users-active` | `200` |
| Manufacturer | `/api/v1.0/web/security-config` | `200` |
| Manufacturer | `/api/v1.0/web/network` | `200` |
| Manufacturer | `/api/v1.0/web/linux-user-permissions` | `200`, body `{"enable_user_tty_access": false}` |

Lưu ý: các route test nội bộ dạng `/test-auth-*` trả `404 There is no forwarding known within the webserver...`. Vì vậy chúng không được dùng làm bằng chứng RBAC chính; chỉ được phân loại là `missing_route_or_empty_backend`.

## 7. Các giới hạn vẫn còn

### 7.1. Không claim full dashboard/charging behavior

WBM đã lên, login/RBAC đã test được, nhưng chưa đủ để claim dashboard charging behavior đầy đủ vì lab vẫn thiếu:

- `/data`, `/log`, `/identity` thật từ thiết bị production/lab.
- ControllerAgent hardware trace.
- CAN/QCA/SECC/HomePlug context thật.
- OCPP backend thật hoặc trace thật.
- Modbus meter thật hoặc trace register thật.
- Load Management topology thật.
- Modem/VPN/routing production context.

### 7.2. Không claim behavior cho mock

Trong bước này chưa dùng mock để tạo dashboard/charging state. Nếu các mock được thêm ở phase sau, mọi response phải có provenance:

- `source_type`
- `evidence_tier`
- `confidence`
- `behavior_claim_allowed=false`

Mock chỉ được dùng để giúp service không treo hoặc để log protocol transcript, không dùng để kết luận hành vi CHARX thật nếu thiếu trace.

## 8. Hướng emulate tiếp theo

### 8.1. Hoàn thiện WBM/API audit

Việc có đủ 3 token role hợp lệ mở khóa phase audit an toàn hơn:

- Parse `routePermissions.json` thành endpoint/method/required-role matrix.
- Probe GET/read-only endpoints theo từng role.
- Tách lỗi thành các nhóm:
  - `authz_failure`
  - `service_unavailable`
  - `missing_runtime_data`
  - `hardware_dependency`
  - `missing_route_or_empty_backend`
- Không gọi endpoint destructive nếu chưa có snapshot/cleanup tự động.

Ưu tiên tiếp theo:

1. Audit toàn bộ GET route trong `/api/v1.0/web`.
2. Audit endpoint upload/verify/update ở chế độ dry-run hoặc metadata-only nếu có.
3. Map frontend menu/component nào gọi endpoint nào, nhưng chỉ dựa trên static bundle và runtime HTTP evidence.

### 8.2. Dựng OCPP backend mock có provenance

Mục tiêu không phải giả lập backend production, mà là:

- Cho OCPP agent có peer tối thiểu để connect/log.
- Ghi lại WebSocket/OCPP frame.
- Không dùng response mock để claim production behavior.

Điều kiện trước khi nâng fidelity:

- Có transcript từ firmware agent khi connect.
- Có config endpoint/backend từ firmware.
- Có log service chỉ ra agent không chỉ treo do thiếu hardware/runtime data.

### 8.3. Dựng Modbus fixture có provenance

Mục tiêu:

- Xác định service nào bind `502`, `9502`, `9555`.
- Gửi request đọc register tối thiểu để xem service phản ứng thế nào.
- Nếu cần mock meter, register map phải được gắn nhãn synthetic/generic, không phải CHARX truth.

Điều kiện nâng fidelity:

- Có config meter từ firmware hoặc tài liệu chính gốc.
- Có runtime log/trace từ service.
- Không suy diễn meter behavior từ ví dụ generic.

### 8.4. Load Management

Chỉ nên test Load Management theo hai mức:

- Mức 1: service health/config/API read-only, không claim state machine.
- Mức 2: topology mock có provenance, chỉ để xem firmware gửi/nhận gì.

Không claim behavior charging park nếu thiếu topology và peer thật.

### 8.5. ControllerAgent/JupiCore

JupiCore đã bind được `5555`; ControllerAgent vẫn không nên coi là source of truth cho charging behavior nếu thiếu hardware trace.

Hướng an toàn:

- Reverse static protocol boundary giữa WBM/JupiCore/ControllerAgent.
- Chỉ stub những call đã quan sát được từ runtime log hoặc static config.
- Mọi stub response ghi `mocked_behavior`.

## 9. Evidence đã lưu

Các file evidence chính:

- `emulation/charx_v190/evidence/wbm-roles-20260424T150221Z/probes/wbm_role_probe.jsonl`
- `emulation/charx_v190/evidence/wbm-roles-20260424T150221Z/probes/wbm_role_probe_summary.json`
- `emulation/charx_v190/evidence/wbm-roles-20260424T150221Z/probes/wbm_role_token_hashes.json`
- `emulation/charx_v190/evidence/wbm-roles-20260424T150221Z/probes/current_post_probe_runtime.txt`
- `emulation/charx_v190/evidence/wbm-roles-20260424T150221Z/integrity/wbm_roles_pre_start_hashes.txt`
- `emulation/charx_v190/evidence/wbm-roles-20260424T150221Z/integrity/wbm_roles_post_start_hashes.txt`
- `emulation/charx_v190/evidence/wbm-roles-20260424T150221Z/integrity/website_db_pre_start.json`
- `emulation/charx_v190/evidence/wbm-roles-20260424T150221Z/integrity/website_db_runtime_post_start.json`
- `emulation/charx_v190/evidence/wbm-roles-20260424T150221Z/deviations.md`

## 10. Re-run nhanh

Tạo fresh WBM roles session mới:

```bash
sudo /home/khoa/charx_labs/charx_v190/scripts/start_fresh_wbm_roles_session.sh wbm-roles-$(date -u +%Y%m%dT%H%M%SZ)
```

Probe role/RBAC:

```bash
cd /home/khoa/charx_labs/charx_v190
CHARX_WBM_BASE_URL=https://localhost sudo -E ./scripts/probe_wbm_roles.py <run_id>
```

Export evidence về workspace Windows:

```bash
sudo /home/khoa/charx_labs/charx_v190/scripts/export_report.sh <run_id>
```

