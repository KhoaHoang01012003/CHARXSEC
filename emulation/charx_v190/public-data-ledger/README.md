# Public Data Ledger - CHARX SEC-3100 V190 Emulation

Ledger này ghi lại các nguồn dữ liệu công khai có thể hỗ trợ dựng lab/emulation cho firmware CHARX SEC-3100 V190.

Nguyên tắc chính: dữ liệu công khai chỉ được dùng để cải thiện scaffolding, checklist, hoặc protocol hints. Không dùng nguồn công khai để bịa `/data`, `/log`, `/identity`, certificate, device UID, password, OCPP backend production data, hoặc hành vi runtime chưa quan sát được.

## Kết luận hiện tại

Tính đến ngày truy cập `2026-04-24`, chưa tìm thấy nguồn công khai đáng tin cậy chứa full runtime dump của một thiết bị CHARX SEC-3100 production/lab, ví dụ:

- dump `/data`
- dump `/log`
- dump `/identity`
- diagnostics archive thật
- OCPP trace đầy đủ gắn với một firmware version cụ thể
- MQTT topic capture đầy đủ
- Modbus meter trace đầy đủ
- OpenVPN runtime routing/certificate trace

Các nguồn đã ghi nhận hiện hữu ích cho nghiên cứu, nhưng không phải ground truth cho hành vi thiết bị V190.

## File trong thư mục này

- `sources.jsonl`: ledger nguồn công khai, mỗi dòng là một JSON object độc lập.
- `recon_queries.md`: cụm từ tìm kiếm định kỳ và quy tắc chấp nhận/từ chối nguồn.

## Source type

| Source type | Ý nghĩa |
|---|---|
| `public_reference` | Bài viết, manual mirror, advisory, slide, hoặc trang mô tả có ích để hiểu bối cảnh |
| `public_runtime_snippet` | Đoạn log/trace runtime công khai, nhỏ, không đủ làm full truth |
| `public_emulation_scaffold` | Script, lab workflow, QEMU/network setup, hoặc workshop giúp dựng emulation |
| `not_behavior_truth` | Nguồn không được dùng để kết luận hành vi runtime của CHARX SEC-3100 V190 |

## Trust tier

Chỉ `Tier 0` và `Tier 1` được dùng làm truth cho fidelity claim.

| Tier | Nguồn | Được dùng làm behavior truth? |
|---|---|---|
| `Tier 0` | Artifact local V190, rootfs/config/manifest từ RAUCB | Có |
| `Tier 1` | Runtime dump/log/trace từ thiết bị lab của mình, khi có | Có |
| `Tier 2` | Public emulation scaffold từ firmware CHARX khác | Không, trừ khi đã đối chiếu bằng V190/runtime |
| `Tier 3` | Public research writeup/slides/manual mirror | Không |
| `Tier 4` | Generic OCPP/MQTT/Modbus examples | Không |

## Quy trình dùng nguồn public

1. Thêm nguồn vào `sources.jsonl` trước khi dùng.
2. Ghi rõ `source_type`, `trust_tier`, `version_applicability`, và `runtime_evidence`.
3. Nếu tạo mock từ nguồn public, mock phải có provenance theo schema trong `../provenance/mock_provenance_schema.json`.
4. Nếu nguồn là script/config public, phải diff thủ công trước khi áp dụng ý tưởng vào lab.
5. Báo cáo emulation phải tách rõ `observed_from_V190`, `observed_runtime`, và `derived_from_public_reference`.

