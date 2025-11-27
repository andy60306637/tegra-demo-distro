# IMX219 Camera to DisplayPort Output Guide

這個指南說明如何在 Jetson Orin Nano 上使用 IMX219 攝影機並將影像輸出到 DisplayPort/HDMI。

## 硬體需求

1. **Jetson Orin Nano 4GB Developer Kit** (P3768-0000 + P3767-0004)
2. **IMX219 攝影機模組** - 連接到 **CAM1** (CSI-C) 接口
3. **DisplayPort 或 HDMI 顯示器**

## 軟體配置

系統已預先配置:
- ✅ IMX219 Device Tree Overlay (CAM1/CSI-C/I2C-7)
- ✅ nvidia-drm 驅動程式 (KMS + fbdev 支援)
- ✅ NVIDIA Argus 攝影機堆疊
- ✅ GStreamer NVIDIA 外掛程式
- ✅ V4L2 工具

## 測試腳本

系統包含三個測試腳本:

### 1. camera-display-test.sh
完整的系統測試腳本,檢查所有元件是否正常運作。

```bash
# 執行測試 (建議先執行此腳本)
sudo camera-display-test.sh
```

檢查項目:
- DisplayPort/HDMI 連接狀態
- nvidia-drm 模組狀態
- DRM 裝置 (/dev/dri/card0)
- V4L2 攝影機裝置 (/dev/video0)
- I2C 攝影機偵測 (bus 7, address 0x10)
- nvargus-daemon 狀態
- GStreamer 外掛程式

### 2. camera-preview.sh
即時預覽攝影機畫面到 DisplayPort/HDMI。

```bash
# 全高清 1080p 預覽
camera-preview.sh

# HD 720p 預覽
camera-preview.sh --width 1280 --height 720

# VGA 預覽
camera-preview.sh --width 640 --height 480

# 自訂解析度和幀率
camera-preview.sh --width 1920 --height 1080 --fps 60

# 顯示說明
camera-preview.sh --help
```

**按 Ctrl+C 停止預覽**

### 3. camera-record.sh
錄製影片到檔案。

```bash
# 錄製 1080p 影片
camera-record.sh video.mp4

# 錄製 720p 60fps 影片
camera-record.sh video.mp4 --width 1280 --height 720 --fps 60

# 錄製高位元率影片
camera-record.sh video.mp4 --bitrate 10000000

# 錄製 H.264 原始串流
camera-record.sh video.h264

# 顯示說明
camera-record.sh --help
```

**按 Ctrl+C 停止錄製**

## 使用步驟

### 首次使用

1. **連接硬體**:
   - 將 IMX219 攝影機連接到 **CAM1** 接口 (注意排線方向)
   - 連接 DisplayPort 或 HDMI 顯示器
   - 開機

2. **執行系統測試**:
   ```bash
   sudo camera-display-test.sh
   ```
   
   確認所有項目顯示 ✓:
   - DisplayPort is connected
   - nvidia-drm module loaded (modeset: Y)
   - /dev/dri/card0 exists
   - /dev/video0 exists
   - IMX219 detected at address 0x10
   - nvargus-daemon is running

3. **啟動即時預覽**:
   ```bash
   camera-preview.sh
   ```
   
   你應該會在 DisplayPort/HDMI 顯示器上看到攝影機畫面。

### 常見問題排除

#### 問題 1: 顯示器無信號

檢查 DisplayPort 連接:
```bash
cat /sys/class/drm/card0-DP-1/status
# 應顯示: connected
```

檢查 nvidia-drm 模組:
```bash
lsmod | grep nvidia_drm
cat /sys/module/nvidia_drm/parameters/modeset
# 應顯示: Y
```

重新載入模組:
```bash
sudo rmmod nvidia_drm
sudo modprobe nvidia_drm modeset=1 fbdev=1
```

#### 問題 2: 攝影機未偵測

檢查 I2C 連接:
```bash
sudo i2cdetect -y -r 7
# 應在 0x10 看到裝置
```

檢查 V4L2 裝置:
```bash
v4l2-ctl --list-devices
ls -la /dev/video*
```

檢查 Device Tree overlay:
```bash
cat /boot/extlinux/extlinux.conf | grep OVERLAYS
# 應包含: tegra234-p3767-camera-p3768-imx219-C.dtbo
```

重新啟動 argus daemon:
```bash
sudo systemctl restart nvargus-daemon
sudo systemctl status nvargus-daemon
```

#### 問題 3: 預覽畫面卡頓

降低解析度或幀率:
```bash
camera-preview.sh --width 1280 --height 720 --fps 30
```

檢查系統負載:
```bash
htop
```

#### 問題 4: GStreamer 錯誤

