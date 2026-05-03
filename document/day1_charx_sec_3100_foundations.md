# Ngày 1 - Tổng quan hệ thống CHARX SEC-3100

Tài liệu này chỉ dựa trên các nguồn trong thư mục `document`, không dựa trên code, config hay phân tích firmware trong workspace. Cấu trúc được chuẩn hóa theo dạng `Question -> Answer -> Evidence`.

## Nguồn tài liệu dùng cho Ngày 1

- [product_1139012_page.md](/d:/CHARXSEC/document/product_1139012_page.md)
- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md)
- [CHARX_control_modular_AC_-_Cover.html](/d:/CHARXSEC/document/CHARX_control_modular_AC_-_Cover.html)
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html)
- [CHARX_help_home.html](/d:/CHARXSEC/document/CHARX_help_home.html)
- [Cybersecurity.html](/d:/CHARXSEC/document/Cybersecurity.html)

## Câu hỏi 1

### Question

`CHARX SEC-3100` là thiết bị gì, và nó nằm ở đâu trong hệ sinh thái sạc EV?

### Answer

`CHARX SEC-3100` là một **bộ điều khiển sạc AC** của Phoenix Contact, thuộc họ `CHARX control modular`. Nếu chỉ dựa trên tài liệu gốc, thiết bị này không được mô tả như một bo điều khiển cục bộ đơn giản, mà như **bộ điều khiển trung tâm của một charging point hoặc một phần của charging park**.

Nó nằm ở giao điểm của ba lớp chức năng:

- `field layer`
  - nơi controller nói chuyện với giao diện sạc, đầu đọc RFID, đồng hồ đo và các I/O hiện trường
- `management layer`
  - nơi controller cung cấp `web-based management` để cấu hình, vận hành và theo dõi trạng thái
- `integration layer`
  - nơi controller kết nối backend hoặc các hệ thống ngoài qua OCPP, Modbus/TCP, MQTT và các giao diện mạng

Vì vậy, khi học về `CHARX SEC-3100`, nên hình dung nó là “bộ não điều phối” của một điểm sạc AC: vừa đứng giữa xe và phần cứng hiện trường, vừa đứng giữa charging point và lớp quản trị hoặc backend.

### Evidence

- [product_1139012_page.md](/d:/CHARXSEC/document/product_1139012_page.md) mô tả đây là `AC charging controller`, thuộc họ `CHARX control modular`, chạy trên `Embedded Linux`.
- Cùng tài liệu này gọi thiết bị là “the centerpiece of an intelligent charging infrastructure”.
- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) xác nhận đây là `AC charging controller`, item number `1139012`.

## Câu hỏi 2

### Question

Thiết bị này hỗ trợ những mô hình vận hành nào?

### Answer

Theo tài liệu kỹ thuật, `CHARX SEC-3100` hỗ trợ ba mô hình vận hành:

- `Stand-Alone`
- `Client`
- `Server`

Điều đó cho thấy controller có thể:

- vận hành độc lập như một controller đơn,
- hoặc tham gia vào một nhóm nhiều controller theo mô hình client/server.

Manual còn đưa thêm ba khái niệm topology để người đọc không nhầm lẫn giữa module, trạm và toàn bộ hệ:

- `Charging park`: toàn bộ tập hợp các charging controller hoạt động trong một mạng
- `Charging station`: một nhóm gồm đúng một module server hoặc client, có thể gắn thêm extension modules
- `Charging point`: đúng một giao diện sạc với I/O tương ứng

Từ góc nhìn kiến trúc, điều này có nghĩa là `SEC-3100` không bị giới hạn ở vai trò một node đơn lẻ. Nó có thể là một thành phần độc lập, hoặc là một mắt xích trong topology nhiều controller, nhiều charging point và có phân vai server/client rõ ràng.

### Evidence

- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) ghi rõ `Operating modes: Stand-Alone, Client, Server`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `charging park`, `charging station`, và `charging point`.
- Cùng tài liệu này nói một charging station có thể có tối đa mười hai charging point.

## Câu hỏi 3

### Question

Các giao diện phần cứng và giao thức chính của thiết bị là gì?

### Answer

Nhìn từ tài liệu sản phẩm, `CHARX SEC-3100` có các giao diện chính sau:

- `Ethernet x2`
- `USB-C`
- `4G/2G cellular communication`
- `CHARX control modular system bus`
- `RS-485` cho energy meter
- `RS-485` cho RFID reader

