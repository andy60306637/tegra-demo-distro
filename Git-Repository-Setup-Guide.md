# Git Repository 建立指南

**目的**: 將 meta-tegrademo layer 和 KAS 專案發布到 GitHub  
**日期**: 2025-11-27  

---

## 📋 Repository 規劃

### Repository 1: meta-tegrademo
- **用途**: 自定義 Yocto/OE layer (DisplayPort + IMX219 相機配置)
- **位置**: `layers/meta-tegrademo/`
- **建議名稱**: `meta-tegrademo-custom` 或 `meta-jetson-orin-nano-custom`

### Repository 2: tegra-demo-distro  
- **用途**: KAS 專案配置 (整合所有 layers)
- **位置**: 專案根目錄
- **建議名稱**: `tegra-demo-distro-custom` 或 `jetson-orin-nano-kas-project`

---

## 🎯 Repository 1: meta-tegrademo

### 步驟 1: 準備 meta-tegrademo layer

```bash
cd /home/andy/proj/tegra-demo-distro/layers/meta-tegrademo

# 初始化 Git (如果尚未初始化)
git init

# 檢查當前檔案
ls -la

# 應包含:
# - conf/              ← Layer 配置
# - recipes-bsp/       ← UEFI/bootloader recipes
# - recipes-containers/
# - recipes-demo/
# - README (需要建立)
```

### 步驟 2: 建立 README.md

