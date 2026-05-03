# Ngày 8 - Firmware unpacking và file system inventory

Tài liệu này dựa trên timeline trong `courses.txt`, các tài liệu chính thức đã tải trong thư mục `document`, và firmware bundle `CHARXSEC3XXXSoftwareBundleV190.raucb` đang có trong workspace. Cấu trúc được chuẩn hóa theo dạng `Question -> Answer -> Evidence`.

Ngày 8 là ngày đầu tiên của tuần 2. Nếu tuần 1 giúp ta hiểu sản phẩm, WBM, OCPP, Modbus, MQTT, OpenVPN, System Control, update flow và các advisory, thì Ngày 8 chuyển sang lớp firmware thực tế: bundle update, root filesystem, service definitions, init scripts, web assets, configs, certificate placeholders và danh sách binary/module cần reverse.

Mục tiêu của ngày này là tạo inventory có bằng chứng, không suy diễn quá mức. Mọi kết luận kỹ thuật dưới đây cần được hiểu là baseline từ firmware bundle `V190`; khi dùng version khác, cần inventory lại.

## Nguồn tài liệu và artifact dùng cho Ngày 8

- [courses.txt](/d:/CHARXSEC/document/courses.txt)
- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md)
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html)
- [Maintenance_repair_and_disposal.html](/d:/CHARXSEC/document/Maintenance_repair_and_disposal.html)
- [PCSA-2024-00002_SECURITY_ADVISORY.pdf](/d:/CHARXSEC/document/PCSA-2024-00002_SECURITY_ADVISORY.pdf)
- [PCSA-2024-00003_SECURITY_ADVISORY.pdf](/d:/CHARXSEC/document/PCSA-2024-00003_SECURITY_ADVISORY.pdf)
- [PCSA-2025-00015_VDE-2025-074.pdf](/d:/CHARXSEC/document/PCSA-2025-00015_VDE-2025-074.pdf)
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt)
- [CHARXSEC3XXXSoftwareBundleV190.raucb](/d:/CHARXSEC/CHARXSEC3XXXSoftwareBundleV190.raucb)
- [manifest.raucm](/d:/CHARXSEC/work/firmware_v190_bundle/manifest.raucm)
- [hook](/d:/CHARXSEC/work/firmware_v190_bundle/hook)
- [root.ext4](/d:/CHARXSEC/work/firmware_v190_bundle/root.ext4)
- [bootimg.vfat](/d:/CHARXSEC/work/firmware_v190_bundle/bootimg.vfat)
- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json)

## Câu hỏi 1

### Question

Theo timeline khóa học, Ngày 8 cần học gì và output cần tạo là gì?

### Answer

Trong `courses.txt`, Ngày 8 được đặt tên là `Firmware unpacking và file system inventory`. Mục tiêu của ngày này là:

- lấy cấu trúc file system từ bundle firmware
- nhận diện rootfs
- nhận diện service definitions
- nhận diện init scripts
- nhận diện web assets
- nhận diện configs
- nhận diện các vùng certificate/key placeholder

Timeline yêu cầu inventory các nhóm sau:

- ELF binaries
- shared libraries
- init scripts
- systemd units hoặc SysV scripts
- `/etc/charx/*.conf`
- nginx config
- route permission JSON
- certs/keys placeholders

Output cần tạo gồm:

- `File inventory có phân nhóm`
- `Danh sách binary quan trọng cần reverse`

Với firmware bundle `V190`, Ngày 8 có thể đi xa hơn mức lý thuyết: bundle thật đã được nhận diện là RAUC/SquashFS, bên trong có `manifest.raucm`, `hook`, `root.ext4` và `bootimg.vfat`. Rootfs là ext4 Linux, chứa cấu trúc CHARX OS, SysV init scripts, `/etc/charx`, `/usr/lib/charx-*`, `/usr/sbin/Charx*`, nginx, mosquitto, OpenVPN, RAUC và route permission JSON.

### Evidence

- [courses.txt](/d:/CHARXSEC/document/courses.txt) ghi `Ngày 8: Firmware unpacking và file system inventory`.
- [courses.txt](/d:/CHARXSEC/document/courses.txt) yêu cầu inventory `ELF binaries`, `shared libraries`, `init scripts`, `systemd units / SysV scripts`, `/etc/charx/*.conf`, `nginx config`, `route permission JSON`, `certs/keys placeholders`.
- [CHARXSEC3XXXSoftwareBundleV190.raucb](/d:/CHARXSEC/CHARXSEC3XXXSoftwareBundleV190.raucb) là firmware bundle được dùng cho phần thực hành.
- [manifest.raucm](/d:/CHARXSEC/work/firmware_v190_bundle/manifest.raucm) mô tả version, compatible target, image rootfs và image kernel.

## Câu hỏi 2

### Question

Firmware bundle `CHARXSEC3XXXSoftwareBundleV190.raucb` có cấu trúc lớp ngoài như thế nào?

### Answer

Bundle `CHARXSEC3XXXSoftwareBundleV190.raucb` là một RAUC bundle được đóng dưới dạng SquashFS. Khi liệt kê lớp ngoài, bundle chứa bốn file chính:

| File trong bundle | Kích thước quan sát | Vai trò |
|---|---:|---|
| `manifest.raucm` | 471 bytes | Manifest RAUC, mô tả compatible target, version, build, hash và image |
| `hook` | 4,811 bytes | Script hook cho install-check, pre-install và post-install |
| `root.ext4` | 514,514,944 bytes | Root filesystem ext4 của firmware |
| `bootimg.vfat` | 20,971,520 bytes | Boot/kernel image ở dạng FAT/VFAT |

Thông tin quan trọng trong manifest:

| Trường | Giá trị |
|---|---|
| `compatible` | `ev3000` |
| `version` | `1.9.0` |
| `description` | `release+421509.20260327.c1656427c.161030bb` |
| `build` | `20260327113354` |
| rootfs filename | `root.ext4` |
| kernel filename | `bootimg.vfat` |

Điều này cho ta pipeline unpacking ban đầu:

1. Nhận diện `.raucb` là SquashFS/RAUC bundle.
2. Bung SquashFS để lấy manifest, hook, rootfs và boot image.
3. Đọc manifest để xác định version/build/hash.
4. Đọc rootfs ext4 offline để inventory filesystem.
5. Đọc hook để hiểu update lifecycle ở mức script.

### Evidence

