# Ngày 3 - Đấu nối phần cứng, I/O và giao diện hiện trường

Tài liệu này chỉ dựa trên các nguồn trong thư mục `document`, không dựa trên code, config hay phân tích firmware trong workspace. Cấu trúc được chuẩn hóa theo dạng `Question -> Answer -> Evidence`.

## Nguồn tài liệu dùng cho Ngày 3

- [wiring_section.html](/d:/CHARXSEC/document/wiring_section.html)
- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md)

## Câu hỏi 1

### Question

Nếu chỉ nhìn từ tài liệu gốc, `CHARX SEC-3100` đưa ra những giao diện phần cứng và nhóm đấu nối nào cần quan tâm trong ngày học này?

### Answer

Ở mức tổng quan phần cứng, tài liệu cho thấy `CHARX SEC-3100` không phải chỉ là một bo điều khiển đơn lẻ, mà là một controller trung tâm có nhiều lớp giao diện vật lý:

- nguồn cấp `12 V DC`
- `2` cổng Ethernet
- `USB-C` cho cấu hình và chẩn đoán
- giao tiếp di động `4G/2G`
- `RS-485` cho công tơ điện
- `RS-485` cho đầu đọc RFID
- `4` digital inputs
- `4` digital outputs
- giao diện xe theo `IEC 61851-1` và `GB/T 18487`

Riêng chương đấu nối trong manual cho thấy khi triển khai thực tế, người học cần nắm các nhóm wiring sau:

- nguồn cấp
- giao diện sạc
- load contactor
- residual current monitoring
- energy meter
- RFID reader
- digital outputs
- digital inputs
- temperature sensors

Nếu ghép các nhóm này lại, có thể xem ngày 3 là ngày dựng “bản đồ hiện trường” của controller: nguồn ở đâu, tín hiệu đi đâu, phần tử công suất nào được điều khiển, và cảm biến hay thiết bị phụ nào tham gia vào vòng vận hành.

### Evidence

- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) liệt kê các interface vật lý gồm `2` Ethernet, `USB-C`, `4G/2G`, `RS-485` cho meter và RFID, `4` digital inputs, `4` digital outputs.
- [wiring_section.html](/d:/CHARXSEC/document/wiring_section.html) có mini table of contents với các mục: `Supply voltage`, `Connecting the charging interface`, `Connecting the load contactor`, `Residual current monitoring`, `Connecting the energy measuring device`, `Connecting an RFID reader`, `Connecting digital outputs`, `Connecting digital inputs`, `Connecting temperature sensors`.

## Câu hỏi 2

### Question

Manual yêu cầu những giả định an toàn nào trước khi bắt đầu đấu nối?

### Answer

Manual đặt phần an toàn lên trước toàn bộ wiring, và thông điệp ở đây rất rõ: đây là một hệ thống có liên quan trực tiếp đến điện lưới nguy hiểm, nên mọi thao tác đấu nối phải được xem như công việc trên thiết bị điện công suất.

Các yêu cầu an toàn được nêu thẳng gồm:

- có nguy cơ điện giật chết người do phải làm việc với điện áp lưới nguy hiểm
- phải bảo đảm chống điện giật
- chỉ thao tác khi thiết bị đã được cắt điện
- phải ngăn việc cấp điện lại trái phép trong lúc đang làm việc
- khi đấu dây phải tuân thủ hướng dẫn về đầu nối và kết nối dây dẫn

Về mặt học tập, điều này có nghĩa là khi đọc các sơ đồ đấu nối phía sau, ta phải hiểu chúng trong bối cảnh commissioning tại hiện trường, không phải như sơ đồ logic thuần túy.

### Evidence

- [wiring_section.html](/d:/CHARXSEC/document/wiring_section.html) ghi `DANGER: Risk of fatal electric shock`.
- Cùng tài liệu này nêu `Protection against electric shock must be ensured`.
- Cùng tài liệu này nêu `Only perform work on the device when the power is disconnected`.
- Cùng tài liệu này nêu phải bảo đảm nguồn không thể bị đóng điện lại bởi người không có thẩm quyền.

## Câu hỏi 3

### Question

Yêu cầu nguồn cấp của `CHARX SEC-3100` là gì, và phải dimension nguồn ra sao?

### Answer

Theo technical data và manual wiring, `CHARX SEC-3100` dùng nguồn `12 V DC`. Nếu ghép hai nguồn này lại, có thể rút ra bộ tham số điện cơ bản sau:

