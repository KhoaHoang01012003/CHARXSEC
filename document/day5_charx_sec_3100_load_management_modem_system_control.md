# Ngày 5 - Load Management, Modem, Time, Log Files, Calibration Law và Developer Mode

Tài liệu này chỉ dựa trên các nguồn trong thư mục `document`, không dựa trên code, config hay phân tích firmware trong workspace. Cấu trúc được chuẩn hóa theo dạng `Question -> Answer -> Evidence`.

## Nguồn tài liệu dùng cho Ngày 5

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html)
- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md)

## Câu hỏi 1

### Question

Ngày 5 nằm ở đâu trong lộ trình học CHARX SEC-3100, và nhóm chủ đề này giúp hiểu lớp vận hành nào của firmware?

### Answer

Nếu Ngày 4 tập trung vào cấu hình một charging point, release logic, Event Actions và OCPP, thì Ngày 5 chuyển lên lớp vận hành cấp charging park và system control. Các chủ đề `Load Management`, `Network/Modem`, `System Control/Time`, `System Control/Log Files`, `System Control/Calibration Law` và `System Control/Developer Mode` không chỉ là các màn hình WBM rời rạc, mà là các điểm quan sát rất quan trọng để hiểu controller vận hành trong thực tế.

Có thể chia Ngày 5 thành sáu lớp học chính:

- `Load Management`: cách controller giới hạn, phân phối và tối ưu dòng sạc giữa nhiều charging points.
- `Modem`: cách controller cấu hình và giám sát kết nối cellular.
- `Time`: cách controller xử lý thời gian hệ thống, timestamp log và timestamp OCPP.
- `Log Files`: cách thu thập dữ liệu chẩn đoán từ system software và application software.
- `Calibration Law`: cách WBM hiển thị và kích hoạt cấu hình liên quan đến tuân thủ calibration law.
- `Developer Mode`: vùng chức năng nâng cao, có cảnh báo rủi ro rõ ràng, đặc biệt liên quan tới tài khoản Linux `user-app`.

Từ góc nhìn security research hợp pháp, Ngày 5 là ngày bắt đầu nối các khối policy của Ngày 4 với lớp vận hành hệ thống. Các điểm như route modem, UTC timestamp, log collection, calibration law service và Developer Mode đều là nơi cần hiểu kỹ trước khi phân tích behavior firmware, không phải để khai thác tùy tiện mà để dựng mô hình vận hành chính xác.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) có các phần `WBM - Load Management`, `Network/Modem`, `System Control/Time`, `System Control/Calibration Law`, `System Control/Developer Mode` và `System Control/Log Files`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả service `Load Management` là `Local load and charging management`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `System Monitor` là service cung cấp dữ liệu hệ thống hiện tại như network status, memory capacity và modem data.

## Câu hỏi 2

### Question

Trang `WBM - Load Management` được tổ chức như thế nào?

### Answer

Manual mô tả trang web dành cho load management trong charging park được chia thành ba phần:

- phần trên cùng hiển thị trạng thái hiện tại của load management
- phần cấu hình cho phép định nghĩa các tham số quản lý tải
- phần thêm charging points vào load management

Các trạng thái chính mà người học cần nắm gồm:

- `Load Management active`: chỉ báo màu cho biết load management agent trong charging controller có đang chạy hay không.
- `Limiting`: cho biết dòng sạc hiện có đang bị giới hạn hay không.
- `Monitored Charging Points`: số charging points đang được load management giám sát.
- `Current`: tổng dòng sạc tại tất cả monitored charging points.
- `Planned current`: tổng dòng sạc dự kiến tại tất cả monitored charging points.

Điểm cần chú ý là `Planned current` không nhất thiết bằng dòng thực tế. Manual nói dòng thực tế thường thấp hơn một chút so với dòng đặt, vì xe tự quyết định dòng với một safety margin so với giá trị setpoint. Vì vậy, khi đọc WBM hoặc log, không nên tự động coi chênh lệch nhỏ giữa planned current và actual current là lỗi.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) ghi trang load management trong charging park được chia thành ba phần: trạng thái hiện tại, cấu hình và thêm charging points vào load management.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `Load Management active` dùng chỉ báo màu: xanh là agent đang chạy, đỏ là agent không chạy.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `Limiting` là trạng thái dòng sạc đang bị giới hạn vì fuse value của load circuit thấp hơn dòng mà xe điện yêu cầu.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `Current` là tổng dòng sạc tại monitored charging points và `Planned current` là tổng dòng dự kiến phản ánh setting dành cho xe.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu dòng thực tế thường thấp hơn set current một chút do xe xác định dòng với safety margin.