- [manifest.raucm](/d:/CHARXSEC/work/firmware_v190_bundle/manifest.raucm) ghi `compatible=ev3000`, `version=1.9.0`, `description=release+421509.20260327.c1656427c.161030bb`, `build=20260327113354`.
- [manifest.raucm](/d:/CHARXSEC/work/firmware_v190_bundle/manifest.raucm) ghi `[image.rootfs]`, `filename=root.ext4`, `size=514514944`, `sha256=46dcc857f97d2797aed9b393e57be2f80b59f6fc8010f2c2dbe0c5328e5a4845`.
- [manifest.raucm](/d:/CHARXSEC/work/firmware_v190_bundle/manifest.raucm) ghi `[image.kernel]`, `filename=bootimg.vfat`, `size=20971520`, `sha256=1112c05c3d82df55d9668fbc109f1212782a97708975dcf3de1e075c99a87216`.
- [hook](/d:/CHARXSEC/work/firmware_v190_bundle/hook) là hook script được manifest tham chiếu.

## Câu hỏi 3

### Question

Root filesystem trong bundle là gì và phản ánh hệ điều hành nào?

### Answer

`root.ext4` là root filesystem Linux ở định dạng ext4. Khi đọc `/usr/lib/os-release` từ rootfs, firmware tự nhận diện là:

| Trường | Giá trị |
|---|---|
| `ID` | `charx` |
| `NAME` | `CHARX control Embedded Linux` |
| `VERSION` | `1.9.0 (kirkstone)` |
| `VERSION_ID` | `1.9.0` |
| `PRETTY_NAME` | `CHARX control Embedded Linux 1.9.0 (kirkstone)` |
| `DISTRO_CODENAME` | `kirkstone` |
| `BUILD_ID` | `release+421509.20260327.c1656427c.161030bb` |

Điều này khớp với tài liệu sản phẩm: CHARX SEC-3100 là charging controller dùng embedded Linux system. Từ góc nhìn reverse engineering, đây là thông tin nền rất quan trọng vì nó cho biết:

- firmware không phải RTOS tối giản mà là Linux filesystem đầy đủ
- có package/userland kiểu embedded Linux
- service lifecycle dùng SysV init style thay vì systemd trong bundle quan sát được
- binary mục tiêu là ARM 32-bit hard-float userland
- nhiều application của CHARX nằm dưới `/usr/lib/charx-*` và `/usr/sbin/Charx*`

Rootfs có các thư mục top-level đáng chú ý:

| Path | Vai trò sơ bộ |
|---|---|
| `/bin`, `/sbin`, `/usr/bin`, `/usr/sbin` | userland executable và service entrypoint |
| `/etc` | cấu hình hệ thống, SysV init, nginx, mosquitto, openvpn, rauc, charx |
| `/usr/lib/charx-*` | module/application chính của CHARX |
| `/data` | vùng dữ liệu runtime được config tham chiếu |
| `/log` | vùng log được các service config tham chiếu |
| `/identity` | vùng identity/device data cần xem kỹ ở lab |
| `/overlays` | vùng overlay gợi ý cơ chế writable overlay |
| `/boot` | boot artifacts trong rootfs |

### Evidence

- [product_1139012_technical_data.md](/d:/CHARXSEC/document/product_1139012_technical_data.md) nêu design của CHARX SEC-3100 là `with Embedded Linux system`.
- [root.ext4](/d:/CHARXSEC/work/firmware_v190_bundle/root.ext4) là Linux ext4 filesystem trong bundle.
- `/usr/lib/os-release` trong [root.ext4](/d:/CHARXSEC/work/firmware_v190_bundle/root.ext4) ghi `CHARX control Embedded Linux 1.9.0 (kirkstone)`.
- Inventory offline của [root.ext4](/d:/CHARXSEC/work/firmware_v190_bundle/root.ext4) cho thấy các thư mục `/bin`, `/boot`, `/data`, `/etc`, `/identity`, `/log`, `/overlays`, `/usr`, `/var`.

## Câu hỏi 4

### Question

Firmware này dùng init system nào, và service startup map ban đầu ra sao?

### Answer

Trong rootfs `V190`, các service được quản lý theo kiểu SysV init. Bằng chứng là có `/etc/init.d` và các thư mục runlevel `/etc/rc0.d` đến `/etc/rc6.d`. Không thấy cần giả định systemd cho bundle này.

Các init scripts CHARX chính trong `/etc/init.d` gồm:

| Init script | Ý nghĩa sơ bộ |
|---|---|
| `charx-hw-init` | khởi tạo phần cứng |
| `charx-network-restore` | khôi phục network |
| `charx-qca` | liên quan QCA/HomePlug/powerline context |
| `charx-system-configure` | cấu hình hệ thống |
| `charx-firewall-configure` | cấu hình firewall |
| `charx-system-config-manager` | System Config Manager |
| `charx-update-agent` | Update Agent |
| `charx-system-init` | system init riêng của CHARX |
| `charx-can-init` | khởi tạo CAN |
| `charx-cellular-network` | cellular network |
| `charx-controller-agent` | Controller Agent |
| `charx-jupicore` | JupiCore |
| `charx-loadmanagement` | Load Management |
| `charx-modbus-agent` | Modbus Agent |
| `charx-modbus-server` | Modbus Server |
| `charx-modem-on` | modem on |
| `charx-ocpp16-agent` | OCPP 1.6J Agent |
| `charx-system-monitor` | System Monitor |
| `charx-website` | WBM/Web service |

Runlevel `rc5.d` cho thấy thứ tự khởi động dạng:

| Thứ tự | Service |
|---|---|
| `S04` | `charx-hw-init` |
| `S05` | `charx-network-restore` |
| `S10` | `charx-qca` |
| `S12` | `charx-system-configure` |
| `S30` | `charx-firewall-configure` |
| `S50` | `charx-system-config-manager` |
| `S60` | `charx-update-agent` |
| `S97` | `charx-system-init` |
| `S98` | `charx-can-init`, `charx-cellular-network` |
| `S99` | controller, JupiCore, Load Management, Modbus, OCPP, System Monitor, Website |

Đây là một phát hiện quan trọng cho Day 12 sau này: advisory 2024 từng nói tới boot-time window và firewall/startup sequence. Với inventory này, ta có điểm bắt đầu để quan sát khi nào firewall, config manager, update agent và các service mạng thật sự bind port.

### Evidence

