# Ngày 14 - Research wrap-up và CVE candidate triage

Tài liệu này tổng kết 2 tuần học CHARX SEC-3100, dựa trên tài liệu chính thức, advisories, và firmware/rootfs `V190` đã unpack. Cấu trúc được chuẩn hóa theo dạng `Question -> Answer -> Evidence`.

Ngày 14 không nhằm tuyên bố CVE mới. Mục tiêu là biến toàn bộ quan sát thành backlog nghiên cứu có kỷ luật: mỗi candidate phải có component, hypothesis, lý do quan trọng, evidence cần thu và safe test method trong lab được phép.

## Nguồn tài liệu và artifact dùng cho Ngày 14

- [courses.txt](/d:/CHARXSEC/document/courses.txt)
- [day7_charx_sec_3100_week1_threat_model_and_lab_plan.md](/d:/CHARXSEC/document/day7_charx_sec_3100_week1_threat_model_and_lab_plan.md)
- [day8_charx_sec_3100_firmware_unpacking_filesystem_inventory.md](/d:/CHARXSEC/document/day8_charx_sec_3100_firmware_unpacking_filesystem_inventory.md)
- [day9_charx_sec_3100_service_graph_call_chain_reconstruction.md](/d:/CHARXSEC/document/day9_charx_sec_3100_service_graph_call_chain_reconstruction.md)
- [day10_charx_sec_3100_web_api_audit.md](/d:/CHARXSEC/document/day10_charx_sec_3100_web_api_audit.md)
- [day11_charx_sec_3100_emulation_planning.md](/d:/CHARXSEC/document/day11_charx_sec_3100_emulation_planning.md)
- [day12_charx_sec_3100_boot_startup_instrumentation.md](/d:/CHARXSEC/document/day12_charx_sec_3100_boot_startup_instrumentation.md)
- [day13_charx_sec_3100_update_pipeline_config_import_export.md](/d:/CHARXSEC/document/day13_charx_sec_3100_update_pipeline_config_import_export.md)
- [PCSA-2024-00002_SECURITY_ADVISORY.pdf](/d:/CHARXSEC/document/PCSA-2024-00002_SECURITY_ADVISORY.pdf)
- [PCSA-2024-00003_SECURITY_ADVISORY.pdf](/d:/CHARXSEC/document/PCSA-2024-00003_SECURITY_ADVISORY.pdf)
- [PCSA-2025-00015_VDE-2025-074.pdf](/d:/CHARXSEC/document/PCSA-2025-00015_VDE-2025-074.pdf)

## Câu hỏi 1

### Question

Day 14 cần tạo output gì?

### Answer

Timeline yêu cầu:

- vulnerability research backlog
- emulation validation report
- next-30-days plan

Mỗi candidate cần có:

- component
- hypothesis
- why it matters
- evidence to collect
- safe test method

Quy tắc quan trọng: candidate không phải CVE. Candidate chỉ là giả thuyết có bằng chứng nền. Nó chỉ trở thành reportable vulnerability nếu lab chứng minh được impact, affected version, exploitability, remediation gap và vendor coordination path.

### Evidence

- [courses.txt](/d:/CHARXSEC/document/courses.txt) ghi Day 14 là `Research wrap-up and CVE candidate triage`.
- [courses.txt](/d:/CHARXSEC/document/courses.txt) yêu cầu shortlist các nhóm auth bypass, file permission, path traversal, deserialization/config injection, upload/download, startup race windows, IPC boundary.

## Câu hỏi 2

### Question

Backlog candidate nên có format nào?

### Answer

Format chuẩn:

| Field | Nội dung |
|---|---|
| ID | mã nội bộ, ví dụ `CHARX-LAB-001` |
| Component | service/module/route |
| Hypothesis | điều nghi ngờ ở mức phòng thủ |
| Evidence base | tài liệu/config/advisory dẫn tới giả thuyết |
| Impact area | confidentiality, integrity, availability, safety, operations |
| Required access | guest/user/operator/manufacturer/local/LAN/backend |
| Safe test method | cách kiểm tra trong lab được phép |
| Data to collect | logs, traces, requests, file diffs, crash data |
| Current status | open/needs setup/invalid/confirmed in lab |
| Next action | bước kế tiếp nhỏ nhất |

Backlog tốt phải giúp mình bỏ bớt giả thuyết yếu. Không phải cứ nhiều candidate là tốt; candidate phải đo được.

### Evidence