## Câu hỏi 3

### Question

`Load Circuit Fuse` và `Limiting` liên hệ với nhau như thế nào trong Load Management?

### Answer

`Load Circuit Fuse` là giá trị cầu chì của load circuit, tính bằng ampere, áp dụng cho tất cả charging points được kết nối vào cùng load circuit. Giá trị này quyết định tổng dòng tối đa mà toàn bộ charging points trong nhóm đó có thể lấy.

`Limiting` là trạng thái xảy ra khi controller phải giới hạn dòng sạc. Manual mô tả trường hợp này là khi fuse value của load circuit thấp hơn dòng mà các electric vehicles đang yêu cầu. Nói cách khác, nếu tổng nhu cầu dòng sạc vượt quá giới hạn được định nghĩa bởi `Load Circuit Fuse`, load management phải can thiệp để giữ tổng dòng trong giới hạn an toàn.

Với người học firmware, mối quan hệ này là một rule vận hành cốt lõi:

- `Load Circuit Fuse` là giới hạn tĩnh do cấu hình.
- tổng dòng xe yêu cầu là biến động vận hành.
- `Limiting` là trạng thái runtime cho biết controller đang phải điều tiết do nhu cầu vượt giới hạn.

Đây là một điểm quan sát quan trọng khi dựng test case. Nếu muốn kiểm tra logic load management trong môi trường lab hợp pháp, cần có kịch bản phân biệt rõ cấu hình fuse, số charging points, planned current và actual current.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `Load Circuit Fuse` là fuse value của load circuit tính bằng ampere, áp dụng cho tất cả connected charging points.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu `Load Circuit Fuse` quyết định maximum amount of current mà tất cả connected charging points có thể lấy.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `Limiting` là trạng thái cho biết charging current đang bị giới hạn vì load circuit fuse value thấp hơn dòng mà electric vehicles yêu cầu.

## Câu hỏi 4

### Question

`Threshold to Current Reduction` là gì, và ví dụ trong manual cho thấy behavior nào?

### Answer

`Threshold to Current Reduction` định nghĩa độ lệch tối đa cho phép giữa dòng sạc thực tế của xe đang kết nối và current specification do load management đặt ra. Nếu độ lệch vượt quá ngưỡng này, current specification sẽ bị giảm.

Manual đưa ví dụ cụ thể:

- current specification từ load management là `16 A`
- actual charging current là `13 A`
- nếu threshold là `4 A`, current specification không bị giảm
- nếu threshold là `2 A`, current specification bị load management giảm

Ví dụ này cho thấy firmware không chỉ phân phối dòng theo setpoint ban đầu. Nó còn theo dõi việc xe thực tế có dùng dòng được cấp hay không. Nếu một xe dùng thấp hơn đáng kể so với dòng được cấp, hệ thống có thể giảm allocation của xe đó để tối ưu phân phối cho các charging points khác.

Điểm tinh tế ở đây là threshold không phải dòng tối đa, mà là ngưỡng sai lệch giữa dòng đặt và dòng thực tế. Khi nghiên cứu log hoặc hành vi runtime, cần đọc nó như một tham số phản hồi của thuật toán phân phối tải.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `Threshold to Current Reduction` là maximum possible deviation giữa charging current thực tế của xe và current specification của load management.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu nếu vượt threshold thì current specification bị giảm.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) đưa ví dụ `16 A` specification và `13 A` actual current: threshold `4 A` thì không giảm, threshold `2 A` thì giảm.

## Câu hỏi 5

### Question

`High Level Measuring Device` dùng để làm gì, và nó thay đổi mô hình Load Management ra sao?

### Answer

`High Level Measuring Device` được dùng khi có các tải khác cùng kết nối vào cùng fuse với charging park. Trong trường hợp này, nếu chỉ nhìn riêng dòng của charging points thì controller chưa đủ thông tin để biết tổng dòng qua feed-in hoặc load circuit có vượt giới hạn hay không.