- điện áp danh định: `12 V DC`
- dung sai theo technical data: `±5%`
- dải điện áp tương ứng: `11.4 V DC ... 12.6 V DC`
- wiring section diễn đạt theo cách khác là `+12 V DC, ±0.6 V`
- dòng tiêu thụ cực đại được nêu trong technical data: `2 A` ở chế độ stand-alone

Manual còn nhấn mạnh ba điểm rất quan trọng khi dimension nguồn:

1. có thể cấp nguồn cho nhiều charging controller qua đầu nối trên DIN rail, nghĩa là chỉ một module cần cấp nguồn trực tiếp, các module còn lại nhận nguồn qua backplane
2. dòng danh định của backplane bus cấp nguồn cho module là `6 A`
3. phải tính tổng dòng theo toàn bộ controller và I/O gắn kèm, vì dòng thực tế còn phụ thuộc vào cấu hình và thiết bị ngoại vi

Ngoài ra, nếu điều khiển load contactor từ lưới AC thì:

- nguồn `12 V` và mạch điều khiển contactor phải nằm cùng pha
- bộ nguồn phải được dimension đủ để xử lý các surge voltage theo yêu cầu tiêu chuẩn

Đây là một chi tiết rất thực dụng: nguồn của controller không thể chọn chỉ theo công suất logic board, mà phải tính cùng toàn bộ hệ I/O và topology module.

### Evidence

- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) ghi `Supply voltage: 12 V DC ±5%`, `Supply voltage range: 11.4 V DC ... 12.6 V DC`, `Max. current consumption: 2 A in stand-alone operation`.
- [wiring_section.html](/d:/CHARXSEC/document/wiring_section.html) ghi controller hoạt động với `+12 V DC, ±0.6 V`.
- Cùng tài liệu này nêu có thể nối nhiều controller qua `DIN rail connector`, chỉ cần một controller được cấp nguồn trực tiếp.
- Cùng tài liệu này nêu `The nominal current of the backplane bus for supplying power to the modules is 6 A`.
- Cùng tài liệu này nêu nguồn `12 V` và điều khiển contactor phải cùng pha khi contactor được điều khiển từ lưới AC.

## Câu hỏi 4

### Question

`CHARX SEC-3100` hỗ trợ những kiểu giao diện sạc nào, và phần đấu nối charging socket/connector phải hiểu ra sao?

### Answer

Manual mô tả hai kiểu triển khai giao diện sạc AC:

- trạm có `charging socket`, tương ứng `Case B` theo `IEC 61851-1`
- trạm có `charging connector` gắn cố định trên cáp, tương ứng `Case C`

Tức là controller này hỗ trợ cả:

- ổ cắm sạc trên trạm, nơi người dùng cắm cáp của xe vào
- cáp sạc cố định gắn sẵn vào trạm

Với charging socket, tài liệu yêu cầu:

- nối `CP` và `PP` vào đầu nối `Socket`
- nối dây bảo vệ của socket vào DIN rail của controller
- đặt trong WBM kiểu kết nối là `Socket`

Với charging connector gắn sẵn:

- cũng phải nối dây bảo vệ vào DIN rail của controller
- trong WBM chọn kiểu kết nối là `Connector`

Manual cũng nhấn mạnh rằng dòng sạc tối đa được cấu hình không được vượt quá khả năng chịu dòng của socket hoặc connector đang dùng. Nghĩa là việc đặt dòng sạc trong phần mềm bị ràng buộc trực tiếp bởi lựa chọn phần cứng ngoài hiện trường.

### Evidence

- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) ghi `Charging standard: IEC 61851-1` và `Charging mode: Mode 3, Case B + C`.
- [wiring_section.html](/d:/CHARXSEC/document/wiring_section.html) ghi controller có thể dùng trong charging station với `charging socket (charging case B in accordance with IEC 61851-1)` hoặc `permanently fastened charging cable with charging connector (charging case C)`.
- Cùng tài liệu này nêu phải nối `Control Pilot (CP)` và `Proximity (PP)` vào đầu nối `Socket`.
- Cùng tài liệu này nêu dây bảo vệ của charging socket hoặc charging connector phải nối tới DIN rail của charging controller.
- Cùng tài liệu này nêu phải bảo đảm `set maximum charging current does not exceed the current carrying capacity` của socket hoặc connector.

## Câu hỏi 5

### Question

