# Ngày 6 - Security Advisory 2025: PCSA-2025-00015 / VDE-2025-074

Tài liệu này chỉ dựa trên các nguồn trong thư mục `document`, không dựa trên code, config hay phân tích firmware trong workspace. Cấu trúc được chuẩn hóa theo dạng `Question -> Answer -> Evidence`.

Theo timeline trong `courses.txt`, Ngày 6 tập trung vào security advisory năm 2025, đặc biệt là `PCSA-2025-00015 / VDE-2025-074`, firmware threshold `1.7.4`, mitigation/remediation, và danh sách điểm cần kiểm tra trong binary/config ở giai đoạn lab.

## Nguồn tài liệu dùng cho Ngày 6

- [courses.txt](/d:/CHARXSEC/document/courses.txt)
- [PCSA-2025-00015_VDE-2025-074.pdf](/d:/CHARXSEC/document/PCSA-2025-00015_VDE-2025-074.pdf)
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt)
- [Cybersecurity.html](/d:/CHARXSEC/document/Cybersecurity.html)
- [Maintenance_repair_and_disposal.html](/d:/CHARXSEC/document/Maintenance_repair_and_disposal.html)
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html)
- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md)

## Câu hỏi 1

### Question

Theo timeline khóa học, Ngày 6 cần học gì và output mong muốn là gì?

### Answer

Trong `courses.txt`, Ngày 6 được đặt tên là `Security advisory 2025`. Mục tiêu của ngày này là:

- nắm issue mới hơn so với nhóm advisory 2024
- hiểu cách Phoenix Contact đặt remediation
- hiểu xu hướng hardening và hướng dẫn vận hành trong closed network
- đọc kỹ `affected products`, `mitigation`, `remediation`
- so sánh version floor `1.7.4` với version trong lab
- ghi chú control nào có thể bị cấu hình hoặc triển khai sai

Output mà timeline yêu cầu gồm:

- một trang tóm tắt advisory 2025
- danh sách thay đổi hoặc điểm khác biệt từ version lab, ví dụ `1.6.3`, lên `1.7.4` cần kiểm tra trong binary/config

Điểm quan trọng là advisory 2025 không cung cấp diff kỹ thuật chi tiết giữa các firmware version. Nó chỉ xác định ngưỡng affected/fixed: firmware `< 1.7.4` là affected, firmware `1.7.4` là fixed. Vì vậy, phần “thay đổi từ 1.6.3 đến 1.7.4” trong ngày học phải được hiểu là **checklist cần kiểm tra khi có firmware bundle**, không phải danh sách thay đổi đã được advisory công bố.

### Evidence

- [courses.txt](/d:/CHARXSEC/document/courses.txt) ghi `Ngày 6: Security advisory 2025`.
- [courses.txt](/d:/CHARXSEC/document/courses.txt) nêu mục tiêu là nắm issue mới hơn, remediation, hardening/closed-network guidance.
- [courses.txt](/d:/CHARXSEC/document/courses.txt) yêu cầu học từ `document/PCSA-2025-00015_VDE-2025-074.pdf`.
- [courses.txt](/d:/CHARXSEC/document/courses.txt) yêu cầu output là trang tóm tắt advisory 2025 và danh sách thay đổi từ `1.6.3` đến `1.7.4` cần kiểm tra trong binary/config.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) nêu affected products là firmware `<1.7.4` và fixed products là firmware `1.7.4`.

## Câu hỏi 2

### Question

`PCSA-2025-00015 / VDE-2025-074` là advisory gì?

### Answer

`PCSA-2025-00015 / VDE-2025-074` là security advisory của Phoenix Contact cho dòng `CHARX SEC-3xxx charging controllers`. Advisory này có document category là `csaf_security_advisory`, trạng thái `FINAL`, current version `1.1.0`, và được gắn TLP `WHITE`.

Advisory cho biết đã phát hiện một vulnerability trong firmware của các charging controller thuộc dòng `CHARX SEC-3xxx`. Severity được đánh giá là `High` với CVSSv3.1 base score `8.8`.

Với khóa học này, advisory là một mốc quan trọng vì nó không chỉ nói “có lỗi”, mà còn cho thấy ba thông tin dùng để định hướng nghiên cứu:

- lớp bị ảnh hưởng là firmware của controller
- điều kiện attacker là remote attacker có tài khoản low-privileged cho Web-based Management
- hậu quả là command injection chạy ở mức root, dẫn tới mất confidentiality, integrity và availability