Manual nói thiết bị đo cấp trên có thể ghi nhận tổng dòng. Việc này giúp đảm bảo fuse value của load circuit vẫn được tôn trọng, kể cả khi các charging points đang ở dưới giá trị dòng đó nhưng các tải khác bên ngoài charging points vẫn tiêu thụ điện.

Manual cho biết thiết bị đo cấp trên có thể được cấu hình theo connection type:

- `None`: không có thiết bị đo cấp trên.
- `TCP/IP connection`: thiết bị đo cấp trên kết nối qua network.
- `RS-485 connection`: thiết bị đo cấp trên kết nối tới charging interface của một charging controller qua RS-485.

Với RS-485, manual nêu hai ràng buộc quan trọng:

- chỉ các energy measuring devices cùng type mới được kết nối vào một RS-485 interface.
- Modbus address của thiết bị đo cấp trên phải đặt thành `Default setting +1`.

Ngoài ra, nếu dùng TCP/IP thì WBM có trường `IP Address` của measuring device và trường `Energy Measuring Device Type`. Các loại thiết bị đo mà manual liệt kê gồm Phoenix Contact EEM377 và Phoenix Contact MA370 với các mã EEM-EM377, EEM-MA370-R, EEM-MA370-24DC và EEM-MA370.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu nếu có other loads kết nối vào cùng fuse với charging park thì higher-level measuring device có thể record total current.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu thiết bị đo cấp trên giúp đảm bảo load circuit fuse value được tôn trọng.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) liệt kê connection type gồm `None`, `TCP/IP connection` và `RS-485 connection`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu với `RS-485 connection`, measuring device kết nối vào charging interface qua RS-485, chỉ energy measuring devices cùng type được kết nối vào một RS-485 interface, và Modbus address phải là `Default setting +1`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu `IP Address` chỉ khả dụng khi chọn `TCP/IP connection`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) liệt kê device type Phoenix Contact EEM377 và MA370, gồm EEM-EM377, EEM-MA370-R, EEM-MA370-24DC và EEM-MA370.
- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) nêu CHARX SEC-3100 có `Energy meter interface: RS-485` và hỗ trợ `Modbus/TCP`.

## Câu hỏi 6

### Question

`Higher Level Fuse Value`, `Load Strategy` và danh sách charging points trong Load Management có vai trò gì?

### Answer

`Higher Level Fuse Value` là fuse value của feed-in, tính bằng ampere. Manual nói giá trị này áp dụng cho tất cả charging points và các tải khác kết nối vào feed-in. Fuse này được higher-level measuring device giám sát, và nó quyết định tổng dòng tối đa mà charging points cùng các tải bổ sung được phép lấy.

`Load Strategy` là nơi chọn chiến lược sạc. Trong tài liệu tải được, manual nêu chiến lược `Equal distribution`. Với chiến lược này, tất cả charging points nhận cùng setting và không có charging point nào được ưu tiên.

Phần `Charging Management Charging Points` là nơi thêm charging points vào load management. Các charging points được chọn sẽ được gán vào load circuit. Điều này quan trọng vì load management chỉ có thể điều phối những charging points nằm trong phạm vi nó quản lý.

Nói gọn lại, cấu hình load management có ba tầng giới hạn:

- giới hạn của load circuit thông qua `Load Circuit Fuse`
- giới hạn tổng cấp trên thông qua `Higher Level Fuse Value`
- phạm vi áp dụng thông qua danh sách charging points được đưa vào load management

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `Higher Level Fuse Value` là fuse value của feed-in tính bằng ampere.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu giá trị này áp dụng cho tất cả charging points và loads kết nối vào feed-in, được monitored bởi higher-level measuring device.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu `Higher Level Fuse Value` quyết định maximum amount of current mà connected charging points và additional loads có thể lấy.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `Load Strategy` và chiến lược `Equal distribution`, trong đó charging points nhận cùng setting và không được ưu tiên.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu có thể add charging points vào load management và selected charging points được assigned to the load circuit.

## Câu hỏi 7

### Question

Load Management tối ưu phân phối dòng như thế nào khi dòng mong muốn của xe và số pha không đồng đều?

