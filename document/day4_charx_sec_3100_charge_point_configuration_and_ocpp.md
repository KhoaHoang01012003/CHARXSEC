# Ngày 4 - Cấu hình charging point, release logic, Event Actions và OCPP

Tài liệu này chỉ dựa trên các nguồn trong thư mục `document`, không dựa trên code, config hay phân tích firmware trong workspace. Cấu trúc được chuẩn hóa theo dạng `Question -> Answer -> Evidence`.

## Nguồn tài liệu dùng cho Ngày 4

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html)
- [application_configuration.html](/d:/CHARXSEC/document/application_configuration.html)
- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md)

## Câu hỏi 1

### Question

Trang `Charging Stations/Charge Point/Configuration` trong WBM được tổ chức như thế nào, và nó nói gì về quá trình cấu hình ban đầu của một charging point?

### Answer

Theo manual, khi charging controller còn ở cấu hình mặc định từ nhà máy thì charging point vẫn được xem là **chưa được cấu hình**. Lần cấu hình đầu tiên được thực hiện trong menu `Create configuration`; sau khi đã có cấu hình, tên menu đổi thành `Configuration`.

Manual mô tả quá trình cấu hình ban đầu theo các ý chính sau:

- có thể copy cấu hình của một charging point khác ở đầu trang
- bắt buộc phải có `name` và `location`
- charging controller được gán cho charging point bằng một `UID`
- nếu thay đổi tham số thì phải bấm `Save`

Điểm quan trọng ở đây là WBM không coi charging point là một khái niệm mặc định tự động sinh đủ. Một charging point chỉ thực sự “tồn tại” về mặt vận hành khi đã được gán danh tính, vị trí và bộ tham số cấu hình tương ứng.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu khi controller ở factory default thì charging point `is not configured`.
- Cùng tài liệu này nêu lần cấu hình đầu nằm dưới `Create configuration`, về sau menu đổi thành `Configuration`.
- Cùng tài liệu này nêu có thể `copy the configuration of a different charging point`.
- Cùng tài liệu này nêu `name` và `location` là bắt buộc, controller được nhận diện bằng `UID`, và phải bấm `Save` khi thay đổi tham số.

## Câu hỏi 2

### Question

Manual chia cấu hình charging point thành những khu vực nào, và nên hiểu mỗi khu vực đó ra sao?

### Answer

Manual nói phần còn lại của cấu hình được chia thành năm khu vực:

- `Charging Connection`
- `Energy`
- `Monitoring`
- `Release Charging`
- `ISO 15118`

Nếu diễn giải lại theo góc nhìn học tập, có thể hiểu năm khu vực này như sau:

- `Charging Connection`
  - định nghĩa mối quan hệ điện và logic giữa controller với xe
- `Energy`
  - định nghĩa dòng sạc, fallback behavior và thiết bị đo
- `Monitoring`
  - định nghĩa các điều kiện bảo vệ, giám sát quá dòng, residual current, derating
- `Release Charging`
  - định nghĩa logic ai hoặc hệ nào được quyền cho phép sạc
- `ISO 15118`
  - định nghĩa nhánh cấu hình HLC của cùng họ sản phẩm, khi tính năng đó được hỗ trợ

Như vậy, từ ngày 4 trở đi, người học không còn nhìn controller chỉ theo chân dây và giao diện vật lý nữa, mà bắt đầu nhìn nó như một tập hợp policy và behavior được cấu hình trong WBM.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) ghi `The remaining structure of the configuration is divided into different areas. The available areas are: Charging Connection, Energy, Monitoring, Release Charging, and ISO 15118.`

## Câu hỏi 3

### Question

Trang `Application configuration` nói gì về `CCL_ChargingMode`, và thông tin đó nên được hiểu như thế nào khi học riêng `CHARX SEC-3100`?

### Answer

Trang `Application configuration` cho biết sau khi khóa socket đóng, một biến tên `CCL_ChargingMode` được cung cấp để nhận biết khả năng sạc. Trang này liệt kê bốn mode tổng quát:

- `Mode 1`
  - nối EV vào ổ AC dân dụng bằng cáp và phích cắm, không có pilot hay auxiliary contacts bổ sung
  - giao tiếp AC bằng cable coding qua `PP`
- `Mode 2`
  - nối EV vào ổ AC dân dụng nhưng có thiết bị EV supply equipment nằm trên cáp
  - có control pilot và bảo vệ chống điện giật
  - giao tiếp AC bằng `CP duty cycle`
  - `EVSE_MaximumCurrentlimit` được tính từ duty cycle
  - tài liệu ghi chưa có `high-level communication`
- `Mode 3`
  - tương tự mode 2 nhưng hỗ trợ công suất cao hơn như cấu hình sạc cơ bản không có high-level communication
- `Mode 4`
  - dùng combined charging system cho sạc DC với high-level communication

Tuy nhiên, khi áp dụng cho `CHARX SEC-3100`, phải đọc trang này một cách cẩn thận. Đây là trang mô tả vocabulary ở mức application hoặc logic chung, không phải tuyên bố rằng `SEC-3100` hỗ trợ toàn bộ các mode đó. Technical data của chính `SEC-3100` ghi rõ đây là `AC charging controller` với `Charging mode: Mode 3, Case B + C`.

Vì vậy, đối với khóa học này, giá trị của trang `Application configuration` nằm ở chỗ nó giúp hiểu cách hệ thống gọi tên các charging modes và vai trò của `PP`, `CP`, `high-level communication`, chứ không phải để suy ra rằng `SEC-3100` là controller DC hay hỗ trợ `Mode 4`.

### Evidence

- [application_configuration.html](/d:/CHARXSEC/document/application_configuration.html) ghi `To detect charging possibilities, CCL_ChargingMode is provided after close of the lock`.
- Cùng tài liệu này liệt kê `Mode 1`, `Mode 2`, `Mode 3`, `Mode 4` cùng mô tả ngắn cho từng mode.
- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) ghi `AC charging controller` và `Charging mode: Mode 3, Case B + C`.

## Câu hỏi 4

### Question

Trong `Charging Connection`, WBM cho phép cấu hình những gì cho giao diện sạc?

### Answer

Theo manual, khu vực `Charging Connection` bao phủ phần nằm giữa charging controller và xe. Các mục cấu hình chính gồm:

- `Connection Type`
  - `Socket Outlet`: dùng ổ cắm sạc, kết nối qua cáp di động
  - `Connector`: dùng cáp sạc gắn cố định với đầu connector
- `Standard`
  - với socket outlet, có thể chọn `IEC 62196`
- `Socket Outlet Type`
  - `4-pos. charging socket, Marquardt type actuator`
  - `4-pos. charging socket, Küster type actuator`
  - `3-pos. charging socket, Hella type actuator`
- `Locking Mode`
  - `On EV connected – disconnected`: vừa cắm xe là khóa, muốn mở thì phải ngắt phía xe trước
  - `Remote control`: khóa không tự điều khiển mà do hệ ngoài điều khiển, ví dụ qua OCPP, Modbus hoặc REST API
- `Plug Rejection`
  - có thể từ chối cáp `13 A`
  - hoặc từ chối cả `20 A & 13 A`
- `Status D Vehicle Rejection`
  - có thể `Reject` hoặc `Accept` xe yêu cầu thông gió bổ sung

Điểm rất quan trọng là manual cho thấy nhiều hành vi tưởng như “thuần phần cứng” thực ra được quyết định ngay trong WBM: kiểu socket, kiểu actuator, logic khóa, việc có chấp nhận một số loại cáp hay vehicle state nhất định hay không.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) ghi `Charging Connection` là khu vực cấu hình phần nằm giữa controller và vehicle.
- Cùng tài liệu này liệt kê `Connection Type` với hai lựa chọn `Socket Outlet` và `Connector`.
- Cùng tài liệu này liệt kê `Standard: IEC 62196` cho cấu hình socket.
- Cùng tài liệu này liệt kê ba loại `Socket Outlet Type`.
- Cùng tài liệu này mô tả `Locking Mode` với hai chế độ `On EV connected – disconnected` và `Remote control`.
- Cùng tài liệu này liệt kê `Plug Rejection` và `Status D Vehicle Rejection`.

