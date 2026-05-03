# Ngày 7 - Tổng kết tuần 1: Threat model v1 và checklist lab emulation

Tài liệu này chỉ dựa trên các nguồn trong thư mục `document`, không dựa trên code, config hay phân tích firmware trong workspace. Cấu trúc được chuẩn hóa theo dạng `Question -> Answer -> Evidence`.

Theo timeline trong `courses.txt`, Ngày 7 là ngày gom toàn bộ kiến thức nền của tuần 1 thành một `threat model` thân thiện với nghiên cứu. Mục tiêu không phải là viết hướng dẫn khai thác, mà là biến các thông tin đã học thành bản đồ có thể dùng cho tuần 2: phân tích firmware, dựng lab, quan sát service, kiểm tra update/config flow và lập checklist triage CVE một cách có hệ thống.

## Nguồn tài liệu dùng cho Ngày 7

- [courses.txt](/d:/CHARXSEC/document/courses.txt)
- [product_1139012_page.md](/d:/CHARXSEC/document/product_1139012_page.md)
- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md)
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html)
- [wiring_section.html](/d:/CHARXSEC/document/wiring_section.html)
- [application_configuration.html](/d:/CHARXSEC/document/application_configuration.html)
- [Maintenance_repair_and_disposal.html](/d:/CHARXSEC/document/Maintenance_repair_and_disposal.html)
- [Cybersecurity.html](/d:/CHARXSEC/document/Cybersecurity.html)
- [PCSA-2024-00002_SECURITY_ADVISORY.pdf](/d:/CHARXSEC/document/PCSA-2024-00002_SECURITY_ADVISORY.pdf)
- [PCSA-2024-00003_SECURITY_ADVISORY.pdf](/d:/CHARXSEC/document/PCSA-2024-00003_SECURITY_ADVISORY.pdf)
- [PCSA-2025-00015_VDE-2025-074.pdf](/d:/CHARXSEC/document/PCSA-2025-00015_VDE-2025-074.pdf)
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt)

## Câu hỏi 1

### Question

Theo timeline khóa học, Ngày 7 cần tạo ra những output nào?

### Answer

Trong `courses.txt`, Ngày 7 được đặt tên là `Tổng kết tuần 1`. Mục tiêu chính là gom toàn bộ kiến thức nền thành một `threat model thân thiện với nghiên cứu`. Timeline yêu cầu viết một trang gồm các nhóm nội dung:

- `attack surface map`
- `trusted boundaries`
- `privileged services`
- `update pipeline`
- `local vs remote management`
- kế hoạch emulation cho tuần 2

Output mong muốn gồm:

- `Threat model v1`
- `Checklist lab emulation`

Vì vậy, Day 7 đóng vai trò như cầu nối giữa tuần 1 và tuần 2. Tuần 1 đã thu thập bối cảnh từ product page, technical data, manual, WBM, wiring, OCPP, Modbus, MQTT, OpenVPN, System Control và security advisories. Tuần 2 sẽ chuyển sang firmware unpacking, service graph, API audit, emulation planning và CVE triage. Day 7 phải biến kiến thức rời rạc thành bản đồ nghiên cứu có thể hành động.

Điểm cần giữ rõ là `threat model` ở đây không phải danh sách cách tấn công. Nó là mô hình giúp trả lời các câu hỏi phòng thủ và nghiên cứu hợp pháp:

- tài sản nào cần bảo vệ?
- entry point nào có trong tài liệu chính thức?
- service nào có quyền cao hoặc chạm vào cấu hình hệ thống?
- boundary nào cần được kiểm tra khi phân tích firmware?
- cần mock thành phần nào khi emulate?
- dữ liệu nào cần log lại khi dựng lab?

### Evidence

- [courses.txt](/d:/CHARXSEC/document/courses.txt) ghi `Ngày 7: Tổng kết tuần 1`.
- [courses.txt](/d:/CHARXSEC/document/courses.txt) nêu mục tiêu là gom kiến thức nền thành `threat model thân thiện với nghiên cứu`.
- [courses.txt](/d:/CHARXSEC/document/courses.txt) yêu cầu thực hành gồm `attack surface map`, `trusted boundaries`, `privileged services`, `update pipeline`, `local vs remote management`.
- [courses.txt](/d:/CHARXSEC/document/courses.txt) yêu cầu output là `Threat model v1` và `Checklist lab emulation`.

## Câu hỏi 2

### Question

Những tài sản kỹ thuật nào của CHARX SEC-3100 cần đưa vào threat model v1?

### Answer

Threat model v1 nên bắt đầu từ danh sách tài sản cần bảo vệ, vì đây là cách tránh nhầm lẫn giữa `bề mặt tấn công` và `tài sản`. Với CHARX SEC-3100, các tài sản chính có thể rút ra từ tài liệu gồm:

| Tài sản | Ý nghĩa trong hệ thống | Lý do cần bảo vệ |
|---|---|---|
| Firmware của controller | Phần mềm chạy trên embedded Linux của charging controller | Nếu firmware bị thay đổi hoặc bị điều khiển sai, toàn bộ controller có thể bị ảnh hưởng |
| System configuration | Cấu hình Ethernet, port sharing, modem, MQTT bridge, OpenVPN, OCPP, load management | Advisory 2025 nêu rõ cấu hình hệ thống là điểm liên quan tới command injection mức root |
| Web-based Management | Giao diện cấu hình, giám sát, update, log, service status | Đây là mặt quản trị chính của thiết bị và xuất hiện trong điều kiện attacker của CVE-2025-41699 |
| Charging point configuration | Cấu hình charging mode, release mode, connector, OCPP, whitelist, load management | Ảnh hưởng trực tiếp tới hành vi sạc và quyền cho phép sạc |
| OCPP backend connection | Kênh giao tiếp với backend quản lý trạm sạc | Có thể tác động tới charge release, diagnostics, update và log |
| Modbus/TCP interface | Kênh đọc dữ liệu sạc và điều khiển charging process | Là giao diện runtime cần quản lý chặt trong mạng |
| MQTT/JupiCore data path | Kênh thu thập và forward dữ liệu charging point tới MQTT broker và service nội bộ/ngoài | Advisory 2024 từng có nhóm lỗi liên quan MQTT handler |
| OpenVPN configuration | Kênh tunnel tới OpenVPN server | Tác động tới routing, remote access và boundary giữa mạng nội bộ với mạng quản trị |
| USB-C/RNDIS commissioning path | Kênh cấu hình/chẩn đoán cục bộ qua USB-C | Là entry point vật lý phục vụ commissioning |
| Logs and diagnostics | Log hệ thống, log application, OCPP diagnostics | Chứa bằng chứng vận hành, phục vụ forensic và support |
| Certificates and credentials | Chứng chỉ OCPP/MQTT/OpenVPN, tài khoản WBM, user-app password | Nếu bị lộ hoặc cấu hình sai có thể làm suy yếu boundary xác thực |
| Update artifacts | Firmware update, application update, full system update | Ảnh hưởng trực tiếp tới tính toàn vẹn firmware |

Từ góc nhìn nghiên cứu firmware, tài sản quan trọng nhất không chỉ là `binary`. Tài sản quan trọng còn gồm cấu hình, file import/export, certificate, route/port state, service status, log, update metadata và state runtime của các protocol. Đây là các điểm mà tuần 2 cần inventory khi unpack firmware hoặc dựng lab.

### Evidence

- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) mô tả CHARX SEC-3100 là `AC charging controller`, thuộc family `CHARX control modular`, dùng `Embedded Linux system`.
- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) nêu các protocol gồm `OCPP 1.6J`, `Modbus/TCP`, `MQTT`, `HTTP`, `HTTPS`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả WBM có các phần System Control, Software, Log Files, Time, OpenVPN, MQTT Bridge, Modbus, OCPP và Load Management.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) liệt kê Import/Export configuration gồm charging park, whitelist, load management, OCPP, system configuration, MQTT bridge và OpenVPN.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) mô tả CVE-2025-41699 liên quan tới việc attacker có tài khoản WBM low-privileged thay đổi system configuration để dẫn tới command injection mức root.

## Câu hỏi 3

### Question

Attack surface map v1 của CHARX SEC-3100 nên được chia như thế nào?

### Answer

Attack surface map v1 nên chia theo cách một researcher có thể dựng lab và kiểm tra từng lớp. Dựa trên tài liệu chính thức, có thể chia thành sáu nhóm lớn:

| Nhóm bề mặt | Entry point hoặc kênh liên quan | Thành phần cần quan sát | Ghi chú nghiên cứu |
|---|---|---|---|
| Local commissioning | USB-C/RNDIS, Ethernet trực tiếp, Ethernet qua router | WBM, network discovery, DHCP/BootP, RNDIS gadget | Dùng để đưa thiết bị vào trạng thái cấu hình ban đầu |
| Web management | HTTP/HTTPS, WBM pages, port sharing, System Control | Web Server, JupiCore, system configuration, logs, software update | Bề mặt quản trị trung tâm, liên quan trực tiếp advisory 2025 |
| Backend/remote operation | OCPP 1.6J, cellular, Ethernet, OpenVPN | OCPP agent, backend URL, certificates, diagnostics, update | Điều khiển từ backend và remote management |
| Data/control protocols | Modbus/TCP, MQTT, MQTT Bridge, JupiCore | Modbus Server/Client, MQTT broker, topic forwarding | Có cả đọc dữ liệu, điều khiển charging process và forwarding dữ liệu |
| Field/hardware interfaces | RS-485 meter, RS-485 RFID reader, digital inputs/outputs, CP/PP, locking actuator, contactor, CAN/backplane | Controller Agent, charging point runtime, extension modules | Khó emulate hoàn chỉnh, cần mock hoặc stub |
| Update/config/log flow | Software update, application update, full system update, import/export config, log download | System Control, firmware bundle, config archive, diagnostics | Cần kiểm tra tính toàn vẹn, quyền truy cập và dữ liệu nhạy cảm |

Map này giúp tránh một lỗi phổ biến khi học firmware: chỉ nhìn vào web UI hoặc binary mà quên rằng thiết bị sạc EV có nhiều boundary vật lý và protocol. CHARX SEC-3100 không chỉ là một web server nhúng. Nó là charging controller có embedded Linux, giao tiếp backend, mạng Ethernet/cellular, bus phần cứng, role client/server, quản lý tải và luồng cập nhật.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả các cách truy cập SEC-3xxx gồm USB-C, Ethernet network với router và Ethernet trực tiếp từ máy tính.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu USB-C yêu cầu RNDIS driver và thiết bị xuất hiện như `Network, USB Ethernet/RNDIS Gadget`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả WBM có các phần OCPP, Modbus, Load Management, Network/OpenVPN, MQTT Bridge và System Control.
- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) nêu thiết bị có hai Ethernet interfaces, USB-C cho configuration/diagnostics, 4G/2G, RS-485 cho energy meter và RFID reader.
- [Maintenance_repair_and_disposal.html](/d:/CHARXSEC/document/Maintenance_repair_and_disposal.html) mô tả update có thể thực hiện cục bộ qua WBM hoặc qua backend bằng OCPP.

## Câu hỏi 4

### Question

Trusted boundaries quan trọng nhất trong threat model v1 là gì?

### Answer

`Trusted boundary` là ranh giới nơi dữ liệu, quyền hoặc giả định tin cậy thay đổi. Với CHARX SEC-3100, threat model v1 nên ghi nhận ít nhất các boundary sau:

| Boundary | Hai phía của boundary | Vì sao quan trọng |
|---|---|---|
| User/WBM role boundary | Người dùng WBM và chức năng quản trị | CVE-2025-41699 nói tới low-privileged remote attacker có tài khoản WBM |
| WBM/system configuration boundary | Form cấu hình trên WBM và thao tác hệ thống bên dưới | Nếu input cấu hình đi tới lệnh hệ thống hoặc file cấu hình đặc quyền, đây là boundary rủi ro cao |
| Local network/device boundary | Host trong LAN và service mở trên controller | Advisory khuyến nghị closed network và firewall cho network-enabled devices |
| USB-C/RNDIS boundary | Máy tính commissioning và network gadget của controller | Là đường truy cập cục bộ tiện lợi, cần coi như một network interface |
| OCPP backend/controller boundary | Backend quản lý và OCPP agent trên thiết bị | Backend có thể ảnh hưởng charge release, diagnostics và update |
| MQTT broker/local service boundary | Remote MQTT broker, MQTT Bridge và broker/topic cục bộ | Topic forwarding có thể chuyển dữ liệu giữa môi trường local và remote |
| OpenVPN tunnel/routing boundary | Mạng nội bộ của controller và remote VPN network | OpenVPN có thể thay đổi routing hoặc tạo đường quản trị từ xa |
| Modbus client/server boundary | Modbus peer và dữ liệu/điều khiển charging process | Modbus Server cho phép đọc charging data và điều khiển charging process |
| Firmware update boundary | Update artifact và runtime firmware đang chạy | Update thay đổi code và application, nên là boundary toàn vẹn rất quan trọng |
| Import/export configuration boundary | File cấu hình bên ngoài và cấu hình nội bộ | File import/export có thể chạm vào nhiều domain cấu hình khác nhau |
| Hardware field boundary | Meter, RFID, contactor, CP/PP, digital I/O và logic charging | Dữ liệu vật lý đi vào firmware và ảnh hưởng trạng thái runtime |

Trong tuần 2, mỗi boundary nên được chuyển thành câu hỏi kiểm tra. Ví dụ:

- input từ WBM được validate ở đâu?
- cấu hình nào cuối cùng trở thành command argument, file config, environment variable hoặc IPC message?
- service nào chấp nhận request trước khi firewall hoặc auth state hoàn tất?
- update package được xác thực ở bước nào?
- OpenVPN/MQTT/OCPP certificate được lưu, đọc và sử dụng bởi service nào?

Những câu hỏi này không cần payload khai thác. Chúng là cách dựng đường đi dữ liệu để phục vụ audit và emulation có kiểm soát.

### Evidence

- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) nêu attacker low-privileged có tài khoản WBM có thể thay đổi system configuration để gây command injection mức root.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu USB-C là cách truy cập ưu tiên vì tránh hạn chế Ethernet và thiết bị xuất hiện dưới dạng RNDIS gadget.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả OCPP backend có thể cấp hoặc thu hồi release khi charging point được cấu hình `By OCPP`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả MQTT Bridge forward topic giữa local MQTT broker và remote MQTT broker.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả OpenVPN có trạng thái connected/not connected, server IP, private IP, activation mode và tùy chọn routing.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả Modbus Server cung cấp interface để đọc charging data và điều khiển charging processes.
- [Maintenance_repair_and_disposal.html](/d:/CHARXSEC/document/Maintenance_repair_and_disposal.html) mô tả update firmware/application/system có thể thực hiện cục bộ hoặc qua backend.

## Câu hỏi 5

### Question

Những privileged services nào cần được đưa vào bản đồ nghiên cứu?

### Answer

Tài liệu WBM không cung cấp đầy đủ tên binary, systemd unit hoặc init script. Vì vậy, Day 7 không nên tự suy diễn tên file/process. Tuy nhiên, tài liệu chính thức có liệt kê các software services/applications trong `System Control/Status`. Đây là danh sách nền để tuần 2 đi tìm binary và service definition tương ứng trong firmware.

| Service/Application theo manual | Vai trò theo tài liệu | Lý do cần ưu tiên nghiên cứu |
|---|---|---|
| System Monitor | Cung cấp dữ liệu hệ thống như network status, memory, modem | Chạm vào trạng thái hệ điều hành và hạ tầng mạng |
| Controller Agent | Chuẩn hóa interface giữa local charging controllers, clients qua Ethernet và extension modules | Nằm gần hardware/charging control và từng liên quan nhóm advisory 2024 qua ControllerAgent/HomePlug |
| OCPP 1.6J | Giao tiếp backend | Tác động tới release, diagnostics, backend connection và remote operation |
| Modbus Client | Kết nối Modbus/TCP meters qua Ethernet | Nhận dữ liệu từ thiết bị mạng bên ngoài |
| Modbus Server | Modbus/TCP interface để đọc charging data và điều khiển charging process | Là interface điều khiển runtime |
| JupiCore | Thu thập dữ liệu từ connected charging points và forward tới MQTT broker, internal services, external REST API | Là hub dữ liệu nội bộ/ngoài, liên quan MQTT/REST |
| Load Management | Local load and charging management | Quyết định phân phối dòng và trạng thái charging park |
| Web Server | Web-based management | Cổng quản trị, log, update, config, user/session |
| Calibration Law Agent | Hiển thị khi active, phục vụ compliance calibration law | Có tính chất policy/compliance, cần hiểu khi firmware bật chế độ này |