### Answer

Manual nói ngoài charging strategy đã chọn, load management còn thực hiện các tối ưu khác không ưu tiên riêng một charging point cụ thể.

Cơ chế tối ưu gồm ba ý chính:

- nếu setting vượt quá desired charging current của một xe, phần dòng còn lại sẽ được phân phối sang các charging points khác
- việc phân phối lại được kiểm tra và lặp lại theo chu kỳ định kỳ
- phân phối lại được thực hiện không có phase delay và có xét phần dòng còn dư trên từng pha

Ý thứ ba rất quan trọng với AC charging. Xe có thể sạc một pha, hai pha hoặc ba pha. Nếu phân phối không xét pha, hệ thống có thể tưởng còn dòng tổng nhưng thực tế lại lệch pha hoặc không tận dụng được pha còn dư. Manual nói load management xét phần current còn lại trên một phase và gán elsewhere trong redistribution, nhằm đảm bảo maximum current được phân phối cho xe một pha, hai pha và ba pha.

Nếu giảm current setting vẫn không đủ để giữ dòng dưới load circuit fuse value, load management có thể ngắt từng xe. Manual nêu xe có thời lượng sạc lâu nhất sẽ bị ngắt trước, và có thể được kết nối lại trong lần redistribution sau.

Với người học security/firmware, đây là behavior stateful. Nó phụ thuộc vào lịch sử thời lượng sạc, số lượng xe, số pha, dòng mong muốn, dòng thực tế và cấu hình fuse. Khi mô phỏng hoặc dựng test, cần coi load management như một vòng điều khiển lặp lại, không phải một phép chia dòng tĩnh.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu nếu setting vượt desired charging current của xe, remaining charging current sẽ được phân phối cho charging points khác.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu redistribution được kiểm tra theo regular intervals và lặp lại.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu redistribution được thực hiện với no phase delay.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu trong uneven distribution, current còn lại trên một phase được tính toán và assigned elsewhere để tối đa hóa current cho xe một pha, hai pha và ba pha.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu nếu giảm current setting không đủ để dưới load circuit fuse value, load management disconnects individual vehicles.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu vehicles with the longest charging duration are disconnected first và có thể connected again trong subsequent redistribution.

## Câu hỏi 8

### Question

Trang `Network/Modem` cho biết những trạng thái cellular nào của controller?

### Answer

Trang `Network/Modem` cho phép cấu hình cellular interface và lấy current status data. Manual yêu cầu login với vai trò `Operator` hoặc `Manufacturer` để truy cập phần này.

Các trạng thái modem được WBM hiển thị gồm:

- `Providers`: nhà mạng mà charging controller hiện đang kết nối.
- `APN`: access point name của access point đang active tới data network.
- `Registration Status`: trạng thái đăng ký mạng, gồm `Not registered/Not searching`, `Registered`, `Searching`, `Registration denied` và `Unknown`.
- `Roaming Status`: controller đang ở mạng nhà hay roaming, gồm `HOME` hoặc `ROAMING`.
- `Signal (Quality)`: chất lượng tín hiệu, gồm `Unknown`, `Marginal or less`, `Marginal`, `OK`, `Good`, `Excellent`.
- `Signal (RSSI)`: cường độ thu tín hiệu cellular, tính bằng dBm.
- `Signal (CQI)`: chỉ báo chất lượng kênh.
- `Radio Technology`: công nghệ wireless đang active, ví dụ `LTE` hoặc `GSM`.
- `IMSI`: định danh duy nhất của cellular communication subscriber.
- `ICCID`: định danh duy nhất của SIM card.
- `MSISDN`: số gọi duy nhất của SIM card.
- `SIM`: trạng thái SIM card.

Với `SIM`, manual liệt kê nhiều trạng thái có thể xuất hiện, gồm `READY`, `SIM PIN`, `SIM PUK`, `SIM not inserted`, `SIM PIN required`, `SIM PUK required`, `SIM failure`, `SIM busy`, `SIM wrong`, `Incorrect password` và `No network service`.

