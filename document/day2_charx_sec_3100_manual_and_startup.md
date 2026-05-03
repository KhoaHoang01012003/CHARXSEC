# Ngày 2 - Startup, truy cập ban đầu và WBM

Tài liệu này chỉ dựa trên các nguồn trong thư mục `document`, không dựa trên code, config hay phân tích firmware trong workspace. Cấu trúc được chuẩn hóa theo dạng `Question -> Answer -> Evidence`.

## Nguồn tài liệu dùng cho Ngày 2

- [CHARX_help_home.html](/d:/CHARXSEC/document/CHARX_help_home.html)
- [CHARX_control_modular_AC_-_Cover.html](/d:/CHARXSEC/document/CHARX_control_modular_AC_-_Cover.html)
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html)
- [Maintenance_repair_and_disposal.html](/d:/CHARXSEC/document/Maintenance_repair_and_disposal.html)
- [Cybersecurity.html](/d:/CHARXSEC/document/Cybersecurity.html)

## Câu hỏi 1

### Question

Quá trình startup và commissioning của `CHARX SEC-3100` bắt đầu như thế nào theo manual?

### Answer

Manual mô tả startup như một quá trình có thứ tự khá rõ và có thể xem như một chuỗi commissioning tối thiểu:

1. kiểm tra và dùng firmware mới nhất,
2. truy cập thiết bị bằng một trong các phương thức được hỗ trợ,
3. mở WBM để cấu hình,
4. đổi mật khẩu trong giai đoạn startup,
5. tiếp tục cấu hình hệ thống và vận hành.

Điểm đáng chú ý là manual đặt cập nhật firmware ngay từ đầu quá trình commissioning. Điều này cho thấy với `CHARX SEC-3100`, startup không tách rời khỏi software lifecycle: thiết bị chỉ nên được cấu hình và đưa vào vận hành sau khi đã được đối chiếu với firmware mới nhất.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mở đầu bằng `NOTE: Check for latest firmware prior to startup`.
- Cùng tài liệu này nói phải `Carry out a firmware update`.
- Cùng tài liệu này trỏ người đọc tới `System Control/Software`.

## Câu hỏi 2

### Question

Thiết bị hỗ trợ những đường truy cập ban đầu nào?

### Answer

Manual mô tả ba đường truy cập ban đầu:

1. qua `USB-C`
2. qua mạng Ethernet có router
3. qua Ethernet trực tiếp từ máy tính

Ba đường này phục vụ cùng một mục đích: đưa người cài đặt vào WBM để cấu hình controller hoặc chuẩn bị thiết bị cho hoạt động trong mạng.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) liệt kê:
  - `Access via the USB-C interface and the USB slot on the computer`
  - `Access via an Ethernet network made up of the charging controller, router, and computer`
  - `Access via the Ethernet interface directly from the computer`

## Câu hỏi 3

### Question

`USB-C` được dùng như thế nào khi truy cập ban đầu?

### Answer

Theo manual, `USB-C` là cách truy cập ưu tiên vì tránh được các hạn chế của mạng Ethernet. Trên Windows, người dùng phải cài RNDIS driver để máy tính nhận ra thiết bị như một giao diện mạng USB.

Sau khi driver được gán đúng, controller có thể được truy cập tại địa chỉ:

- `192.168.5.1`

Manual còn khuyến nghị nếu có thể thì dùng `HTTPS` khi vào WBM, ví dụ:

- `https://192.168.5.1`

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) ghi `This is the preferred way, since it avoids restrictions in Ethernet networks`.
- Cùng tài liệu này yêu cầu tải RNDIS driver và tìm `USB\VID_0525&PID_A4A2` hoặc `RNDIS Gadget`.
- Cùng tài liệu này ghi rõ `Find the device ... at the IP address 192.168.5.1`.
- Cùng tài liệu này khuyến nghị truy cập WBM bằng `https://` nếu có thể.

## Câu hỏi 4

### Question

`ETH0` và `ETH1` có vai trò khác nhau như thế nào trong manual?

### Answer

Manual phân biệt rất rõ:

- `ETH0` là giao diện mạng chính để truy cập thiết bị qua router
- `ETH1` không phải cổng truy cập WBM tự do