Nếu nhóm theo chức năng, có thể chia các giao diện này thành:

- `giao diện truy cập và quản trị`
  - `Ethernet x2`
  - `USB-C`
  - `4G/2G cellular communication`
- `giao diện thiết bị hiện trường`
  - `RS-485` cho energy meter
  - `RS-485` cho RFID reader
  - system bus của họ `CHARX control modular`
- `giao diện với xe`
  - `IEC 61851-1`
  - `GB/T 18487`

Ở cấp giao thức phần mềm, tài liệu nhấn mạnh các nhóm sau:

- `OCPP 1.6J`
- `Modbus/TCP`
- `MQTT`
- `HTTP`
- `HTTPS`

Điều này cho thấy thiết bị không chỉ là controller cục bộ, mà còn là điểm hội tụ giữa:

- quản trị web,
- tích hợp công nghiệp,
- kết nối backend,
- và logic điều khiển EVSE.

Nói cách khác, ngay từ ngày đầu, có thể xem `SEC-3100` là nơi giao nhau giữa `networking`, `management`, `protocol integration` và `vehicle-side charging control`.

### Evidence

- [product_1139012_page.md](/d:/CHARXSEC/document/product_1139012_page.md) liệt kê `Ethernet x2`, `Cellular communication 4G/2G`, `USB-C`, và các giao thức `OCPP 1.6J`, `Modbus/TCP`, `MQTT`, `HTTP`, `HTTPS`.
- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) bổ sung `RS-485` cho energy meter và RFID reader, cùng giao tiếp xe `IEC 61851-1 and GB/T 18487`.

## Câu hỏi 4

### Question

Nền tảng kỹ thuật tổng quát của `CHARX SEC-3100` là gì?

### Answer

Theo tài liệu sản phẩm, nền tảng kỹ thuật của thiết bị là một hệ thống `Embedded Linux`. Đây là một dữ kiện rất quan trọng vì nó cho thấy controller có một software stack tương đối đầy đủ, chứ không chỉ là firmware tối giản kiểu MCU thuần.

Từ dữ liệu đang có, có thể suy ra ba ý chính:

- nó có lớp phần mềm hệ thống đủ lớn để chạy `web-based management`, update workflow và các chức năng tích hợp
- nó có tài nguyên lưu trữ cục bộ đáng kể, cụ thể là `8 GByte eMMC`
- nó được Phoenix Contact định vị như một nền tảng mở cho các ứng dụng IoT và smart services

Ngoài ra, trang sản phẩm còn nhấn mạnh thiết bị là một nền tảng mở cho:

- ứng dụng IoT theo nhu cầu khách hàng,
- smart services,
- sector coupling,
- và khả năng mở rộng từ một bộ sạc đơn đến charging park lớn.

Từ góc nhìn học tập, đây là lý do ngày 1 phải dừng ở mức kiến trúc và vai trò hệ thống trước khi đi sâu vào cấu hình, wiring hay các bề mặt nghiên cứu chi tiết hơn.

### Evidence

- [product_1139012_page.md](/d:/CHARXSEC/document/product_1139012_page.md) mô tả `Design: Embedded Linux system`.
- Cùng tài liệu này nói tới “open Linux platform for customer-specific IoT applications, smart services, and sector coupling”.
- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) bổ sung dữ kiện về `8 GByte eMMC`, cho thấy đây là một thiết bị có lưu trữ cục bộ đáng kể chứ không chỉ là logic board tối giản.

## Câu hỏi 5

### Question

Manual và help hub chính thức của thiết bị này thuộc nhánh tài liệu nào?

### Answer

Tài liệu chính thức đang có trong workspace cho thấy `CHARX SEC-3100` nằm trong nhánh manual `CHARX control modular AC`, với user manual dành cho firmware version `1.7`. Đây là tài liệu cấp họ sản phẩm, bao phủ nhiều model `SEC`, trong đó `SEC-3100` được map đúng với item number `1139012`.

Điều này quan trọng vì khi đọc manual, cần hiểu rằng:

- một số trang áp dụng cho cả họ sản phẩm,
- nhưng cover page cho phép xác định model nào thuộc nhánh firmware nào,
- và help hub đang dùng trong workspace là bản đã được Phoenix Contact công bố/xem xét vào `2026-02-23`.