Trong threat model v1, `privileged` không chỉ có nghĩa là service chạy với quyền root. Vì tài liệu không cho biết UID/GID runtime, ta nên dùng nghĩa rộng hơn: service nào có khả năng tác động mạnh tới hệ thống, cấu hình, mạng, update, hoặc trạng thái sạc. Tuần 2 mới là lúc xác nhận service nào thật sự chạy với quyền gì.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `System Control/Status` cung cấp thông tin về embedded Linux system và software services/applications.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) liệt kê `System Monitor`, `Controller Agent`, `OCPP 1.6J`, `Modbus Client`, `Modbus Server`, `JupiCore`, `Load Management`, `Web Server` và `Calibration Law Agent`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả có thể restart individual programs trong application overview.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `REBOOT SYSTEM` sẽ restart toàn bộ hệ thống và terminate active charging processes.

## Câu hỏi 6

### Question

Local management và remote management của CHARX SEC-3100 khác nhau như thế nào?

### Answer

Threat model v1 nên tách rõ `local management` và `remote management`, vì mỗi loại có điều kiện truy cập, boundary và rủi ro khác nhau.

| Loại quản trị | Kênh truy cập | Tác vụ chính | Boundary cần chú ý |
|---|---|---|---|
| Local qua USB-C/RNDIS | USB-C từ máy tính commissioning | Truy cập WBM, cấu hình/chẩn đoán, tránh hạn chế Ethernet | Máy tính local trở thành network peer của controller |
| Local qua Ethernet/router | ETH0 trong mạng có DHCP/router | Truy cập WBM trong LAN, commissioning, cấu hình | Phụ thuộc firewall, port sharing, segmentation |
| Local qua Ethernet trực tiếp | Máy tính nối trực tiếp controller, có thể cần BootP/DHCP server | Cấu hình khi không có router | DHCP/static addressing là một phần của lab setup |
| Remote qua OCPP backend | OCPP 1.6J qua Ethernet hoặc cellular | Charge release, backend management, diagnostics, update | Backend được tin cậy để điều phối charge point |
| Remote qua OpenVPN | VPN tunnel tới OpenVPN server | Remote network access, routing, test connection, on-request activation | VPN mở boundary giữa mạng controller và mạng quản trị |
| Remote qua MQTT Bridge | Topic forwarding giữa local broker và remote broker | Forward dữ liệu hoặc trạng thái như VPN connection state | Topic direction và certificate validation là điểm cần kiểm tra |
| Remote qua Modbus/TCP | Modbus peer trên mạng | Đọc charging data, điều khiển charging process | Cần đóng/mở port theo nhu cầu thực tế |

Một kết luận quan trọng: tài liệu Phoenix Contact liên tục nhấn mạnh khuyến nghị vận hành trong closed industrial networks và firewall phù hợp. Điều đó cho thấy threat model không nên giả định thiết bị được phơi trực tiếp ra Internet. Thay vào đó, lab nên mô phỏng các kịch bản hợp lý hơn:

- attacker hoặc researcher nằm trong LAN được kiểm soát
- attacker có tài khoản WBM low-privileged trong phạm vi lab
- backend/OCPP peer hoặc MQTT broker được mock
- OpenVPN/Modbus được dựng trong mạng lab tách biệt
- port sharing được kiểm tra như một control phòng thủ

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu access to SEC-3xxx có thể qua USB-C, Ethernet network với router hoặc Ethernet trực tiếp.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu ETH0 factory default dùng dynamic address qua DHCP.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu Ethernet trực tiếp có thể cần gán IP qua BootP/DHCP server.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả OCPP backend connection, OpenVPN connection và MQTT Bridge.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) khuyến nghị dùng thiết bị trong closed networks và protected by suitable firewall.

## Câu hỏi 7

### Question

Port exposure map nào nên dùng cho tuần 2?

### Answer

Manual có phần `Network/Port Sharing` cho phép block từng incoming port để ngăn truy cập từ network bên ngoài. Đây là nguồn rất quan trọng để dựng port exposure map ban đầu. Bảng dưới đây nên được dùng làm baseline cho tuần 2:

| Port | Tên trong manual | Ý nghĩa nghiên cứu |
|---|---|---|
| 22 | SSH Access | Cần xác nhận có mở trong lab hay không, role/account nào dùng được |
| 80 | HTTP Access | WBM hoặc redirect/access layer không mã hóa |
| 81 | Custom Website | Bề mặt web tùy biến nếu được bật |
| 443 | HTTPS Access | WBM hoặc web access qua TLS |
| 502 | MODBUS Server | Modbus/TCP requests, liên quan đọc/điều khiển charging process |
| 1603 | Frame data for load management | Dữ liệu frame phục vụ load management |
| 1883 | MQTT | Broker/topic surface |
| 2106 | OCPP Remote | Bề mặt OCPP remote theo tài liệu |
| 5000 | Web Server | Web server/application backend cần inventory |
| 5353 | mDNS | Discovery trong local network |
| 5555 | Jupicore accesses | Manual nêu WBM full functions cần port này |
| 9502 | MODBUS Client Configuration | Cấu hình Modbus Client |

Port exposure map không thay thế việc scan trong lab. Nó là baseline từ tài liệu. Khi có firmware hoặc thiết bị, tuần 2 cần đối chiếu:

- port nào bind trên interface nào?
- port nào chỉ listen trên localhost, LAN, USB/RNDIS hoặc VPN?
- port nào bị port sharing chặn/mở?
- service nào đứng sau từng port?
- auth được kiểm tra ở layer web, service backend hay IPC?
- sau reboot, thứ tự bind port và firewall state thay đổi thế nào?

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `Network/Port Sharing` cho phép block individual incoming ports để ngăn external network access.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) khuyến nghị close các port không required.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) liệt kê các port 22, 80, 81, 443, 502, 1603, 1883, 2106, 5000, 5353, 5555 và 9502.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu WBM full functions require port `5555` và có thể tạm mở nếu WBM chỉ dùng occasionally.

## Câu hỏi 8

### Question

Update pipeline của CHARX SEC-3100 nên được mô hình hóa ra sao?

### Answer