## Câu hỏi 5

### Question

Khu vực `Energy` trong cấu hình charging point điều khiển những gì?

### Answer

Manual cho biết trong khu vực `Energy`, WBM gom hai nhóm cài đặt:

- cài đặt dòng sạc
- cài đặt energy measuring device

Ở phần `Energy | Charge Currents`, các tham số chính là:

- `Charge Current Minimum`
  - dòng đặt tối thiểu theo ampere
- `Charge Current Maximum`
  - dòng đặt tối đa theo ampere
  - dòng đặt thực tế luôn nằm trong khoảng min đến max
- `Fallback Charging Current`
  - dòng fallback tự động được áp dụng khi hết thời gian fallback
- `Fallback Time`
  - thời gian tính bằng giây
  - nếu mất kết nối tới front module liên quan, controller chờ hết thời gian này rồi chuyển sang fallback charging current

Ở phần `Energy | Energy measuring device settings`, manual cho thấy có thể chọn loại công tơ được hỗ trợ trong phần mềm. Manual cũng nhấn mạnh `Connector Phase Rotation` không bắt buộc, nhưng giúp cải thiện load management và khả năng giới hạn out-of-balance load.

Điều này cho thấy khu vực `Energy` không chỉ để nhập một con số dòng tối đa. Nó là nơi ràng buộc giữa:

- charging current policy
- fallback behavior khi topology bị gián đoạn
- và chất lượng của dữ liệu đo phục vụ monitoring hoặc load management

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) ghi trong `Energy` có `charging current settings` và `settings for the energy measuring device`.
- Cùng tài liệu này liệt kê `Charge Current Minimum`, `Charge Current Maximum`, `Fallback Charging Current`, `Fallback Time`.
- Cùng tài liệu này nêu `Fallback Time` được dùng khi `connection to the relevant front module is lost`.
- Cùng tài liệu này liệt kê các lựa chọn trong `Energy Measuring Device Type`.
- Cùng tài liệu này nêu `Connector Phase Rotation` giúp `improve load management behavior` và `make it possible to limit out-of-balance loads`.

## Câu hỏi 6

### Question

Trong WBM, khu vực `Monitoring` cho phép cấu hình những cơ chế bảo vệ và giám sát nào?

### Answer

Theo manual, `Monitoring` là nơi gom các cơ chế bảo vệ liên quan đến an toàn và tính đúng đắn của charging point. Có ba nhóm chính cần nắm:

- `Monitoring | Protection`
- `Monitoring | Charge Current Monitoring`
- `Monitoring | Derating`

Trong `Monitoring | Protection`, manual mô tả:

- `Contactor Monitoring`
  - dùng để phát hiện contactor không mở
  - phải chỉ định một digital input cho chức năng này
- `Auxiliary contact`
  - chọn kiểu `N/C contact` hoặc `N/O contact`
  - khi contactor bị kẹt, cách xuất hiện của mức áp sẽ phụ thuộc loại auxiliary contact
- `DC Residual Current Monitoring`
  - có thể bật hoặc tắt qua check box

Trong `Monitoring | Charge Current Monitoring`, manual nêu:

- việc giám sát dòng chỉ khả thi nếu đã cấu hình measuring device
- `Over Current Detection` có hai mode
  - `EV/ZE Ready`: derating theo các nấc chuẩn EV/ZE Ready
  - `Overcurrent shutdown`: shutdown nếu quá dòng trong `100 s` ở mức `>110%` hoặc `10 s` ở mức `>120%`