Tài liệu không công bố payload, endpoint cụ thể hoặc cách khai thác. Do đó, cách đọc đúng là dùng advisory để tạo threat model và checklist audit, không biến nó thành hướng dẫn exploit.

### Evidence

- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) ghi `PCSA-2025-00015`, `VDE-2025-074`, publisher là Phoenix Contact GmbH & Co. KG.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) ghi document category là `csaf_security_advisory`.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) ghi current version `1.1.0`, status `FINAL`, TLP `WHITE`.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) ghi CVSSv3.1 base score `8.8`, severity `High`.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) tóm tắt rằng vulnerability nằm trong firmware của `CHARX SEC-3xxx charging controllers`.

## Câu hỏi 3

### Question

Những sản phẩm nào bị ảnh hưởng, và `CHARX SEC-3100` nằm ở đâu trong danh sách này?

### Answer

Advisory liệt kê bốn model affected khi chạy firmware `< 1.7.4`:

| Model | Điều kiện affected | Order number |
|---|---|---|
| `CHARX SEC-3150` | `FW <1.7.4` | `1138965` |
| `CHARX SEC-3100` | `FW <1.7.4` | `1139012` |
| `CHARX SEC-3050` | `FW <1.7.4` | `1139018` |
| `CHARX SEC-3000` | `FW <1.7.4` | `1139022` |

Với model đang học, `CHARX SEC-3100` item `1139012` nằm trực tiếp trong danh sách affected nếu firmware thấp hơn `1.7.4`.

Advisory cũng liệt kê bốn model fixed khi chạy firmware `1.7.4`:

| Model | Điều kiện fixed | Order number |
|---|---|---|
| `CHARX SEC-3150` | `FW 1.7.4` | `1138965` |
| `CHARX SEC-3100` | `FW 1.7.4` | `1139012` |
| `CHARX SEC-3050` | `FW 1.7.4` | `1139018` |
| `CHARX SEC-3000` | `FW 1.7.4` | `1139022` |

Như vậy, rule triage của Day 6 rất rõ:

- nếu lab `SEC-3100` đang chạy firmware `< 1.7.4`, lab thuộc affected range theo advisory
- nếu lab đã chạy firmware `1.7.4`, advisory xem đây là fixed product
- nếu version lab không xác định, việc đầu tiên là lấy firmware version từ WBM hoặc metadata firmware

### Evidence

- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) liệt kê affected products gồm `FW <1.7.4 installed on CHARX SEC-3150`, `SEC-3100`, `SEC-3050`, `SEC-3000`.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) liệt kê order number `1139012` cho `CHARX SEC-3100`.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) liệt kê fixed products là `FW 1.7.4` installed trên cùng bốn model.
- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) xác nhận product name là `CHARX SEC-3100` và item number là `1139012`.

## Câu hỏi 4

### Question

CVE chính trong advisory 2025 là gì, và root cause class được mô tả ra sao?

### Answer

CVE chính trong advisory là `CVE-2025-41699`.

Advisory mô tả lỗi như sau ở mức khái niệm:

- attacker là remote attacker
- attacker cần có một account cho Web-based Management
- account đó là low-privileged
- attacker có thể thay đổi system configuration
- thay đổi này có thể dẫn tới command injection chạy với quyền root
- root cause class là `CWE-94: Improper Control of Generation of Code ('Code Injection')`

Nói theo ngôn ngữ học tập, đây là lỗi thuộc nhóm **configuration-to-command boundary failure**. Tức là dữ liệu hoặc tham số cấu hình đi qua WBM không được kiểm soát đủ chặt trước khi tham gia vào quá trình tạo hoặc thực thi command/code ở hệ thống. Advisory không nói chính xác field nào, endpoint nào, payload nào hoặc command nào bị ảnh hưởng.

Khi đọc để nghiên cứu CVE mới, bài học không phải là “làm sao exploit CVE-2025-41699”, mà là xác định pattern:

- input từ Web-based Management
- action thay đổi system configuration
- privilege boundary từ low-privileged WBM account tới root-level effect
- class `CWE-94`

Pattern này sẽ được dùng ở tuần 2 để kiểm tra các đường import/export config, system config, update config, network config, OpenVPN/MQTT config hoặc các endpoint backend có khả năng sinh command.