Nhóm trạng thái này rất có ích khi phân biệt lỗi cấu hình APN, lỗi SIM, lỗi sóng, lỗi roaming và lỗi đăng ký mạng. Khi nghiên cứu sự cố OCPP qua cellular, các trường modem này là lớp quan sát trước khi kết luận backend hoặc OCPP service có lỗi.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu `Network/Modem` dùng để configure cellular interface và acquire current status data.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu cần login `Operator` hoặc `Manufacturer`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả các trường status gồm `Providers`, `APN`, `Registration Status`, `Roaming Status`, `Signal (Quality)`, `Signal (RSSI)`, `Signal (CQI)`, `Radio Technology`, `IMSI`, `ICCID`, `MSISDN` và `SIM`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu `Radio Technology` là công nghệ wireless đang active, ví dụ `LTE` hoặc `GSM`.
- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) nêu CHARX SEC-3100 có `Cellular communication: 4G/2G`.

## Câu hỏi 9

### Question

Các trường cấu hình Modem nói gì về APN, credential và routing?

### Answer

Phần `Modem Configuration` trong WBM chứa các trường để bật modem tích hợp, cấu hình SIM/APN và quyết định cách traffic đi qua cellular interface.

Các trường cấu hình chính gồm:

- `Service active`: nút để activate integrated modem.
- `SIM Pin`: trường nhập PIN của SIM card, do cellular provider cung cấp.
- `APN`: trường nhập access point, do cellular provider cung cấp.
- `Use credentials`: dùng khi APN yêu cầu username và password.
- `User`: username để truy cập APN, do cellular provider cung cấp.
- `Password`: password để truy cập APN, do cellular provider cung cấp.
- `Default Route`: nếu bật, cellular connection được dùng làm default route cho data traffic.
- `Prefer Modem over ETH0`: nếu interface khác đang là default route, cellular interface được ưu tiên bằng metric nhỏ hơn.
- `SAVE`: chuyển configuration data vào charging controller.
- `RESTART MODEM SERVICE`: restart modem.
- `TEST MODEM`: gửi ping tới network address đã nhập.

Manual giải thích thêm rằng khi `Default Route` được bật, cellular connection là default route cho data traffic. Trong trường hợp này, explicit route qua `ETH0` hoặc `ppp0` không được chỉ định trong user program.

Từ góc nhìn vận hành, `Default Route` và `Prefer Modem over ETH0` là hai tham số có tác động trực tiếp tới đường đi của traffic như OCPP, MQTT, REST hoặc các kết nối backend khác. Khi phân tích connectivity issue, cần ghi lại network interface được chọn ở OCPP, trạng thái modem và các flag route này.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `Service active` là button để activate integrated modem.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `SIM Pin`, `APN`, `Use credentials`, `User` và `Password` đều là thông tin do cellular provider cung cấp hoặc phụ thuộc yêu cầu của APN.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu nếu `Default Route` được enable thì cellular connection được dùng làm default route cho data traffic.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu khi dùng `Default Route`, explicit route qua `ETH0` hoặc `ppp0` không được chỉ định trong user program.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu `Prefer Modem over ETH0` sẽ ưu tiên cellular interface bằng smaller metric nếu interface khác được chọn làm default route.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `SAVE`, `RESTART MODEM SERVICE` và `TEST MODEM`.
- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) nêu các protocol được hỗ trợ gồm `OCPP 1.6J`, `Modbus/TCP`, `MQTT`, `HTTP` và `HTTPS`.

## Câu hỏi 10

### Question

`System Control/Time` xử lý thời gian như thế nào, và vì sao UTC quan trọng với log và OCPP?

### Answer

Trong `System Control/Time`, người vận hành có thể xem và đặt current system time/date. Manual cũng nói có thể áp dụng thời gian đang đặt trên PC từ web browser.

Điểm quan trọng nhất là controller vận hành nội bộ bằng UTC. Manual nêu charging controller dùng UTC time cho timestamp trong log files và trong OCPP communication. Ngoài ra, timestamp từ OCPP backend được chuyển đổi sang system time của charging controller, và để làm việc này thì backend phải gửi UTC time.

Vì vậy, khi đọc log hoặc đối chiếu OCPP trace, cần tách ba khái niệm:

- thời gian hiển thị trong WBM hoặc trình duyệt
- UTC time dùng nội bộ trong controller
- timestamp từ backend OCPP được gửi và chuyển đổi