- [day7_charx_sec_3100_week1_threat_model_and_lab_plan.md](/d:/CHARXSEC/document/day7_charx_sec_3100_week1_threat_model_and_lab_plan.md) đã định nghĩa threat model v1.
- [day8_charx_sec_3100_firmware_unpacking_filesystem_inventory.md](/d:/CHARXSEC/document/day8_charx_sec_3100_firmware_unpacking_filesystem_inventory.md) cung cấp file inventory.
- [day10_charx_sec_3100_web_api_audit.md](/d:/CHARXSEC/document/day10_charx_sec_3100_web_api_audit.md) cung cấp API inventory baseline.

## Câu hỏi 3

### Question

Shortlist CVE candidate triage v1 gồm những nhóm nào?

### Answer

Backlog v1:

| ID | Component | Hypothesis | Why it matters | Safe test method |
|---|---|---|---|---|
| `CHARX-LAB-001` | WBM route permissions | role enforcement có thể lệch giữa `routePermissions.json` và backend module | advisory 2025 liên quan low-privileged WBM account | role matrix test trong lab |
| `CHARX-LAB-002` | import/export | config import có thể thiếu schema/rollback | chạm system config, OpenVPN, MQTT, OCPP | import file hợp lệ/lỗi nhẹ, quan sát log |
| `CHARX-LAB-003` | update upload/install | update upload path có thể có permission hoặc validation edge case | update thay đổi code/system | dùng invalid package offline, không flash thiết bị thật |
| `CHARX-LAB-004` | System Config Manager | config apply có thể gọi helper/system action không sanitize đủ | liên quan CVE-2025-41699 pattern | trace route -> SCM -> helper |
| `CHARX-LAB-005` | helper scripts/sudoers | service user có sudo quyền rộng hơn cần thiết | command boundary | audit sudoers + exec trace |
| `CHARX-LAB-006` | log download | logs có thể chứa secret/backend URL/cert path | information disclosure | generate config actions, download logs, redact review |
| `CHARX-LAB-007` | OpenVPN config | VPN config import/manual entry có thể ảnh hưởng routing/secrets | remote access boundary | mock OpenVPN, observe route/noexec handling |
| `CHARX-LAB-008` | OCPP certificate/update | OCPP config/cert/update path có validation gap | backend trust boundary | mock backend, inspect cert/update handling |
| `CHARX-LAB-009` | startup sequence | before firewall/login/update-ready window | advisory 2024 pattern | boot instrumentation only in isolated lab |
| `CHARX-LAB-010` | MQTT bridge/topics | topic forwarding có trust boundary issue | local/remote broker bridge | mock brokers and log topic direction |
| `CHARX-LAB-011` | Modbus server | runtime control exposed through Modbus/TCP | charging process control | isolated Modbus client tests |
| `CHARX-LAB-012` | file removal route | `system-config-manager/remove-file` needs strict path control | arbitrary file deletion class risk | safe path test in disposable rootfs |

Các candidate này phải được thu hẹp bằng evidence trước khi báo cáo.

### Evidence

- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json) chứa route permissions cho WBM, SCM, OCPP, update, import/export.
- [day13_charx_sec_3100_update_pipeline_config_import_export.md](/d:/CHARXSEC/document/day13_charx_sec_3100_update_pipeline_config_import_export.md) phân tích update và config pipeline.
- [PCSA-2024-00003_SECURITY_ADVISORY.pdf](/d:/CHARXSEC/document/PCSA-2024-00003_SECURITY_ADVISORY.pdf) cung cấp pattern startup/firewall và password reset.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) cung cấp pattern WBM/system configuration/command injection.

## Câu hỏi 4

### Question

Evidence package cho một candidate cần gồm gì?

### Answer

Một evidence package tối thiểu:

| Loại evidence | Nội dung |
|---|---|
| Source evidence | manual/advisory/config/route dẫn tới giả thuyết |
| Firmware evidence | file path, module, function/string nếu có |
| Runtime evidence | request/response, log, process, port, file access |
| Impact evidence | dữ liệu/permission/state bị ảnh hưởng |
| Version evidence | firmware version, build, hash |
| Repro boundary | lab topology, account role, network segment |
| Negative controls | test chứng minh không phải false positive |
| Safety note | xác nhận không thử trên hạ tầng thật |

Không có runtime evidence thì candidate vẫn chỉ là hypothesis. Không có version evidence thì khó nói affected product/version.

### Evidence

- [manifest.raucm](/d:/CHARXSEC/work/firmware_v190_bundle/manifest.raucm) cung cấp version/build/hash của firmware `V190`.
- [day11_charx_sec_3100_emulation_planning.md](/d:/CHARXSEC/document/day11_charx_sec_3100_emulation_planning.md) định nghĩa lab/emulation plan.
- [day12_charx_sec_3100_boot_startup_instrumentation.md](/d:/CHARXSEC/document/day12_charx_sec_3100_boot_startup_instrumentation.md) định nghĩa dữ liệu runtime cần thu.