```bash
cat > README.md << 'EOF'
# meta-tegrademo-custom

Custom Yocto/OpenEmbedded layer for NVIDIA Jetson Orin Nano with DisplayPort and IMX219 camera support.

## Description

This layer provides configuration and recipes for:
- **DisplayPort/HDMI output** via nvidia-drm with KMS support
- **IMX219 camera** on CAM1 (CSI-C) port
- **Device Tree overlays** management
- Custom bootloader (L4TLauncher) configuration

## Dependencies

This layer depends on:
- **meta-tegra** (OE4T BSP layer for Tegra platforms)
- **meta-openembedded** (meta-oe, meta-python, meta-networking, meta-multimedia)
- **openembedded-core** (or poky)

## Compatible Machines

- `p3768-0000-p3767-0004` (Jetson Orin Nano 4GB Developer Kit)

## Layer Structure

```
meta-tegrademo-custom/
├── conf/
│   ├── layer.conf                    # Layer configuration
│   ├── distro/
│   │   ├── tegrademo.conf
│   │   └── include/tegrademo.inc
│   └── templates/                    # Build templates
├── recipes-bsp/
│   └── uefi/
│       └── l4t-launcher-extlinux.bbappend  # FDT/DTBO overlay support
├── recipes-containers/
│   └── docker/
├── recipes-demo/
│   └── data-overlay-setup/
├── dynamic-layers/
│   └── meta-swupdate/
└── scripts/
```

## Key Features

### 1. DisplayPort/HDMI Support

Automatic nvidia-drm configuration with:
- Kernel mode setting (modeset=1)
- Framebuffer device support (fbdev=1)
- DRM device at `/dev/dri/card0`

### 2. IMX219 Camera Support

Pre-configured for Sony IMX219 8MP camera:
- Connected to CAM1 connector (CSI-C)
- I2C address: 0x10 on bus 7
- Device Tree overlay: `tegra234-p3767-camera-p3768-imx219-C.dtbo`
- V4L2 device: `/dev/video0`

### 3. Custom extlinux.conf with FDT/DTBO

Modified `l4t-launcher-extlinux` recipe to support:
- Main Device Tree: `/boot/devicetree/tegra234-p3768-0000+p3767-0004-nv-super.dtb`
- Overlays: `/boot/devicetree/*.dtbo`
- Automatic `devicetree/` subdirectory creation

## Usage

### With KAS

Add to your `kas` project file (e.g., `project.yml`):

```yaml
repos:
  meta-tegrademo-custom:
    url: "https://github.com/YOUR_USERNAME/meta-tegrademo-custom.git"
    refspec: main
    layers:
      .:
```

### With BitBake

Add to `conf/bblayers.conf`:

```
BBLAYERS ?= " \
  /path/to/layers/meta-tegrademo-custom \
  ... \
"
```

### Configuration

In `conf/local.conf` or KAS `local_conf_header`:

```bash
MACHINE = "p3768-0000-p3767-0004"
DISTRO = "tegrademo"

# Enable DisplayPort
IMAGE_INSTALL:append = " nvidia-drm-loadconf kernel-module-nvidia-drm"
KERNEL_ARGS:append = " nvidia-drm.modeset=1 nvidia-drm.fbdev=1"

# Enable IMX219 Camera
IMAGE_INSTALL:append = " tegra-argus-daemon tegra-mmapi v4l-utils"
UBOOT_EXTLINUX_FDT = "devicetree/tegra234-p3768-0000+p3767-0004-nv-super.dtb"
UBOOT_EXTLINUX_FDTOVERLAYS = "devicetree/tegra234-p3767-camera-p3768-imx219-C.dtbo"
```

## Testing

### DisplayPort Verification

```bash
# Check DRM device
ls -la /dev/dri/card0

# Check modeset
cat /sys/module/nvidia_drm/parameters/modeset  # Should be: Y

# Check DisplayPort status
cat /sys/class/drm/card0-DP-1/status  # Should be: connected
```

### Camera Verification

```bash
# Check V4L2 device
v4l2-ctl --list-devices

# Check I2C detection
i2cdetect -y -r 7  # Should show device at 0x10

# Test with GStreamer
gst-launch-1.0 nvarguscamerasrc sensor-id=0 ! \
    'video/x-raw(memory:NVMM),width=1920,height=1080,framerate=30/1' ! \
    nvoverlaysink
```

## Building

See the main KAS project README for complete build instructions.

## License

MIT License (see LICENSE file)

## Maintainer

YOUR_NAME <your.email@example.com>

## References

- [OE4T meta-tegra](https://github.com/OE4T/meta-tegra)
- [Jetson Orin Nano Developer Kit](https://developer.nvidia.com/embedded/learn/get-started-jetson-orin-nano-devkit)
- [Yocto Project](https://www.yoctoproject.org/)
EOF
```

### 步驟 3: 建立 .gitignore

```bash
cat > .gitignore << 'EOF'
# Build artifacts
*.pyc
__pycache__/
*.swp
*~

# Editor files
.vscode/
.idea/
*.sublime-*

# OS files
.DS_Store
Thumbs.db
EOF
```

### 步驟 4: Commit 到本地 Git

```bash
# 添加所有檔案
git add .

# 檢查將要提交的內容
git status

# 建立第一個 commit
git commit -m "Initial commit: meta-tegrademo with DisplayPort and IMX219 support

Features:
- DisplayPort/HDMI via nvidia-drm (modeset + fbdev)
- IMX219 camera on CAM1 (CSI-C)
- Custom l4t-launcher-extlinux.bbappend for FDT/DTBO support
- Device Tree overlay configuration
"
```

### 步驟 5: 建立 GitHub Repository

1. **前往 GitHub**: https://github.com/new
2. **Repository 名稱**: `meta-tegrademo-custom` (或您喜歡的名稱)
3. **Description**: `Custom Yocto layer for Jetson Orin Nano with DisplayPort and IMX219 camera`
4. **可見性**: Public 或 Private
5. **不要**勾選 "Add a README" (我們已經建立了)
6. 點擊 **Create repository**

### 步驟 6: 推送到 GitHub

```bash
# 添加 remote (替換 YOUR_USERNAME)
git remote add origin https://github.com/YOUR_USERNAME/meta-tegrademo-custom.git

# 推送到 GitHub
git branch -M main
git push -u origin main
```

---

## 🎯 Repository 2: tegra-demo-distro (KAS 專案)

### 步驟 1: 準備專案檔案

```bash
cd /home/andy/proj/tegra-demo-distro

# 檢查當前 remote
git remote -v

# 如果要 fork,先移除原始 remote
git remote remove origin

# 或重新命名為 upstream
git remote rename origin upstream
```

### 步驟 2: 整理檔案

```bash
# 建立 .gitignore (如果不存在)
cat > .gitignore << 'EOF'
# Build directory
build/
!build/.gitkeep

# KAS work directory
.kas/

# Downloaded sources
repos/bitbake/
repos/openembedded-core/
repos/meta-openembedded/
repos/meta-tegra/
repos/meta-tegra-community/
repos/meta-virtualization/
repos/poky/

# Submodules (KAS will fetch)
layers/

# Build logs
bitbake-cookerdaemon.log
*.log

# Editor files
.vscode/
.idea/
*.sublime-*
*~
*.swp

# OS files
.DS_Store
Thumbs.db

# Documentation (optional - 可以選擇保留或忽略)
# *.md
# *.docx
EOF
```

### 步驟 3: 建立/更新 README.md

```bash
cat > README.md << 'EOF'
# Jetson Orin Nano KAS Project

KAS-based build project for NVIDIA Jetson Orin Nano 4GB Developer Kit with DisplayPort and IMX219 camera support.

## Quick Start

### Prerequisites

```bash
# Install KAS
pip3 install kas

# Install dependencies
sudo apt-get install -y gawk wget git diffstat unzip texinfo \
    gcc build-essential chrpath socat cpio python3 python3-pip \
    python3-pexpect xz-utils debianutils iputils-ping python3-git \
    python3-jinja2 libegl1-mesa libsdl1.2-dev pylint xterm \
    python3-subunit mesa-common-dev zstd liblz4-tool
```

### Build

```bash
# Clone the project
git clone https://github.com/YOUR_USERNAME/jetson-orin-nano-kas-project.git
cd jetson-orin-nano-kas-project

# Build with KAS
kas build project.yml

# Output will be in:
# build/tmp-glibc/deploy/images/p3768-0000-p3767-0004/
```

## Features

- **Target**: NVIDIA Jetson Orin Nano 4GB (p3768-0000-p3767-0004)
- **BSP**: OE4T meta-tegra (L4T R36.4.4)
- **Yocto**: Scarthgap (5.0)
- **Boot**: NVMe (TEGRA_FLASH_USE_NVME=1)
- **Display**: DisplayPort/HDMI via nvidia-drm
- **Camera**: Sony IMX219 8MP on CAM1

## Project Structure

```
jetson-orin-nano-kas-project/
├── project.yml                        # Main KAS configuration
├── setup-env                          # Setup script (legacy)
├── scripts-setup/                     # Setup utilities
├── build/                             # Build output (generated)
├── layers/                            # Custom layers (KAS fetches)
│   └── meta-tegrademo/               # Submodule/fetched layer
├── repos/                             # Upstream layers (KAS fetches)
│   ├── poky/
│   ├── meta-openembedded/
│   ├── meta-tegra/
│   └── ...
└── *.md                               # Documentation
```

## Configuration

### project.yml

Key configurations in `project.yml`:

```yaml
machine: p3768-0000-p3767-0004        # Jetson Orin Nano 4GB
distro: my-distro
target: demo-image-egl                 # Minimal graphics image

repos:
  meta-tegrademo-custom:
    url: "https://github.com/YOUR_USERNAME/meta-tegrademo-custom.git"
    refspec: main

local_conf_header:
  my-project: |
    TEGRA_FLASH_USE_NVME = "1"
    TEGRA_BOARDSKU = "0004"
    
    # DisplayPort/HDMI
    IMAGE_INSTALL:append = " nvidia-drm-loadconf kernel-module-nvidia-drm"
    KERNEL_ARGS:append = " nvidia-drm.modeset=1 nvidia-drm.fbdev=1"
    
    # Camera
    IMAGE_INSTALL:append = " tegra-argus-daemon tegra-mmapi v4l-utils"
    UBOOT_EXTLINUX_FDT = "devicetree/tegra234-p3768-0000+p3767-0004-nv-super.dtb"
    UBOOT_EXTLINUX_FDTOVERLAYS = "devicetree/tegra234-p3767-camera-p3768-imx219-C.dtbo"
```

## Flashing

### Extract Flashing Package

```bash
cd build/tmp-glibc/deploy/images/p3768-0000-p3767-0004/
tar -xvf demo-image-egl-*.tegraflash.tar.gz
cd mfi_p3768-0000-p3767-0004/
```

### Flash to Jetson

1. Connect Jetson to host via USB-C
2. Put Jetson in Recovery Mode:
   - Hold RECOVERY button
   - Press RESET button
   - Release RECOVERY button
3. Flash:

```bash
sudo ./doflash.sh
```

## Verification

After booting the system:

```bash
# Check DisplayPort
cat /sys/module/nvidia_drm/parameters/modeset  # Should be: Y
cat /sys/class/drm/card0-DP-1/status           # Should be: connected

# Check Camera
v4l2-ctl --list-devices                        # Should show /dev/video0
i2cdetect -y -r 7                              # Should show 0x10

# Test Camera
gst-launch-1.0 nvarguscamerasrc sensor-id=0 ! \
    'video/x-raw(memory:NVMM),width=1920,height=1080,framerate=30/1' ! \
    nvoverlaysink
```

## Documentation

- [DisplayPort Configuration Guide](DisplayPort-Configuration-Analysis.md)
- [IMX219 Camera Configuration Guide](IMX219-Camera-Configuration-Analysis.md)
- [System Verification Guide](System-Verification-Guide.md)
- [extlinux.conf FDT/OVERLAYS Guide](extlinux-fdt-overlays-configuration-guide.md)

## Troubleshooting

See individual documentation files for detailed troubleshooting steps.

## License

MIT License (or specify your license)

## Maintainer

YOUR_NAME <your.email@example.com>

## References

- [OE4T tegra-demo-distro](https://github.com/OE4T/tegra-demo-distro)
- [KAS Documentation](https://kas.readthedocs.io/)
- [meta-tegra](https://github.com/OE4T/meta-tegra)
EOF
```

### 步驟 4: Commit 變更

```bash
# 檢查狀態
git status

# 添加修改的檔案
git add project.yml
git add layers/meta-tegrademo/recipes-bsp/uefi/l4t-launcher-extlinux.bbappend
git add .gitignore README.md

# 添加文檔 (可選)
git add *.md

# Commit
git commit -m "Custom KAS project for Jetson Orin Nano

Features:
- DisplayPort/HDMI output with nvidia-drm
- IMX219 camera on CAM1 (CSI-C)
- NVMe boot support
- Custom extlinux.conf with FDT/DTBO overlays
- Comprehensive documentation

Target: p3768-0000-p3767-0004 (Jetson Orin Nano 4GB)
Image: demo-image-egl
BSP: meta-tegra L4T R36.4.4
"
```

### 步驟 5: 建立 GitHub Repository

1. **前往 GitHub**: https://github.com/new
2. **Repository 名稱**: `jetson-orin-nano-kas-project` (或您喜歡的名稱)
3. **Description**: `KAS project for Jetson Orin Nano 4GB with DisplayPort and IMX219 camera`
4. **可見性**: Public 或 Private
5. **不要**勾選 "Add a README"
6. 點擊 **Create repository**

### 步驟 6: 推送到 GitHub

```bash
# 添加新的 remote
git remote add origin https://github.com/YOUR_USERNAME/jetson-orin-nano-kas-project.git

# 推送到 GitHub
git branch -M main
git push -u origin main
```

### 步驟 7: 更新 project.yml 引用 meta-tegrademo

修改 `project.yml` 中的 `meta-tegrademo` 引用:

```yaml
repos:
  # ... 其他 repos ...
  
  meta-tegrademo-custom:
    url: "https://github.com/YOUR_USERNAME/meta-tegrademo-custom.git"
    path: layers/meta-tegrademo
    refspec: main
    layers:
      .:
```

Commit 並推送:

```bash
git add project.yml
git commit -m "Update meta-tegrademo reference to custom GitHub repo"
git push
```

---

## 📝 Repository 關係

### 依賴結構

```
jetson-orin-nano-kas-project (KAS 專案)
    │
    ├─→ meta-tegrademo-custom (您的 custom layer)
    │
    ├─→ meta-tegra (OE4T BSP)
    │
    ├─→ meta-openembedded
    │
    ├─→ poky (OpenEmbedded-Core)
    │
    └─→ meta-virtualization
```

### Git Submodules vs KAS Fetch

**選項 A: 使用 KAS 自動 fetch (推薦)**
- KAS 自動 clone 所有 repos
- 不需要 git submodules
- `project.yml` 定義所有依賴

**選項 B: 使用 Git Submodules**
```bash
# 添加 submodule
git submodule add https://github.com/YOUR_USERNAME/meta-tegrademo-custom.git layers/meta-tegrademo
git commit -m "Add meta-tegrademo-custom as submodule"
git push
```

---

## ✅ 最終檢查清單

### meta-tegrademo-custom
- [ ] README.md 完整
- [ ] .gitignore 設定
- [ ] 所有修改的 recipes committed
- [ ] 推送到 GitHub
- [ ] Repository 設定正確 (public/private)

### jetson-orin-nano-kas-project
- [ ] project.yml 更新 meta-tegrademo URL
- [ ] README.md 完整
- [ ] .gitignore 排除 build/ 和 repos/
- [ ] 文檔檔案已添加
- [ ] 推送到 GitHub
- [ ] 測試從零開始 clone + build

---

## 🚀 測試新 Repository

在新機器上測試:

```bash
# Clone KAS 專案
git clone https://github.com/YOUR_USERNAME/jetson-orin-nano-kas-project.git
cd jetson-orin-nano-kas-project

# KAS 會自動 fetch 所有依賴 (包含 meta-tegrademo-custom)
kas build project.yml

# 檢查輸出
ls -lh build/tmp-glibc/deploy/images/p3768-0000-p3767-0004/
```

---

## 📚 後續維護

### 更新 meta-tegrademo-custom

```bash
cd layers/meta-tegrademo
# 進行修改...
git add .
git commit -m "Description of changes"
git push
```

### 更新 KAS 專案

```bash
cd /home/andy/proj/jetson-orin-nano-kas-project
# 修改 project.yml 或添加文檔...
git add .
git commit -m "Description of changes"
git push
```

### 版本標籤

```bash
# 在穩定版本打標籤
git tag -a v1.0.0 -m "Release 1.0.0: Initial stable release"
git push origin v1.0.0

# 在 project.yml 中引用特定版本
repos:
  meta-tegrademo-custom:
    url: "https://github.com/YOUR_USERNAME/meta-tegrademo-custom.git"
    refspec: v1.0.0  # 或 commit hash
```

---

## 🎉 完成!

您現在有兩個 GitHub repositories:
1. **meta-tegrademo-custom** - 可重用的 Yocto layer
2. **jetson-orin-nano-kas-project** - KAS 專案配置

其他人可以:
```bash
git clone https://github.com/YOUR_USERNAME/jetson-orin-nano-kas-project.git
cd jetson-orin-nano-kas-project
kas build project.yml
```

一鍵重現您的完整配置! 🚀