Update pipeline trong threat model v1 nên chia thành ba lớp: `nguồn update`, `đường đưa update vào thiết bị`, và `đối tượng được update`.

| Lớp | Nội dung | Điểm cần kiểm tra ở tuần 2 |
|---|---|---|
| Nguồn update | Firmware/application/system update từ Phoenix Contact hoặc backend quản lý | Metadata, version, signature/integrity nếu có trong bundle |
| Đường update | WBM local hoặc OCPP backend qua Ethernet/cellular | Auth, authorization, transport, log, rollback/failure handling |
| Đối tượng update | Individual app programs, charging controller firmware, complete system update | Service bị restart, config migration, version floor |

Tài liệu maintenance nói có thể update individual software programs hoặc complete software update. Update có thể làm local qua WBM hoặc qua backend sử dụng OCPP. Với backend update qua cellular, tài liệu cảnh báo full update có thể làm tăng chi phí do data volume; đôi khi chỉ cần update individual applications.

Trong threat model, update pipeline là boundary toàn vẹn cao vì nó thay đổi code chạy trên controller. Các advisory cũng cho thấy update và version floor là phần phải kiểm soát:

- Advisory 2024 VDE-2024-022 fixed tại firmware `1.6.3`.
- Advisory 2025 VDE-2025-074 fixed tại firmware `1.7.4`.
- Firmware `<1.7.4` trên SEC-3100 item `1139012` affected bởi CVE-2025-41699.

Khi sang tuần 2, không nên giả định ngay update format hoặc cơ chế signature nếu chưa có firmware bundle. Checklist đúng là:

- lấy firmware bundle chính thức
- inventory package structure
- xác định file manifest/version
- xác định script update/migration nếu có
- kiểm tra đường gọi từ WBM/OCPP tới update handler
- kiểm tra log khi update thành công/thất bại
- so sánh thay đổi giữa version lab và fixed version nếu có đủ bundle

### Evidence

- [Maintenance_repair_and_disposal.html](/d:/CHARXSEC/document/Maintenance_repair_and_disposal.html) mô tả software update có thể update individual software programs hoặc complete software update.
- [Maintenance_repair_and_disposal.html](/d:/CHARXSEC/document/Maintenance_repair_and_disposal.html) nêu update có thể thực hiện local qua WBM hoặc backend sử dụng OCPP.
- [Maintenance_repair_and_disposal.html](/d:/CHARXSEC/document/Maintenance_repair_and_disposal.html) lưu ý full update qua cellular có thể gây thêm chi phí do data volume và có thể chỉ cần application update.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu nên vận hành với latest firmware và quan sát change notes khi update.
- [PCSA-2024-00003_SECURITY_ADVISORY.pdf](/d:/CHARXSEC/document/PCSA-2024-00003_SECURITY_ADVISORY.pdf) nêu remediation là upgrade affected controllers lên firmware `1.6.3` hoặc cao hơn.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) nêu remediation là upgrade lên firmware `1.7.4` để fix CVE-2025-41699.

## Câu hỏi 9

### Question

Những bài học nào từ security advisories 2024 cần đưa vào threat model v1?

### Answer

Nhóm security advisories 2024 cho thấy nhiều pattern lỗi lịch sử cần chuyển thành checklist audit, không phải thành hướng dẫn exploit. Có thể tóm tắt thành các nhóm root cause sau:

| Nhóm pattern | Mô tả ở mức threat model | Boundary liên quan |
|---|---|---|
| Script upload/config handling | Chức năng upload hoặc thay đổi cấu hình có thể dẫn tới thực thi lệnh nếu kiểm soát input yếu | WBM/config/system boundary |
| Firewall/startup race | Trong một khoảng thời gian sau boot, internal service hoặc file có thể bị truy cập trước khi firewall/control sẵn sàng | Boot sequence/network boundary |
| Default/credential reset | Firmware update feature từng liên quan tới reset password low-privileged về default | Update/auth boundary |
| File permission/exposure | File hoặc directory có thể accessible/writable trong thời điểm không mong muốn | Filesystem/service boundary |
| MQTT handler memory issues | MQTT handler từng có lỗi improper input validation dẫn tới memory read/write và RCE | MQTT broker/service boundary |
| HomePlug/ControllerAgent issues | Malformed HomePlug packets từng làm crash ControllerAgent và có use-after-free path | Field protocol/controller boundary |
| OCPP cleartext/MITM risk | OCPP 1.6J có advisory về thiếu mã hóa dữ liệu nhạy cảm trong một tình huống MITM | Backend/controller boundary |

Điểm quan trọng là những advisory này không nhất thiết nói firmware hiện tại vẫn lỗi. Chúng cung cấp lịch sử hardening và mẫu kiểm tra:

- kiểm tra mọi đường upload/import/config
- kiểm tra state trong boot window
- kiểm tra account reset/migration khi update
- kiểm tra quyền file tạm và config file
- kiểm tra parser của protocol message
- kiểm tra transport security và certificate handling
- kiểm tra service crash có dẫn tới restart loop hoặc state inconsistent không

### Evidence

- [PCSA-2024-00002_SECURITY_ADVISORY.pdf](/d:/CHARXSEC/document/PCSA-2024-00002_SECURITY_ADVISORY.pdf) mô tả nhiều vulnerability trong CHARX SEC-3xxx firmware, gồm script upload, configuration modification, firewall rule, MQTT handler và HomePlug/ControllerAgent related issues.
- [PCSA-2024-00002_SECURITY_ADVISORY.pdf](/d:/CHARXSEC/document/PCSA-2024-00002_SECURITY_ADVISORY.pdf) nêu affected SEC-3100 item `1139012` với firmware version `<=1.5.0`.
- [PCSA-2024-00002_SECURITY_ADVISORY.pdf](/d:/CHARXSEC/document/PCSA-2024-00002_SECURITY_ADVISORY.pdf) ghi một số issue có thể dẫn tới RCE hoặc complete compromise khi chained.
- [PCSA-2024-00003_SECURITY_ADVISORY.pdf](/d:/CHARXSEC/document/PCSA-2024-00003_SECURITY_ADVISORY.pdf) mô tả firewall service start sequence issue và password reset về default trong firmware upgrade context.
- [PCSA-2024-00003_SECURITY_ADVISORY.pdf](/d:/CHARXSEC/document/PCSA-2024-00003_SECURITY_ADVISORY.pdf) nêu CVE-2024-3913 liên quan file writable/accessibility trong thời gian ngắn sau startup và CVE-2024-6788 liên quan reset password low-privileged `user-app`.

