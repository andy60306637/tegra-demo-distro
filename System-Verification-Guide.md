# Jetson Orin Nano 系統驗證指南

**目的**: 驗證 DisplayPort 和 IMX219 相機配置已正確載入到系統中  
**日期**: 2025-11-27  

---

## 1. DisplayPort (DP) 配置驗證

### 1.1 檢查 Device Tree 載入

#### 確認 DTB 和 DTBO 已載入

```bash
# 檢查 extlinux.conf
cat /boot/extlinux/extlinux.conf

# 應包含:
# FDT /boot/devicetree/tegra234-p3768-0000+p3767-0004-nv-super.dtb
# OVERLAYS /boot/devicetree/tegra234-p3767-camera-p3768-imx219-C.dtbo
```

#### 檢查 DisplayPort 節點是否存在

```bash
# 方法 1: 檢查 display 相關節點
ls -la /proc/device-tree/ | grep -i display

# 方法 2: 檢查 sor (Serial Output Resource - DP/HDMI 控制器)
ls -la /proc/device-tree/sor*
ls -la /proc/device-tree/host1x*/sor*

# 方法 3: 檢查 dcb (Display Controller B)
ls -la /proc/device-tree/display@*
```

#### 檢查 nvidia-drm 設定

```bash
# 檢查 drm 參數
cat /sys/module/nvidia_drm/parameters/modeset
# 應輸出: Y (表示 modeset 已啟用)

cat /sys/module/nvidia_drm/parameters/fbdev
# 應輸出: Y (表示 fbdev 已啟用)
```

### 1.2 檢查 Kernel 驅動載入

#### 檢查 DRM 裝置

```bash
# 檢查 DRM card
ls -la /dev/dri/
# 應顯示:
# card0      ← 主要 GPU 裝置
# renderD128 ← Render 節點

# 檢查 card0 詳細資訊
cat /sys/class/drm/card0/device/uevent
```

#### 檢查 Framebuffer 裝置

```bash
# 檢查 framebuffer 裝置
ls -la /dev/fb*
# 應顯示: /dev/fb0

# 檢查 fb0 資訊
cat /sys/class/graphics/fb0/name
# 應輸出: tegra_fb 或類似名稱

# 檢查解析度
cat /sys/class/graphics/fb0/modes
# 應顯示支援的解析度,例如: U:1920x1080p-60
```

#### 檢查 DisplayPort 連接狀態

```bash
# 檢查 DRM 連接器狀態
for connector in /sys/class/drm/card0-*/status; do
    echo "$connector: $(cat $connector)"
done

# 應顯示:
# /sys/class/drm/card0-DP-1/status: connected  ← DisplayPort 已連接 ✅
# /sys/class/drm/card0-HDMI-A-1/status: disconnected
```

#### 檢查顯示模式

```bash
# 檢查當前 DisplayPort 模式
cat /sys/class/drm/card0-DP-1/modes
# 應列出支援的解析度,例如:
# 1920x1080
# 1280x720
# ...

# 檢查當前啟用的模式
cat /sys/class/drm/card0-DP-1/enabled
# 應輸出: enabled
```

### 1.3 檢查 dmesg 日誌

```bash
# 檢查 nvidia-drm 初始化訊息
dmesg | grep -i "nvidia-drm"
# 預期輸出:
# [drm] [nvidia-drm] [GPU ID ...] Loading driver
# [drm] Initialized nvidia-drm 0.0.0 ...

# 檢查 modeset 啟用訊息
dmesg | grep -i modeset

# 檢查 DisplayPort 偵測訊息
dmesg | grep -iE "dp|displayport"
# 預期輸出:
# tegradc ... Connected to display
# DP: ... link training successful
```

### 1.4 測試 DisplayPort 輸出

#### 使用 fbset 檢查 framebuffer

```bash
# 安裝 fbset (如果尚未安裝)
# apt-get install fbset

fbset -fb /dev/fb0
# 應顯示當前 framebuffer 配置:
# mode "1920x1080-60"
#     geometry 1920 1080 1920 1080 32
#     ...
```

