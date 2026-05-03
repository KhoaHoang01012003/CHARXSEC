# Internet Reconnaissance - Public Runtime Data Search

Tài liệu này định nghĩa cách tìm định kỳ các nguồn dữ liệu công khai có thể tăng độ chính xác của emulation CHARX SEC-3100, nhưng không làm mờ ranh giới giữa dữ liệu thật và dữ liệu tham khảo.

## Cụm từ tìm kiếm định kỳ

- `"CHARX SEC" diagnostics`
- `"CHARX SEC" logs`
- `"CHARX SEC" GetDiagnostics`
- `"CHARX SEC-3100" "OCPP" trace`
- `"CHARX SEC-3100" "MQTT" topics`
- `"CHARX SEC-3100" "Modbus" registers trace`
- `"CHARX SEC-3100" "OpenVPN"`
- `"CharxJupiCore"`
- `"CharxWebsite"`
- `"routePermissions.json" "CHARX"`
- `"CHARX-SEC-Software-Bundle"`
- `"CHARX SEC" "diagnostics archive"`
- `"CHARX SEC" "download logs"`

## Nguồn ưu tiên

- GitHub/GitLab repositories có artifact rõ ràng.
- Conference repositories/workshop material có version và file đi kèm.
- Phoenix Contact vendor docs, PSIRT, advisory.
- Research writeups có mô tả version, firmware bundle, hoặc hash.
- Public packet captures hoặc logs có quyền sử dụng rõ ràng và không chứa secret.

## Điều kiện chấp nhận nguồn runtime

Một nguồn chỉ được coi là runtime evidence nếu đáp ứng tối thiểu:

- có artifact cụ thể để tải hoặc kiểm tra;
- có version, model, hoặc firmware hash liên quan;
- có provenance rõ ràng;
- không chứa secret chưa được sanitize;
- không vi phạm quyền sử dụng;
- có thể tách khỏi exploit payload hoặc dữ liệu nhạy cảm;
- có thể ghi vào ledger với `source_type=public_runtime_snippet` hoặc cao hơn.

## Điều kiện từ chối

Từ chối hoặc chỉ ghi `not_behavior_truth` nếu nguồn:

- chỉ là blog tường thuật không có artifact;
- không gắn được model/version;
- chứa credential, private key, device identity, SIM/APN private data, hoặc OCPP backend secret;
- là exploit payload nhưng không phải behavior bình thường;
- là generic OCPP/MQTT/Modbus sample không liên quan CHARX;
- không có quyền sử dụng rõ ràng.

## Kết quả recon ngày 2026-04-24

Các truy vấn public hiện tìm thấy manual mirror, product pages, advisory/CVE aggregator, ONEKEY workshop, RET2 writeups, và NCC/44CON slides.

Chưa tìm thấy nguồn công khai đáng tin cậy có full runtime dump như `/data`, `/log`, `/identity`, diagnostics archive thật, OCPP/MQTT/Modbus trace đầy đủ của một thiết bị CHARX SEC-3100 production/lab.