### Evidence

- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) ghi vulnerability là `CVE-2025-41699`.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) mô tả attacker là low privileged remote attacker có account cho Web-based Management.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) nêu attacker có thể change system configuration để perform command injection as root.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) gán CWE là `CWE-94: Improper Control of Generation of Code ('Code Injection')`.

## Câu hỏi 5

### Question

CVSS vector của CVE-2025-41699 nói gì về điều kiện tấn công?

### Answer

Advisory gán CVSS vector:

`CVSS:3.1/AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H`

Giải nghĩa theo từng phần:

| Thành phần | Ý nghĩa | Diễn giải trong bối cảnh advisory |
|---|---|---|
| `AV:N` | Attack Vector: Network | lỗi có thể bị tác động qua mạng |
| `AC:L` | Attack Complexity: Low | điều kiện khai thác được đánh giá là độ phức tạp thấp |
| `PR:L` | Privileges Required: Low | attacker cần quyền thấp, không cần quyền admin/root |
| `UI:N` | User Interaction: None | không cần tương tác của người dùng khác |
| `S:U` | Scope: Unchanged | scope không đổi theo CVSS |
| `C:H` | Confidentiality: High | ảnh hưởng nặng tới confidentiality |
| `I:H` | Integrity: High | ảnh hưởng nặng tới integrity |
| `A:H` | Availability: High | ảnh hưởng nặng tới availability |

Điểm đáng chú ý nhất là combination `AV:N + PR:L + UI:N`. Điều này nghĩa là hệ thống exposed qua network và có tài khoản WBM quyền thấp vẫn là rủi ro đáng kể nếu cấu hình hoặc phân quyền không được giới hạn đúng. Đây cũng là lý do mitigation của Phoenix Contact nhấn mạnh closed network và firewall.

### Evidence

- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) ghi CVSS vector cho `FW <1.7.4 installed on CHARX SEC-3100` là `CVSS:3.1/AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H`.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) ghi CVSS base score là `8.8`.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) ghi severity là `High`.

## Câu hỏi 6

### Question

Impact của CVE-2025-41699 là gì?

### Answer

Advisory nêu impact ở mức rất nghiêm trọng: vulnerability có thể dẫn đến total loss của confidentiality, integrity và availability của thiết bị.

Nếu nối impact này với mô tả kỹ thuật của CVE, lý do là command injection chạy ở mức root có thể phá vỡ cả ba thuộc tính bảo mật:

- confidentiality: root-level effect có thể làm lộ dữ liệu cấu hình, log, credential hoặc trạng thái hệ thống nếu đường lỗi bị lạm dụng
- integrity: attacker có thể thay đổi system configuration hoặc trạng thái hệ thống
- availability: root-level command injection có thể làm service hoặc thiết bị mất ổn định

Tuy nhiên, advisory không mô tả payload, command cụ thể hay endpoint cụ thể. Do đó, trong tài liệu học, ta chỉ kết luận ở mức class và impact như advisory nêu, không suy diễn kỹ thuật khai thác.

### Evidence

- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) nêu impact là total loss of confidentiality, integrity and availability.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) mô tả command injection as root.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) ghi CVSS impact components `C:H/I:H/A:H`.

## Câu hỏi 7

### Question

Mitigation của Phoenix Contact là gì, và nó nói gì về closed-network guidance?

### Answer

Mitigation của Phoenix Contact là dùng các affected charging controllers trong closed industrial networks và bảo vệ bằng firewall phù hợp. Advisory nói các controller này được thiết kế và phát triển cho use case trong closed industrial networks, vì vậy Phoenix Contact strongly recommends dùng thiết bị exclusively trong closed networks và protected by a suitable firewall.

Điều này tạo ra một nguyên tắc hardening rõ ràng cho lab và production:

| Chủ đề | Diễn giải thực tế |
|---|---|
| Network placement | Không đặt WBM hoặc management surface trực tiếp ra Internet |
| Firewall | Chỉ mở port/service thật sự cần thiết |
| Account exposure | Low-privileged WBM account vẫn phải được coi là sensitive |
| Remote management | OCPP, MQTT, OpenVPN, WBM, Modbus/TCP cần được đặt trong network boundary có kiểm soát |
| Monitoring | Log, firmware version và config changes cần được ghi nhận khi vận hành |