- nếu cơ chế overcurrent monitoring đã trigger, sau `1` phút sẽ thử cho sạc lại; nếu quá dòng lặp lại thì charging point chuyển sang error status
- `Out-of-balance Suppression` có thể bật/tắt tới mức tối đa `20 A`

Trong `Monitoring | Derating`, manual cho phép:

- chọn `Sensor Type`
  - `Pt 1000`
  - `PTC`
- nếu là `Pt 1000`, cấu hình `Start Temperature`, `Stop Temperature`, `Start Current`, `Stop Current`
- nếu là `PTC`, cấu hình terminating resistor

Điểm đáng chú ý là toàn bộ nhánh `Monitoring` cho thấy WBM là nơi nối giữa dữ liệu phần cứng đo được và logic phản ứng vận hành: từ phát hiện contactor kẹt, residual current, quá dòng cho tới hạ dòng vì nhiệt.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `Monitoring | Protection`, `Monitoring | Charge Current Monitoring` và `Monitoring | Derating`.
- Cùng tài liệu này nêu `Contactor Monitoring` dùng để phát hiện `a non-opening contactor` và phải chỉ định một digital input.
- Cùng tài liệu này mô tả `Auxiliary contact` với hai loại `N/C contact` và `N/O contact`.
- Cùng tài liệu này nêu `DC Residual Current Monitoring` có thể bật hoặc tắt qua check box.
- Cùng tài liệu này nêu charge current monitoring chỉ khả thi nếu `a measuring device is configured`.
- Cùng tài liệu này mô tả hai mode `Over Current Detection`, ngưỡng `100 s >110%` và `10 s >120%`, cùng hành vi thử lại sau `one minute`.
- Cùng tài liệu này nêu `Out-of-balance Suppression` tới `20 A`.
- Cùng tài liệu này mô tả `Sensor Type` gồm `Pt 1000` và `PTC` cùng các trường nhiệt độ hoặc điện trở tương ứng.

## Câu hỏi 7

### Question

`Allow Charging` trong WBM định nghĩa logic cấp quyền sạc như thế nào?

### Answer

Manual nói rất rõ: `The charging release determines when a vehicle is authorized to charge. Without a charging release, the vehicle stays in status B.` Đây là một trong những điểm quan trọng nhất của ngày 4 vì nó cho thấy “được phép sạc” là một policy tách biệt khỏi trạng thái cắm xe.

Các `Release Mode` được manual liệt kê gồm:

- `Via Dashboard`
  - chỉ cấp release qua web page
  - thao tác thủ công trên dashboard hoặc status page
- `By Local Whitelist`
  - kiểm tra RFID card hoặc EVCC ID với whitelist lưu cục bộ trên controller
  - dữ liệu phải được quản lý trong mục `Whitelist`
- `Via Remote Control`
  - release do hệ ngoài cấp hoặc thu hồi
  - ví dụ qua REST API hoặc Event Actions
- `Permanent Charging Release`
  - release luôn tồn tại
  - không thu hồi qua web page
  - nếu cần ngăn sạc thì phải lock hoặc unlock charging point theo cách manual mô tả
- `By OCPP`
  - release được cấp và thu hồi bởi backend OCPP
  - không thể cấp thêm qua web page
  - OCPP backend connection chỉ khả thi với cấu hình này
  - nếu đổi setting hoặc chuyển từ OCPP sang local whitelist thì phải restart OCPP agent
- `Via Modbus`
  - release được cấp và thu hồi qua Modbus registers
  - không thể cấp thêm qua web page

Về mặt vận hành, `Allow Charging` chính là policy engine xác định ai hoặc hệ nào có quyền mở khóa quá trình sạc. Nó cũng là điểm nối giữa charging point với các cơ chế xác thực cục bộ, tự động hóa, OCPP hoặc Modbus.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) ghi `Without a charging release, the vehicle stays in status B`.
- Cùng tài liệu này liệt kê các mode `Via Dashboard`, `By Local Whitelist`, `Via Remote Control`, `Permanent Charging Release`, `By OCPP`, `Via Modbus`.
- Cùng tài liệu này nêu với `By OCPP`, release do backend cấp/thu hồi và `Additional release via the web page is not possible`.
- Cùng tài liệu này nêu `OCPP backend connection is only possible with this setting`.
- Cùng tài liệu này nêu nếu đổi setting hoặc chuyển từ OCPP sang local whitelist thì phải restart OCPP agent.