## Câu hỏi 10

### Question

Advisory 2025 bổ sung gì cho threat model so với nhóm advisory 2024?

### Answer

Advisory 2025 làm threat model sắc hơn ở boundary giữa `WBM account`, `system configuration` và `root-level command execution`. Nếu nhóm advisory 2024 cho thấy nhiều lớp lỗi lịch sử ở upload, firewall, boot, MQTT, HomePlug và update, thì advisory 2025 chỉ ra một pattern mới hơn:

- attacker là remote attacker
- attacker có account WBM low-privileged
- attacker có thể thay đổi system configuration
- hậu quả là command injection chạy ở mức root
- ảnh hưởng là mất confidentiality, integrity và availability
- fixed version là firmware `1.7.4`

Điều này tạo ra một câu hỏi trọng tâm cho tuần 2:

Khi WBM hoặc backend thay đổi system configuration, dữ liệu cấu hình đi qua những service nào trước khi trở thành file, command, restart action hoặc system state?

Câu hỏi này cần được trả lời bằng service graph và data-flow graph, không phải bằng phỏng đoán. Khi có firmware, cần tìm:

- route hoặc handler của system configuration
- schema/validation của input
- nơi ghi file cấu hình
- nơi gọi restart service hoặc shell command nếu có
- khác biệt quyền giữa low-privileged WBM user và admin
- log/audit trail của thay đổi cấu hình

### Evidence

- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) nêu CVE-2025-41699 có CVSSv3.1 base score `8.8`, severity `High`.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) mô tả low-privileged remote attacker có tài khoản WBM có thể thay đổi system configuration để thực hiện command injection as root.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) nêu impact là total loss of confidentiality, integrity and availability.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) nêu firmware `<1.7.4` trên CHARX SEC-3100 affected và firmware `1.7.4` fixed.

## Câu hỏi 11

### Question

Configuration import/export có vai trò gì trong threat model?

### Answer

Configuration import/export là một boundary quan trọng vì nó đưa dữ liệu có cấu trúc từ bên ngoài vào nhiều domain nội bộ của controller. Manual liệt kê nhiều nhóm cấu hình có thể import/export:

- charging park
- CHARX RFID/NFC config
- whitelist
- load management
- OCPP
- system configuration, gồm Ethernet, port sharing, modem
- MQTT bridge
- OpenVPN

Điểm đáng chú ý là các domain này chạm vào nhiều vùng rủi ro khác nhau:

- `charging park` ảnh hưởng topology server/client và charging point
- `whitelist` ảnh hưởng authorization local
- `load management` ảnh hưởng phân phối dòng
- `OCPP` ảnh hưởng backend URL, certificate và release behavior
- `system configuration` ảnh hưởng Ethernet, port sharing và modem
- `MQTT bridge` ảnh hưởng topic forwarding và remote broker
- `OpenVPN` ảnh hưởng tunnel, routing và activation mode

Do đó, trong tuần 2, import/export nên được kiểm tra như một luồng dữ liệu cấp cao:

- file format là gì?
- có schema hoặc validation không?
- import có restart service nào không?
- quyền nào được import domain nào?
- export có lộ secret, certificate hoặc password không?
- import lỗi có rollback không?
- log có ghi đủ context để forensic không?

Đây là kiểm tra phòng thủ quan trọng vì advisory 2025 đã chỉ ra system configuration là nơi có thể dẫn tới command injection nếu kiểm soát input không đủ tốt.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) liệt kê Import/Export configuration gồm charging park, CHARX RFID/NFC config, whitelist, load management, OCPP, system configuration, MQTT bridge và OpenVPN.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả system configuration bao gồm Ethernet, port sharing và modem.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) mô tả CVE-2025-41699 liên quan tới thay đổi system configuration dẫn tới command injection as root.

## Câu hỏi 12

### Question

Log Files và diagnostics nên được dùng như thế nào trong lab emulation?

### Answer

Log Files và diagnostics là kênh quan sát chính khi dựng lab. Manual mô tả chức năng `DOWNLOAD LOGS`, log được nén lại và cũng có thể được truy cập thông qua OCPP `GetDiagnostics`. Vì vậy, log vừa là công cụ debug, vừa là tài sản cần bảo vệ.

Trong lab, log nên được dùng để trả lời các câu hỏi:

- service nào khởi động trước/sau?
- port nào mở trước khi firewall hoặc auth state ổn định?
- khi thay đổi cấu hình, service nào restart?
- khi OCPP/MQTT/OpenVPN/Modbus lỗi, log ghi gì?
- khi import/export hoặc update thất bại, có rollback hoặc lỗi rõ ràng không?
- log có vô tình chứa secret, token, password, certificate material hoặc backend URL nhạy cảm không?

Về mặt threat model, log nằm giữa hai nhu cầu:

- cần đủ chi tiết để hỗ trợ vận hành, support và forensic
- không nên lộ dữ liệu nhạy cảm nếu user low-privileged hoặc remote attacker có thể download log

Trong tuần 2, khi emulate hoặc chạy lab, nên lưu lại log theo mốc:

- baseline sau boot
- sau login WBM
- sau thay đổi port sharing
- sau thay đổi OCPP/MQTT/OpenVPN
- sau import/export config
- sau update thử nghiệm trong môi trường hợp pháp
- sau reboot

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `System Control/Log Files` có chức năng `DOWNLOAD LOGS`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu logs được compressed.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu logs cũng có thể được truy cập qua OCPP `GetDiagnostics`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu OCPP messages list hiển thị last 50 messages và older messages có trong logs qua System Control/Log Files.

## Câu hỏi 13

### Question

Threat model v1 tổng hợp nên trông như thế nào?

### Answer

Bảng sau là `Threat model v1` của tuần 1. Đây là baseline để tuần 2 chuyển sang firmware inventory, service graph và emulation.

| Component/Domain | Entry point | Trusted boundary | Known risk pattern từ tài liệu | Câu hỏi lab đầu tiên |
|---|---|---|---|---|
| WBM/Web Server | HTTP/HTTPS, ports 80/443/5000, port 5555 cho WBM full functions | User role -> system action | Advisory 2025: WBM low-privileged account + system configuration -> command injection as root | Route nào thay đổi system configuration và quyền nào được gọi? |
| System configuration | WBM, import/export, port sharing, modem, Ethernet | Config input -> privileged service/file/command | Advisory 2025, advisory 2024 config modification/RCE pattern | Config được validate, lưu và apply ở đâu? |
| OCPP 1.6J | Backend URL, network interface, certificates, port 2106 | Backend -> controller | Release control, diagnostics, update, transport security issue trong advisory 2024 | OCPP agent nhận config và restart như thế nào? |
| Modbus/TCP | Port 502, Modbus Client/Server, port 9502 config | Network peer -> charging process | Runtime read/control surface | Register map và auth/network restriction được áp dụng ở đâu? |
| MQTT/JupiCore | Port 1883, MQTT Bridge, topic forwarding | Remote broker -> local broker/service | Advisory 2024 MQTT handler memory issue pattern | Topic nào được bridge và parser nào xử lý message? |
| OpenVPN | VPN config, activation mode, routing | Remote VPN network -> controller network | Routing and remote access boundary | Config import khác manual entry ra sao về secret visibility? |
| Load Management | WBM, frame data port 1603, charging point list | Policy/config -> current distribution | Safety/availability impact nếu config sai | Current allocation được tính bởi service nào và log ra sao? |
| Controller Agent/field interfaces | Backplane, clients, extension modules, HomePlug/vehicle side context | Physical/protocol input -> charging control | Advisory 2024 HomePlug/ControllerAgent crash/RCE pattern | Hardware dependency nào cần mock để service chạy được? |
| USB-C/RNDIS | USB-C commissioning network | Physical access -> network peer | Local commissioning bypasses Ethernet restrictions | RNDIS interface expose port nào so với ETH0? |
| Update pipeline | WBM, OCPP backend, firmware/application package | Update artifact -> executable code | 2024 update/password reset pattern, version floors 1.6.3/1.7.4 | Update handler xác thực package và migrate config thế nào? |
| Logs/Diagnostics | WBM log download, OCPP GetDiagnostics | Diagnostic access -> sensitive operational data | Potential information disclosure if logs expose secrets | Log có chứa secret/config nhạy cảm không? |

Bảng này nên được coi là version 1. Khi có firmware bundle hoặc thiết bị thật, tuần 2 sẽ cập nhật thành `Threat model v2` bằng dữ liệu quan sát:

- process thật
- binary thật
- config file thật
- route/API thật
- open port thật
- log thật
- update scripts thật

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả WBM, OCPP, Modbus, MQTT Bridge, OpenVPN, Load Management, System Control, Log Files và Software Update.
- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) nêu thiết bị là embedded Linux system với OCPP 1.6J, Modbus/TCP, MQTT, HTTP và HTTPS.
- [PCSA-2024-00002_SECURITY_ADVISORY.pdf](/d:/CHARXSEC/document/PCSA-2024-00002_SECURITY_ADVISORY.pdf) cung cấp các pattern lịch sử liên quan script upload, config, firewall rule, MQTT handler và HomePlug/ControllerAgent.
- [PCSA-2024-00003_SECURITY_ADVISORY.pdf](/d:/CHARXSEC/document/PCSA-2024-00003_SECURITY_ADVISORY.pdf) cung cấp pattern boot-time firewall/service exposure và password reset trong firmware update.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) cung cấp pattern WBM low-privileged account, system configuration và command injection as root.

## Câu hỏi 14

### Question

Checklist lab emulation cho tuần 2 nên gồm những gì?

### Answer

Checklist lab emulation cần biến threat model thành các bước chuẩn bị có thể thực hiện được. Mục tiêu của emulation không phải mô phỏng hoàn hảo toàn bộ trạm sạc ngay từ đầu. Mục tiêu thực tế hơn là chạy được đủ thành phần để quan sát data flow, service behavior, config handling và update/log flow.

Checklist đề xuất:

| Nhóm việc | Việc cần làm | Kết quả mong muốn |
|---|---|---|
| Firmware inventory | Lấy firmware bundle chính thức, unpack, phân loại rootfs, app bundle, manifest, version file | Bảng file -> role -> risk |
| Service discovery | Tìm init scripts, service definitions, binary, web backend, frontend assets, IPC/socket | Service graph ban đầu |
| Web/API mapping | Đối chiếu WBM function với route/API trong firmware hoặc catalog | API inventory theo domain |
| Network emulation | Tạo network namespace/container hoặc QEMU network cho ETH0, RNDIS-like interface, VPN test network | Môi trường tách biệt, quan sát port bind |
| Mock OCPP backend | Dựng backend mock đủ để nhận connection, log message, test config/restart behavior | Quan sát OCPP agent mà không cần backend thật |
| Mock MQTT broker | Dựng local/remote broker mock, topic allowlist, certificate test nếu cần | Quan sát MQTT Bridge/JupiCore behavior |
| Mock Modbus peers | Dựng Modbus server/client giả cho meter hoặc peer | Test parsing/config without field hardware |
| Mock hardware dependency | Stub RS-485 meter, RFID reader, CAN/backplane, CP/PP, digital I/O nếu service cần | Giảm crash do thiếu phần cứng |
| Log capture | Thu system/application logs trước/sau mỗi hành động | Timeline hành vi có bằng chứng |
| Update dry-run analysis | Phân tích update package offline trước khi chạy trong lab | Hiểu manifest/script/migration |
| Config import/export tests | Tạo file cấu hình hợp lệ và lỗi nhẹ để quan sát validation | Xác định schema, rollback, log |
| Permission model | Tạo test matrix theo role WBM nếu lab hợp pháp có account | Map chức năng theo quyền |
| Version comparison | So sánh version lab với fixed floors `1.6.3` và `1.7.4` | Biết advisory nào còn cần kiểm tra |

Nguyên tắc thực tế: bắt đầu từ `service replay` và `config flow` trước, rồi mới tiến tới emulation sâu hơn. Với thiết bị kiểu charging controller, nhiều service có thể phụ thuộc hardware hoặc bus vật lý. Nếu cố emulate toàn hệ thống quá sớm, lab dễ bị kẹt ở lỗi thiếu device node thay vì trả lời câu hỏi nghiên cứu.

### Evidence

- [courses.txt](/d:/CHARXSEC/document/courses.txt) nêu tuần 2 gồm firmware unpacking, filesystem inventory, service graph, API audit, emulation planning, boot/startup instrumentation, update pipeline và CVE candidate triage.
- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) nêu thiết bị dùng embedded Linux system và có nhiều interface/protocol như Ethernet, USB-C, RS-485, OCPP, Modbus/TCP, MQTT, HTTP và HTTPS.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả các service trong System Control/Status, các protocol OCPP/Modbus/MQTT/OpenVPN và Log Files.
- [wiring_section.html](/d:/CHARXSEC/document/wiring_section.html) cung cấp bối cảnh field interfaces và wiring cần cân nhắc khi mock phần cứng.

## Câu hỏi 15

### Question

Khi sang tuần 2, cần tránh những suy diễn nào từ tài liệu tuần 1?

### Answer

Threat model v1 chỉ dựa trên tài liệu chính thức, nên nó có giới hạn rõ ràng. Cần tránh các suy diễn sau:

- Không suy diễn tên binary, path config, systemd unit hoặc user runtime nếu tài liệu không nêu.
- Không coi port list trong manual là trạng thái port thật trong mọi firmware version; cần scan và đối chiếu trong lab.
- Không giả định một service chạy root chỉ vì nó có chức năng mạnh; cần xác nhận bằng firmware/runtime.
- Không giả định update package có hoặc không có signature nếu chưa phân tích bundle.
- Không dùng advisory để suy ra payload khai thác; advisory chỉ cho root cause class và affected/fixed version.
- Không coi lỗi lịch sử 2024 là còn tồn tại trên firmware fixed; phải kiểm tra version và patch status.
- Không coi WBM là bề mặt duy nhất; field bus, MQTT, Modbus, OCPP, VPN, USB-C/RNDIS và update cũng là boundary quan trọng.
- Không bỏ qua vận hành an toàn: thiết bị charging controller có thể điều khiển quá trình sạc, contactor, locking actuator và load management, nên lab phải tách biệt khỏi hạ tầng thật.

Nguyên tắc tuần 2 là: tài liệu cho câu hỏi, firmware/lab cho câu trả lời xác nhận. Mỗi hypothesis phải được gắn với evidence:

- evidence từ manual/advisory
- evidence từ file inventory
- evidence từ service graph
- evidence từ runtime log
- evidence từ network trace trong lab

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả service/application ở mức chức năng nhưng không cung cấp đầy đủ binary path hoặc UID runtime.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) liệt kê port sharing nhưng trạng thái thực tế phụ thuộc cấu hình và môi trường.
- [Maintenance_repair_and_disposal.html](/d:/CHARXSEC/document/Maintenance_repair_and_disposal.html) mô tả update flow ở mức vận hành, không mô tả chi tiết package internals hoặc signature scheme.
- [PCSA-2024-00002_SECURITY_ADVISORY.pdf](/d:/CHARXSEC/document/PCSA-2024-00002_SECURITY_ADVISORY.pdf) và [PCSA-2024-00003_SECURITY_ADVISORY.pdf](/d:/CHARXSEC/document/PCSA-2024-00003_SECURITY_ADVISORY.pdf) mô tả vulnerabilities lịch sử và remediation, không cung cấp payload khai thác.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) mô tả CVE-2025-41699 ở mức advisory, affected/fixed version và mitigation/remediation, không cung cấp endpoint hoặc payload cụ thể.

## Kết luận Ngày 7

Ngày 7 chuyển toàn bộ kiến thức tuần 1 thành hai sản phẩm thực dụng:

- `Threat model v1`: bản đồ tài sản, entry point, trusted boundary, privileged services, update/config flow và known risk patterns từ advisory.
- `Checklist lab emulation`: danh sách việc cần làm cho tuần 2 để inventory firmware, dựng service graph, mock OCPP/MQTT/Modbus/hardware dependency, capture log và kiểm tra update/config flow.

Điểm lõi của Day 7 là giữ nghiên cứu ở trạng thái có kỷ luật: mọi giả thuyết phải quay về evidence trong tài liệu, rồi được xác nhận bằng firmware/lab ở tuần 2. Không nhảy thẳng từ advisory sang exploit; hãy đi qua threat model, service graph, data flow, log và version comparison trước.