Mitigation này phù hợp với hướng dẫn cybersecurity chung của Phoenix Contact: charging infrastructure ngày càng chịu yêu cầu bảo mật cao hơn, nhà sản xuất cần security updates và vulnerability management, còn người vận hành cần giảm nguy cơ cybersecurity attacks và tampering.

### Evidence

- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) nêu affected charging controllers được thiết kế và phát triển cho use in closed industrial networks.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) nêu Phoenix Contact strongly recommends using devices exclusively in closed networks and protected by a suitable firewall.
- [Cybersecurity.html](/d:/CHARXSEC/document/Cybersecurity.html) nêu charging infrastructure đang chịu yêu cầu IT security tăng lên và nhà sản xuất phải bảo đảm security updates, vulnerability management và CE marking.
- [Cybersecurity.html](/d:/CHARXSEC/document/Cybersecurity.html) nêu Phoenix Contact cung cấp regular and free security updates để giảm risk của cybersecurity attacks và tampering.

## Câu hỏi 8

### Question

Remediation chính thức là gì, và firmware `1.7.4` có vai trò gì?

### Answer

Remediation chính thức trong advisory là upgrade lên firmware version `1.7.4`. Advisory nói firmware `1.7.4` fixes vulnerability `CVE-2025-41699`.

Với `CHARX SEC-3100`, quy tắc remediation là:

- `FW <1.7.4 installed on CHARX SEC-3100`: affected
- `FW 1.7.4 installed on CHARX SEC-3100`: fixed

Manual bảo trì cũng mô tả các cách update:

- update individual software programs
- perform complete software update
- update locally via Web-based Management
- update via backend using OCPP connection
- OCPP backend update có thể thực hiện qua Ethernet hoặc cellular interface

Manual cũng cảnh báo rằng full update qua cellular communication có thể tốn data volume hơn, nên cần kiểm tra xem full system update có thật sự cần thiết không, có thể chỉ cần update individual applications, và có thể liên hệ Phoenix Contact Support.

### Evidence

- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) nêu Phoenix Contact strongly recommends upgrade to firmware version `1.7.4`.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) nêu `1.7.4` fixes `CVE-2025-41699`.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) liệt kê `FW <1.7.4 installed on CHARX SEC-3100` là affected và `FW 1.7.4 installed on CHARX SEC-3100` là fixed.
- [Maintenance_repair_and_disposal.html](/d:/CHARXSEC/document/Maintenance_repair_and_disposal.html) nêu có thể update individual software programs hoặc perform complete software update.
- [Maintenance_repair_and_disposal.html](/d:/CHARXSEC/document/Maintenance_repair_and_disposal.html) nêu update có thể thực hiện locally via WBM hoặc via backend using OCPP connection.
- [Maintenance_repair_and_disposal.html](/d:/CHARXSEC/document/Maintenance_repair_and_disposal.html) nêu OCPP backend updates có thể thực hiện qua Ethernet connection và cellular interface.
- [Maintenance_repair_and_disposal.html](/d:/CHARXSEC/document/Maintenance_repair_and_disposal.html) cảnh báo increased data volume cho full update qua cellular communication.

## Câu hỏi 9

### Question

Làm sao so sánh version trong lab với version floor `1.7.4`?

### Answer

Advisory đưa ra version floor rất rõ: `<1.7.4` là affected, `1.7.4` là fixed. Vì vậy, bước đầu tiên trong lab là xác định firmware version đang chạy.

Manual startup nói firmware version của charging station có thể xem trong WBM, và firmware có thể update qua `System Control/Software`. Manual cũng nhấn mạnh nên vận hành controller với latest firmware version và quan sát change notes của firmware version.

Checklist so sánh version trong lab:

| Việc cần làm | Kết luận nếu kết quả như sau |
|---|---|
| Ghi lại model và item number | Với `SEC-3100`, item number phải là `1139012` |
| Ghi lại firmware version | Nếu `<1.7.4`, lab nằm trong affected range |
| Kiểm tra đã có firmware `1.7.4` chưa | Nếu có, lab thuộc fixed range theo advisory |
| Ghi lại update path | WBM local, OCPP backend, Ethernet hoặc cellular |
| Lưu release notes nếu có | Dùng cho so sánh thay đổi thực tế giữa bản lab và `1.7.4` |
| Không thấy version | Cần lấy từ WBM, package metadata hoặc firmware bundle trước khi triage |