## Câu hỏi 8

### Question

Trong cấu hình charging point, RFID reader và `OCPP ConnectorID` được đặt ra sao?

### Answer

Manual mô tả phần này như lớp ánh xạ giữa charging point cụ thể với hai thực thể quan trọng:

- đầu đọc RFID tại hiện trường
- định danh connector phía backend OCPP

Các trường chính gồm:

- `RFID Reader`
  - chọn terminal point RFID dùng cho charging point
  - tất cả charging point có trong mạng được liệt kê để tham chiếu chéo
- `Type of RFID Reader`
  - `ELATEC TWN4`
  - `DUALI MDE 950-4 XCP`
  - `Netronix UW-XEU1`
  - `CHARX RFID/NFC`
- `RFID Timeout`
  - thời gian tính bằng giây
  - sau khoảng này, nếu đã cấp release qua RFID nhưng không có xe kết nối thì release bị loại bỏ
- `OCPP ConnectorID`
  - giá trị mặc định là `-1`
  - khi vận hành OCPP, phải khai báo một ID duy nhất trong charging park
  - ID phải bắt đầu từ `1`
  - ID này chính là ID của connector trong backend OCPP

Điều này cho thấy mỗi charging point trong WBM không chỉ là một đối tượng cục bộ. Nó còn được gắn:

- với một kênh xác thực vật lý tại hiện trường
- và với một định danh logic ở backend

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả trường `RFID Reader` là nơi chỉ ra RFID reader terminal point dùng cho charging point.
- Cùng tài liệu này liệt kê các lựa chọn trong `Type of RFID Reader`.
- Cùng tài liệu này nêu `RFID Timeout` là thời gian sau đó release qua RFID bị loại bỏ nếu không có vehicle kết nối.
- Cùng tài liệu này nêu `OCPP ConnectorID` mặc định là `-1`, phải là ID duy nhất trong charging park, bắt đầu từ `1`, và đại diện cho ID ở OCPP backend.

## Câu hỏi 9

### Question

Nhánh `ISO 15118` trong cấu hình charging point nói gì, và cần đọc nó thế nào khi nghiên cứu riêng model `SEC-3100`?

### Answer

Manual có một khu vực `ISO 15118` trong cấu hình charging point, nhưng chính tài liệu ghi rõ rằng các cài đặt đặc biệt để kích hoạt ISO 15118 áp dụng cho `CHARX SEC-3050` và `CHARX SEC-3150`. Vì vậy, khi học riêng `SEC-3100`, phải hiểu đây là nhánh cấu hình của **cùng họ manual**, chứ không phải mặc định là tính năng trọng tâm của model `3100`.

Các trường manual mô tả gồm:

- `High Level Communication`
  - `Required`: chỉ xe có HLC mới sạc được
  - `Optional`: xe có HLC hoặc không có HLC đều sạc được
  - `Disabled`: không có giao tiếp theo ISO 15118 ở charging point
- `EVSE ID`
  - định dạng `CountryCode + Operator ID + E + ChargingStation ID`
  - ví dụ `DE123E4567`
- `Free EVSE Charge Service`
  - cho phép thông báo với xe qua HLC rằng việc sạc là miễn phí
- `Payment Options`
  - thanh toán có thể qua vehicle identification hoặc external payment
  - nếu chứng chỉ không thể nạp qua web page thì khách hàng chỉ chọn được `Allow External Payment`
- `TLS Policy`
  - manual ghi rõ hiện tại chứng chỉ chưa thể nạp qua web page
  - trường này chỉ có giá trị hiển thị