- [root.ext4](/d:/CHARXSEC/work/firmware_v190_bundle/root.ext4) chứa `/etc/init.d` và các thư mục `/etc/rc0.d` đến `/etc/rc6.d`.
- `/etc/init.d` trong rootfs chứa các script `charx-controller-agent`, `charx-jupicore`, `charx-loadmanagement`, `charx-modbus-agent`, `charx-modbus-server`, `charx-ocpp16-agent`, `charx-system-config-manager`, `charx-system-monitor`, `charx-update-agent`, `charx-website`.
- `/etc/rc5.d` trong rootfs chứa các symlink khởi động `S04charx-hw-init`, `S30charx-firewall-configure`, `S50charx-system-config-manager`, `S60charx-update-agent`, `S99charx-website`.
- [PCSA-2024-00003_SECURITY_ADVISORY.pdf](/d:/CHARXSEC/document/PCSA-2024-00003_SECURITY_ADVISORY.pdf) mô tả issue liên quan firewall service start sequence trong firmware cũ.

## Câu hỏi 5

### Question

Các file cấu hình quan trọng trong `/etc/charx` là gì?

### Answer

`/etc/charx` là thư mục cấu hình trung tâm của nhiều service CHARX. Trong firmware `V190`, thư mục này chứa ít nhất các file sau:

| File | Vai trò sơ bộ | Risk cần ghi chú |
|---|---|---|
| `charx-controller-agent.conf` | cấu hình Controller Agent, CAN, remote device network, SECC network, firmware update options | chạm vào CAN, Ethernet client/server, SECC cert/key path, update behavior |
| `charx-jupicore.conf` | cấu hình JupiCore, REST API, MQTT, Controller Agent peer, charging defaults | hub dữ liệu charging point và MQTT/REST |
| `charx-loadmanagement-agent.conf` | cấu hình Load Management Agent | ảnh hưởng phân phối tải |
| `charx-loadmanagement-load-circuite.conf` | cấu hình load circuit | ảnh hưởng current limit/load circuit |
| `charx-modbus-agent.conf` | cấu hình Modbus Agent | liên quan Modbus client/meter |
| `charx-modbus-server.conf` | cấu hình Modbus Server | liên quan Modbus/TCP runtime control |
| `charx-ocpp16-agent.conf` | cấu hình OCPP 1.6J Agent | backend URL, MQTT local, JupiCore peer, REST port 2106 |
| `charx-system-config-manager.conf` | cấu hình System Config Manager | liên quan API config/import/export/reboot/remove-file |
| `charx-system-monitor.conf` | cấu hình System Monitor | quan sát modem/network/system |
| `charx-update-agent.conf` | cấu hình Update Agent | liên quan update flow |
| `charx-website.conf` | cấu hình Web/WBM backend | REST API port 5000, MQTT local, upload folder, database |
| `load-circuit-measure-device.json` | cấu hình đo load circuit | liên quan load management |
| `mqtt_broker.pem` | certificate placeholder hoặc CA/cert material cho MQTT broker | cần kiểm tra secret/cert handling |
| `routePermissions.json` | map route/API sang role | cực kỳ quan trọng cho Web/API audit |
| `system-default-configuration.ini` | cấu hình default hệ thống | ảnh hưởng reset/default state |
| `website.db` | database mặc định hoặc seed cho website | cần xem schema và dữ liệu khởi tạo |

Từ góc nhìn security research, `/etc/charx` là một trong các thư mục đầu tiên cần inventory sâu vì nó nối tài liệu manual với firmware thật. Các service trong manual có file config tương ứng gần như trực tiếp: JupiCore, OCPP, Modbus, Load Management, System Monitor, System Config Manager, Update Agent và Website.

### Evidence

- [root.ext4](/d:/CHARXSEC/work/firmware_v190_bundle/root.ext4) chứa `/etc/charx`.
- `/etc/charx` trong rootfs chứa các file `charx-controller-agent.conf`, `charx-jupicore.conf`, `charx-loadmanagement-agent.conf`, `charx-modbus-agent.conf`, `charx-modbus-server.conf`, `charx-ocpp16-agent.conf`, `charx-system-config-manager.conf`, `charx-system-monitor.conf`, `charx-update-agent.conf`, `charx-website.conf`.
- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json) nằm trong `/etc/charx`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả các services/applications tương ứng trong `System Control/Status`.

## Câu hỏi 6

### Question

Các service trong manual map sang file/module firmware như thế nào?

### Answer

Manual mô tả các service ở mức chức năng. Firmware `V190` cho phép map chúng sang init script, config và application/module cụ thể.

| Service trong manual | Init script | Config | Application/module quan sát được |
|---|---|---|---|
| Controller Agent | `/etc/init.d/charx-controller-agent` | `/etc/charx/charx-controller-agent.conf` | `/usr/sbin/CharxControllerAgent` |
| JupiCore | `/etc/init.d/charx-jupicore` | `/etc/charx/charx-jupicore.conf` | `/usr/lib/charx-jupicore/CharxJupiCore`, nhiều `.so` |
| OCPP 1.6J | `/etc/init.d/charx-ocpp16-agent` | `/etc/charx/charx-ocpp16-agent.conf` | `/usr/lib/charx-ocpp16-agent/CharxOcpp16Agent`, nhiều `.so` |
| Modbus Client/Agent | `/etc/init.d/charx-modbus-agent` | `/etc/charx/charx-modbus-agent.conf` | `/usr/lib/charx-modbus-agent/CharxModbusAgent`, nhiều `.so` |
| Modbus Server | `/etc/init.d/charx-modbus-server` | `/etc/charx/charx-modbus-server.conf` | `/usr/lib/charx-modbus-server/CharxModbusServer`, nhiều `.so` |
| Load Management | `/etc/init.d/charx-loadmanagement` | `/etc/charx/charx-loadmanagement-agent.conf` | `/usr/lib/charx-loadmanagement/CharxControllerLoadmanagement`, nhiều module con |
| System Monitor | `/etc/init.d/charx-system-monitor` | `/etc/charx/charx-system-monitor.conf` | `/usr/lib/charx-system-monitor/CharxSystemMonitor`, nhiều `.so` |
| System Config Manager | `/etc/init.d/charx-system-config-manager` | `/etc/charx/charx-system-config-manager.conf` | `/usr/lib/charx-system-config-manager/CharxSystemConfigManager`, nhiều `.so` |
| Update Agent | `/etc/init.d/charx-update-agent` | `/etc/charx/charx-update-agent.conf` | `/usr/lib/charx-update-agent/CharxUpdateAgent`, `client.so`, `server.so` |
| Web Server/WBM | `/etc/init.d/charx-website` | `/etc/charx/charx-website.conf` | `/usr/lib/charx-website/CharxWebsite`, API `.so`, `dist/` |