Nếu timeline của bạn dùng ví dụ `1.6.3`, thì `1.6.3` nhỏ hơn `1.7.4`, nên theo advisory nó thuộc affected range. Tuy nhiên, advisory không nêu diff cụ thể giữa `1.6.3` và `1.7.4`; diff phải được xác minh bằng release notes hoặc so sánh firmware bundle.

### Evidence

- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) nêu affected là `FW <1.7.4` và fixed là `FW 1.7.4`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu firmware version của charging station có thể được update qua `System Control/Software`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) khuyến nghị operate charging controller với latest firmware version, observe change notes, và carry out firmware update.
- [Maintenance_repair_and_disposal.html](/d:/CHARXSEC/document/Maintenance_repair_and_disposal.html) nêu available updates và associated release notes nằm dưới item number tương ứng của charging controller.
- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) xác nhận `CHARX SEC-3100` có item number `1139012`.

## Câu hỏi 10

### Question

Advisory cho thấy control point nào có thể bị sai, và nên triage ở lớp nào?

### Answer

Advisory nói attacker có thể change `system configuration` để dẫn tới command injection as root. Vì vậy, control point quan trọng nhất là **đường đi từ WBM/API input tới system configuration rồi tới command/code generation**.

Trong tài liệu WBM, có nhiều khu vực liên quan tới system-level configuration hoặc remote/network configuration:

| Control surface | Lý do cần triage |
|---|---|
| `System configuration (Ethernet, port sharing, modem)` | Nằm trong danh sách import/export của WBM |
| `OpenVPN` | Có copy/paste configuration, import file, route interaction và activation mode |
| `MQTT Bridge` | Có broker, credential, certificate, prefix, station identity và topic forwarding |
| `Network/Ethernet` | Có IP, gateway, DNS, hostname |
| `Network/Port Sharing` | Có danh sách port, block/open port, add custom port |
| `Routing table` | Có gateway, interface, metric, persist route |
| `System Control/Software` | Có update individual application, firmware hoặc entire system |

Đây là danh sách triage để kiểm tra trong lab, không phải kết luận rằng mọi surface đều vulnerable. Advisory chỉ xác nhận một vulnerability thuộc nhóm system configuration dẫn tới command injection; nó không chỉ ra exact endpoint hoặc field.

Khi vào tuần 2, cần mapping các WBM form/API endpoint tương ứng với các control surface này và kiểm tra:

- validation của input
- escaping hoặc command construction
- privilege boundary giữa WBM user và root/system service
- allowlist của tham số cấu hình
- file permission và owner của generated config
- log evidence khi cấu hình thay đổi

### Evidence

- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) mô tả low-privileged remote attacker có WBM account có thể change system configuration để perform command injection as root.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu `Import/Export` có thể export/import `System configuration (Ethernet, port sharing, modem)`, `MQTT bridge` và `OpenVPN`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `Network/Port Sharing` cho phép block incoming ports và add further ports bằng `New Port` và `ADD PORT`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `Network/OpenVPN`, `Routing table` và `MQTT Bridge`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu `System Control/Software` có thể update individual application programs, charging controller firmware hoặc entire system.

## Câu hỏi 11

### Question

Advisory 2025 có nói rõ “thay đổi từ 1.6.3 đến 1.7.4” không?

### Answer

Không. Advisory `PCSA-2025-00015 / VDE-2025-074` không cung cấp danh sách diff cụ thể từ `1.6.3` đến `1.7.4`. Advisory chỉ nói:

- firmware `<1.7.4` là affected
- firmware `1.7.4` là fixed
- upgrade lên `1.7.4` để fix `CVE-2025-41699`

Vì vậy, yêu cầu “danh sách thay đổi từ 1.6.3 đến 1.7.4” trong timeline nên được xử lý theo hai lớp:

| Lớp | Cách hiểu |
|---|---|
| Confirmed by advisory | `1.7.4` là remediation floor, `<1.7.4` là affected |
| To be verified in lab | actual diff giữa `1.6.3` và `1.7.4` phải kiểm tra bằng release notes, firmware bundle, binary diff hoặc config diff |

Danh sách cần kiểm tra trong binary/config khi có firmware bundle:

| Nhóm kiểm tra | Câu hỏi defensive cần trả lời |
|---|---|
| WBM system configuration handlers | Input nào có thể thay đổi system configuration? |
| Command construction | Có còn đường tạo command từ input cấu hình không? |
| Privilege boundary | Low-privileged WBM user có thể chạm tới action root-level nào? |
| Sanitization/allowlist | Field cấu hình có allowlist ký tự/format rõ ràng không? |
| Config import/export | File import có được validate schema và path không? |
| Network config | IP/gateway/DNS/route/port field có bị đưa vào shell command không? |
| OpenVPN/MQTT config | Config text, certificate, broker, prefix, topic có validate không? |
| Logging | Thay đổi system configuration có log đủ bằng chứng không? |
| Update effect | Sau update lên `1.7.4`, handler hoặc validator nào thay đổi? |

Đây là checklist học tập và audit phòng thủ. Nó không khẳng định các điểm trên vulnerable; nó chỉ dịch advisory thành câu hỏi nghiên cứu có hệ thống.

### Evidence

- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) nêu affected products là `FW <1.7.4` và fixed products là `FW 1.7.4`.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) nêu remediation là upgrade to firmware version `1.7.4`.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) không nêu diff chi tiết giữa `1.6.3` và `1.7.4`.
- [Maintenance_repair_and_disposal.html](/d:/CHARXSEC/document/Maintenance_repair_and_disposal.html) nêu available updates và associated release notes nằm dưới item number tương ứng.

## Câu hỏi 12

### Question

Advisory matrix cho CVE-2025-41699 nên được ghi như thế nào?

### Answer

Advisory matrix cho Day 6:

| Field | Nội dung |
|---|---|
| Advisory | `PCSA-2025-00015 / VDE-2025-074` |
| CVE | `CVE-2025-41699` |
| Product family | `CHARX SEC-3xxx charging controllers` |
| Product đang học | `CHARX SEC-3100`, item `1139012` |
| Affected version | `FW <1.7.4` |
| Fixed version | `FW 1.7.4` |
| Severity | `High` |
| CVSS base score | `8.8` |
| CVSS vector | `CVSS:3.1/AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H` |
| Attacker condition | Remote attacker có low-privileged WBM account |
| Root cause class | `CWE-94`, improper control of code generation/code injection |
| Affected component class | Firmware/system configuration path exposed through WBM |
| Impact | Total loss of confidentiality, integrity, availability |
| Mitigation | Closed industrial network và suitable firewall |
| Remediation | Upgrade firmware to `1.7.4` |
| What failed | Boundary giữa low-privileged WBM config change và root-level command/code generation |
| What not to infer | Không có endpoint, payload hoặc exact vulnerable field trong advisory |

Matrix này giúp chuyển advisory thành ngôn ngữ audit. Thay vì chỉ ghi CVE, ta ghi rõ điều kiện, component class, boundary failure và action remediation.

### Evidence

- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) cung cấp advisory ID, CVE, affected/fixed versions, CVSS, attacker condition, root cause class, impact, mitigation và remediation.
- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) xác nhận `CHARX SEC-3100` item `1139012`.

## Câu hỏi 13

### Question

Từ advisory 2025, nên rút ra những giả thuyết nghiên cứu nào cho fuzzing và audit?

### Answer

Các giả thuyết nghiên cứu nên ở mức an toàn, có kiểm soát, và tập trung vào root cause class thay vì payload:

| Giả thuyết | Evidence từ advisory | Cách kiểm tra an toàn ở tuần 2 |
|---|---|---|
| WBM low-privileged role có thể chạm tới system configuration nhạy cảm | Advisory yêu cầu attacker có low-privileged WBM account | Map permission của endpoint/action theo role |
| Một số field cấu hình từng đi vào command/code generation | Advisory nêu command injection as root do code generation control kém | Tìm code path tạo command từ config, không chạy payload nguy hiểm |
| Validator hoặc allowlist đã thay đổi ở `1.7.4` | Advisory nói `1.7.4` fixes CVE | Diff handler/validator giữa firmware cũ và `1.7.4` |
| Config import/export có thể là vùng audit quan trọng | WBM có import/export system configuration, MQTT bridge, OpenVPN | Kiểm tra schema validation, path handling, permission |
| Network-related config đáng ưu tiên | System config gồm Ethernet, port sharing, modem; OpenVPN và MQTT có config text/certificate | Audit field format và file generation |
| Logging cần đủ để điều tra config abuse | Impact rất cao và remediation yêu cầu update | Kiểm tra log khi config thay đổi, role nào, timestamp nào |

