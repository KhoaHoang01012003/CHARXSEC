# Đánh giá khả năng emulate firmware CHARX SEC-3100 từ RAUC bundle V190

Tài liệu này đánh giá khả năng emulate firmware CHARX SEC-3100 chỉ dựa trên artifact đang có trong workspace: `CHARXSEC3XXXSoftwareBundleV190.raucb`, các tài liệu nguồn trong `document`, và bộ tài liệu học tập Day 1 đến Day 14. Các tỷ lệ phần trăm dưới đây là ước lượng kỹ thuật có điều kiện, không phải kết quả benchmark runtime hoàn chỉnh.

Nguyên tắc: không bịa hành vi. Chỗ nào có bằng chứng từ bundle/config/manual thì ghi là có bằng chứng. Chỗ nào cần thiết bị thật, runtime capture hoặc hardware-in-the-loop thì ghi rõ là cần thêm.

## Kết luận nhanh

| Mục tiêu emulate | Khả năng từ RAUC bundle hiện có | Đánh giá |
|---|---:|---|
| Unpack, inventory, static analysis rootfs | 95-100% | Rất khả thi |
| Reverse userland binaries/modules | 80-90% | Khả thi, nhưng binary stripped |
| Chạy binary ARM riêng lẻ bằng QEMU user | 60-75% | Khả thi có điều kiện |
| Service replay cho WBM/API, SCM, một phần JupiCore | 55-70% | Khả thi nếu dựng đúng `/data`, `/log`, users, network namespace và mocks |
| Emulate OCPP/MQTT/Modbus/OpenVPN ở mức protocol lab | 50-70% | Khả thi nếu dùng mock peers |
| Boot full rootfs bằng QEMU system | 35-50% | Có cơ sở, nhưng phụ thuộc board/i.MX6UL/DTB/boot args/partition layout |
| Emulate chính xác Controller Agent và hardware charging behavior | 20-35% | Thiếu hardware state và field interfaces |
| Emulate chính xác end-to-end như thiết bị thật chỉ từ RAUCB | 30-40% | Không đủ để gọi là full fidelity |
| Emulate phục vụ nghiên cứu Web/API/update/config một cách nghiêm túc | 60-70% | Mục tiêu thực tế nhất từ artifact hiện có |

Kết luận gọn: chỉ từ RAUCB, ta có thể emulate tốt phần filesystem, userland, WBM/API, update/config pipeline và nhiều service ở mức lab. Nhưng không thể emulate chính xác toàn bộ hành vi của CHARX SEC-3100 như thiết bị thật nếu thiếu `/data`, `/log`, `/identity`, bootloader environment, partition layout runtime, certificates/provisioning, network peers thật hoặc mock có căn cứ, và hardware charging interfaces.

## Vì sao RAUCB hiện có là nền tảng tốt?

| Artifact | Bằng chứng | Ý nghĩa |
|---|---|---|
| `CHARXSEC3XXXSoftwareBundleV190.raucb` | SquashFS/RAUC bundle | Có bundle update thật |
| `manifest.raucm` | `version=1.9.0`, `compatible=ev3000` | Có version/build/hash |
| `root.ext4` | ext4 rootfs 514,514,944 bytes | Có root filesystem thật |
| `bootimg.vfat` | FAT image 20,971,520 bytes | Có boot image |
| `zImage` | nằm trong `bootimg.vfat` | Có kernel image |
| `zImage-imx6ul-ksp0632.dtb` | nằm trong `bootimg.vfat` | Có DTB/board hint |
| `/boot/barebox.bin` | nằm trong rootfs | Có bootloader artifact |
| `/usr/lib/os-release` | `CHARX control Embedded Linux 1.9.0 (kirkstone)` | Biết OS baseline |
| `/lib/modules/5.15.195` | kernel modules present | Có module set |
| `/etc/rc5.d` | SysV startup order | Có boot service baseline |
| `/etc/charx/*.conf` | service configs | Có service graph baseline |

Điểm rất có giá trị là firmware không chỉ có binary rời. Nó có rootfs, kernel, DTB, bootloader artifact, RAUC config, init scripts, configs, route permissions, nginx config, service modules và helper scripts. Với một firmware embedded Linux, đây là nền tảng khá giàu.

## Những phần có thể emulate tương đối tốt