#### 測試 framebuffer 輸出

```bash
# 填充紅色到螢幕 (測試顯示輸出)
cat /dev/urandom > /dev/fb0

# 或使用 dd 填充特定顏色
# 紅色
dd if=/dev/zero of=/dev/fb0 bs=1920x1080x4 count=1 | tr '\0' '\xff'

# 清除螢幕 (填充黑色)
dd if=/dev/zero of=/dev/fb0 bs=1920x1080x4 count=1
```

#### 使用 DRM test 工具

```bash
# 如果系統有 modetest 工具
modetest -M nvidia-drm

# 應顯示:
# - Connectors (DP-1, HDMI-A-1)
# - Encoders
# - CRTCs
# - Framebuffers
```

---

## 2. IMX219 相機配置驗證

### 2.1 檢查 Device Tree 載入

#### 確認相機 DTBO 已載入

```bash
# 檢查 extlinux.conf
cat /boot/extlinux/extlinux.conf | grep OVERLAYS
# 應顯示: OVERLAYS /boot/devicetree/tegra234-p3767-camera-p3768-imx219-C.dtbo

# 檢查 DTBO 檔案存在
ls -lh /boot/devicetree/tegra234-p3767-camera-p3768-imx219-C.dtbo
```

#### 檢查相機節點

```bash
# 檢查 tegra-capture-vi (Video Input)
ls -la /proc/device-tree/tegra-capture-vi/

# 檢查 nvcsi (CSI interface)
ls -la /proc/device-tree/nvcsi*/

# 檢查 i2c@c250000 (I2C bus 7 - 相機 I2C)
ls -la /proc/device-tree/i2c@c250000/

# 檢查 IMX219 sensor 節點
ls -la /proc/device-tree/i2c@c250000/*imx219*/
# 或
find /proc/device-tree -name "*imx219*"
```

### 2.2 檢查 Kernel 驅動載入

#### 檢查相機驅動模組

```bash
# 檢查 IMX219 驅動是否載入
lsmod | grep imx219
# 應顯示: imx219 ...

# 檢查相機相關模組
lsmod | grep -E "imx219|tegra.*cam|nvcsi|vi"
# 應顯示:
# imx219
# tegra_vi5
# nvcsi
# nvhost_vi
```

#### 檢查 V4L2 裝置

```bash
# 列出所有 video 裝置
ls -la /dev/video*
# 應顯示: /dev/video0 (相機裝置)

# 檢查 video0 詳細資訊
v4l2-ctl --list-devices
# 應顯示:
# vi-output, imx219 7-0010 (platform:tegra-capture-vi):
#     /dev/video0

# 檢查支援的格式
v4l2-ctl -d /dev/video0 --list-formats-ext
# 應顯示 IMX219 支援的格式:
# [0]: 'RG10' (10-bit Bayer RGRG/GBGB)
#     Size: Discrete 3280x2464
#     Size: Discrete 1920x1080
#     Size: Discrete 1280x720
```

### 2.3 檢查 I2C 通訊

#### 確認 IMX219 在 I2C bus 上

```bash
# 掃描 I2C bus 7 (CAM1 使用 I2C 7)
i2cdetect -y -r 7
# 應在 0x10 位置顯示 "10" (IMX219 預設位址)
#      0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
# 00:          -- -- -- -- -- -- -- -- -- -- -- -- --
# 10: 10 -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
# 20: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
# ...

# 讀取 IMX219 chip ID (寄存器 0x0000 應為 0x02, 0x0001 應為 0x19)
i2cget -y 7 0x10 0x00 w
# 應輸出: 0x1902 或 0x0219 (取決於字節序)
```

### 2.4 檢查 Argus Daemon

#### 確認 nvargus-daemon 運行

```bash
# 檢查 nvargus-daemon 進程
ps aux | grep nvargus
# 應顯示: /usr/sbin/nvargus-daemon

# 檢查 daemon 狀態 (systemd)
systemctl status nvargus-daemon
# 應顯示: active (running)

# 檢查 daemon 日誌
journalctl -u nvargus-daemon --no-pager | tail -50
# 應包含相機初始化訊息
```