Tài liệu nói gì về locking actuator 4 cực, 3 cực và ý nghĩa của chúng đối với phần đấu nối?

### Answer

Đây là một điểm rất quan trọng vì manual phân biệt rõ hai kiểu actuator cho charging socket:

- `4-pos. locking actuator`
- `3-pos. locking actuator`

Theo tài liệu, controller được tối ưu cho socket dùng `4-pos. locking actuator`. Đây là cấu hình được xem như đường đi chuẩn. Nếu dùng socket với `3-pos. locking actuator`, manual cảnh báo controller có thể hoạt động sai hoặc bị hỏng nếu không bổ sung mạch bảo vệ ngoài.

Với `3-pos. locking actuator`, manual yêu cầu thêm một protective circuit để bảo vệ ngõ vào `Lock Detection`, gồm:

- điện trở `1 kΩ`
- diode Zener `3 V`

Ý nghĩa kỹ thuật của đoạn này là: cùng là “socket có khóa”, nhưng cách phản hồi tín hiệu khóa không hoàn toàn tương đương giữa các thế hệ/cấu hình phần cứng. Vì vậy controller không thể coi mọi locking actuator là thay thế lẫn nhau mà không cần conditioning mạch.

### Evidence

- [wiring_section.html](/d:/CHARXSEC/document/wiring_section.html) ghi `The charging controller is optimized for operation with charging sockets with a 4-pos. locking actuator`.
- Cùng tài liệu này nêu việc dùng `3-pos. locking actuators` có thể làm controller malfunction hoặc bị hỏng nếu không có `external protective circuit`.
- Cùng tài liệu này nêu protective circuit cho `Lock Detection` gồm `a 1 kΩ resistor and a 3 V Zener diode`.

## Câu hỏi 6

### Question

`Load contactor` có vai trò gì, controller điều khiển nó như thế nào, và có thể giám sát lỗi ra sao?

### Answer

Manual mô tả `load contactor` là phần tử đóng/cắt xe điện với lưới điện. `CHARX SEC-3100` không chỉ phát lệnh logic mà trực tiếp bật/tắt load contactor thông qua một `floating contact`.

Tài liệu phân biệt hai tình huống:

- với các bộ điều khiển không có giao tiếp `ISO/IEC 15118` với xe, ví dụ `CHARX SEC-3x00`, contactor có thể được đóng cắt bằng `DC < 30 V` hoặc `mains voltage < 250 V AC`
- với các bộ điều khiển có giao tiếp `ISO/IEC 15118`, tài liệu khuyên dùng điện áp lưới cho điều khiển contactor để phát hiện điểm zero-cross

Ngoài việc điều khiển contactor, manual còn mô tả cơ chế giám sát lỗi:

- có thể dùng `auxiliary switch` của contactor
- đưa một mức `12 V` vào một digital input còn trống qua auxiliary switch
- trong WBM cấu hình input đó cho chức năng monitor, đồng thời chỉ ra auxiliary contact là `normally closed` hay `normally open`

Về mặt kiến trúc, điều này cho thấy controller có một vòng điều khiển đóng cắt công suất và một vòng xác nhận phản hồi trạng thái contactor qua input.

### Evidence

- [wiring_section.html](/d:/CHARXSEC/document/wiring_section.html) ghi `The load contactor connects the electric vehicle to the power grid`.
- Cùng tài liệu này nêu contactor được controller bật/tắt `via a floating contact`.
- Cùng tài liệu này nêu đối với `CHARX SEC-3x00`, contactor có thể điều khiển bằng `DC voltage <30 V` hoặc `mains voltage <250 V AC`.
- Cùng tài liệu này nêu với controller có `ISO/IEC 15118 communication`, nên dùng mains voltage để phát hiện `zero cross detection`.
- Cùng tài liệu này nêu có thể monitor contactor bằng `auxiliary switch` và đưa `12 V potential` vào một digital input tự do.

## Câu hỏi 7

### Question

Residual current monitoring được triển khai như thế nào theo manual?

### Answer

Đây là một trong những phần quan trọng nhất của wiring chapter vì nó gắn trực tiếp với an toàn điện theo `IEC 61851-1`. Manual nói rằng trong charging station cho EV có thể xuất hiện DC residual currents, và điều này có thể làm suy giảm chức năng của residual current protection. Vì vậy phải triển khai một trong các biện pháp mà chuẩn yêu cầu.

Theo manual, controller hỗ trợ hai cách triển khai chính:

1. vận hành với `type B all-current-sensitive residual current device`
2. vận hành với `6 mA DC residual current sensor`

Nếu dùng `type B`:

- phải tạo cầu nối giữa chân `12V` và `ER2` trên đầu nối `RCM`
- đồng thời phải bảo đảm residual current monitoring bị vô hiệu hóa trong WBM

Nếu dùng cảm biến `6 mA DC residual current`:

- controller chấp nhận cả cảm biến báo lỗi kiểu `Active High` lẫn `Active Low`
- tín hiệu lỗi đi qua open-collector hoặc open-drain
- controller có sẵn pull-up lên `12 V`
- đầu nối `RCM` cung cấp `12V` và `0V` để nuôi cảm biến ngoài
- chân số `5` trên `RCM` cung cấp tín hiệu test `12 V`, do controller điều khiển tự động
- nếu cảm biến báo lỗi kiểu `Active High` hoặc `12 V`, đưa ngõ lỗi vào `ER1`
- nếu cảm biến báo lỗi kiểu `Active Low` hoặc `0 V`, đưa ngõ lỗi vào `ER2`

Manual còn cảnh báo rất mạnh rằng đảo cực giữa chân `Fault` và `Test` sẽ gây short circuit trên cảm biến residual current và làm cảm biến mất chức năng.

Đoạn này rất quan trọng để hiểu controller không “tự phát hiện” residual current theo kiểu tất cả nằm trong SoC, mà nó phối hợp chặt với phần cứng bảo vệ ngoài thông qua đầu nối `RCM`.

### Evidence

- [wiring_section.html](/d:/CHARXSEC/document/wiring_section.html) nêu theo `IEC 61851-1`, DC residual currents có thể xuất hiện trong charging stations cho EV.
- Cùng tài liệu này nêu với `type B all-current-sensitive residual current protection`, phải tạo bridge giữa `12V` và `ER2` trên đầu nối `RCM`.
- Cùng tài liệu này nêu khi dùng cảm biến `6 mA DC residual current`, có thể dùng cảm biến `Active High` hoặc `Active Low`, controller có `integrated pull-up resistor to 12 V`, và cung cấp `12 V test signal` tại terminal point `5`.
- Cùng tài liệu này nêu `Active High` fault output nối vào `ER1`, còn `Active Low` fault output nối vào `ER2`.
- Cùng tài liệu này cảnh báo đảo cực `Fault` và `Test` sẽ gây `short circuit` và làm cảm biến không còn hoạt động.

## Câu hỏi 8

### Question

Energy meter được nối thế nào, và khi nào nó trở thành thành phần bắt buộc?

### Answer

Manual mô tả energy meter như phần tử dùng để ghi nhận charging currents, được kết nối tới controller qua giao diện `RS-485` trên đầu nối `Meter`.

Điểm rất quan trọng là energy meter không chỉ là thiết bị “để đo cho biết”, mà manual nói rõ nó cần được kết nối nếu muốn dùng các chức năng sau:

- current monitoring
- overcurrent monitoring
- out-of-balance monitoring
- load management

Nghĩa là trong kiến trúc của `CHARX SEC-3100`, nhiều chức năng giám sát dòng và điều phối tải dựa vào dữ liệu đo từ công tơ ngoài, chứ không hoàn toàn suy ra từ trạng thái logic nội bộ.

Manual hiện liệt kê các meter được hỗ trợ:

- Phoenix Contact `EEM-350-D-MCB`, `2905849`
- Phoenix Contact `EEM-DM357`, `1252817`
- Phoenix Contact `EEM-DM357-70`, `1219095`
- Phoenix Contact `EEM-EM357`, `2908588`
- Phoenix Contact `EEM-EM357-EE`, `1311985`
- Phoenix Contact `EEM-EM157-EE`, `1311993`
- Phoenix Contact `EEM-AM157-70`, `1219090`
- Carlo Gavazzi `EM24`
- Carlo Gavazzi `EM111`
- Carlo Gavazzi `EM340`
- Inepro `PRO380-Mod`
- Iskra `WM3M4(C)`

Ngoài ra, manual nói danh sách meter hỗ trợ có thể được mở rộng qua các software update trong tương lai, và phiên bản software đang chạy sẽ quyết định danh sách nào thực sự xuất hiện trong WBM.

### Evidence

- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) ghi `Energy meter interface: RS-485`.
- [wiring_section.html](/d:/CHARXSEC/document/wiring_section.html) ghi dùng giao diện `RS-485` trên đầu nối `Meter` để kết nối energy measuring device.
- Cùng tài liệu này nêu `Always connect an energy measuring device if you want to use functions for current monitoring (overcurrent and out-of-balance monitoring) or load management`.
- Cùng tài liệu này liệt kê danh sách energy meter currently supported và nói danh sách đó có thể được mở rộng trong các software update tương lai.

## Câu hỏi 9

### Question

RFID reader được tích hợp vào hệ thống như thế nào, và manual yêu cầu những ràng buộc cụ thể nào?

### Answer

Theo manual, RFID reader được dùng để authorize người dùng và nối vào controller qua giao diện `RS-485` trên đầu nối `Supply/RFID`.

Tài liệu mô tả mô hình hoạt động như sau:

- thẻ RFID đọc được có thể được đối chiếu với `local white list`
- hoặc được kiểm tra qua `external management system`
- một đầu đọc RFID có thể phục vụ nhiều charging point
- đầu đọc có thể được cấp nguồn `12 V` ngay từ đầu nối `Supply/RFID`
- dây truyền thông của đầu đọc được nối vào `A+/B-`

Manual liệt kê các đầu đọc được hỗ trợ tại thời điểm tài liệu:

- `CHARX RFID/NFC`
- `ELATEC T4W2 PALON COMPACT LIGHT PCB (T4W2-F02B6)`
- `ELATEC TWN4 PALON COMPACT LIGHT Panel (T4PK-F02TR6)`
- `DUALI DE-950-4`, `DUALI DE-950-4-CXP`
- `Netronix UW-XEU1`

Manual cũng nêu các ràng buộc rất cụ thể theo từng vendor:

- với đầu đọc `ELATEC`, phải dùng `AppBlaster` và file `TWN4_NCx320_STD203_Standard.bix`
- `termination resistor` tại `DIP switch 8` phải tắt
- file chương trình được cung cấp chỉ tương thích với bootloader version `1.08`
- với `CHARX RFID/NFC`, không được để vỏ kim loại che anten
- khoảng cách đến vỏ phải càng nhỏ càng tốt nhưng không nhỏ hơn `2 mm`
- cáp nối không được tạo lực cơ học lên đầu đọc

Điều này cho thấy lớp RFID của hệ thống phụ thuộc khá mạnh vào chi tiết phần cứng và firmware của reader bên ngoài, không chỉ ở mức “cắm RS-485 là chạy”.

### Evidence

- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) ghi `RFID reader interface: RS-485`.
- [wiring_section.html](/d:/CHARXSEC/document/wiring_section.html) ghi RFID readers được nối qua `Supply/RFID` `RS-485 interface`, có thể đối chiếu thẻ với `local white list` hoặc `external management system`, và một reader có thể dùng cho nhiều charging points.
- Cùng tài liệu này nêu đầu đọc có thể lấy nguồn `12 V` từ đầu nối `Supply/RFID`, còn dây communication nối vào `A+/B-`.
- Cùng tài liệu này liệt kê các model RFID reader được hỗ trợ.
- Cùng tài liệu này nêu các yêu cầu riêng với ELATEC (`AppBlaster`, file `.bix`, tắt `DIP switch 8`, bootloader `1.08`) và với `CHARX RFID/NFC` (tránh kim loại che anten, khoảng cách ít nhất `2 mm`, tránh strain lên cáp).

## Câu hỏi 10

### Question

Digital outputs hoạt động ra sao, và các giới hạn điện cần nhớ là gì?

### Answer

Theo technical data, controller có `4` digital outputs. Manual mô tả ba mode điện cơ bản của output:

- `Low Side`
- `High Side`
- `Floating`

Ý nghĩa của chúng:

- `Low Side`: khi active, output được kéo xuống mass
- `High Side`: khi active, output được đưa lên `12 V`
- `Floating`: không nối xuyên tới một reference potential nào

Manual nhấn mạnh các ràng buộc điện rất quan trọng:

- digital outputs không có bảo vệ quá tải
- phải tự bảo đảm không vượt quá dòng đầu ra tối đa
- ở mode `Low Side`, điện áp cấp cho tải nối vào không được vượt quá `12 V`
- nếu tải được cấp từ nguồn ngoài, GND của nguồn ngoài phải nối chung với GND của charging controller