## Câu hỏi 5

### Question

Emulation validation report nên có cấu trúc nào?

### Answer

Report nên có:

| Section | Nội dung |
|---|---|
| Lab scope | firmware version, rootfs, services chạy |
| Network topology | segments, mocks, blocked outbound |
| Services started | Website, SCM, JupiCore, MQTT, OCPP, Modbus |
| Mocks used | OCPP backend, MQTT broker, Modbus peer, OpenVPN |
| What worked | API reachable, logs, port bind, mock interaction |
| What failed | missing hardware, device node, dependency |
| Deviations | config chỉnh để chạy lab |
| Evidence links | logs, captures, file diffs |
| Open questions | việc cần thiết bị thật hoặc QEMU system |

Report này giúp tránh nhầm kết quả emulation với hành vi thiết bị thật. Nó nói rõ mình đã chạy được gì và chưa chạy được gì.

### Evidence

- [day11_charx_sec_3100_emulation_planning.md](/d:/CHARXSEC/document/day11_charx_sec_3100_emulation_planning.md) đề xuất phases và mock services.
- [charx-system-monitor.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-system-monitor.conf) cho thấy nhiều dependency phần cứng/network cần mock.

## Câu hỏi 6

### Question

Next-30-days plan nên đi theo lộ trình nào?

### Answer

Lộ trình 30 ngày:

| Giai đoạn | Mục tiêu |
|---|---|
| Tuần 1 | hoàn thiện service replay: Website, SCM, JupiCore, MQTT |
| Tuần 1 | merge thêm `charx-api-catalog.json` nếu có |
| Tuần 2 | role matrix test cho WBM/API |
| Tuần 2 | import/export/update dry-run trong rootfs lab |
| Tuần 3 | mock OCPP backend và kiểm tra OCPP config/update/log |
| Tuần 3 | mock Modbus/MQTT/OpenVPN boundaries |
| Tuần 4 | boot instrumentation trên lab hoặc QEMU/system setup |
| Tuần 4 | triage candidate: invalid, needs-more-evidence, reportable |

Mỗi tuần nên kết thúc bằng một artifact:

- updated service graph
- API matrix
- emulation report
- candidate evidence package

### Evidence

- [courses.txt](/d:/CHARXSEC/document/courses.txt) nêu mục tiêu cuối khóa là dựng quy trình emulation/lab và checklist triage CVE.
- [day10_charx_sec_3100_web_api_audit.md](/d:/CHARXSEC/document/day10_charx_sec_3100_web_api_audit.md) ghi `work/charx-api-catalog.json` hiện chưa có trong workspace.
- [day13_charx_sec_3100_update_pipeline_config_import_export.md](/d:/CHARXSEC/document/day13_charx_sec_3100_update_pipeline_config_import_export.md) cung cấp update/config checklist.

## Câu hỏi 7

### Question

Sau 2 tuần, bộ kỹ năng đã đạt được là gì?

### Answer

Sau 2 tuần, researcher có baseline để:

- đọc tài liệu Phoenix Contact theo kiến trúc firmware
- map manual service sang firmware file/module
- dựng service graph từ config và init scripts
- tách frontend, backend, service và device-control layers
- hiểu update flow, boot flow, remote/local management boundary
- dựng emulation plan cho embedded Linux firmware
- lập vulnerability backlog có evidence và safe test method

Điểm trưởng thành nhất của khóa học là không nhảy từ advisory sang kết luận. Mỗi giả thuyết đều đi qua tài liệu, inventory, graph, lab, evidence và triage.

### Evidence

- [day1_charx_sec_3100_foundations.md](/d:/CHARXSEC/document/day1_charx_sec_3100_foundations.md) đến [day14_charx_sec_3100_research_wrapup_cve_candidate_triage.md](/d:/CHARXSEC/document/day14_charx_sec_3100_research_wrapup_cve_candidate_triage.md) tạo thành chuỗi học 14 ngày.
- [COURSE_INDEX.md](/d:/CHARXSEC/document/COURSE_INDEX.md) liệt kê toàn bộ tài liệu khóa học.

## Kết luận Ngày 14

Day 14 chốt toàn bộ khóa học:

- threat model đã có từ Day 7
- firmware inventory đã có từ Day 8
- service graph đã có từ Day 9
- API audit baseline đã có từ Day 10
- emulation plan đã có từ Day 11
- boot instrumentation plan đã có từ Day 12
- update/config analysis đã có từ Day 13
- vulnerability research backlog đã có từ Day 14

Từ đây, bước nghiên cứu thật sự là chạy lab, thu evidence, loại bỏ giả thuyết yếu và chỉ giữ lại candidate có impact rõ, version rõ, reproduction rõ và remediation question rõ.