Vì vậy, khi trích thông tin trong các ngày tiếp theo, luôn phải nhớ kiểm tra xem một đoạn đang nói về riêng `SEC-3100` hay đang nói về cả họ `SEC-3xxx`.

### Evidence

- [CHARX_control_modular_AC_-_Cover.html](/d:/CHARXSEC/document/CHARX_control_modular_AC_-_Cover.html) ghi tiêu đề `Installing and starting up the charging controller with firmware version 1.7`.
- Cùng trang cover này liệt kê:
  - `CHARX SEC-3100`
  - firmware version `1.7`
  - item number `1139012`
- [CHARX_help_home.html](/d:/CHARXSEC/document/CHARX_help_home.html) ghi `Published/reviewed: 2026-02-23`.

## Câu hỏi 6

### Question

Tài liệu chính thức mô tả chức năng quản trị và vận hành của thiết bị ở mức nào?

### Answer

Ngay từ trang sản phẩm và manual, Phoenix Contact mô tả `CHARX SEC-3100` như một thiết bị có đầy đủ chức năng quản trị, chứ không chỉ là phần cứng điều khiển. Các năng lực vận hành được nhấn mạnh gồm:

- `web-based management`
- `role-based access control`
- `regular signed software updates`
- quản lý từ một bộ sạc đơn đến charging park
- tích hợp với backend và hệ thống ngoài

Điểm quan trọng là các năng lực này không nằm rời rạc. Khi ghép lại, chúng tạo thành một management plane khá rõ ràng:

- có giao diện quản trị
- có phân quyền
- có vòng đời cập nhật
- có liên hệ trực tiếp tới vận hành an toàn và bảo mật

Tức là ngay từ tài liệu gốc, thiết bị đã được định vị như một nền tảng điều khiển có `management plane`, `update plane` và `security lifecycle` rõ ràng.

### Evidence

- [product_1139012_page.md](/d:/CHARXSEC/document/product_1139012_page.md) nêu rõ:
  - `regular signed software updates`
  - `cybersecurity and role-based access control`
  - `web-based management`
  - khả năng scale từ single charger tới large charging parks
- [Cybersecurity.html](/d:/CHARXSEC/document/Cybersecurity.html) nói tới `regular and free security updates`, `vulnerability management`, và PSIRT.

## Câu hỏi 7

### Question

Từ tài liệu gốc, nên hình dung kiến trúc chức năng của thiết bị như thế nào trong ngày đầu học?

### Answer

Nếu chỉ dùng tài liệu gốc, cách hình dung đúng nhất là chia thiết bị thành bốn lớp chức năng:

1. `Lớp điều khiển sạc`
   - điều khiển charging point
   - tuân thủ chuẩn sạc
2. `Lớp tích hợp`
   - OCPP
   - Modbus/TCP
   - MQTT
3. `Lớp quản trị`
   - web-based management
   - role-based access
   - dashboard, configuration, update
4. `Lớp hạ tầng phần cứng`
   - Ethernet
   - USB-C
   - cellular
   - RS-485
   - system bus

Đây là mô hình đủ tốt để bắt đầu học vì nó trả lời được ba câu hỏi nền tảng:

- controller này điều khiển cái gì ở hiện trường
- controller này được quản trị ra sao
- controller này tích hợp với hệ ngoài như thế nào

Nói ngắn gọn, nếu nắm chắc bốn lớp này thì sang ngày 2 và ngày 3 sẽ dễ hiểu hơn rất nhiều vì mọi cấu hình WBM, wiring và behavior sau đó đều rơi vào một trong bốn lớp trên.

### Evidence

- [product_1139012_page.md](/d:/CHARXSEC/document/product_1139012_page.md) và [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) cung cấp đầy đủ các interface, protocol, mode vận hành và năng lực quản trị.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) cho thấy WBM, charging park, charging station, charge point, và client/server vận hành ra sao trong thực tế.

## Kết quả cần nắm sau Ngày 1

Sau khi học xong Ngày 1, bạn nên nắm chắc:

- `CHARX SEC-3100` là controller trung tâm của hạ tầng sạc AC
- thiết bị chạy trên `Embedded Linux`
- nó hỗ trợ `Stand-Alone`, `Client`, `Server`
- nó kết nối backend qua `OCPP 1.6J`
- nó tích hợp công nghiệp qua `Modbus/TCP`, `MQTT`, `RS-485`
- nó có web management, role-based access control và update lifecycle
- manual branch đang dùng cho model này là firmware `1.7`, item `1139012`