`ETH0` được cài sẵn để nhận địa chỉ động qua DHCP. Khi có router, controller có thể xuất hiện dưới tên:

- `ev3000.local`
- `ev3000`

Trong khi đó, `ETH1` được dành riêng cho mô hình client/server với các charging controller khác trong họ `SEC-3xxx`. Manual nói rõ rằng giao diện này không dùng để truy cập WBM hay vận hành Ethernet chung.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) ghi `The ETH0 interface is set at the factory to dynamic address assignment by a DHCP server`.
- Cùng tài liệu này nói controller có thể được truy cập tại `http://ev3000.local` hoặc `http://ev3000`.
- Cùng tài liệu này ghi `The ETH1 interface is reserved for setting up client/server systems`.
- Cùng tài liệu này nói `The ETH1 interface is not available for access to the WBM or unrestricted operation in Ethernet networks`.

## Câu hỏi 5

### Question

Nếu không có router thì người dùng truy cập controller ra sao?

### Answer

Manual cho biết kết nối trực tiếp giữa PC và controller vẫn khả thi, nhưng khi không có router thì thường cũng không có DHCP server. Trong trường hợp này, Phoenix Contact khuyến nghị dùng một công cụ BOOTP/DHCP để cấp địa chỉ IP ban đầu cho controller.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nói `The initial connection ... can also be established without a router`.
- Cùng tài liệu này nói khi đó `there is generally no DHCP server available`.
- Cùng tài liệu này khuyến nghị `Rockwell BOOTP/DHCP Server 2.3`.

## Câu hỏi 6 

### Question

WBM là gì và có vai trò gì trong startup?

### Answer

`WBM` là `web-based management`, tức giao diện quản trị web của controller. Trong giai đoạn startup, WBM là trung tâm để:

- đăng nhập,
- xem dashboard,
- cấu hình charging park,
- cấu hình network,
- quản lý modem,
- tải log,
- chuyển module sang client/server mode,
- thực hiện software update.

Nếu nhìn theo vai trò hệ thống, WBM chính là management plane tại chỗ của controller: nơi người vận hành đi từ truy cập ban đầu sang cấu hình, chẩn đoán và update.

Điều quan trọng là manual nói WBM không phải lúc nào cũng sẵn sàng ngay sau khi controller khởi động, vì nó là một trong những process được start muộn. Vì vậy khi kiểm tra khả năng truy cập sau boot, không nên vội kết luận controller lỗi chỉ vì WBM chưa lên ngay.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nói WBM dùng để `read static and dynamic frame data` và `make configuration settings`.
- Cùng tài liệu này có phần `WBM – Dashboard and Login`.
- Cùng tài liệu này ghi `one of the last processes to be started is the WBM`.

## Câu hỏi 7

### Question

Dashboard trong WBM cho biết những gì?

### Answer

Dashboard cho người vận hành cái nhìn tổng quan về các charging point đã được kết nối và cấu hình qua controller này. Nếu hệ thống chạy theo nhóm client/server, dashboard còn hiển thị thêm các client và extension modules của chúng.

Thông tin tổng quát mà dashboard hiển thị bao gồm:

- số charging point sẵn sàng cho phiên sạc mới,
- số controller đang bị chiếm nhưng chưa sạc,
- số controller đang sạc,
- tổng công suất đang sạc.

Dashboard cũng hiển thị cho từng charging controller:

- tên và vị trí,
- trạng thái hiện tại,
- công suất hiện tại,
- năng lượng đang sạc,
- thời gian sạc,
- thời gian cắm.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `the dashboard provides you with an overview of all charging points`.
- Cùng tài liệu này liệt kê:
  - `Number of charging points available for new charging processes`
  - `Number of occupied charging controllers without an active charging process`
  - `Number of charging controllers currently engaged in a charging process`
  - `Total power currently being charged`
- Cùng tài liệu này nói `Only configured charging points are visible in the dashboard`.

## Câu hỏi 8

### Question

Manual định nghĩa `charging park`, `charging station` và `charging point` như thế nào?

### Answer

Manual đưa ra ba khái niệm rất quan trọng để hiểu topology của hệ thống:

- `Charging park`
  - toàn bộ các charging controller kết hợp trong một mạng
  - có thể gồm server, clients và các extension modules