Đây là output rất quan trọng của Day 8: ta đã biến danh sách service trong manual thành danh sách file cần phân tích. Day 9 có thể dùng bảng này để dựng service dependency graph.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) liệt kê `System Monitor`, `Controller Agent`, `OCPP 1.6J`, `Modbus Client`, `Modbus Server`, `JupiCore`, `Load Management`, `Web Server`, `Calibration Law Agent`.
- [root.ext4](/d:/CHARXSEC/work/firmware_v190_bundle/root.ext4) chứa init scripts trong `/etc/init.d`.
- [root.ext4](/d:/CHARXSEC/work/firmware_v190_bundle/root.ext4) chứa service modules trong `/usr/lib/charx-*` và executable trong `/usr/sbin`.
- `/etc/charx` trong rootfs chứa các config tương ứng với service.

## Câu hỏi 7

### Question

Web/WBM trong firmware gồm những file nào đáng chú ý?

### Answer

Web/WBM nằm chủ yếu ở `/usr/lib/charx-website` và được cấu hình bởi `/etc/charx/charx-website.conf`. Config cho thấy:

| Trường | Giá trị quan sát |
|---|---|
| `LogFilePath` | `/log/charx-website/charx-website.log` |
| `RestApi Host` | `0.0.0.0` |
| `RestApi Port` | `5000` |
| `MqttParameters Host` | `127.0.0.1` |
| `MqttParameters Port` | `1883` |
| `UploadFolder` | `/data/charx-website/upload/` |
| `DatabaseFilePath` | `/data/charx-website/website.db` |

Các module `.so` đáng chú ý trong `/usr/lib/charx-website` gồm:

| Module | Gợi ý chức năng từ tên file |
|---|---|
| `webserver.so` | web server backend |
| `websocket_server.so` | websocket |
| `api_auth_resource.so` | authentication resource |
| `api_user.so`, `user_management.so` | user management |
| `api_file.so` | file operation/download/upload surface |
| `api_import.so`, `api_export.so` | import/export config |
| `api_firewall.so` | firewall/port sharing |
| `api_openvpn.so`, `openvpn_manager.so` | OpenVPN |
| `api_modem.so` | modem |
| `api_network.so`, `routing_table_manager.so`, `api_routing_table.so` | network/routing |
| `api_certificates.so` | certificate handling |
| `api_ocpp.so` | OCPP related web API |
| `api_remote_control.so`, `remote_control_manager.so` | remote control |
| `api_topics_forwarding.so`, `mqtt_bridge_manager.so` | MQTT Bridge/topic forwarding |
| `api_linux_user_permissions.so` | Linux user permissions |
| `dist/` | frontend/static web assets |

Đây là bề mặt cần audit sâu ở Day 10. Đặc biệt, advisory 2025 nói tới low-privileged WBM account và system configuration dẫn tới command injection as root. Vì vậy, các module `api_import`, `api_export`, `api_firewall`, `api_openvpn`, `api_modem`, `api_network`, `api_routing_table`, `api_certificates`, `api_linux_user_permissions` và các manager tương ứng cần được đưa vào danh sách ưu tiên.

### Evidence

- [charx-website.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-website.conf) ghi REST API listen `0.0.0.0:5000`, MQTT local `127.0.0.1:1883`, upload folder và database path.
- `/usr/lib/charx-website` trong [root.ext4](/d:/CHARXSEC/work/firmware_v190_bundle/root.ext4) chứa các module `api_auth_resource.so`, `api_file.so`, `api_import.so`, `api_export.so`, `api_firewall.so`, `api_openvpn.so`, `api_certificates.so`, `api_linux_user_permissions.so`, `webserver.so`, `websocket_server.so`.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) mô tả CVE-2025-41699 liên quan tới WBM account, system configuration và command injection as root.

## Câu hỏi 8

### Question

`routePermissions.json` cho biết gì về quyền truy cập API?

### Answer

`routePermissions.json` là file quan trọng nhất cho Day 10 Web/API audit. Trong firmware `V190`, file này có 70 route pattern. Khi thống kê các role được gán trong file, có các role:

| Role | Số lần xuất hiện trong method permissions |
|---|---:|
| `guest` | 12 |
| `user` | 33 |
| `operator` | 56 |
| `manufacturer` | 17 |

Một số route/domain đáng chú ý xuất hiện trong file:

| Route/domain pattern | Vì sao cần chú ý |
|---|---|
| `/api/[^/]*/web/firewall` | liên quan port sharing/firewall |
| `/api/[^/]*/web/openvpn` | liên quan OpenVPN config |
| `/api/[^/]*/web/openvpn_credentials` | liên quan credential/cert boundary |
| `/api/[^/]*/web/routing_table` | liên quan routing |
| `/api/[^/]*/web/download/logs` | liên quan log download |
| `/api/[^/]*/web/modem` | liên quan modem/cellular |
| `/api/[^/]*/web/update`, `/update2-upload`, `/update2-install` | liên quan update flow |
| `/api/[^/]*/web/export`, `/import` | liên quan config import/export |
| `/api/[^/]*/web/linux-user/change-password` | liên quan Linux user password |
| `/api/[^/]*/web/linux-user-permissions` | liên quan quyền Linux user |
| `/api/[^/]*/system-config-manager/remove-file` | liên quan file removal qua system config manager |
| `/api/[^/]*/ocpp16/config/*` | liên quan cấu hình OCPP |
| `/api/[^/]*/ocpp16/diagnostic/*` | liên quan OCPP diagnostics |

Điểm cần hiểu đúng: route permission JSON không tự chứng minh endpoint an toàn hay không an toàn. Nó chỉ cho biết policy mapping theo role. Day 10 cần đối chiếu file này với code path trong `/usr/lib/charx-website`, `/usr/lib/charx-system-config-manager` và các service backend để xem policy được enforce ở đâu.

### Evidence

- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json) chứa 70 route pattern.
- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json) có role `guest`, `user`, `operator`, `manufacturer`.
- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json) chứa các route liên quan firewall, OpenVPN, routing table, logs, modem, update, import/export, linux-user, system-config-manager và OCPP.
- [courses.txt](/d:/CHARXSEC/document/courses.txt) nêu Day 10 sẽ audit Web/API từ `charx-api-catalog.json` và route permissions.

## Câu hỏi 9

### Question

System Config Manager trong firmware có vai trò gì?

### Answer

System Config Manager là một service trung tâm cho cấu hình hệ thống. Trong rootfs, nó có:

- init script: `/etc/init.d/charx-system-config-manager`
- config: `/etc/charx/charx-system-config-manager.conf`
- application: `/usr/lib/charx-system-config-manager/CharxSystemConfigManager`
- modules: `api_config.so`, `api_export.so`, `api_import.so`, `api_reboot.so`, `api_remove_file.so`, `config_manager.so`, `export_service.so`, `import_service.so`, `system_config_file_manager.so`, `system_time.so`