Giá trị của phần này trong khóa học là ở chỗ nó cho thấy cùng một khung WBM được thiết kế để bao phủ cả các model có HLC/ISO 15118. Nhưng với `SEC-3100`, người học nên coi đây là nhánh tham chiếu để hiểu họ sản phẩm, chứ không nên đồng nhất nó với năng lực cốt lõi của model AC này.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) ghi `You must make special settings to activate ISO 15118 communication on the CHARX SEC-3050 and -3150 modules.`
- Cùng tài liệu này liệt kê `High Level Communication` với ba giá trị `Required`, `Optional`, `Disabled`.
- Cùng tài liệu này mô tả định dạng `EVSE ID`.
- Cùng tài liệu này mô tả `Free EVSE Charge Service`, `Payment Options` và `TLS Policy`.
- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) xác nhận `CHARX SEC-3100` là `AC charging controller`.

## Câu hỏi 10

### Question

`Event Actions` hoạt động như thế nào, và vì sao đây là một trong những phần cấu hình quan trọng nhất của WBM?

### Answer

Manual mô tả `Event Action` là sự kết hợp giữa:

- một `event` hoặc input
- một `condition` tùy chọn
- và một `action`

Ở mức khái niệm, đây là cơ chế rule engine cục bộ của charging controller. Nó cho phép biến các thay đổi trạng thái hoặc tín hiệu vào thành hành động cụ thể ở charging point.

Các đặc điểm quan trọng mà manual nêu gồm:

- Event Actions có thể được kích bởi tín hiệu nội bộ hoặc thay đổi ở input
- ví dụ event nội bộ có thể là `RFID denied` hoặc phát hiện xe cắm vào
- ví dụ tín hiệu ngoài có thể là thay đổi mức áp hoặc `rising/falling edge`
- có thể thêm hoặc xóa Event Actions
- số lượng tối đa là `32`
- Event Actions được xử lý trong một vòng lặp vô hạn theo đúng thứ tự đã chỉ định
- một action có thể bị Event Action ở sau ghi đè trực tiếp
- nếu condition không còn đúng thì action **không tự động đảo ngược**
- vì vậy cần tạo reset có chủ đích khi cần

Manual còn mô tả cách dùng `Action Timer`:

- nếu muốn action mất hiệu lực gần như ngay khi condition đổi, đặt timer rất thấp, ví dụ `10 ms`
- nếu không muốn action tự mất hiệu lực, đặt timer là `0 ms`

Đây là phần đặc biệt quan trọng vì nó biến charging controller thành một bộ điều khiển logic sự kiện cục bộ, chứ không chỉ là thiết bị làm theo vài checkbox cấu hình tĩnh.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu `In the “Charging Stations | Charge Point | Event Actions” menu item, specific actions can be assigned to events that occur.`
- Cùng tài liệu này nêu event có thể đến từ tín hiệu nội bộ hoặc từ input signals.
- Cùng tài liệu này nêu `The maximum number of configured Event Actions is 32`.
- Cùng tài liệu này cảnh báo Event Actions được xử lý `in an endless loop in the specified sequence`.
- Cùng tài liệu này nêu action không tự reset chỉ vì event hết hoặc condition không còn đúng.
- Cùng tài liệu này mô tả `Action Timer` với ví dụ `10 ms` và `0 ms`.

## Câu hỏi 11

### Question

Manual cho biết những loại event, condition và action nào có thể xuất hiện trong `Event Actions`?

### Answer

Manual liệt kê một tập lựa chọn khá rộng, cho thấy `Event Actions` có thể bám vào cả trạng thái vật lý, trạng thái logic, trạng thái backend lẫn trạng thái bảo vệ.

Ví dụ về `event` hoặc `input/event`:

- `Digital Input X Rising`
- `Digital Input X Falling`
- `Plug Connected`
- `Plug Disconnected`
- `EV Connected`
- `EV Disconnected`
- `RFID Charge Release`
- `RFID Denied`
- `Temperature Derating Started`
- `Temperature Derating Ended`
- `Contactor Failure Detected`
- `New Error`
- `Error Resolved`