### 2.5 檢查 dmesg 日誌

```bash
# 檢查 IMX219 驅動初始化
dmesg | grep -i imx219
# 預期輸出:
# imx219 7-0010: probing v4l2 sensor
# imx219 7-0010: detected IMX219 sensor

# 檢查 VI (Video Input) 初始化
dmesg | grep -i "tegra.*vi"
# 預期輸出:
# tegra-vi5 ... Probed camera sensor
# tegra-capture-vi ... subdev registered

# 檢查 CSI 初始化
dmesg | grep -i nvcsi
# 預期輸出:
# nvcsi ... CSI port C
```

### 2.6 測試相機擷取

#### 使用 v4l2-ctl 擷取測試

```bash
# 擷取一張測試圖片 (RAW format)
v4l2-ctl -d /dev/video0 \
    --set-fmt-video=width=1920,height=1080,pixelformat=RG10 \
    --stream-mmap \
    --stream-count=1 \
    --stream-to=test.raw

# 檢查檔案是否產生
ls -lh test.raw
# 應顯示約 4MB 的檔案 (1920x1080x2 bytes)
```

#### 使用 GStreamer 測試 (推薦)

```bash
# 測試 1080p @ 30fps 預覽
gst-launch-1.0 nvarguscamerasrc sensor-id=0 ! \
    'video/x-raw(memory:NVMM),width=1920,height=1080,framerate=30/1' ! \
    nvoverlaysink

# 如果看到影像,表示相機工作正常 ✅

# 測試並儲存影片
gst-launch-1.0 nvarguscamerasrc sensor-id=0 num-buffers=300 ! \
    'video/x-raw(memory:NVMM),width=1920,height=1080,framerate=30/1' ! \
    nvv4l2h264enc ! h264parse ! qtmux ! filesink location=test.mp4

# 檢查影片檔案
ls -lh test.mp4
```

---

## 3. 完整驗證腳本

### 自動化驗證腳本

建立檔案: `verify-system-config.sh`

```bash
#!/bin/bash

echo "======================================"
echo "Jetson Orin Nano 系統配置驗證"
echo "======================================"
echo ""

# 顏色定義
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_pass() {
    echo -e "${GREEN}[✓]${NC} $1"
}

check_fail() {
    echo -e "${RED}[✗]${NC} $1"
}

check_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

echo "1. 檢查 extlinux.conf 配置"
echo "-----------------------------------"
if grep -q "FDT /boot/devicetree" /boot/extlinux/extlinux.conf; then
    check_pass "FDT 設定存在"
    grep "FDT" /boot/extlinux/extlinux.conf
else
    check_fail "FDT 設定缺失"
fi

if grep -q "OVERLAYS.*imx219" /boot/extlinux/extlinux.conf; then
    check_pass "IMX219 OVERLAYS 設定存在"
    grep "OVERLAYS" /boot/extlinux/extlinux.conf
else
    check_fail "IMX219 OVERLAYS 設定缺失"
fi
echo ""

echo "2. 檢查 DisplayPort 配置"
echo "-----------------------------------"
if [ -e /dev/dri/card0 ]; then
    check_pass "DRM 裝置存在 (/dev/dri/card0)"
else
    check_fail "DRM 裝置不存在"
fi

if [ -e /dev/fb0 ]; then
    check_pass "Framebuffer 裝置存在 (/dev/fb0)"
else
    check_fail "Framebuffer 裝置不存在"
fi

if [ "$(cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null)" = "Y" ]; then
    check_pass "nvidia-drm modeset 已啟用"
else
    check_fail "nvidia-drm modeset 未啟用"
fi

if [ -d /sys/class/drm/card0-DP-1 ]; then
    dp_status=$(cat /sys/class/drm/card0-DP-1/status 2>/dev/null)
    if [ "$dp_status" = "connected" ]; then
        check_pass "DisplayPort 已連接"
    else
        check_warn "DisplayPort 狀態: $dp_status"
    fi
else
    check_warn "DisplayPort 連接器不存在 (可能使用 HDMI)"
fi
echo ""

echo "3. 檢查 IMX219 相機配置"
echo "-----------------------------------"
if [ -e /dev/video0 ]; then
    check_pass "相機裝置存在 (/dev/video0)"
else
    check_fail "相機裝置不存在"
fi

if lsmod | grep -q imx219; then
    check_pass "IMX219 驅動已載入"
else
    check_fail "IMX219 驅動未載入"
fi

if pgrep -x "nvargus-daemon" > /dev/null; then
    check_pass "nvargus-daemon 正在運行"
else
    check_fail "nvargus-daemon 未運行"
fi

if command -v i2cdetect &> /dev/null; then
    if i2cdetect -y -r 7 2>/dev/null | grep -q " 10 "; then
        check_pass "IMX219 在 I2C bus 7 位址 0x10 被偵測到"
    else
        check_fail "IMX219 在 I2C bus 7 未被偵測到"
    fi
else
    check_warn "i2c-tools 未安裝,跳過 I2C 檢查"
fi
echo ""

echo "4. 系統資訊"
echo "-----------------------------------"
echo "Kernel: $(uname -r)"
echo "L4T Version: $(cat /etc/nv_tegra_release 2>/dev/null || echo 'Unknown')"
if [ -e /sys/class/graphics/fb0/modes ]; then
    echo "顯示模式: $(cat /sys/class/graphics/fb0/modes | head -1)"
fi
echo ""

echo "======================================"
echo "驗證完成"
echo "======================================"
```