Config cho thấy service có REST API:

| Trường | Giá trị quan sát |
|---|---|
| `LogFilePath` | `/log/charx-system-config-manager/charx-system-config-manager.log` |
| `RestApi Host` | `0.0.0.0` |
| `RestApi Port` | `5001` |

Đây là service phải ưu tiên trong nghiên cứu vì nhiều lý do:

- advisory 2025 nhắc trực tiếp tới `system configuration`
- service này có module import/export
- có module reboot
- có module remove-file
- hook update dùng System Config Manager trong workaround cho version cũ
- WBM có route liên quan system-config-manager trong `routePermissions.json`

Trong Day 9 và Day 10, cần dựng data flow: WBM route -> Website API -> System Config Manager -> file/config/action. Không nên chỉ audit frontend hoặc route permission JSON riêng lẻ.

### Evidence

- [charx-system-config-manager.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-system-config-manager.conf) ghi REST API listen `0.0.0.0:5001`.
- `/usr/lib/charx-system-config-manager` trong [root.ext4](/d:/CHARXSEC/work/firmware_v190_bundle/root.ext4) chứa `api_config.so`, `api_export.so`, `api_import.so`, `api_reboot.so`, `api_remove_file.so`, `system_config_file_manager.so`.
- [hook](/d:/CHARXSEC/work/firmware_v190_bundle/hook) có logic install new SystemConfigManager trước khi update CHARX-OS trong workaround cho version cũ.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) mô tả CVE-2025-41699 liên quan thay đổi system configuration dẫn tới command injection as root.

## Câu hỏi 10

### Question

OCPP 1.6J trong firmware map sang những file nào?

### Answer

OCPP 1.6J được triển khai dưới service `charx-ocpp16-agent`. Trong firmware `V190`, service này gồm:

- init script: `/etc/init.d/charx-ocpp16-agent`
- config: `/etc/charx/charx-ocpp16-agent.conf`
- application: `/usr/lib/charx-ocpp16-agent/CharxOcpp16Agent`
- modules: nhiều `.so` liên quan REST API, MQTT communication, firmware update, websocket, config, logic và payload

Config quan sát được có các điểm đáng chú ý:

| Nhóm | Giá trị hoặc ý nghĩa |
|---|---|
| Log | `/log/charx-ocpp16-agent/charx-ocpp16-agent.log` |
| Database | `/data/charx-ocpp16-agent/ocpp16.db` |
| MQTT local | `127.0.0.1:1883`, client ID `charx-ocpp16-agent` |
| OCPP backend | có template/default `wss://...` |
| Network interface | `eth0` |
| JupiCore peer | `127.0.0.1:5555` |
| REST | `0.0.0.0:2106` |

Các module quan trọng:

| Module | Lý do cần xem |
|---|---|
| `agent_rest_api.so` | API của OCPP agent |
| `charx_rest_client.so` | REST client tới service khác |
| `mqtt_communication.so`, `mqtt_logic.so` | giao tiếp MQTT nội bộ |
| `ocpp_configuration.so` | cấu hình OCPP |
| `ocpp_connector.so` | kết nối OCPP |
| `ocpp_firmware_update.so` | OCPP firmware update |
| `ocpp_logic.so` | logic OCPP chính |
| `ocpp_req_payload.so`, `ocpp_res_payload.so` | request/response payload |
| `ocpp_security_event_handler.so` | security event |
| `websocket_handler.so` | WebSocket transport |

Từ góc nhìn threat model, OCPP là boundary giữa backend và controller. Day 8 chỉ inventory file. Day 9 và Day 10 mới dựng call-chain và API mapping.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả OCPP 1.6J backend communication và WBM/OCPP.
- [charx-ocpp16-agent.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-ocpp16-agent.conf) ghi MQTT local `127.0.0.1:1883`, JupiCore `127.0.0.1:5555`, REST `0.0.0.0:2106`.
- `/usr/lib/charx-ocpp16-agent` trong [root.ext4](/d:/CHARXSEC/work/firmware_v190_bundle/root.ext4) chứa `ocpp_firmware_update.so`, `ocpp_logic.so`, `ocpp_connector.so`, `websocket_handler.so`.
- [Maintenance_repair_and_disposal.html](/d:/CHARXSEC/document/Maintenance_repair_and_disposal.html) nêu update có thể thực hiện qua backend bằng OCPP.

## Câu hỏi 11

### Question

JupiCore trong firmware đóng vai trò gì trong inventory?

### Answer

JupiCore là hub dữ liệu trung tâm giữa charging points, MQTT broker, internal services và external REST API. Manual đã mô tả vai trò này, và firmware cho thấy nó có service riêng:

- init script: `/etc/init.d/charx-jupicore`
- config: `/etc/charx/charx-jupicore.conf`
- application: `/usr/lib/charx-jupicore/CharxJupiCore`
- modules: charging controller, charging point, IO controller, HMI board, MQTT connector, topology manager, database manager

Config quan sát được:

| Nhóm | Giá trị hoặc ý nghĩa |
|---|---|
| Log | `/log/charx-jupicore/charx-jupicore.log` |
| Database | `/data/charx-jupicore/jupicore.db` |
| REST API | `0.0.0.0:5555` |
| MQTT local | `127.0.0.1:1883`, client ID `charx-jupicore` |
| Controller Agent peer | `127.0.0.1:4444` |
| Charging current defaults | min/max/default values trong config |

Các module đáng chú ý:

| Module | Lý do cần xem |
|---|---|
| `charging_controller.so` | logic charging controller |
| `charging_point.so` | logic charging point |
| `charging_controller_v2g_ac.so` | AC charging/V2G context |
| `io_controller.so` | I/O controller |
| `mqtt_connector.so` | MQTT data path |
| `topology_builder.so`, `topology_manager.so` | topology charging park |
| `api_charging_points.so`, `api_charging_controllers.so` | API nội bộ |

JupiCore là điểm nối rất tốt cho Day 9 service graph vì nó kết nối Controller Agent, MQTT, Web/WBM, charging point data và topology.

### Evidence

- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả JupiCore là service thu thập dữ liệu từ connected charging points và forward tới MQTT broker, internal services, external services qua REST API.
- [charx-jupicore.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-jupicore.conf) ghi REST API `0.0.0.0:5555`, MQTT `127.0.0.1:1883`, Controller Agent `127.0.0.1:4444`.
- `/usr/lib/charx-jupicore` trong [root.ext4](/d:/CHARXSEC/work/firmware_v190_bundle/root.ext4) chứa `charging_controller.so`, `charging_point.so`, `mqtt_connector.so`, `topology_builder.so`, `topology_manager.so`.