Nếu không làm rõ UTC, rất dễ nhầm thứ tự sự kiện. Ví dụ, một lỗi nhìn như xảy ra trước khi bắt đầu session có thể chỉ là do lệch timezone hoặc timestamp backend không ở UTC như manual yêu cầu.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu có thể view và set current system time/date qua `System Control/Time`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu có thể apply time set on the PC from the web browser.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) ghi rõ `UTC time used internally in the system`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu charging controller vận hành nội bộ với UTC time và dùng nó cho timestamps trong log files và OCPP communication.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu timestamps từ OCPP backend được converted to charging controller system time, và UTC time phải được gửi.

## Câu hỏi 11

### Question

`System Control/Log Files` cung cấp những gì cho chẩn đoán và support?

### Answer

Trong `System Control/Log Files`, người vận hành có thể tải current log data của system software và application software bằng nút `DOWNLOAD LOGS`.

Manual nói log data của các relevant software services được lưu trong nhiều file khác nhau. Khi tải xuống, các log files được nén thành một file duy nhất, sau đó có thể giải nén trên target computer.

Khi liên hệ Phoenix Contact Support, manual yêu cầu chuẩn bị:

- log files
- error description
- details of the charging controllers used

Manual cũng nêu log files có thể được truy cập bởi charging controller thông qua OCPP command `GetDiagnostics`. Điều này nối trực tiếp phần Log Files với phần OCPP đã học ở Ngày 4. Về mặt vận hành, có hai đường lấy log:

- đường local/WBM bằng `DOWNLOAD LOGS`
- đường backend/OCPP bằng `GetDiagnostics`

Với security research hợp pháp, log files là bằng chứng quan trọng để tái dựng sequence. Tuy nhiên, tài liệu tải được không liệt kê đường dẫn nội bộ, định dạng từng file log, hay tên process cụ thể bên trong firmware. Vì vậy, mọi suy luận sâu hơn về file path hoặc process cần được đánh dấu là phân tích riêng, không phải nội dung từ official manual.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu `System Control/Log Files` cho phép download current log data for the system and the application software bằng nút `DOWNLOAD LOGS`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu log data của relevant software services được lưu trong various files.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu khi downloaded, log files được compressed into one file và có thể extracted on the target computer.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu khi support cần chuẩn bị log files, error description và details of the charging controllers used.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu log files cũng có thể accessed qua OCPP command `GetDiagnostics`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) ở phần OCPP nêu previous messages trong log file có thể downloaded qua `System Control/Log Files`.

## Câu hỏi 12

### Question

`System Control/Calibration Law` hiển thị và kích hoạt những gì?

### Answer

`System Control/Calibration Law` là khu vực WBM để tạo các setting liên quan đến calibration law. Manual nói trang này cũng hiển thị overview của các setting liên quan tới calibration law cho từng charging point và OCPP.

Manual mô tả cách WBM đánh dấu trạng thái như sau:

- setting không compliant với calibration laws được hiển thị màu đỏ
- warning được hiển thị màu vàng

Người vận hành có thể kích hoạt calibration law bằng nút `SWITCH ON CALIBRATION LAW`. Sau thao tác này, controller restart và một software service bổ sung được start.

Trong bảng `System Control | Status`, manual nêu service `Calibration Law Agent` chỉ visible khi calibration law đang active. Service này đảm bảo charging station được vận hành compliant với calibration laws.

Điểm cần giữ rất rõ là tài liệu tải được mô tả behavior trong WBM và service ở mức vận hành, nhưng không giải thích chi tiết pháp lý của từng thị trường, cũng không mô tả thuật toán ký dữ liệu đo hoặc định dạng dữ liệu đo. Vì vậy, phần này nên được học như một control surface chính thức của firmware liên quan tới compliance, chưa phải tài liệu pháp lý đầy đủ.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu trong `System Control/Calibration Law`, có thể make settings for the calibration law.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu khu vực này hiển thị overview của settings relevant to calibration law cho individual charging points và OCPP.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu settings không compliant với calibration laws được hiển thị màu đỏ và warnings màu vàng.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu có thể activate calibration law bằng nút `SWITCH ON CALIBRATION LAW`, sau đó controller restart và additional software service được started.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu `Calibration Law Agent` chỉ visible khi calibration law active và đảm bảo charging station operated in compliance with calibration laws.