執行驗證:

```bash
chmod +x verify-system-config.sh
sudo ./verify-system-config.sh
```

---

## 4. 故障排除

### DisplayPort 無輸出

1. **檢查實體連接**:
   ```bash
   cat /sys/class/drm/card0-DP-1/status
   # 應為 "connected"
   ```

2. **檢查 modeset 參數**:
   ```bash
   cat /sys/module/nvidia_drm/parameters/modeset
   # 應為 "Y"
   ```

3. **檢查 dmesg 錯誤**:
   ```bash
   dmesg | grep -iE "error|fail" | grep -iE "drm|display"
   ```

### 相機無法偵測

1. **檢查硬體連接**:
   ```bash
   i2cdetect -y -r 7
   # 應在 0x10 看到裝置
   ```

2. **重新載入驅動**:
   ```bash
   sudo modprobe -r imx219
   sudo modprobe imx219
   ```

3. **重啟 argus daemon**:
   ```bash
   sudo systemctl restart nvargus-daemon
   ```

4. **檢查詳細日誌**:
   ```bash
   dmesg | grep -iE "imx219|vi5|nvcsi"
   ```

---

## 5. 預期結果總結

### ✅ DisplayPort 正常

- `/dev/dri/card0` 存在
- `/dev/fb0` 存在
- `nvidia-drm modeset=Y`
- DisplayPort status: `connected`
- dmesg 無顯示相關錯誤

### ✅ IMX219 相機正常

- `/dev/video0` 存在
- `lsmod | grep imx219` 有輸出
- `i2cdetect -y 7` 在 0x10 位置顯示裝置
- `nvargus-daemon` 運行中
- GStreamer 可以擷取影像

### ✅ 完整系統驗證

執行驗證腳本,所有項目顯示綠色 ✓:
```
[✓] FDT 設定存在
[✓] IMX219 OVERLAYS 設定存在
[✓] DRM 裝置存在
[✓] Framebuffer 裝置存在
[✓] nvidia-drm modeset 已啟用
[✓] DisplayPort 已連接
[✓] 相機裝置存在
[✓] IMX219 驅動已載入
[✓] nvargus-daemon 正在運行
[✓] IMX219 在 I2C bus 7 被偵測到
```

🎉 **系統配置完成並驗證成功!**