## Câu hỏi 12

### Question

Update pipeline trong firmware thể hiện qua những file nào?

### Answer

Update pipeline trong firmware `V190` xuất hiện ở nhiều lớp:

| Lớp | File hoặc service | Vai trò |
|---|---|---|
| RAUC bundle metadata | `manifest.raucm` | version, compatible target, rootfs/kernel image, hash |
| RAUC hook | `hook` | install-check, pre-install, post-install |
| Rootfs image | `root.ext4` | filesystem mới được cài |
| Kernel/boot image | `bootimg.vfat` | boot/kernel image |
| Update Agent | `/etc/init.d/charx-update-agent`, `/usr/lib/charx-update-agent/*` | service update runtime |
| RAUC binary/config | `/usr/bin/rauc`, `/etc/rauc/system.conf`, `/etc/rauc/root-ca.crt` | RAUC update framework |
| System update helper | `/usr/sbin/charx_system_update` | helper script/binary liên quan system update |
| OCPP firmware update | `/usr/lib/charx-ocpp16-agent/ocpp_firmware_update.so` | OCPP-related firmware update path |

Hook script cho thấy các phase quan trọng:

- `install-check`: kiểm tra compatibility giữa manifest và system
- `slot-pre-install`: drop caches trước khi install
- `slot-post-install`: xử lý sau install rootfs
- workaround cho version `<1.5.0`: cài SystemConfigManager mới trước khi install image để xử lý secure reboot command
- `update_bootloader`: so sánh và cập nhật bootloader nếu khác

Điều này khớp với manual: update có thể là individual application programs, charging controller firmware hoặc entire system. Manual cũng nói update có thể qua WBM hoặc OCPP backend. Trong firmware, ta thấy cả Web/WBM update route, Update Agent, RAUC, OCPP firmware update module và hook RAUC.

### Evidence

- [manifest.raucm](/d:/CHARXSEC/work/firmware_v190_bundle/manifest.raucm) mô tả rootfs/kernel images và hook.
- [hook](/d:/CHARXSEC/work/firmware_v190_bundle/hook) chứa các case `install-check`, `slot-pre-install`, `slot-post-install`.
- [hook](/d:/CHARXSEC/work/firmware_v190_bundle/hook) có logic `install_system_conifg_manager_to_current_system` và `update_bootloader`.
- `/usr/lib/charx-update-agent` trong [root.ext4](/d:/CHARXSEC/work/firmware_v190_bundle/root.ext4) chứa `CharxUpdateAgent`, `client.so`, `server.so`.
- `/usr/lib/charx-ocpp16-agent` trong rootfs chứa `ocpp_firmware_update.so`.
- [startup_section.html](/d:/CHARXSEC/document/startup_section.html) mô tả `System Control/Software` có thể update individual application programs, charging controller firmware hoặc entire system.
- [Maintenance_repair_and_disposal.html](/d:/CHARXSEC/document/Maintenance_repair_and_disposal.html) nêu update có thể qua WBM hoặc OCPP backend.

## Câu hỏi 13

### Question

Certificate, key và secret placeholder nào cần ghi vào inventory?

### Answer

Day 8 không nên kết luận secret nào là thật hay giả nếu chưa phân tích runtime và provisioning. Tuy nhiên, inventory cần ghi lại mọi vị trí certificate/key/credential placeholder vì chúng là boundary tin cậy.

| Path hoặc config | Ý nghĩa |
|---|---|
| `/etc/charx/mqtt_broker.pem` | certificate material liên quan MQTT broker |
| `/etc/nginx/dhparam.pem` | DH parameters cho nginx/TLS |
| `/etc/nginx/snippets/self-signed.conf` | snippet TLS/self-signed config |
| `/etc/nginx/snippets/ssl-params.conf` | SSL params |
| `/etc/rauc/root-ca.crt` | root CA cho RAUC/update trust |
| `/etc/ssl` | CA/certificate store |
| `/etc/openvpn` | OpenVPN client/server/sample config area |
| `/etc/charx/charx-controller-agent.conf` | tham chiếu `SeccTlsCertFile` và `SeccTlsKeyFile` dưới `/data/charx-controller-agent/cert/` |
| `routePermissions.json` route `OCPPCertificate` | API surface liên quan OCPP certificate |
| `api_certificates.so` | module xử lý certificate trong Web/WBM |

Các điểm này cần được kiểm tra ở tuần 2 theo hướng phòng thủ:

- file nào là default placeholder?
- file nào được tạo lúc provisioning?
- file nào export/import được?
- quyền file là gì?
- service nào đọc file?
- log có lộ path hoặc secret không?
- update có giữ lại hay thay thế certificate không?

### Evidence

- [charx-controller-agent.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-controller-agent.conf) tham chiếu `SeccTlsCertFile=/data/charx-controller-agent/cert/secc.cert` và `SeccTlsKeyFile=/data/charx-controller-agent/cert/secc.key`.
- `/etc/charx` trong rootfs chứa `mqtt_broker.pem`.
- `/etc/nginx` trong rootfs chứa `dhparam.pem` và snippets TLS.
- `/etc/rauc` trong rootfs chứa `root-ca.crt` và `system.conf`.
- `/usr/lib/charx-website` trong rootfs chứa `api_certificates.so`.
- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json) chứa route liên quan `OCPPCertificate`.

## Câu hỏi 14

### Question

Những helper script và sudoers entry nào cần đưa vào inventory?

### Answer

Firmware `V190` có nhiều helper script dưới `/usr/local/bin` và nhiều sudoers entry dưới `/etc/sudoers.d`. Đây là vùng rất quan trọng vì advisory 2025 liên quan tới command injection as root từ system configuration. Inventory không cần khẳng định có lỗi; chỉ cần đánh dấu nơi userland service có thể gọi helper hoặc được cấp quyền đặc biệt.

Các helper đáng chú ý:

| Helper | Gợi ý chức năng từ tên |
|---|---|
| `charx_get_config_param` | đọc config parameter |
| `charx_set_config_param` | set config parameter |
| `charx_create_config_param` | tạo config parameter |
| `charx_create_firewall_settings` | tạo firewall settings |
| `charx_create_network_file` | tạo network file |
| `charx_set_ip_address` | set IP address |
| `charx_update_ip_addresses` | update IP addresses |
| `charx_set_datetime` | set datetime |
| `charx_set_timezone` | set timezone |
| `charx_set_password` | set password |
| `charx_reset_passwords` | reset passwords |
| `charx_restore_from_config` | restore from config |
| `charx_rm_file` | remove file |
| `charx_pack_logs` | package logs |
| `charx_flash_qca_firmware` | flash QCA firmware |
| `charx_modem_on`, `charx_modem_send_AT` | modem operations |
| `openvpn-test-wrapper` | OpenVPN test wrapper |
| `unpriv-ip`, `unpriv-ip-filter` | network helper wrappers |