- `Charging station`
  - một nhóm gồm đúng một server hoặc một client module
  - có thể gắn thêm extension modules
- `Charging point`
  - đúng một giao diện sạc cùng với thiết bị I/O tương ứng

Các khái niệm này đặc biệt quan trọng cho nghiên cứu bảo mật và emulation vì chúng cho biết controller được tổ chức theo mô hình nhiều cấp, không chỉ là một node đơn lẻ.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) có các định nghĩa cho:
  - `Charging park (A)`
  - `Charging station (B)`
  - `Charging point (C)`
- Cùng tài liệu này nói `A displayed charging station can have up to twelve charging points`.

## Câu hỏi 9

### Question

Role model mặc định của WBM là gì?

### Answer

Manual mô tả bốn vai trò chính:

- `Guest`
- `User`
- `Operator`
- `Manufacturers`

Mỗi vai trò có quyền khác nhau. Tóm tắt theo manual:

- `Guest`
  - chỉ có quyền đọc dashboard
- `User`
  - có quyền đọc rộng hơn
  - có thể cấp charging release
  - chỉnh whitelist
  - tải log
- `Operator`
  - có toàn bộ quyền của `User`
  - thêm quyền cấu hình network, backend, load management và software update
- `Manufacturers`
  - không bị hạn chế

Manual còn ghi rõ username/password mặc định cho `User`, `Operator` và `Manufacturers`.

Từ góc nhìn bảo mật vận hành, đây là điểm rất đáng chú ý: WBM không phải giao diện một vai trò duy nhất, mà là giao diện có sẵn mô hình phân quyền ngay từ đầu. Điều này ảnh hưởng trực tiếp tới cách đánh giá bề mặt truy cập, quản trị và thao tác update ở các ngày sau.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) có bảng `User roles`.
- Cùng tài liệu này ghi:
  - `User` / `user`
  - `Operator` / `operator`
  - `manufacturer` / `manufacturer`
- Cùng tài liệu này ghi `Guest` chỉ có `Read-only access only to the dashboard`.

## Câu hỏi 10

### Question

Manual khuyến nghị gì về mật khẩu và phiên đăng nhập?

### Answer

Manual yêu cầu đổi mật khẩu trong quá trình startup tại nơi lắp đặt, chậm nhất là ở giai đoạn này. Ngoài ra, manual còn khuyến nghị phải đăng xuất khỏi WBM khi không sử dụng để tránh lạm dụng profile người dùng.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) có ghi `NOTE: Change your password regularly`.
- Cùng tài liệu này nói `change your passwords during startup at the installation location, at the very latest`.
- Cùng tài liệu này ghi `NOTE: Log out when not using the WBM`.

## Câu hỏi 11

### Question

`System Control` trong WBM bao gồm những gì?

### Answer

Theo manual, `System Control` là cụm chức năng quản trị hệ thống, bao gồm:

- `Status`
- `Time`
- `Calibration Law`
- `Developer Mode`
- `Log Files`
- `Module Switch`
- `Software`

Trong thực tế vận hành, đây là nơi tập trung phần lớn các tác vụ hệ thống quan trọng: xem trạng thái hệ thống Linux nhúng, đặt thời gian, tải log, chuyển chế độ module và cập nhật phần mềm.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) có phần `WBM – System Control`.
- Cùng tài liệu này có các mục:
  - `System Control/Status`
  - `System Control/Time`
  - `System Control/Calibration Law`
  - `System Control/Developer Mode`
  - `System Control/Log Files`
  - `System Control/Module Switch`
  - `System Control/Software`

## Câu hỏi 12

### Question

Update path chính thức của thiết bị được mô tả như thế nào trong tài liệu?

### Answer

Tài liệu maintenance và startup cho thấy update có nhiều lớp:

- cập nhật từng application riêng lẻ,
- cập nhật firmware của charging controller,
- cập nhật toàn bộ hệ thống.

Update có thể được thực hiện:

- cục bộ qua WBM,
- qua backend bằng kết nối OCPP,
- qua Ethernet,
- qua cellular interface.

Trong mô hình client/server, manual còn nói sau khi server update và restart, server sẽ kiểm tra version của các client và cập nhật chúng ở bước tiếp theo. Quá trình này có thể mất đến mười phút cho mỗi charging point.

