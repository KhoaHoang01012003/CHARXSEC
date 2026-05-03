# CHARX SEC-3100 V190 Emulation Workspace

Workspace này chứa artifact hỗ trợ dựng lab/emulation cho firmware CHARX SEC-3100 V190.

Nguyên tắc xuyên suốt: không bịa hành vi. Mọi dữ liệu đưa vào lab phải có provenance và phải tách rõ giữa artifact local V190, runtime trace thật, nguồn public, và generic protocol sample.

## Cấu trúc hiện tại

| Path | Mục đích |
|---|---|
| `public-data-ledger/` | ledger nguồn public và quy trình Internet reconnaissance |
| `evidence/` | trust tiers và accuracy gates |
| `provenance/` | schema/template provenance cho mock/fixture |
| `policies/` | policy tạo mock và giới hạn fidelity claim |

## Cách dùng nhanh

1. Đọc [TRUST_TIERS.md](/d:/CHARXSEC/emulation/charx_v190/evidence/TRUST_TIERS.md) trước khi dùng dữ liệu.
2. Ghi nguồn public mới vào [sources.jsonl](/d:/CHARXSEC/emulation/charx_v190/public-data-ledger/sources.jsonl).
3. Nếu tạo mock, tạo provenance theo [mock_provenance_schema.json](/d:/CHARXSEC/emulation/charx_v190/provenance/mock_provenance_schema.json).
4. Kiểm tra mock bằng [ACCURACY_GATES.md](/d:/CHARXSEC/emulation/charx_v190/evidence/ACCURACY_GATES.md).
5. Báo cáo emulation phải ghi rõ phần nào là `observed_from_V190`, `observed_runtime`, và `derived_from_public_reference`.

## WSL Runtime Note

Trong WSL, named `ip netns` có thể không persistent giữa các lần gọi `wsl.exe`. Vì vậy scripts hỗ trợ hai đường:

- `start_namespace.sh` + `run_service_replay.sh` cho Linux environment giữ được named namespace.
- `run_isolated_smoke.sh` cho WSL single-session smoke replay bằng `unshare --net`, chỉ có loopback và không có default route.

## Fidelity rule

Chỉ `Tier 0` và `Tier 1` được dùng làm truth cho behavior claim.

`Tier 2`, `Tier 3`, và `Tier 4` có thể giúp lab chạy tốt hơn, nhưng không làm firmware trở nên “full-fidelity”.

## Current Implemented Lab

- WSL lab path: `/home/khoa/charx_labs/charx_v190`
- First exported run: `20260424T093036Z`
- Implementation report: [charx_sec_3100_emulation_lab_implementation_report.md](/d:/CHARXSEC/document/charx_sec_3100_emulation_lab_implementation_report.md)
- Exported status: [wsl_lab_status.md](/d:/CHARXSEC/emulation/charx_v190/evidence/wsl_lab_status.md)
