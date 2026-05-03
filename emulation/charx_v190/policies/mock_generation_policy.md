# Mock Generation Policy - CHARX SEC-3100 V190

Policy này áp dụng cho mọi mock, stub, fixture hoặc test harness dùng trong emulation CHARX SEC-3100 V190.

## Mục tiêu

- Giúp service chạy trong lab mà không bịa hành vi thiết bị.
- Tách rõ dữ liệu quan sát từ firmware V190, runtime thật, nguồn public, và generic protocol sample.
- Ngăn việc vô tình dùng exploit payload, secret, hoặc public writeup như production behavior.

## Quy tắc bắt buộc

1. Mỗi mock phải có provenance theo `../provenance/mock_provenance_schema.json`.
2. Mỗi mock response phải có tag nguồn, tối thiểu gồm `source_type`, `evidence_tier`, `confidence`, và `behavior_claim_allowed`.
3. Mock dựa trên nguồn public phải có `source_url`, `source_type`, `confidence`, `version_applicability`.
4. Mock dựa trên generic protocol sample phải đặt `behavior_claim_allowed=false`.
5. Báo cáo emulation phải tách `observed_from_V190`, `observed_runtime`, và `derived_from_public_reference`.
6. Không tăng fidelity score nếu chỉ có public writeup/manual mirror mà không có runtime trace.
7. Nếu cần thay đổi config để service chạy, lưu diff và ghi kết quả là `modified-runtime behavior`.

## Dữ liệu không được bịa

Không tạo hoặc suy diễn các dữ liệu sau từ Internet:

- `/identity`
- device UID
- private key
- certificate production
- password hoặc account production
- SIM/APN private data
- OCPP backend production URL/token/credential
- OpenVPN private key/certificate production
- meter calibration data thật
- log runtime thật nếu chưa có capture

Nếu cần test, dùng lab/test identity rõ ràng và gắn `not_behavior_truth`.

## Cách dùng nguồn public

| Nguồn | Được phép | Không được phép |
|---|---|---|
| ONEKEY workshop | tham khảo extraction, QEMU, network, TAP, CAN setup | dùng output/config làm truth cho V190 |
| RET2 discovery writeup | attack-surface checklist, Controller Agent boundary hints | đưa exploit payload vào fixture mặc định |
| RET2 exploit follow-up | hiểu risk class và blind spots | mô phỏng exploit như behavior bình thường |
| NCC/44CON slides | vuln taxonomy và câu hỏi triage | tạo mock response từ slide |
| ManualsLib mirror | đối chiếu manual/OCPP overview khi local docs thiếu trang | coi là runtime trace |
| Generic OCPP/MQTT/Modbus examples | smoke test parser/connection | claim CHARX-specific behavior |

## Confidence

| Confidence | Điều kiện |
|---|---|
| `high` | Tier 0/Tier 1, version phù hợp, artifact/trace kiểm tra được |
| `medium` | Public source đáng tin nhưng không phải runtime truth hoặc version mismatch |
| `low` | Generic sample, placeholder, hoặc mock chỉ để giữ service không treo |

## Accuracy gates

Không claim full-fidelity cho các phần sau nếu chỉ dựa trên public examples:

- Controller Agent
- charging state machine
- CP/PP behavior
- OCPP backend behavior
- Modbus meter behavior
- MQTT production topology
- OpenVPN routing/certificate lifecycle
- device identity/provisioning

Chỉ nâng fidelity estimate khi có runtime dump/log/trace thật hoặc hardware-in-the-loop.

## Review checklist trước khi dùng mock

- Mock đã có provenance file chưa?
- `source_type` có đúng không?
- `evidence_tier` có vượt quá nguồn thật không?
- Có version mismatch nào chưa ghi không?
- Có chứa secret hoặc identity không?
- Có đang dùng exploit payload như normal behavior không?
- Báo cáo test có phân biệt mock với behavior thật không?