| Thành phần | Khả năng | Vì sao |
|---|---:|---|
| Static rootfs | 95-100% | rootfs ext4 đã có đầy đủ |
| SysV startup graph | 90-95% | `/etc/rc5.d` và `/etc/init.d` đã có |
| Nginx/WBM frontend | 70-85% | nginx config và `/usr/lib/charx-website/dist` có trong rootfs |
| Website backend | 55-70% | có `CharxWebsite`, `api_*.so`, route permissions, config |
| System Config Manager | 55-70% | có binary/modules/config, ít phụ thuộc hardware hơn Controller Agent |
| Update pipeline offline | 75-85% | có RAUC manifest, hook, system.conf, root CA path, Update Agent |
| API authorization mapping | 85-95% | `routePermissions.json` có đầy đủ baseline |
| OCPP Agent protocol lab | 50-65% | có agent/modules/config, cần mock backend |
| MQTT paths | 60-75% | local Mosquitto/config present, cần topic capture/mocks |
| Modbus service lab | 45-65% | có modules/config, cần mock Modbus devices |

Mục tiêu phù hợp nhất là emulate để nghiên cứu các luồng:

- WBM/API authorization
- config import/export
- update upload/install pipeline
- OCPP config and diagnostics
- OpenVPN/MQTT/Modbus configuration surfaces
- service graph and log behavior
- helper script and sudoers boundaries

## Những phần khó hoặc không thể chính xác nếu chỉ có RAUCB

| Thành phần | Vì sao khó | Cần thêm gì |
|---|---|---|
| Full board boot chính xác | QEMU cần machine/SoC/DTB/boot args khớp i.MX6UL/KSP0632 | bootloader env, kernel cmdline, partition layout thật, board model mapping |
| `/data`, `/log`, `/identity` thật | RAUCB chỉ cung cấp rootfs/boot image; fstab mount `/dev/mmcblk1p8`, `p9`, `p10` | dump hoặc export runtime partitions từ thiết bị lab |
| Controller Agent behavior | phụ thuộc CAN, eth1, eth2, SECC, QCA/HomePlug, certs | hardware hoặc mocks có trace thật |
| Charging state machine chính xác | cần CP/PP, contactor, locking actuator, meter, RFID, vehicle simulator | EVSE/EV simulator hoặc hardware-in-the-loop |
| Modem behavior | config dùng `/dev/ttyMODEM2`, `/dev/cdc-wdm0` | modem USB/QMI hoặc mock dựa trên trace |
| USB-C/RNDIS commissioning | cần USB gadget/device mode behavior | thiết bị thật hoặc kernel gadget setup tương đương |
| OpenVPN behavior chính xác | cần server config, routing, certs, activation path | OpenVPN server lab và config thật |
| OCPP backend behavior chính xác | backend là external system | backend thật hoặc mock theo trace/spec |
| Device identity/certs | không nên bịa cert/UID/secret | lấy từ thiết bị lab được phép hoặc dùng test provisioning rõ ràng |

Điểm mấu chốt: nếu thiếu `/identity` và provisioning data, nhiều hành vi “thiết bị thật” sẽ biến thành default/lab behavior. Điều đó vẫn hữu ích cho research, nhưng không được gọi là accurate emulation.

## Tỷ lệ theo lớp hành vi

| Lớp hành vi | Tỷ lệ từ RAUCB | Tỷ lệ nếu thêm mocks tốt | Tỷ lệ nếu thêm thiết bị lab + runtime dump |
|---|---:|---:|---:|
| Filesystem/package analysis | 95-100% | 95-100% | 95-100% |
| Userland reverse engineering | 80-90% | 80-90% | 85-95% |
| WBM/API behavior | 55-70% | 70-80% | 80-90% |
| Update/config behavior | 60-75% | 70-85% | 85-90% |
| OCPP/MQTT/Modbus protocol behavior | 40-60% | 65-80% | 80-90% |
| Boot/startup behavior | 35-50% | 45-60% | 75-90% |
| Hardware charging behavior | 20-35% | 35-55% | 80-95% với hardware-in-the-loop |
| End-to-end exactness | 30-40% | 50-65% | 80-90% |

Không nên đặt mục tiêu 100%. Với firmware gắn hardware sạc EV, “100% exact emulation” gần như đồng nghĩa với có thiết bị thật hoặc mô hình hardware-in-the-loop được đo bằng trace thật.

## Cần thêm gì để emulate đầy đủ và chính xác hơn?