Ví dụ về `condition`:

- `Active`
- `Digital Input High`
- `Digital Input Low`
- `Connector plugged`
- `Error`
- `PP XX A`
- `Status A`, `Status B`, `Status C`, `Status D`
- `Available`, `Preparation`, `Charging`, `Suspended EV`, `Unavailable`
- `Charge Release`, `No Charge Release`
- `Backend offline`, `Backend online`, `Backend online and charging point available`
- `Temperature Derating`
- `Current reduced for External Reasons`
- `CP PWM on`, `CP PWM off`

Ví dụ về `action`:

- `Enable Charging`
  - `Bus controlled`
  - `Enable`
  - `Disable`
- `Lock Connector`
- `Unlock Connector`
- `Digital Output X Low`
- `Digital Output X High`
- `Digital Output X Floating`
- `Digital Output X Flashing High`
- `Digital Output X Flashing Low`
- `Digital Output X Pulsatile Low`
- `Digital Output X Buscontrolled`
- `Reduce maximum charging current`
- `External Release`
  - `Bus controlled`
  - `Enable`
  - `Disable`

Manual còn nêu một ví dụ rất đáng chú ý: có thể gửi mô tả lỗi tùy ý lên OCPP backend từ Event Action. Nếu nhập `EmergencyStop` làm error description, backend sẽ nhận `StopReason` là `EmergencyStop`.

Từ góc nhìn nghiên cứu vận hành, phần này cho thấy một lượng rất lớn behavior của charging point có thể được biểu diễn bằng cấu hình rule trong WBM, thay vì bị hard-code vào một workflow cố định.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) liệt kê nhiều `Input/Event` như `Digital Input X Rising`, `Plug Connected`, `RFID Denied`, `Temperature Derating Started`, `Contactor Failure Detected`.
- Cùng tài liệu này liệt kê nhiều `Condition` như `Digital Input High`, `Status A/B/C/D`, `Charge Release`, `Backend online`, `Temperature Derating`, `CP PWM on`.
- Cùng tài liệu này liệt kê nhiều `Output or Action` như `Enable Charging`, `Lock Connector`, `Unlock Connector`, `Digital Output X High/Low/Floating`, `Reduce maximum charging current`, `External Release`.
- Cùng tài liệu này nêu có thể gửi error description lên OCPP backend và nếu dùng `EmergencyStop` thì `StopReason` truyền đi cũng là `EmergencyStop`.

## Câu hỏi 12

### Question

WBM mô tả cấu hình OCPP như thế nào, và `local whitelist` được vận hành ra sao?

### Answer

Manual dành hẳn các khu riêng cho `WBM – OCPP` và `WBM – Whitelist`, cho thấy đây là hai thành phần vận hành rất quan trọng của charging park.

Với `WBM – OCPP`, manual nêu ba lớp nội dung chính:

- `OCPP Status Information`
  - xem trạng thái kết nối tới OCPP management system
  - xanh là có kết nối, đỏ là không có kết nối
  - xem được trạng thái các charging point do backend điều khiển
  - xem được `50` message gần nhất giữa controller và backend
  - nếu menu không hiện đủ charging points thì phải kiểm tra `Allow Charging`, cấu hình `By OCPP` và `ConnectorID`
- `OCPP settings`
  - `Protocol Version`: hiện chỉ chọn được `OCPP 1.6J`
  - `Network Interface`: `ppp0`, `wlan0` hoặc `eth0`
  - `Backend URL`
  - `AuthorizationUser`
  - `AuthorizationKey`
  - `Upload Certificate` khi dùng `wss://...`
  - `Delete Certificate`
  - `Charging Station Model`
  - `Charging Station Manufacturer`
  - `Charging Station Serial Number`
  - `SAVE`
  - `RESTART OCPP SERVICE`
