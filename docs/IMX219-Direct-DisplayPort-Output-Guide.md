# IMX219 相機直接輸出至 DisplayPort 完整實作指南

## 專案概述

本文件詳細記錄如何在 NVIDIA Jetson Orin Nano 4GB 開發板上，使用 Yocto Project 建構一個 kiosk mode 系統，實現 IMX219 相機畫面直接輸出到 DisplayPort 顯示器，**不需要 Wayland compositor（如 Weston）**，達到真正的硬體直接輸出。

### 硬體規格
- **開發板**: Jetson Orin Nano 4GB (P3768-0000+P3767-0004)
- **相機**: IMX219 CSI Camera（連接到 CAM1 / CSI-C）
- **顯示**: DisplayPort 輸出
- **作業系統**: 基於 Yocto Project (scarthgap) 的客製化 Linux

### 軟體架構
- **BSP**: OE4T meta-tegra (L4T R36.4.4)
- **Yocto**: scarthgap (5.0)
- **Init System**: systemd
- **編譯工具**: KAS (setup tool for bitbake based projects)
- **視訊框架**: GStreamer 1.22 with NVIDIA plugins

---

## 目錄

1. [專案結構](#專案結構)
2. [KAS 與 Yocto 基礎知識](#kas-與-yocto-基礎知識)
3. [專案配置詳解](#專案配置詳解)
4. [Camera Kiosk 實作](#camera-kiosk-實作)
5. [GStreamer 管線設計](#gstreamer-管線設計)
6. [編譯與部署](#編譯與部署)
7. [問題排除](#問題排除)
8. [學習資源](#學習資源)

---

## 專案結構

```
tegra-demo-distro/
├── project.yml                    # KAS 專案配置檔（主要配置）
├── setup-env                      # 環境設定腳本
├── build/                         # 編譯輸出目錄
│   ├── conf/                      # BitBake 配置
│   │   ├── bblayers.conf         # Layer 配置
│   │   └── local.conf            # 本地編譯配置
│   ├── downloads/                # 原始碼下載快取
│   ├── sstate-cache/             # Shared State Cache
│   └── tmp/                      # 編譯暫存檔
│       └── deploy/images/        # 最終映像檔輸出
├── layers/                        # 本地 layers
│   └── meta-tegrademo/           # 專案特定 layer
├── repos/                         # Git submodules
│   ├── poky/                     # Yocto 核心
│   ├── meta-openembedded/        # OE layers
│   ├── meta-tegra/               # NVIDIA Tegra BSP
│   ├── meta-tegra-community/     # 社群擴充
│   └── meta-my-project/          # 我們的客製化 layer
│       ├── conf/
│       │   └── layer.conf        # Layer 定義
│       ├── recipes-apps/
│       │   └── camera-kiosk/     # Camera Kiosk 應用
│       │       ├── camera-kiosk.bb
│       │       └── files/
│       │           ├── camera-kiosk.service
│       │           ├── camera-kiosk.sh
│       │           └── camera-kiosk-debug.sh
│       └── recipes-graphics/
│           └── weston/            # (已廢棄) Weston 配置
└── docs/
    └── (本文件)
```

---

## KAS 與 Yocto 基礎知識

### 什麼是 Yocto Project？

Yocto Project 是一個開源協作專案，提供工具和流程來創建客製化的 Linux 發行版，特別適合嵌入式系統。

**核心概念：**

1. **Layer (層)**
   - 組織相關 recipes 的方式
   - 可以疊加和覆寫
   - 命名規範：`meta-<name>`
   
2. **Recipe (.bb 檔案)**
   - 描述如何建構軟體包
   - 包含：原始碼位置、依賴關係、編譯/安裝步驟
   
3. **BitBake**
   - Yocto 的任務執行引擎
   - 解析 recipes 並執行編譯任務
   
4. **Image Recipe**
   - 定義最終系統映像檔包含哪些套件
   - 範例：`demo-image-egl.bb`

5. **Shared State Cache (sstate)**
   - 快取已編譯的任務結果
   - 加速重複編譯

### 什麼是 KAS？

KAS 是一個設定工具，用於管理基於 BitBake 的專案（如 Yocto）。

**優點：**
- 使用單一 YAML 檔案 (`project.yml`) 管理所有配置
- 自動處理多個 Git repositories
- 簡化環境設定
- 支援多專案配置

**基本命令：**
```bash
# 編譯專案
kas build project.yml

# 進入編譯環境 shell
kas shell project.yml

# 執行 BitBake 命令
kas shell project.yml -c "bitbake <package>"
```

---

## 專案配置詳解

### 1. project.yml - KAS 配置檔

這是專案的核心配置檔，定義了所有 layers、機器類型、發行版和編譯選項。

```yaml
header:
  version: 11

# 目標機器：Jetson Orin Nano 4GB
machine: p3768-0000-p3767-0004

# 發行版：自訂發行版
distro: my-distro

# 要編譯的映像檔
target: demo-image-egl

# Git Repositories 定義
repos:
  # Yocto 核心
  poky:
    url: "git://git.yoctoproject.org/poky"
    path: repos/poky
    refspec: scarthgap
    layers:
      meta:
      meta-poky:
      meta-yocto-bsp:

  # OpenEmbedded 擴充 layers
  meta-openembedded:
    url: "git://git.openembedded.org/meta-openembedded"
    path: repos/meta-openembedded
    refspec: scarthgap
    layers:
      meta-oe:
      meta-python:
      meta-networking:
      meta-multimedia:
      meta-filesystems:

  # NVIDIA Tegra BSP (官方支援)
  meta-tegra:
    url: "https://github.com/OE4T/meta-tegra.git"
    path: repos/meta-tegra
    refspec: scarthgap

  # Tegra 社群擴充
  meta-tegra-community:
    url: "https://github.com/OE4T/meta-tegra-community"
    path: repos/meta-tegra-community
    refspec: scarthgap

  # 我們的客製化 layer
  meta-my-project:
    url: "https://github.com/andy60306637/meta-my-project.git"
    path: repos/meta-my-project
    refspec: main

  # 本地 layer
  meta-tegrademo:
    path: "layers/meta-tegrademo"

# local.conf 配置
local_conf_header:
  my-project: |
    CONF_VERSION = "2"
    
    # === Jetson 硬體配置 ===
    TEGRA_FLASH_USE_NVME = "1"
    TEGRA_BOARDSKU = "0004"
    
    # === Init System: systemd ===
    DISTRO_FEATURES:append = " systemd pam"
    DISTRO_FEATURES_BACKFILL_CONSIDERED:append = " sysvinit"
    VIRTUAL-RUNTIME_init_manager = "systemd"
    VIRTUAL-RUNTIME_initscripts = "systemd-compat-units"
    
    # === 映像檔包含的套件 ===
    IMAGE_INSTALL:append = " \
        tegra-argus-daemon \
        tegra-mmapi \
        gstreamer1.0-plugins-tegra \
        gstreamer1.0-plugins-nvvideosinks \
        gstreamer1.0-plugins-nvvidconv \
        gstreamer1.0-plugins-nvarguscamerasrc \
        gstreamer1.0-plugins-nvv4l2camerasrc \
        gstreamer1.0-plugins-nveglgles \
        gstreamer1.0-plugins-bad \
        gstreamer1.0-plugins-good \
        gstreamer1.0-plugins-base \
        cuda-libraries \
        libv4l \
        v4l-utils \
        tegra-firmware \
        nvidia-drm-loadconf \
        kernel-module-nvidia-drm \
        camera-display-test \
        i2c-tools \
        libdrm \
        libdrm-tests \
        mesa-demos \
        camera-kiosk \
        sudo \
        systemd \
        systemd-serialgetty \
    "
    
    # === Bootloader 配置 ===
    # 指定裝置樹（Device Tree）檔案
    UBOOT_EXTLINUX_FDT = "devicetree/tegra234-p3768-0000+p3767-0004-nv-super.dtb"
    
    # 載入相機 overlay（啟用 IMX219 on CAM1）
    UBOOT_EXTLINUX_FDTOVERLAYS = "devicetree/tegra234-p3767-camera-p3768-imx219-C.dtbo"
    
    # === Kernel 參數 ===
    # 啟用 nvidia-drm 的 KMS（Kernel Mode Setting）和 fbdev 支援
    KERNEL_ARGS:append = " nvidia-drm.modeset=1 nvidia-drm.fbdev=1"
    
    # === 除錯選項 ===
    EXTRA_IMAGE_FEATURES ?= "debug-tweaks"
```

#### 關鍵配置說明

**1. systemd 啟用**
```yaml
DISTRO_FEATURES:append = " systemd pam"
VIRTUAL-RUNTIME_init_manager = "systemd"
```
- 使用 systemd 作為 init system（取代傳統 SysVinit）
- 啟用 PAM (Pluggable Authentication Modules) 支援

**2. Device Tree 配置**
```yaml
UBOOT_EXTLINUX_FDT = "devicetree/tegra234-p3768-0000+p3767-0004-nv-super.dtb"
UBOOT_EXTLINUX_FDTOVERLAYS = "devicetree/tegra234-p3767-camera-p3768-imx219-C.dtbo"
```
- **FDT**: 主裝置樹，定義板子的硬體配置
- **FDTOVERLAYS**: Device Tree Overlay，動態載入 IMX219 相機支援（CAM1 位置）

**3. NVIDIA DRM 啟用**
```yaml
KERNEL_ARGS:append = " nvidia-drm.modeset=1 nvidia-drm.fbdev=1"
```
- `nvidia-drm.modeset=1`: 啟用 KMS，允許直接控制顯示輸出
- `nvidia-drm.fbdev=1`: 啟用 framebuffer device 支援

**4. 移除不必要的套件**

我們**不需要**以下套件（已從 IMAGE_INSTALL 移除）：
- `weston` - Wayland compositor（過於複雜）
- `weston-init` - Weston 啟動腳本
- `weston-examples` - Weston 範例程式
- `weston-kiosk-init` - 自訂 Weston kiosk service
- `packagegroup-core-x11` - X11 相關套件群組

**原因**: 我們使用 `nvdrmvideosink` 直接輸出到硬體，不需要 compositor。

---

## Camera Kiosk 實作

### Layer 結構

在 `meta-my-project` layer 中，我們創建了 `camera-kiosk` 套件：

```
meta-my-project/
├── conf/
│   └── layer.conf
└── recipes-apps/
    └── camera-kiosk/
        ├── camera-kiosk.bb              # Recipe 定義
        └── files/
            ├── camera-kiosk.service     # systemd service 檔案
            ├── camera-kiosk.sh          # 啟動腳本
            └── camera-kiosk-debug.sh    # 除錯腳本
```

### 1. camera-kiosk.bb - Recipe 定義

```bitbake
SUMMARY = "IMX219 Camera Kiosk Mode - Direct DisplayPort Output"
DESCRIPTION = "Systemd service to automatically display IMX219 camera via direct hardware output on boot"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# 原始檔案
SRC_URI = " \
    file://camera-kiosk.service \
    file://camera-kiosk.sh \
    file://camera-kiosk-debug.sh \
"

S = "${WORKDIR}"

# 繼承 systemd 類別（提供 systemd 相關功能）
inherit systemd

# 定義 systemd service
SYSTEMD_SERVICE:${PN} = "camera-kiosk.service"
SYSTEMD_AUTO_ENABLE = "enable"

# 安裝步驟
do_install() {
    # 安裝 systemd service 檔案
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/camera-kiosk.service ${D}${systemd_system_unitdir}/
    
    # 安裝執行腳本
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/camera-kiosk.sh ${D}${bindir}/
    install -m 0755 ${WORKDIR}/camera-kiosk-debug.sh ${D}${bindir}/
}

# 定義套件包含的檔案
FILES:${PN} = " \
    ${systemd_system_unitdir}/camera-kiosk.service \
    ${bindir}/camera-kiosk.sh \
    ${bindir}/camera-kiosk-debug.sh \
"

# 執行時期依賴
RDEPENDS:${PN} = "gstreamer1.0-plugins-tegra gstreamer1.0-plugins-nvvideosinks bash"
```

#### Recipe 關鍵概念解說

**變數說明：**
- `${PN}`: Package Name（套件名稱）
- `${D}`: Destination directory（安裝目標目錄）
- `${WORKDIR}`: 工作目錄（解壓縮的原始檔案位置）
- `${bindir}`: Binary directory（通常是 `/usr/bin`）
- `${systemd_system_unitdir}`: systemd service 檔案目錄（`/lib/systemd/system`）

**inherit systemd:**
- 自動處理 systemd service 的安裝和啟用
- 提供 `${systemd_system_unitdir}` 等變數

**RDEPENDS:**
- 定義執行時期依賴的套件
- BitBake 會自動確保這些套件也被安裝

### 2. camera-kiosk.service - systemd Service 定義

```ini
[Unit]
Description=IMX219 Camera Kiosk Mode - Direct DisplayPort Output
After=nvargus-daemon.service systemd-udev-settle.service
Requires=nvargus-daemon.service

[Service]
Type=simple
ExecStartPre=/bin/sleep 3
ExecStart=/usr/bin/camera-kiosk.sh
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
```

#### Service 配置解說

**[Unit] 區段：**
- `After=`: 在指定的 services 之後啟動
  - `nvargus-daemon.service`: NVIDIA Argus camera daemon（必須先啟動）
  - `systemd-udev-settle.service`: 等待 udev 裝置初始化完成
- `Requires=`: 強依賴關係（如果 nvargus-daemon 失敗，此 service 也會失敗）

**[Service] 區段：**
- `Type=simple`: 最簡單的 service 類型（前景執行）
- `ExecStartPre=/bin/sleep 3`: 啟動前等待 3 秒（讓硬體穩定）
- `Restart=always`: 如果程式崩潰，自動重啟
- `RestartSec=3`: 重啟前等待 3 秒
- `User=root`: 以 root 身份執行（需要存取硬體裝置）

**[Install] 區段：**
- `WantedBy=multi-user.target`: 在多用戶模式下自動啟動

### 3. camera-kiosk.sh - 啟動腳本

```bash
#!/bin/bash
# IMX219 Camera Kiosk Mode
# Direct hardware output to DisplayPort without compositor

# Wait for DRM device to be ready
for i in {1..10}; do
    if [ -e /dev/dri/card0 ]; then
        echo "DRM device ready"
        break
    fi
    echo "Waiting for DRM device... ($i/10)"
    sleep 1
done

# Wait for camera to be ready
for i in {1..10}; do
    if [ -c /dev/video0 ]; then
        echo "Camera device ready"
        break
    fi
    echo "Waiting for camera... ($i/10)"
    sleep 1
done

# Configuration
SENSOR_ID=0
WIDTH=1920
HEIGHT=1080
FRAMERATE=30

echo "======================================"
echo "Starting Camera Kiosk Mode"
echo "======================================"
echo "Resolution: ${WIDTH}x${HEIGHT} @ ${FRAMERATE}fps"
echo "Output: Direct to DisplayPort via nvdrmvideosink"
echo ""

# Launch fullscreen camera display
# Direct hardware output using nvdrmvideosink (no compositor needed)
exec gst-launch-1.0 -v \
    nvarguscamerasrc sensor-id=$SENSOR_ID ! \
    "video/x-raw(memory:NVMM),width=$WIDTH,height=$HEIGHT,framerate=$FRAMERATE/1" ! \
    nvvidconv ! \
    "video/x-raw(memory:NVMM)" ! \
    nvdrmvideosink
```

#### 腳本設計重點

**1. 裝置就緒檢查**
```bash
for i in {1..10}; do
    if [ -e /dev/dri/card0 ]; then
        echo "DRM device ready"
        break
    fi
    sleep 1
done
```
- 等待 DRM 裝置就緒（最多 10 秒）
- `/dev/dri/card0`: NVIDIA DRM 裝置節點

**2. 相機裝置檢查**
```bash
if [ -c /dev/video0 ]; then
    echo "Camera device ready"
fi
```
- 確認 V4L2 相機裝置存在
- `-c`: 檢查是否為字元裝置（character device）

**3. 使用 exec 啟動 GStreamer**
```bash
exec gst-launch-1.0 ...
```
- `exec`: 取代當前 shell 程序（不產生子程序）
- 好處：當 GStreamer 結束時，systemd 會知道並可以重啟 service

---

## GStreamer 管線設計

### 最終管線（直接硬體輸出）

```bash
gst-launch-1.0 -v \
    nvarguscamerasrc sensor-id=0 ! \
    "video/x-raw(memory:NVMM),width=1920,height=1080,framerate=30/1" ! \
    nvvidconv ! \
    "video/x-raw(memory:NVMM)" ! \
    nvdrmvideosink
```

### 管線元件詳解

#### 1. nvarguscamerasrc
```
nvarguscamerasrc sensor-id=0
```
- **功能**: NVIDIA Argus Camera Source（專為 NVIDIA 相機設計）
- **sensor-id=0**: 使用 sensor 0（IMX219 on CAM1）
- **輸出**: 原始感光器資料，經過 ISP (Image Signal Processor) 處理

#### 2. Caps Filter（第一個）
```
"video/x-raw(memory:NVMM),width=1920,height=1080,framerate=30/1"
```
- **功能**: 定義視訊格式和參數
- **memory:NVMM**: 使用 NVIDIA Memory Management（零拷貝，高效能）
- **width/height**: 解析度 1920x1080
- **framerate=30/1**: 30 FPS

#### 3. nvvidconv
```
nvvidconv
```
- **功能**: NVIDIA Video Converter（格式轉換、縮放、色彩空間轉換）
- **硬體加速**: 使用 NVIDIA GPU 的 Video Processing Engine
- **用途**: 確保格式相容於下游元件

#### 4. Caps Filter（第二個）
```
"video/x-raw(memory:NVMM)"
```
- **保持 NVMM 格式**: 避免不必要的記憶體拷貝
- **效能最佳化**: 全程使用 GPU 記憶體

#### 5. nvdrmvideosink
```
nvdrmvideosink
```
- **功能**: NVIDIA DRM Video Sink（直接輸出到 DRM/KMS）
- **不需要 compositor**: 繞過 Wayland/X11，直接控制硬體
- **自動偵測**: 自動找到 DisplayPort 輸出
- **全螢幕**: 預設全螢幕顯示

### 為什麼不使用 Weston/Wayland？

**傳統方式（使用 Weston）：**
```
Camera → GStreamer → Wayland → Weston → DRM/KMS → Display
                        ↑
                  額外的 compositor
```

**直接輸出方式（我們的方案）：**
```
Camera → GStreamer → nvdrmvideosink → DRM/KMS → Display
                          ↑
                    直接控制硬體
```

**優點：**
1. **更低延遲**: 少一層軟體抽象
2. **更少資源**: 不需要執行 compositor
3. **更快開機**: 減少服務依賴
4. **更簡單**: 配置和除錯更容易
5. **更穩定**: 軟體層級更少，故障點更少

### 其他測試過的 Sink

我們測試了以下 sinks，但有不同的問題：

1. **waylandsink** ❌
   - 需要 Wayland compositor（Weston）
   - 增加複雜度和資源消耗

2. **nv3dsink** ❌
   - 狀態變更失敗
   - 可能需要特定的 X11 或 Wayland 環境

3. **nvoverlaysink** ❌
   - 套件中不存在此元件

4. **kmssink** ⚠️
   - 通用 KMS sink（非 NVIDIA 專用）
   - 需要手動指定 connector-id 和 plane-id
   - 不支援某些格式（如 NVMM）

5. **nvdrmvideosink** ✅
   - **最佳選擇**！
   - NVIDIA 專用，完整支援 Tegra 硬體
   - 自動偵測顯示輸出
   - 支援 NVMM 零拷貝

---

## 編譯與部署

### 編譯流程

#### 1. 準備環境

```bash
cd /home/andy/proj/tegra-demo-distro

# 確保所有 Git submodules 都已更新
git submodule update --init --recursive
```

#### 2. 清理並重新編譯

```bash
# 清理 camera-kiosk 套件的編譯狀態
kas shell project.yml -c "bitbake camera-kiosk -c cleansstate"

# 編譯完整映像檔
kas build project.yml

# 或使用 kas shell 進行更細緻的控制
kas shell project.yml -c "bitbake demo-image-egl"
```

#### 3. 編譯時間估計

- **首次編譯**: 2-4 小時（取決於 CPU 和網路速度）
- **增量編譯**: 10-30 分鐘（僅重新編譯變更的部分）

#### 4. 輸出檔案位置

```bash
cd build/tmp/deploy/images/p3768-0000-p3767-0004/

# 主要輸出檔案
ls -lh demo-image-egl-p3768-0000-p3767-0004.tegraflash.tar.gz
```

### 燒錄到 Jetson

#### 方法一：使用官方工具

```bash
# 解壓縮 tegraflash 套件
cd build/tmp/deploy/images/p3768-0000-p3767-0004/
tar -xzf demo-image-egl-p3768-0000-p3767-0004.tegraflash.tar.gz

# 將 Jetson 進入 Recovery Mode
# 1. 按住 Force Recovery 按鈕
# 2. 按下 Reset 按鈕
# 3. 放開 Reset 按鈕
# 4. 放開 Force Recovery 按鈕

# 確認 Jetson 已進入 Recovery Mode
lsusb | grep -i nvidia

# 燒錄
sudo ./initrd-flash
```

#### 方法二：使用 NVMe（如果已經有運作中的系統）

```bash
# 在開發機上，透過網路複製映像檔
scp demo-image-egl-*.wic.gz root@192.168.0.200:/tmp/

# 在 Jetson 上
ssh root@192.168.0.200
cd /tmp
gunzip demo-image-egl-*.wic.gz

# 燒錄到 NVMe（⚠️ 注意：這會清除所有資料！）
dd if=demo-image-egl-*.wic of=/dev/nvme0n1 bs=4M status=progress
sync
reboot
```

### 驗證部署

#### 1. 開機後檢查

```bash
# SSH 連線到 Jetson
ssh root@192.168.0.200

# 檢查 systemd services 狀態
systemctl status nvargus-daemon
systemctl status camera-kiosk

# 查看服務日誌
journalctl -u camera-kiosk -f
```

#### 2. 預期輸出

正常情況下，相機畫面應該會自動顯示在 DisplayPort 顯示器上。

日誌輸出範例：
```
DRM device ready
Camera device ready
======================================
Starting Camera Kiosk Mode
======================================
Resolution: 1920x1080 @ 30fps
Output: Direct to DisplayPort via nvdrmvideosink

Setting pipeline to PAUSED ...
Pipeline is live and does not need PREROLL ...
Pipeline is PREROLLED ...
Setting pipeline to PLAYING ...
New clock: GstSystemClock
```

---

## 問題排除

### 常見問題與解決方案

#### 1. 相機裝置不存在 (`/dev/video0` 不存在)

**症狀：**
```bash
ls /dev/video*
# ls: cannot access '/dev/video*': No such file or directory
```

**診斷：**
```bash
# 檢查 I2C 是否偵測到相機
i2cdetect -y 7

# 應該在 0x10 看到 "10"
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:          -- -- -- -- -- -- -- -- -- -- -- -- --
10: 10 -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
```

**可能原因：**
- 相機排線未正確連接
- Device Tree Overlay 未正確載入
- nvargus-daemon 未啟動

**解決方案：**
```bash
# 檢查 Device Tree Overlay 是否載入
cat /boot/extlinux/extlinux.conf | grep OVERLAY

# 應該看到
# FDTOVERLAYS devicetree/tegra234-p3767-camera-p3768-imx219-C.dtbo

# 重啟 nvargus-daemon
systemctl restart nvargus-daemon
systemctl status nvargus-daemon
```

#### 2. DisplayPort 無輸出

**診斷：**
```bash
# 檢查 DRM 裝置
ls -la /dev/dri/

# 檢查顯示器連接狀態
modetest -M tegra-udrm -c

# 應該看到類似輸出
# Connectors:
# id    encoder status      name        size (mm)       modes   encoders
# 63    62      connected   DP-1        600x340         10      62
```

**可能原因：**
- DisplayPort 線材未連接
- 顯示器未開啟
- nvidia-drm 模組未正確載入

**解決方案：**
```bash
# 檢查 nvidia-drm 模組
lsmod | grep nvidia_drm

# 如果未載入，手動載入
modprobe nvidia-drm modeset=1

# 檢查 kernel 參數
cat /proc/cmdline | grep nvidia-drm
# 應該看到 nvidia-drm.modeset=1
```

#### 3. GStreamer 管線錯誤

**常見錯誤訊息：**

**a) "no element 'nvdrmvideosink'"**
```bash
# 檢查套件是否安裝
opkg list-installed | grep gstreamer

# 應該看到
# gstreamer1.0-plugins-nvvideosinks - 1.22.x

# 檢查元件是否存在
gst-inspect-1.0 nvdrmvideosink
```

**b) "not-negotiated" 錯誤**
```
streaming stopped, reason not-negotiated (-4)
```

**原因**: Caps filter 不相容

**解決方案**: 使用 `-v` 參數查看詳細日誌
```bash
gst-launch-1.0 -v nvarguscamerasrc ! nvvidconv ! nvdrmvideosink
```

#### 4. Service 無法啟動

**診斷：**
```bash
# 查看 service 狀態
systemctl status camera-kiosk

# 查看詳細日誌
journalctl -u camera-kiosk -n 50 --no-pager

# 查看所有相關 services
systemctl list-units | grep -E "(camera|nvargus|weston)"
```

**常見問題：**

**a) 依賴的 service 未啟動**
```bash
# 檢查 nvargus-daemon
systemctl status nvargus-daemon

# 如果失敗，查看日誌
journalctl -u nvargus-daemon -n 50
```

**b) 腳本權限問題**
```bash
# 檢查腳本權限
ls -l /usr/bin/camera-kiosk.sh

# 應該是 -rwxr-xr-x
# 如果不是，修正權限
chmod +x /usr/bin/camera-kiosk.sh
```

### 除錯工具

#### camera-kiosk-debug.sh

我們提供了一個完整的除錯腳本：

```bash
# 執行除錯腳本
camera-kiosk-debug.sh

# 或儲存輸出到檔案
camera-kiosk-debug.sh > /tmp/debug-output.txt 2>&1
```

腳本會檢查：
1. Systemd services 狀態
2. DRM 裝置
3. 相機裝置
4. DisplayPort 連接
5. Kernel 訊息
6. 相關日誌

#### 手動測試 GStreamer 管線

```bash
# 基本測試（使用 fakesink）
gst-launch-1.0 nvarguscamerasrc sensor-id=0 num-buffers=100 ! fakesink

# 測試直接輸出
gst-launch-1.0 -v \
    nvarguscamerasrc sensor-id=0 ! \
    'video/x-raw(memory:NVMM), width=1920, height=1080, framerate=30/1' ! \
    nvvidconv ! \
    'video/x-raw(memory:NVMM)' ! \
    nvdrmvideosink

# 按 Ctrl+C 停止
```

---

## 進階配置

### 調整解析度和幀率

修改 `camera-kiosk.sh`:

```bash
# Configuration
SENSOR_ID=0
WIDTH=1280        # 改為 1280x720
HEIGHT=720
FRAMERATE=60      # 改為 60 FPS
```

**支援的解析度（IMX219）：**
- 3280x2464 @ 21 FPS (最大解析度)
- 1920x1080 @ 30 FPS
- 1640x1232 @ 30 FPS  
- 1280x720 @ 60 FPS
- 640x480 @ 90 FPS

### 多相機支援

如果有多個相機：

```bash
# CAM0 (sensor-id=0)
gst-launch-1.0 nvarguscamerasrc sensor-id=0 ! ...

# CAM1 (sensor-id=1)  
gst-launch-1.0 nvarguscamerasrc sensor-id=1 ! ...
```

可以使用 `nvcompositor` 或 `compositor` 元件合併多個相機畫面。

### 新增影像處理效果

在管線中加入 GStreamer 濾鏡：

```bash
gst-launch-1.0 -v \
    nvarguscamerasrc sensor-id=0 ! \
    "video/x-raw(memory:NVMM),width=1920,height=1080,framerate=30/1" ! \
    nvvidconv ! \
    "video/x-raw(memory:NVMM)" ! \
    # 加入濾鏡
    nvvidconv ! \
    "video/x-raw,format=I420" ! \
    videobalance brightness=0.1 contrast=1.2 ! \
    nvvidconv ! \
    "video/x-raw(memory:NVMM)" ! \
    nvdrmvideosink
```

---

## Yocto 進階概念

### Layer 優先級

在 `conf/layer.conf` 中定義：

```python
BBFILE_PRIORITY_meta-my-project = "10"
```

數字越大，優先級越高。用於解決多個 layers 提供相同 recipe 時的衝突。

### Recipe 版本和變體

```bash
camera-kiosk_1.0.bb        # 版本 1.0
camera-kiosk_1.1.bb        # 版本 1.1
camera-kiosk.bbappend      # 追加/覆寫現有 recipe
```

### BitBake 變數優先級

從低到高：
1. `=` - 直接賦值
2. `?=` - 如果未定義則賦值（預設值）
3. `??=` - 弱預設值
4. `:append` - 追加到變數後面
5. `:prepend` - 追加到變數前面
6. `:remove` - 移除特定值

範例：
```python
IMAGE_INSTALL = "base-package"          # 設定初始值
IMAGE_INSTALL:append = " my-package"    # 追加套件
IMAGE_INSTALL:remove = "unwanted-pkg"   # 移除套件
```

### Shared State (sstate) Cache

加速編譯的關鍵：

```bash
# 清理特定套件的 sstate
bitbake camera-kiosk -c cleansstate

# 清理所有 sstate（完全重新編譯）
rm -rf build/sstate-cache/*

# 使用遠端 sstate mirror
SSTATE_MIRRORS ?= "file://.* http://sstate.yoctoproject.org/PATH"
```

### 平行編譯優化

在 `local.conf` 中：

```python
# CPU 核心數
BB_NUMBER_THREADS = "8"

# Make 平行執行數
PARALLEL_MAKE = "-j 8"
```

---

## 學習資源

### 官方文件

1. **Yocto Project**
   - [Yocto Project Documentation](https://docs.yoctoproject.org/)
   - [BitBake User Manual](https://docs.yoctoproject.org/bitbake/)
   - [Yocto Project Mega Manual](https://docs.yoctoproject.org/singleindex.html)

2. **NVIDIA Tegra**
   - [meta-tegra GitHub](https://github.com/OE4T/meta-tegra)
   - [L4T Documentation](https://docs.nvidia.com/jetson/l4t/)
   - [Jetson Linux Developer Guide](https://docs.nvidia.com/jetson/archives/r36.4/DeveloperGuide/index.html)

3. **GStreamer**
   - [GStreamer Documentation](https://gstreamer.freedesktop.org/documentation/)
   - [NVIDIA Accelerated GStreamer](https://docs.nvidia.com/jetson/l4t-multimedia/group__l4t__mm__gstreamer__plugins.html)

4. **KAS**
   - [KAS Documentation](https://kas.readthedocs.io/)
   - [KAS GitHub](https://github.com/siemens/kas)

### 社群資源

- [Yocto Project Mailing List](https://lists.yoctoproject.org/)
- [NVIDIA Jetson Forums](https://forums.developer.nvidia.com/c/agx-autonomous-machines/jetson-embedded-systems/)
- [Stack Overflow - Yocto Tag](https://stackoverflow.com/questions/tagged/yocto)

### 範例專案

- [meta-tegra demos](https://github.com/OE4T/meta-tegra-community)
- [Yocto Project Quickstart](https://docs.yoctoproject.org/brief-yoctoprojectqs/index.html)

---

## 附錄 A：完整檔案清單

### project.yml
```yaml
# (見前文完整內容)
```

### camera-kiosk.bb
```bitbake
# (見前文完整內容)
```

### camera-kiosk.service
```ini
# (見前文完整內容)
```

### camera-kiosk.sh
```bash
# (見前文完整內容)
```

---

## 附錄 B：術語表

| 術語 | 說明 |
|------|------|
| **BitBake** | Yocto Project 的任務執行引擎 |
| **BSP** | Board Support Package（板級支援套件） |
| **DRM** | Direct Rendering Manager（Linux 顯示子系統） |
| **KMS** | Kernel Mode Setting（核心模式設定） |
| **Layer** | Yocto 的模組化單位，包含 recipes 和配置 |
| **NVMM** | NVIDIA Memory Management（零拷貝記憶體管理） |
| **Recipe** | 描述如何建構軟體包的 BitBake 檔案 (.bb) |
| **sstate** | Shared State Cache（共享狀態快取） |
| **systemd** | 現代 Linux init system |
| **Tegra** | NVIDIA 的嵌入式 SoC 平台 |

---

## 附錄 C：故障排除快速查詢

| 症狀 | 可能原因 | 快速檢查 |
|------|----------|----------|
| 相機裝置不存在 | 硬體連接 / DT overlay | `i2cdetect -y 7` |
| DisplayPort 無輸出 | DRM 未載入 / 顯示器問題 | `modetest -M tegra-udrm -c` |
| Service 無法啟動 | 依賴服務失敗 | `systemctl status nvargus-daemon` |
| GStreamer 錯誤 | 套件缺失 / caps 不相容 | `gst-inspect-1.0 nvdrmvideosink` |
| 編譯失敗 | 依賴問題 / 網路問題 | 查看 `build/tmp/log/` |

---

## 結語

透過這個專案，我們學習了：

1. ✅ **Yocto Project 基礎**：Layer、Recipe、BitBake 概念
2. ✅ **KAS 工具**：簡化專案配置和管理
3. ✅ **systemd 整合**：創建自訂 service
4. ✅ **GStreamer 管線**：硬體加速視訊處理
5. ✅ **DRM/KMS**：直接硬體輸出（繞過 compositor）
6. ✅ **NVIDIA Tegra 開發**：相機、顯示、驅動整合

這個方案展示了如何在嵌入式 Linux 系統上實現**真正的 kiosk mode**：
- 🚀 快速開機
- 💪 直接硬體控制
- 🎯 單一用途設計
- 🔧 易於維護和除錯

希望這份文件能幫助您理解整個系統的架構，並能夠根據需求進行客製化開發！

---

**版本**: 1.0  
**日期**: 2025-11-29  
**作者**: Andy  
**專案**: tegra-demo-distro