Về hành vi logic, outputs có thể được cấu hình để phản ứng với:

- điều kiện hoặc trạng thái hệ thống, ví dụ `Vehicle connected`, `charging the vehicle`, `charging station in error state`
- sự kiện, ví dụ `RFID invalid`, `temperature derating activated`

Các kiểu tín hiệu khi active gồm:

- `High`
- `Low`
- `Flashing High`
- `Flashing Low`
- `Pulsatile Low`
- `Floating`

Manual còn cho phép:

- đặt `PWM duty cycle` cho tín hiệu nhấp nháy
- đặt timer giới hạn thời gian kích hoạt
- gán nhiều điều kiện khác nhau cho cùng một output

Điều này biến digital outputs thành lớp “field signaling” khá linh hoạt, dùng để lái LED, đèn báo, tín hiệu phụ hoặc liên động hiện trường.

### Evidence

- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) ghi `Digital outputs: 4`.
- [wiring_section.html](/d:/CHARXSEC/document/wiring_section.html) nêu ba operating modes: `Low Side`, `High Side`, `Floating`.
- Cùng tài liệu này nêu outputs `are not protected against overload`.
- Cùng tài liệu này nêu trong mode `Low Side`, điện áp tải không được vượt quá `12 V`.
- Cùng tài liệu này nêu nếu cấp nguồn từ ngoài thì GND phải nối chung với GND của controller.
- Cùng tài liệu này liệt kê các event/state ví dụ và các output mode như `Flashing High`, `Flashing Low`, `Pulsatile Low`, cùng khả năng đặt `PWM duty cycle` và timer.

## Câu hỏi 11

### Question

Digital inputs được dùng như thế nào trong hệ thống này?

### Answer

Theo technical data, controller có `4` digital inputs. Wiring section mô tả chúng như lớp nhận tín hiệu từ hiện trường, có thể nhận từ hai kiểu nguồn tín hiệu:

- `passive signal generators` như switch hoặc button, dùng nguồn `12 V` của controller
- `active signal generators`, có nguồn `12 V` riêng

Điểm wiring bắt buộc là:

- khi inputs được điều khiển bằng signal generator active, GND của signal generator phải nối chung với GND của controller

Ở mức logic, digital inputs được cấu hình trong WBM và có thể:

- bắt sự kiện `Rising edge`
- bắt sự kiện `Falling edge`
- gán nhiều action cho cùng một input
- hoạt động như `analog threshold switches` thông qua điều kiện `Digital input 1 ... 4 above/below xxx mV`

Như vậy, digital inputs không chỉ là chân đọc mức logic đơn giản, mà còn là lớp ghép nối giữa controller với liên động ngoài, công tắc hiện trường và các tín hiệu analog-ngưỡng được ánh xạ vào action.

### Evidence

- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) ghi `Digital inputs: 4`.
- [wiring_section.html](/d:/CHARXSEC/document/wiring_section.html) nêu có thể nối digital inputs với `passive or active signal generators`.
- Cùng tài liệu này nêu passive signal generators dùng nguồn `12 V` của controller, còn active signal generators có nguồn `12 V` riêng.
- Cùng tài liệu này nêu phải dùng `same GND potential`.
- Cùng tài liệu này nêu inputs được cấu hình trong WBM, hỗ trợ `Rising edge`, `Falling edge`, và có thể dùng như `analog threshold switches` với điều kiện `above/below xxx mV`.

## Câu hỏi 12

### Question

Temperature sensors và cơ chế derating được mô tả ra sao?

### Answer

Manual cho thấy controller hỗ trợ kết nối cảm biến nhiệt để phục vụ giám sát và derating dòng sạc. Các cảm biến này được nối vào các chân `PTC` trên đầu nối `Input`.

Hai chế độ cảm biến được hỗ trợ là:

- `PTC chains`
- `Pt1000 sensors`

Với chế độ `PTC`:

- người dùng đặt một ngưỡng điện trở
- khi vượt ngưỡng đó, quá trình sạc sẽ bị ngắt
- việc kích hoạt lại dùng hysteresis `3%`

Với chế độ `PT1000`:

- người dùng đặt một dải nhiệt độ để derating
- mỗi nhiệt độ giới hạn được gán với một dòng còn cho phép
- khi đạt nhiệt độ bắt đầu, controller bắt đầu giảm dòng
- giữa hai điểm giới hạn, dòng cho phép được nội suy tuyến tính
- khi đạt nhiệt độ dừng, dòng được đặt về `0 A`