## Câu hỏi 13

### Question

`System Control/Developer Mode` là gì, và vì sao manual cảnh báo phải cẩn thận?

### Answer

`System Control/Developer Mode` là khu vực cho phép truy cập advanced system functions. Manual đưa cảnh báo rõ ràng rằng incorrect settings có thể làm hệ thống bị impairment hoặc failure.

Trong tài liệu tải được, Developer Mode được mô tả cụ thể liên quan đến tài khoản Linux `user-app`:

- có thể đổi password cho user `user-app` trong khu vực `Linux User Change Password`
- cần current valid password để đổi password
- password đã đổi vẫn giữ nguyên sau complete system update và không bị reset
- có thể reset password của `user-app` về delivery state bằng nút `RESET PASSWORD`
- delivery-state password được manual ghi là `user`

Từ góc nhìn vận hành an toàn, đây là khu vực phải được kiểm soát quyền truy cập chặt. Vì password mới vẫn tồn tại sau full system update, việc thay đổi hoặc mất kiểm soát password không phải là vấn đề tạm thời. Nó có thể ảnh hưởng lâu dài tới khả năng bảo trì, truy cập ứng dụng hoặc quy trình khôi phục.

Với security research hợp pháp, Developer Mode nên được ghi nhận như một official administrative surface. Khi dựng lab, cần tách rõ môi trường nghiên cứu riêng, thiết bị thuộc quyền sở hữu/ủy quyền, và không áp dụng thao tác này trên hệ thống sản xuất nếu chưa có change plan.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu `System Control/Developer Mode` cung cấp access to advanced system functions.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) cảnh báo `Incorrect settings can result in impairment or failure of the system`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu có thể change password cho user `user-app` trong `Linux User Change Password`, và cần currently valid password.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu changed password vẫn giữ sau complete system update và không reset.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu có thể reset password cho user `user-app` về delivery state bằng `RESET PASSWORD`, với password `user`.

## Câu hỏi 14

### Question

Các service trong `System Control | Status` giúp liên kết Day 5 với kiến trúc phần mềm như thế nào?

### Answer

Bảng `System Control | Status` trong manual không chỉ là màn hình trạng thái. Nó cho thấy một bản đồ service ở mức vận hành, giúp người học nối các trang WBM với các khối phần mềm bên trong controller.

Các service liên quan trực tiếp tới Day 5 và các ngày trước gồm:

- `System Monitor`: cung cấp dữ liệu hệ thống hiện tại như network status, memory capacity và modem data.
- `Controller Agent`: chuẩn hóa interface giữa local charging controllers kết nối qua backplane bus, clients qua Ethernet và extension modules.
- `OCPP 1.6J`: backend communication theo OCPP 1.6J.
- `Modbus Client`: kết nối các Modbus/TCP meters qua Ethernet.
- `Modbus Server`: cung cấp Modbus/TCP interface để đọc charging data và điều khiển charging processes.
- `JupiCore`: thu thập dữ liệu từ tất cả connected charging points và forward tới MQTT broker, internal services và external services qua REST API.
- `Load Management`: local load and charging management.
- `Web Server`: web-based management của charging controller.
- `Calibration Law Agent`: chỉ visible khi calibration law active, đảm bảo charging station vận hành compliant với calibration laws.

Đây là một lát cắt rất hữu ích cho việc học firmware. Nó cho thấy WBM không phải một giao diện cô lập, mà là mặt trước của nhiều service: web server hiển thị cấu hình, system monitor cung cấp telemetry, modem data đi vào network status, OCPP/JupiCore/Modbus kết nối ra hệ sinh thái ngoài, còn Load Management và Calibration Law Agent thực thi logic vận hành chuyên biệt.

Tuy nhiên, manual không đưa tên binary, process ID, systemd unit, đường dẫn file hoặc source code. Vì vậy, khi học tới mức firmware/code, cần phân biệt rõ: service name trong WBM là bằng chứng chính thức, còn mapping sang process hoặc file firmware là bước reverse engineering riêng cần làm trong lab.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `System Monitor` cung cấp current system data như network status, memory capacity và modem data.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `Controller Agent` chuẩn hóa interface giữa local charging controllers qua backplane bus, clients qua Ethernet và extension modules.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `OCPP 1.6J` là backend communication.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `Modbus Client`, `Modbus Server`, `JupiCore`, `Load Management`, `Web Server` và `Calibration Law Agent`.
- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) nêu supported protocols gồm `OCPP 1.6J`, `Modbus/TCP`, `MQTT`, `HTTP` và `HTTPS`.