Điều này cho thấy update path của `CHARX SEC-3100` không chỉ là thao tác “nạp firmware”, mà là một cơ chế vận hành nhiều tầng: có thể cục bộ hoặc từ xa, có thể áp dụng cho application riêng lẻ hoặc toàn hệ, và có logic lan truyền trong topology nhiều controller.

### Evidence

- [Maintenance_repair_and_disposal.html](/d:/CHARXSEC/document/Maintenance_repair_and_disposal.html) ghi:
  - `update individual software programs`
  - `perform a complete software update`
  - update qua `web-based management`
  - update qua backend dùng `OCPP connection`
  - update qua `Ethernet` và `cellular interface`
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) ghi trong `System Control/Software`:
  - có thể cập nhật `individual application programs`
  - `charging controller firmware`
  - `the entire system`
- Cùng tài liệu này nói update trong nhóm client/server có thể mất `up to 10 minutes per charging point`.

## Câu hỏi 13

### Question

Tài liệu maintenance nói gì về vận hành và bảo trì thiết bị?

### Answer

Ở mức chính thức, Phoenix Contact mô tả thiết bị là `maintenance-free`. Tuy nhiên, tài liệu vẫn dành riêng một chương cho:

- software update,
- tháo lắp phần cứng,
- tháo microSD,
- tháo SIM,
- tháo antenna,
- thay thế thiết bị,
- sửa chữa và gửi trả hãng.

Điều này cho thấy thiết bị có vòng đời vận hành khá nghiêm túc, trong đó software maintenance là một phần quan trọng hơn bảo trì cơ khí thông thường.

### Evidence

- [Maintenance_repair_and_disposal.html](/d:/CHARXSEC/document/Maintenance_repair_and_disposal.html) ghi `The device is maintenance-free`.
- Cùng tài liệu này có các mục:
  - `Software update`
  - `Removing the microSD card`
  - `Removing the SIM card`
  - `Removing the antenna`
  - `Device replacement`
  - `repairs`

## Câu hỏi 14

### Question

Tài liệu chính thức nói gì về an toàn thông tin và vòng đời bảo mật?

### Answer

Trang `Cybersecurity` cho thấy Phoenix Contact đặt vấn đề bảo mật như một phần chính thức của sản phẩm, không phải tài liệu phụ. Thông điệp chính là:

- charging infrastructure chịu yêu cầu bảo mật ngày càng cao,
- thiết bị cần có security updates và vulnerability management,
- Phoenix Contact duy trì cập nhật bảo mật định kỳ và miễn phí,
- có kênh `PSIRT` để báo cáo lỗ hổng và theo dõi safety notes.

Vì vậy, khi nghiên cứu `CHARX SEC-3100`, không nên xem bảo mật như phần thêm vào, mà phải xem nó là một phần của vòng đời sản phẩm.

### Evidence

- [Cybersecurity.html](/d:/CHARXSEC/document/Cybersecurity.html) nói tới `regular and free security updates`.
- Cùng tài liệu này nói tới `vulnerability management`.
- Cùng tài liệu này giới thiệu `Product Security Incident Response Team`.

## Ghi chú quan trọng cần nhớ sau Ngày 2

- tài liệu startup đang trỏ tới `phoenixcontact.com/qr/1138965` trong phần kiểm tra firmware mới nhất, trong khi cover page map `CHARX SEC-3100` với item `1139012`
- đây là một điểm cần kiểm tra chéo khi tra cứu firmware và release notes, nhưng bản thân tài liệu hiện có đúng là đang ghi như vậy

## Kết quả cần nắm sau Ngày 2

Sau khi học xong Ngày 2, bạn nên nắm chắc:

- ba đường truy cập ban đầu của controller
- vai trò riêng của `USB-C`, `ETH0`, `ETH1`
- WBM là management plane trung tâm
- dashboard hiển thị charging park, charging station và charging point ra sao
- các role mặc định và quyền cơ bản của chúng
- `System Control` là khu vực trọng tâm cho log, trạng thái, chuyển mode và update
- software update có thể diễn ra cục bộ hoặc qua backend, và có logic lan truyền từ server sang client