檢查 GStreamer 外掛程式:
```bash
gst-inspect-1.0 nvarguscamerasrc
gst-inspect-1.0 nvoverlaysink
```

測試簡單的管線:
```bash
gst-launch-1.0 nvarguscamerasrc num-buffers=100 ! fakesink
```

## GStreamer 管線說明

### 基本預覽管線
```bash
gst-launch-1.0 \
    nvarguscamerasrc sensor-id=0 ! \
    'video/x-raw(memory:NVMM),width=1920,height=1080,framerate=30/1' ! \
    nvoverlaysink
```

元件說明:
- **nvarguscamerasrc**: NVIDIA Argus 攝影機來源 (使用 ISP 處理)
- **video/x-raw(memory:NVMM)**: NVMM (NVIDIA Memory Management) 格式
- **nvoverlaysink**: 直接輸出到 framebuffer (不需要 X11/Wayland)

### 錄製管線
```bash
gst-launch-1.0 -e \
    nvarguscamerasrc sensor-id=0 ! \
    'video/x-raw(memory:NVMM),width=1920,height=1080,framerate=30/1' ! \
    nvv4l2h264enc bitrate=8000000 ! \
    h264parse ! \
    qtmux ! \
    filesink location=video.mp4
```

元件說明:
- **nvv4l2h264enc**: NVIDIA 硬體 H.264 編碼器
- **h264parse**: H.264 串流解析器
- **qtmux**: MP4 容器封裝器
- **filesink**: 寫入檔案

### 預覽 + 錄製管線 (分岔)
```bash
gst-launch-1.0 -e \
    nvarguscamerasrc sensor-id=0 ! \
    'video/x-raw(memory:NVMM),width=1920,height=1080,framerate=30/1' ! \
    tee name=t \
    t. ! queue ! nvoverlaysink \
    t. ! queue ! nvv4l2h264enc bitrate=8000000 ! h264parse ! qtmux ! filesink location=video.mp4
```

## 支援的解析度

IMX219 支援以下解析度:

| 解析度 | 最大幀率 | 說明 |
|--------|---------|------|
| 3280x2464 | 21 fps | 最大解析度 (8MP) |
| 1920x1080 | 30 fps | Full HD (建議) |
| 1640x1232 | 41 fps | 4:3 格式 |
| 1280x720 | 60 fps | HD (高幀率) |
| 640x480 | 90 fps | VGA (極高幀率) |

## 進階用法

### 調整攝影機參數

```bash
# 手動曝光
gst-launch-1.0 \
    nvarguscamerasrc sensor-id=0 aelock=true exposuretimerange="33333333 33333333" ! \
    'video/x-raw(memory:NVMM),width=1920,height=1080,framerate=30/1' ! \
    nvoverlaysink

# 調整白平衡
gst-launch-1.0 \
    nvarguscamerasrc sensor-id=0 wbmode=1 ! \
    'video/x-raw(memory:NVMM),width=1920,height=1080,framerate=30/1' ! \
    nvoverlaysink

# 調整增益
gst-launch-1.0 \
    nvarguscamerasrc sensor-id=0 gainrange="1 16" ! \
    'video/x-raw(memory:NVMM),width=1920,height=1080,framerate=30/1' ! \
    nvoverlaysink
```

### 多攝影機同時使用

如果有多個攝影機:
```bash
# 攝影機 0
camera-preview.sh --sensor 0

# 攝影機 1
camera-preview.sh --sensor 1
```

### 使用 V4L2 直接存取

```bash
# 列出支援的格式
v4l2-ctl --list-formats-ext

# 擷取一張照片
v4l2-ctl --set-fmt-video=width=1920,height=1080,pixelformat=RG10 --stream-mmap --stream-count=1 --stream-to=image.raw

# 串流預覽 (不透過 Argus)
gst-launch-1.0 v4l2src device=/dev/video0 ! 'video/x-raw,width=1920,height=1080' ! videoconvert ! autovideosink
```

## 效能調校

### CPU 模式設定
```bash
# 最大效能模式
sudo nvpmodel -m 0
sudo jetson_clocks

# 檢查目前模式
sudo nvpmodel -q
```

### 監控效能
```bash
# 即時監控
sudo tegrastats

# 或使用 jtop (需要安裝)
sudo jtop
```

## 參考資料

- [NVIDIA Argus Camera API](https://docs.nvidia.com/jetson/l4t-multimedia/group__LibargusAPI.html)
- [GStreamer NVIDIA Plugins](https://docs.nvidia.com/jetson/l4t-multimedia/mmapi_gst_plugins.html)
- [IMX219 Sensor Datasheet](https://www.sony-semicon.com/en/products/is/industry/img_sensor.html)

## 授權

MIT License