## Câu hỏi 15

### Question

`Import/Export` liên quan gì tới các chủ đề Ngày 5?

### Answer

Mặc dù user request của Ngày 5 tập trung vào Load Management, Modem, Time, Log Files, Calibration Law và Developer Mode, phần `Import/Export` trong cùng vùng System Control cũng đáng ghi nhận vì nó cho thấy những nhóm cấu hình có thể được xuất hoặc nhập.

Manual nói có thể export hoặc import current settings cho các sub-registers sau:

- `Charging park`
- `CHARX RFID/NFC configuration`
- `Whitelist`
- `Load management`
- `OCPP`
- `System configuration (Ethernet, port sharing, modem)`
- `MQTT bridge (configuration, topic forwarding)`
- `OpenVPN`

Liên hệ với Ngày 5, hai nhóm đặc biệt quan trọng là `Load management` và `System configuration (Ethernet, port sharing, modem)`. Điều này cho thấy cấu hình quản lý tải và cấu hình modem/network không chỉ được chỉnh trong WBM, mà còn thuộc nhóm có thể import/export.

Với nghiên cứu firmware hợp pháp, import/export là một điểm cần học kỹ ở giai đoạn sau vì nó có thể cho biết cấu trúc dữ liệu cấu hình, phạm vi tham số, và cách controller serialize/restore trạng thái. Tuy nhiên, trong tài liệu hiện có, manual chỉ nêu danh sách nhóm có thể import/export, chưa mô tả định dạng file hoặc schema.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) nêu trong `Import/Export`, có thể export hoặc import current settings cho các sub-registers.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) liệt kê `Load management`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) liệt kê `System configuration (Ethernet, port sharing, modem)`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) cũng liệt kê `Charging park`, `CHARX RFID/NFC configuration`, `Whitelist`, `OCPP`, `MQTT bridge` và `OpenVPN`.

## Kết quả cần nắm sau Ngày 5

Sau khi học xong Ngày 5, bạn nên nắm chắc:

- `Load Management` là lớp local load and charging management cho charging park, gồm status, cấu hình fuse, thiết bị đo cấp trên, load strategy và danh sách charging points được quản lý.
- `Load Circuit Fuse` giới hạn tổng dòng của các connected charging points, còn `Higher Level Fuse Value` giới hạn tổng dòng ở feed-in khi xét cả additional loads.
- `Threshold to Current Reduction` là ngưỡng sai lệch giữa current specification và actual charging current, dùng để quyết định có giảm current specification hay không.
- load management không chỉ chia đều dòng, mà còn phân phối lại dòng dư, xét pha, lặp lại theo chu kỳ và có thể disconnect xe có thời lượng sạc lâu nhất nếu giảm dòng không đủ.
- `Network/Modem` cho thấy cả trạng thái cellular như provider, APN, registration, roaming, RSSI/CQI, radio technology, SIM status và cấu hình modem như SIM PIN, APN, credentials, default route, modem preference, restart và test.
- `System Control/Time` dùng UTC nội bộ cho log timestamp và OCPP communication, nên mọi phân tích log/OCPP phải kiểm tra timezone và UTC.
- `System Control/Log Files` là đường lấy log qua WBM bằng `DOWNLOAD LOGS`, đồng thời log cũng có thể được truy cập qua OCPP `GetDiagnostics`.
- `System Control/Calibration Law` là control surface cho compliance-related settings, có màu đỏ/vàng để báo non-compliance/warning và có thể start thêm `Calibration Law Agent` sau khi kích hoạt.
- `System Control/Developer Mode` là vùng advanced system functions, có cảnh báo rủi ro hệ thống và có chức năng đổi/reset password cho Linux user `user-app`.
- `System Control | Status` cung cấp bản đồ service ở mức WBM, nhưng không đủ để kết luận tên binary, process path hoặc source code bên trong firmware.