Những giả thuyết này chưa phải CVE mới. Chúng là backlog audit để tránh nghiên cứu lan man. Mỗi giả thuyết cần đi kèm evidence, component, expected behavior, safe test method và tiêu chí dừng.

### Evidence

- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) mô tả low privileged remote attacker có WBM account.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) mô tả change system configuration để perform command injection as root.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) nêu root cause class là `CWE-94`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu `Import/Export` có `System configuration`, `MQTT bridge` và `OpenVPN`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả WBM có nhiều vùng cấu hình system/network như Ethernet, Port Sharing, OpenVPN, Routing table và MQTT Bridge.

## Câu hỏi 14

### Question

Day 6 nên kết nối với Day 7 và tuần 2 như thế nào?

### Answer

Day 6 tạo bridge từ tài liệu advisory sang threat model và lab plan.

Cho Day 7, cần đưa CVE-2025-41699 vào threat model tuần 1:

| Threat model item | Nội dung cần ghi |
|---|---|
| Asset | system configuration, WBM accounts, firmware integrity |
| Entry point | Web-based Management qua network |
| Trust boundary | low-privileged WBM user tới root/system configuration service |
| Failure class | command/code generation control, `CWE-94` |
| Impact | total CIA loss |
| Mitigation | closed network, firewall, least privilege, update |
| Remediation | firmware `1.7.4` |

Cho tuần 2, Day 6 tạo checklist để phân tích firmware:

| Tuần 2 task | Câu hỏi cần trả lời |
|---|---|
| Firmware unpacking | File nào chứa WBM backend, config handlers, validators? |
| Service graph | WBM gọi service nào để thay đổi system configuration? |
| Web/API audit | Endpoint nào cho low-privileged user sửa system config? |
| Emulation planning | Mock gì để test config handler an toàn? |
| Startup instrumentation | Service nào chạy root, service nào nhận config từ WBM? |
| Update pipeline | `1.7.4` thay đổi validator, permission hay command path nào? |
| CVE candidate triage | Có boundary nào tương tự nhưng chưa được advisory nêu không? |

Nói ngắn gọn, Day 6 không dừng ở “đọc advisory”. Nó biến advisory thành bản đồ câu hỏi nghiên cứu cho tuần 2.

### Evidence

- [courses.txt](/d:/CHARXSEC/document/courses.txt) nêu Day 7 là tổng kết tuần 1 để gom kiến thức thành threat model và checklist lab emulation.
- [courses.txt](/d:/CHARXSEC/document/courses.txt) nêu tuần 2 gồm firmware unpacking, service graph, web/API audit, emulation planning, boot instrumentation, update pipeline và CVE candidate triage.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) cung cấp root cause class, affected/fixed versions, mitigation và remediation cần đưa vào threat model.

## Kết quả cần nắm sau Ngày 6

Sau khi học xong Ngày 6, bạn nên nắm chắc:

- `PCSA-2025-00015 / VDE-2025-074` là advisory Phoenix Contact cho `CHARX SEC-3xxx charging controllers`.
- `CHARX SEC-3100` item `1139012` affected nếu chạy firmware `<1.7.4`.
- Firmware `1.7.4` là remediation floor được advisory xem là fixed cho CVE này.
- CVE chính là `CVE-2025-41699`, severity `High`, CVSS base score `8.8`.
- CVSS vector là `CVSS:3.1/AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H`.
- Attacker condition theo advisory là remote attacker có low-privileged account cho Web-based Management.
- Root cause class là `CWE-94`, improper control of code generation/code injection.
- Impact được advisory mô tả là total loss của confidentiality, integrity và availability.
- Mitigation chính là dùng thiết bị trong closed industrial networks và bảo vệ bằng suitable firewall.
- Remediation chính là upgrade firmware lên `1.7.4`.
- Advisory không công bố endpoint, payload, field cụ thể hoặc diff chi tiết từ `1.6.3` đến `1.7.4`.
- Danh sách “thay đổi từ 1.6.3 đến 1.7.4” phải được xử lý như checklist cần kiểm tra bằng firmware bundle/release notes, không phải fact đã có trong advisory.
- Các vùng nên ưu tiên audit ở tuần 2 là WBM system configuration, import/export, network config, OpenVPN, MQTT Bridge, route/port config, update flow và privilege boundary từ WBM user tới root-level service.