Các sudoers entry đáng chú ý:

| Entry | Gợi ý |
|---|---|
| `charx-web` | quyền đặc biệt cho web/WBM side |
| `charx-scm` | quyền đặc biệt cho System Config Manager |
| `charx-ua` | quyền đặc biệt cho Update Agent hoặc user-app context |
| `charx-oa` | OCPP Agent context |
| `charx-jc` | JupiCore context |
| `charx-ms` | Modbus Server context |
| `openvpn` | OpenVPN context |
| `user-app` | low-privileged user-app context |
| `arp-sudoers`, `pxc-sudoers` | system/network related permissions |

Day 9 và Day 10 nên kiểm tra call-chain từ API module đến helper script, đặc biệt với các helper liên quan file, firewall, network, password, OpenVPN, logs và config import/export.

### Evidence

- `/usr/local/bin` trong rootfs chứa các helper `charx_get_config_param`, `charx_set_config_param`, `charx_create_firewall_settings`, `charx_create_network_file`, `charx_set_ip_address`, `charx_set_password`, `charx_restore_from_config`, `charx_rm_file`, `charx_pack_logs`, `openvpn-test-wrapper`.
- `/etc/sudoers.d` trong rootfs chứa `charx-web`, `charx-scm`, `charx-ua`, `charx-oa`, `charx-jc`, `charx-ms`, `openvpn`, `user-app`.
- [.tmp_pcsa_2025_074.txt](/d:/CHARXSEC/document/.tmp_pcsa_2025_074.txt) mô tả CVE-2025-41699 là command injection as root thông qua thay đổi system configuration bởi WBM low-privileged account.

## Câu hỏi 15

### Question

Danh sách binary/module quan trọng cần reverse sau Day 8 là gì?

### Answer

Danh sách ưu tiên reverse nên bắt đầu từ các file nằm trên đường giao giữa WBM, system configuration, update, network protocol và service có quyền cao.

| Ưu tiên | File/module | Lý do |
|---:|---|---|
| 1 | `/usr/lib/charx-website/api_import.so` | config import từ WBM |
| 2 | `/usr/lib/charx-website/api_export.so` | config export và dữ liệu nhạy cảm |
| 3 | `/usr/lib/charx-website/api_file.so` | file upload/download surface |
| 4 | `/usr/lib/charx-website/api_firewall.so` | port sharing/firewall boundary |
| 5 | `/usr/lib/charx-website/api_network.so` | network configuration |
| 6 | `/usr/lib/charx-website/api_openvpn.so` | OpenVPN config/credential boundary |
| 7 | `/usr/lib/charx-website/api_certificates.so` | certificate handling |
| 8 | `/usr/lib/charx-website/api_linux_user_permissions.so` | Linux user permission boundary |
| 9 | `/usr/lib/charx-system-config-manager/api_config.so` | system config API |
| 10 | `/usr/lib/charx-system-config-manager/import_service.so` | import service implementation |
| 11 | `/usr/lib/charx-system-config-manager/system_config_file_manager.so` | file/config manager |
| 12 | `/usr/lib/charx-system-config-manager/api_remove_file.so` | remove-file API |
| 13 | `/usr/lib/charx-update-agent/server.so` | update server side |
| 14 | `/usr/lib/charx-update-agent/client.so` | update client side |
| 15 | `/usr/lib/charx-ocpp16-agent/ocpp_firmware_update.so` | OCPP firmware update path |
| 16 | `/usr/lib/charx-ocpp16-agent/websocket_handler.so` | OCPP WebSocket transport |
| 17 | `/usr/lib/charx-ocpp16-agent/ocpp_logic.so` | OCPP core logic |
| 18 | `/usr/lib/charx-jupicore/mqtt_connector.so` | MQTT data path |
| 19 | `/usr/lib/charx-modbus-server/modbus_server.so` | Modbus/TCP server |
| 20 | `/usr/sbin/CharxControllerAgent` | Controller Agent, field/control boundary |

Kiểu file quan sát được:

- `CharxControllerAgent` là ELF 32-bit LSB PIE executable cho ARM, dynamically linked, stripped.
- Nhiều module `.so` trong `/usr/lib/charx-*` là ELF 32-bit LSB shared object cho ARM, dynamically linked, stripped.
- `rauc` là ELF 32-bit LSB PIE executable cho ARM.

Điều này gợi ý toolchain reverse cần hỗ trợ ARM 32-bit EABI5/hard-float, stripped binaries và shared object analysis.

### Evidence

- `/usr/sbin/CharxControllerAgent` trong rootfs là ELF 32-bit ARM PIE executable, dynamically linked, stripped.
- `/usr/lib/charx-website/webserver.so` và `/usr/lib/charx-jupicore/charging_controller.so` là ELF 32-bit ARM shared objects, dynamically linked, stripped.
- `/usr/lib/charx-website` trong rootfs chứa nhiều `api_*.so` module.
- `/usr/lib/charx-system-config-manager` trong rootfs chứa API/import/export/config/file manager modules.
- `/usr/lib/charx-update-agent` trong rootfs chứa `client.so` và `server.so`.
- `/usr/lib/charx-ocpp16-agent` trong rootfs chứa `ocpp_firmware_update.so`, `ocpp_logic.so`, `websocket_handler.so`.

## Câu hỏi 16

### Question

File inventory có phân nhóm cho Day 8 nên được chốt như thế nào?

### Answer

File inventory v1 cho firmware `CHARXSEC3XXXSoftwareBundleV190.raucb`:

| Nhóm | Path/file | Role | Risk hoặc câu hỏi tiếp theo |
|---|---|---|---|
| Bundle metadata | `manifest.raucm` | version, compatible, hash, images | xác nhận version/build/hash khi so sánh firmware |
| Update hook | `hook` | install-check, pre/post-install, bootloader update | kiểm tra command/helper gọi trong update lifecycle |
| Rootfs | `root.ext4` | CHARX control Embedded Linux 1.9.0 | inventory filesystem và service |
| Boot image | `bootimg.vfat` | boot/kernel image | kiểm tra boot artifacts nếu cần |
| Init scripts | `/etc/init.d/charx-*` | lifecycle service | dựng startup order và boot-time boundary |
| Runlevel links | `/etc/rc*.d/S*charx*` | service start/stop order | đối chiếu advisory boot sequence |
| CHARX configs | `/etc/charx/*.conf` | service config | map port, log, peer, file path |
| Route permissions | `/etc/charx/routePermissions.json` | API role mapping | Day 10 audit auth/authorization |
| Web modules | `/usr/lib/charx-website/*.so` | WBM backend API | ưu tiên import/export/update/file/network/cert |
| JupiCore modules | `/usr/lib/charx-jupicore/*.so` | charging data hub | map Controller Agent/MQTT/REST |
| OCPP modules | `/usr/lib/charx-ocpp16-agent/*.so` | OCPP backend communication | update, websocket, payload parser |
| Modbus modules | `/usr/lib/charx-modbus-*/*.so` | Modbus client/server | parser/register/control surface |
| System Config Manager | `/usr/lib/charx-system-config-manager/*.so` | config import/export/apply | advisory 2025 boundary |
| Update Agent | `/usr/lib/charx-update-agent/*.so` | update service | WBM/OCPP/RAUC update path |
| Helper scripts | `/usr/local/bin/charx_*` | privileged system actions | command invocation/input validation |
| Sudoers | `/etc/sudoers.d/*charx*` | privilege delegation | verify least privilege and command restrictions |
| Nginx | `/etc/nginx/*` | frontend/proxy/TLS | map public ports to backend |
| Mosquitto | `/etc/mosquitto/*` | MQTT broker config | local broker and bridge boundary |
| OpenVPN | `/etc/openvpn/*` | VPN config area | credential/routing boundary |
| RAUC | `/etc/rauc/*`, `/usr/bin/rauc` | update trust framework | root CA and system.conf |
| Logs/data | `/log/*`, `/data/*` references | runtime data/log DB | check secret leakage and persistence |

Đây là inventory đủ tốt để chuyển sang Day 9. Day 9 không cần đọc lại toàn bộ filesystem từ đầu; chỉ cần lấy inventory này làm bản đồ và dựng service dependency graph.

### Evidence

- [manifest.raucm](/d:/CHARXSEC/work/firmware_v190_bundle/manifest.raucm) và [hook](/d:/CHARXSEC/work/firmware_v190_bundle/hook) cung cấp lớp bundle/update.
- [root.ext4](/d:/CHARXSEC/work/firmware_v190_bundle/root.ext4) cung cấp root filesystem.
- `/etc/init.d`, `/etc/rc*.d`, `/etc/charx`, `/usr/lib/charx-*`, `/usr/local/bin`, `/etc/sudoers.d`, `/etc/nginx`, `/etc/mosquitto`, `/etc/openvpn`, `/etc/rauc` đều có trong rootfs inventory.

## Câu hỏi 17

### Question

Sau Day 8, checklist chuẩn bị cho Day 9 là gì?

### Answer

Day 9 sẽ dựng service graph và call-chain reconstruction. Từ inventory Day 8, checklist chuẩn bị gồm:

| Việc cần làm | Input từ Day 8 | Output mong muốn cho Day 9 |
|---|---|---|
| Dựng service start order | `/etc/rc5.d`, `/etc/init.d` | boot/service timeline |
| Map service -> config -> port | `/etc/charx/*.conf` | bảng service/port/peer |
| Map WBM API -> module | `/usr/lib/charx-website/api_*.so`, `routePermissions.json` | web API graph |
| Map Website -> System Config Manager | `api_import/export/config`, SCM REST `5001` | config data flow |
| Map Website/JupiCore/OCPP/MQTT | configs local MQTT `127.0.0.1:1883` | internal messaging graph |
| Map update path | RAUC manifest/hook, Update Agent, OCPP firmware update | update pipeline graph |
| Map privileged helpers | `/usr/local/bin/charx_*`, `/etc/sudoers.d` | helper invocation graph |
| Map logs | `LogFilePath` trong configs | observability plan |
| Map cert/key paths | `/etc/rauc`, `/etc/nginx`, `/etc/charx`, `/data/.../cert` | trust material inventory |

Danh sách câu hỏi cần đem sang Day 9:

- service nào bind port trực tiếp và service nào chỉ gọi qua localhost?
- WBM `api_*.so` gọi service nào phía sau?
- System Config Manager expose REST ở `5001` cho ai gọi?
- `routePermissions.json` được load bởi module nào?
- `charx_*` helper nào được gọi bởi web hoặc SCM?
- update qua WBM và update qua OCPP gặp nhau ở service nào?
- log có đủ để dựng timeline request -> action -> restart không?

### Evidence

- [courses.txt](/d:/CHARXSEC/document/courses.txt) nêu Day 9 là `Service graph và call-chain reconstruction`.
- [charx-website.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-website.conf), [charx-jupicore.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-jupicore.conf), [charx-ocpp16-agent.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-ocpp16-agent.conf), [charx-system-config-manager.conf](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/charx-system-config-manager.conf) cung cấp port/peer/log path.
- [routePermissions.json](/d:/CHARXSEC/work/firmware_v190_rootfs/etc/charx/routePermissions.json) cung cấp route/role mapping.
- [hook](/d:/CHARXSEC/work/firmware_v190_bundle/hook) và `/usr/lib/charx-update-agent` cung cấp update pipeline starting points.

## Kết luận Ngày 8

Ngày 8 đã chuyển từ tài liệu và threat model sang firmware inventory thật:

- Bundle `CHARXSEC3XXXSoftwareBundleV190.raucb` là RAUC/SquashFS bundle.
- Manifest cho biết firmware version `1.9.0`, compatible target `ev3000`, rootfs `root.ext4`, kernel image `bootimg.vfat`.
- Rootfs là `CHARX control Embedded Linux 1.9.0 (kirkstone)`.
- Service lifecycle dùng SysV init scripts trong `/etc/init.d` và `/etc/rc*.d`.
- `/etc/charx` là thư mục cấu hình trọng tâm.
- `/usr/lib/charx-*` chứa nhiều application/module `.so` quan trọng.
- `routePermissions.json` là bản đồ role/API quan trọng cho Day 10.
- Update pipeline gồm RAUC manifest/hook, Update Agent, OCPP firmware update module và helper system update.
- Danh sách binary/module ưu tiên reverse đã được chốt cho các ngày tiếp theo.

Điểm quan trọng nhất: Day 8 không kết luận lỗ hổng. Day 8 tạo bản đồ file có bằng chứng. Từ bản đồ này, Day 9 mới dựng service graph, Day 10 mới audit API, Day 11 mới lên kế hoạch emulation sâu hơn.
