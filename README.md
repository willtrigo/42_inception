# 42_inception

> **Inception** — System Administration & DevOps project
> Dockerized WordPress + MariaDB + NGINX + Bonus stack running in a Debian-based custom images, fully managed with `docker-compose`.

### Development Environment

#### Host Machine (Ubuntu 22.04.5 LTS)
| Component                          | Specification                            |
|------------------------------------|------------------------------------------|
| Machine                            | Dell OptiPlex 7400 All-in-One            |
| CPU                                | Intel® Core™ i7-12700 (12 cores / 20 threads) |
| RAM                                | 16 GB DDR4                               |
| GPU                                | AMD Radeon™ RX 6500 XT                   |
| Host OS                            | Ubuntu 22.04.5 LTS                       |

#### Virtual Machine (VirtualBox 7.x)
| Setting                            | Value                                      |
|------------------------------------|--------------------------------------------|
| Guest OS                           | Fedora Everything 43 (64-bit)              |
| CPUs                               | 10 vCPUs (with Nested VT-x/AMD-V enabled) |
| RAM                                | 12 GB (12288 MB)                           |
| Storage                            | 120 GB VDI (dynamic)                       |
| Graphics                           | 128 MB VRAM ✳ 3D Acceleration ✳ VMSVGA    |
| Network                            | Adapter 1 → Bridged (enp0s31f6)            |
| Virtualization                     | KVM + Nested Paging                        |
| Shared Folders                     | **None** (intentionally disabled)          |

> **Why no Shared Folders?**  
> VirtualBox shared folders break Docker volume permissions and violate the subject rule that volumes must live in `/home/login/data`. All work is done inside the VM via SSH + VS Code Remote.

#### VirtualBox Configuration Screenshots
![General - Basic](screenshots/vbox_general_basic.png)
![General - Advanced](screenshots/vbox_general_advanced.png)
![System - Motherboard](screenshots/vbox_system_motherboard.png)
![System - Processor](screenshots/vbox_system_processor.png)
![System - Acceleration](screenshots/vbox_system_acceleration.png)
![Display - Screen](screenshots/vbox_display_display.png)
![Storage](screenshots/vbox_storage.png)
![Network (Bridged)](screenshots/vbox_network.png)