- `OCPP | Servervariables`
  - hiển thị cả key chuẩn OCPP và key riêng của CHARX control
  - biến `ReadOnly = False` có thể sửa qua backend hoặc WBM
  - biến `ReadOnly = True` chỉ xem được
  - ví dụ các key được manual nêu gồm `NewBackendURL`, `WebSocketPingTimeout`, `AllowTimeSyncDuringSession`, `AvailabilityOnlyWhenTimeSynchronized`, `PresentingRFIDEndCharging`, `SignedDataFormat`, `AuthorizationUser`, `AuthorizationKey`

Với `WBM – Whitelist`, manual mô tả:

- mỗi charging park có thể có một local whitelist tùy chọn
- whitelist của các module `3xxx` bị giới hạn `500` entry
- trong charging parks có hỗ trợ ISO 15118, có thể thêm cả `RFID UID` lẫn `EVCC ID`
- có thể `export` whitelist ra file `csv`
- có thể `import` theo hai cách
  - `Add From Import`
  - `Replace with Import`
- có thể tạo từng entry bằng `+ NEW ENTRY`
- mỗi entry có các trường:
  - `Type`: RFID card hoặc EVCC ID
  - `RFID Tag/EVCC ID`
  - `Name`
  - `Allow Charging`
  - `Expiry Date/Expiry Time`
  - `Recently scanned RFIDs/EVCC IDs`

Nói ngắn gọn, OCPP là cơ chế ủy quyền và điều phối từ backend, còn local whitelist là cơ chế ủy quyền cục bộ trong charging park. Cả hai đều đi qua policy của charging point và có liên hệ trực tiếp với `Allow Charging`.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả khu `WBM – OCPP`.
- Cùng tài liệu này nêu status OCPP có chỉ báo xanh/đỏ, hiển thị được `the last 50 messages`, và yêu cầu kiểm tra `Allow Charging` cùng `ConnectorID` nếu menu không hiện đúng charging points.
- Cùng tài liệu này nêu `Protocol Version` hiện chỉ có `OCPP 1.6J`, cùng các trường `Network Interface`, `Backend URL`, `AuthorizationUser`, `AuthorizationKey`, certificate upload/delete và `RESTART OCPP SERVICE`.
- Cùng tài liệu này nêu `OCPP | Servervariables` bao gồm cả key chuẩn OCPP và key riêng của CHARX control, với phân biệt `ReadOnly = False` và `ReadOnly = True`.
- Cùng tài liệu này mô tả `WBM – Whitelist`, giới hạn `500` entries cho modules `3xxx`, khả năng lưu `RFID UID` và `EVCC ID`, export/import bằng `csv`, cùng các trường của một entry whitelist.

## Kết quả cần nắm sau Ngày 4

Sau khi học xong Ngày 4, bạn nên nắm chắc:

- một charging point chỉ thực sự sẵn sàng vận hành sau khi được tạo cấu hình, gán danh tính và lưu tham số trong WBM
- WBM chia cấu hình charging point thành các khu vực phản ánh trực tiếp behavior của controller: `Charging Connection`, `Energy`, `Monitoring`, `Allow Charging` và nhánh `ISO 15118`
- `Application configuration` giúp hiểu vocabulary `CCL_ChargingMode`, nhưng không thay đổi thực tế rằng `SEC-3100` là AC controller `Mode 3`
- nhiều hành vi quan trọng như locking, plug rejection, fallback current, contactor monitoring, overcurrent monitoring và derating được quyết định bằng cấu hình WBM
- `Allow Charging` là policy engine trung tâm, quyết định release đến từ dashboard, whitelist, remote control, OCPP hay Modbus
- `Event Actions` là rule engine cục bộ với `event + condition + action`, tối đa `32` rule, xử lý theo thứ tự và không tự reset action
- OCPP trong WBM gồm trạng thái kết nối, tham số backend, certificate workflow, service restart và server variables
- local whitelist là cơ chế ủy quyền cục bộ của charging park, có import/export, giới hạn số entry và có thể chứa cả RFID UID lẫn EVCC ID trong các park phù hợp
