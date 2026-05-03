# CHARX SEC-3100 - Public Data Acquisition Track

Tài liệu này bổ sung cho plan emulate full-fidelity của CHARX SEC-3100 V190. Mục tiêu là tận dụng dữ liệu công khai trên Internet để tăng chất lượng lab, nhưng không bịa hành vi firmware và không nhầm public writeup với runtime truth.

## Summary

- Track mới: `Public Data Acquisition`.
- Tính đến `2026-04-24`, chưa tìm thấy public full runtime dump đáng tin cậy cho CHARX SEC-3100 như `/data`, `/log`, `/identity`, diagnostics archive thật, OCPP/MQTT/Modbus trace đầy đủ.
- Có nguồn công khai hữu ích cho emulation scaffolding và protocol/attack-surface hints.
- Chỉ `Tier 0` và `Tier 1` được dùng làm truth cho fidelity claim.

## Nguồn công khai đã đưa vào ledger

| Nguồn | Cách dùng hợp lệ | Không dùng để |
|---|---|---|
| ONEKEY BHEU23 firmware workshop | tham khảo extraction, QEMU, TAP/network, CAN setup, workflow emulation | runtime truth cho V190 |
| RET2 vulnerability discovery | tham khảo Controller Agent, ETH0/ETH1, UDP discovery, TCP `4444`, HomePlug/raw Ethernet context | mock behavior mặc định hoặc exploit payload |
| RET2 exploit follow-up | hiểu risk class và blind spots | import payload vào fixtures |
| NCC/44CON Pwn2Own slides | tham khảo vuln taxonomy | runtime data |
| ManualsLib mirror | đối chiếu manual/OCPP overview khi local docs thiếu trang | OCPP runtime trace |

Ledger cụ thể nằm tại [sources.jsonl](/d:/CHARXSEC/emulation/charx_v190/public-data-ledger/sources.jsonl).

## Trust tiers

| Tier | Nguồn | Dùng làm behavior truth? |
|---|---|---|
| `Tier 0` | local V190 RAUCB/rootfs/config/manifest | Có |
| `Tier 1` | runtime dump/log/trace từ thiết bị lab của mình | Có |
| `Tier 2` | public emulation scaffold từ firmware CHARX khác | Không, trừ khi đã validate |
| `Tier 3` | public writeup/slides/manual mirror | Không |
| `Tier 4` | generic OCPP/MQTT/Modbus examples | Không |

Chi tiết: [TRUST_TIERS.md](/d:/CHARXSEC/emulation/charx_v190/evidence/TRUST_TIERS.md).

## Mock provenance

Mọi mock/fixture tạo từ dữ liệu public phải có provenance gồm:

- `source_url`
- `source_type`
- `evidence_tier`
- `confidence`
- `version_applicability`
- `behavior_claim_allowed`
- `generated_from`
- `redaction_status`

Schema nằm tại [mock_provenance_schema.json](/d:/CHARXSEC/emulation/charx_v190/provenance/mock_provenance_schema.json).

## Internet reconnaissance định kỳ

Các cụm tìm kiếm được chuẩn hóa trong [recon_queries.md](/d:/CHARXSEC/emulation/charx_v190/public-data-ledger/recon_queries.md), gồm:

- `CHARX SEC diagnostics`
- `CHARX SEC logs`
- `CHARX SEC GetDiagnostics`
- `CHARX SEC-3100 OCPP trace`
- `CharxJupiCore`
- `CharxWebsite`
- `routePermissions.json`
- `CHARX-SEC-Software-Bundle`

Chỉ nhận nguồn nếu có artifact cụ thể, version/model/hash liên quan, provenance rõ, quyền sử dụng rõ, và không chứa secret chưa sanitize.

## Policy quan trọng

- Không tạo `/identity`, certs, UID, passwords, production OCPP backend data từ Internet.
- Không dùng generic OCPP/MQTT/Modbus sample để kết luận behavior CHARX.
- Không đưa exploit payload vào fixture mặc định.
- Không tăng fidelity score dựa trên public writeup nếu không có runtime trace.
- Nếu dùng ONEKEY workshop để dựng network/QEMU/CAN setup, phải diff với V190 trước.
- Nếu dùng RET2 Controller Agent notes để tạo mock discovery tối thiểu, tag phải là `public_reference_derived` hoặc tương đương và `behavior_claim_allowed=false`.

Policy đầy đủ nằm tại [mock_generation_policy.md](/d:/CHARXSEC/emulation/charx_v190/policies/mock_generation_policy.md).

## Updated Test Plan

Các gate kiểm tra được tách thành file riêng:

- [ACCURACY_GATES.md](/d:/CHARXSEC/emulation/charx_v190/evidence/ACCURACY_GATES.md)

Test plan yêu cầu:

- mỗi nguồn public phải có ledger entry;
- mọi version mismatch phải được ghi rõ;
- mọi mock response phải có provenance tag;
- emulation report phải tách `observed_from_V190` và `derived_from_public_reference`;
- không claim full-fidelity cho Controller Agent, charging state machine, OCPP backend behavior, Modbus meter behavior hoặc OpenVPN routing nếu chỉ dựa trên public examples.

## Cập nhật cho fidelity assessment

Track này không làm thay đổi kết luận cốt lõi: nếu chưa có thiết bị lab hoặc runtime trace thật, public Internet data chỉ tăng chất lượng scaffolding, không thay thế dữ liệu thật của thiết bị.

Vì vậy:

- WBM/API/update/config research vẫn có thể tiến nhanh với Tier 0.
- Protocol mocks có thể tốt hơn nhờ Tier 2/Tier 3, nhưng vẫn là mock.
- Controller Agent, charging state machine, OCPP backend behavior, Modbus meter behavior và OpenVPN routing không được claim full-fidelity nếu chỉ dựa trên public examples.