| Nhóm cần thêm | Cụ thể | Mục đích |
|---|---|---|
| Runtime partitions | dump `/data`, `/log`, `/identity` từ thiết bị lab | giữ config, DB, cert, identity, logs thật |
| Boot metadata | kernel cmdline, barebox env, RAUC slot state, partition table eMMC | boot chính xác hơn |
| Hardware profile | SoC/board exact, DTB confirmed, device tree overlays nếu có | chọn QEMU/machine hoặc HIL |
| Process baseline | `ps`, service status, users/groups, open ports sau boot | validate service replay |
| Network baseline | `ip addr`, `ip route`, firewall rules, port sharing state | không tự bịa network behavior |
| Service logs | logs sau boot, sau login, sau import/export, sau update dry-run | đối chiếu behavior |
| OCPP backend trace | handshake/messages/config update/diagnostics | mock backend có căn cứ |
| MQTT topic trace | local topics, remote bridge direction, retained messages | mock broker chính xác hơn |
| Modbus traces | meter/client/server request-response | mô phỏng device behavior 
| OpenVPN config/trace | server config, route behavior, cert lifecycle | mô phỏng VPN chính xác |
| Hardware-in-the-loop | CP/PP simulator, contactor/locking actuator, RS-485 meter/RFID, CAN/backplane, QCA/HomePlug | emulate charging behavior |
| Credentials/certs hợp pháp | test certificates, lab identity, non-production secrets | tránh bịa hoặc dùng secret thật ngoài phạm vi |

## Cách emulate mà ít làm thay đổi hành vi nhất

| Nguyên tắc | Cách làm |
|---|---|
| Không patch binary trước | chạy binary/module gốc bằng QEMU user hoặc rootfs lab |
| Không sửa config nếu chưa cần | ưu tiên network namespace để giữ IP/port như config |
| Không bịa service peer | mock peer phải log rõ và dựa trên spec/trace |
| Không fake identity như thật | dùng lab identity rõ ràng, hoặc dump identity từ thiết bị được phép |
| Không bỏ qua `/data` | tạo partition/data volume riêng; nếu dùng empty data thì ghi rõ là first-boot/default behavior |
| Không đổi port để dễ chạy | dùng namespace/port forwarding thay vì sửa port trong config |
| Không coi mock là thiết bị thật | mọi kết quả mock phải ghi trong emulation report |
| Không test update trên hạ tầng thật | chỉ dry-run/offline hoặc thiết bị lab có thể phục hồi |

Nếu bắt buộc sửa config để service chạy, cần lưu diff và coi kết quả là `modified-runtime behavior`, không phải exact firmware behavior.

## Chiến lược thực tế nên chọn

| Phase | Mục tiêu | Độ ưu tiên |
|---|---|---|
| 1 | Hoàn thiện static inventory và service graph | Cao |
| 2 | Dựng rootfs lab với `/data`, `/log`, `/identity` riêng | Cao |
| 3 | Chạy Website + nginx + route permissions + mock SCM/JupiCore | Cao |
| 4 | Chạy SCM thật, trace import/export/config | Cao |
| 5 | Thêm MQTT local, JupiCore, OCPP mock backend | Trung bình cao |
| 6 | Thêm Modbus/OpenVPN mocks | Trung bình |
| 7 | Boot QEMU system với kernel/DTB nếu machine khớp | Trung bình |
| 8 | Hardware-in-the-loop cho Controller Agent và charging behavior | Cao nếu mục tiêu là firmware behavior đầy đủ |

Với mục tiêu tìm CVE ở WBM/config/update, không cần chờ full hardware emulation. Với mục tiêu nghiên cứu charging control logic, Controller Agent hoặc CP/PP state machine, cần hardware-in-the-loop hoặc trace thật.

## Đánh giá cuối cùng

Nếu chỉ dùng `CHARXSEC3XXXSoftwareBundleV190.raucb`, mức emulate hợp lý là:

| Cách hiểu “emulate” | Tỷ lệ |
|---|---:|
| Emulate để đọc, reverse, map service, audit API/update/config | khoảng 60-70% |
| Emulate để chạy đầy đủ mọi service userland ổn định | khoảng 45-60% |
| Emulate boot/rootfs giống thiết bị thật | khoảng 35-50% |
| Emulate chính xác toàn bộ charging controller end-to-end | khoảng 30-40% |

Muốn lên mức 80-90% cho end-to-end behavior, cần thêm thiết bị lab hoặc runtime dump, hardware traces, `/data`/`/identity`, network peers và mock services dựa trên hành vi đo được. Muốn trên 90%, gần như cần hardware-in-the-loop hoặc thiết bị thật để đối chiếu liên tục.