Về mặt kiến trúc vận hành, đây là chỗ cho thấy controller gắn trực tiếp logic sạc với dữ liệu nhiệt từ phần cứng ngoài, chứ không chỉ dựa trên nhiệt độ nội bộ của bo mạch.

### Evidence

- [wiring_section.html](/d:/CHARXSEC/document/wiring_section.html) ghi cảm biến nhiệt được nối qua các chân `PTC` trên đầu nối `Input`.
- Cùng tài liệu này nêu có thể dùng cả `PTC chains` và `Pt 1000 sensors`.
- Cùng tài liệu này nêu với mode `PTC`, quá trình sạc bị ngắt khi vượt ngưỡng điện trở và kích hoạt lại với hysteresis `3%`.
- Cùng tài liệu này nêu với mode `PT1000`, controller bắt đầu derating tại nhiệt độ bắt đầu, nội suy tuyến tính giữa hai điểm nhiệt độ, và đặt dòng về `0 A` tại nhiệt độ dừng.

## Câu hỏi 13

### Question

Sau khi học xong các sơ đồ wiring, nên hình dung “bộ phần cứng tối thiểu” quanh `CHARX SEC-3100` như thế nào?

### Answer

Nếu gom lại toàn bộ thông tin từ technical data và wiring section, một charging point AC tối thiểu xoay quanh `CHARX SEC-3100` nên được hình dung như một cụm gồm:

- `CHARX SEC-3100` làm charging controller trung tâm
- nguồn `12 V DC`
- một giao diện sạc kiểu `Socket` hoặc `Connector`
- `CP/PP` nối về controller
- `load contactor` để đóng/cắt xe với lưới điện
- một phương án residual current monitoring, hoặc `type B RCD` với bridge phù hợp, hoặc cảm biến `6 mA DC`

Các thành phần mở rộng tùy chức năng gồm:

- `energy meter` nếu muốn current monitoring hoặc load management
- `RFID reader` nếu muốn xác thực người dùng tại chỗ
- `digital inputs` và `digital outputs` cho signaling, liên động, monitor
- cảm biến nhiệt `PTC` hoặc `Pt1000` cho derating

Đây là mô hình phần cứng quan trọng nhất cần nắm ở ngày 3, vì toàn bộ các nghiên cứu sâu hơn về hành vi vận hành, bề mặt tấn công giao tiếp ngoại vi, hoặc mô phỏng thiết bị sau này đều sẽ dựa trên sơ đồ khối này.

Nói cách khác, sau ngày 3, người học nên chuyển từ cách nhìn “một controller có nhiều chân nối” sang cách nhìn “một hệ thống gồm controller, công suất, bảo vệ, đo lường, xác thực và signaling cùng hoạt động với nhau”.

### Evidence

- [wiring_section.html](/d:/CHARXSEC/document/wiring_section.html) lần lượt mô tả cách nối nguồn, charging interface, load contactor, residual current monitoring, energy meter, RFID reader, digital outputs, digital inputs và temperature sensors.
- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) xác nhận các interface vật lý cốt lõi gồm `RS-485` cho meter và RFID, `4` digital inputs, `4` digital outputs, cùng vehicle interface theo chuẩn sạc.

## Kết quả cần nắm sau Ngày 3

Sau khi học xong Ngày 3, bạn nên nắm chắc:

- nguồn cấp đúng của `CHARX SEC-3100` là `12 V DC`, với các ràng buộc về dung sai, dòng và backplane
- controller hỗ trợ `Case B` và `Case C`, và việc chọn `Socket` hay `Connector` kéo theo wiring và cấu hình khác nhau
- `4-pos. locking actuator` là đường đi chuẩn, còn `3-pos. locking actuator` cần mạch bảo vệ ngoài
- load contactor là cầu nối công suất giữa EV và lưới, có thể vừa điều khiển vừa giám sát qua auxiliary switch
- residual current monitoring có hai hướng triển khai chính và wiring `RCM` là phần không thể bỏ qua
- energy meter là thành phần gần như bắt buộc nếu muốn các chức năng giám sát dòng và load management
- RFID, digital inputs, digital outputs và temperature sensors tạo thành lớp giao tiếp hiện trường bao quanh controller
- toàn bộ logic phần mềm về charging current, authorization, signaling và derating đều gắn trực tiếp với các lựa chọn đấu nối phần cứng ở hiện trường
