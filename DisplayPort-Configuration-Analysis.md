# Jetson Orin Nano DisplayPort 配置分析報告

**日期**: 2025-11-24  
**平台**: Jetson Orin Nano 4GB (P3767-0004) + P3768 載板  
**L4T 版本**: R36.4.4

---

## 1. 硬體 DisplayPort 支援概況

### 1.1 Device Tree 配置

在主 DTB (`tegra234-p3768-0000+p3767-0004-nv-super.dtb`) 中，DisplayPort 已完整配置:

```dts
display@13800000 {
    compatible = "nvidia,tegra234-display";
    power-domains = <0x03 0x03>;
    nvidia,num-dpaux-instance = <0x01>;  // 1 個 DisplayPort AUX 實例
    
    reg-names = "nvdisplay", "dpaux0", "hdacodec", "mipical";
    reg = <0x00 0x13800000 0x00 0xeffff    // nvdisplay 主控制器
           0x00 0x155c0000 0x00 0xffff     // dpaux0 (DP AUX channel)
           0x00 0x242c000 0x00 0x1000      // hdacodec (DP 音訊)
           0x00 0x3990000 0x00 0x10000>;   // mipical
    
    interrupt-names = "nvdisplay", "dpaux0", "hdacodec";
    interrupts = <0x00 0x1a0 0x04   // nvdisplay IRQ
                  0x00 0x1a3 0x04   // dpaux0 IRQ
                  0x00 0x3d 0x04>;  // hdacodec IRQ
    
    // I2C 通道用於 EDID 讀取與 DP++ 轉接器偵測
    dp_aux_ch0_i2c = "/bus@0/i2c@31b0000";
    dp_aux_ch1_i2c = "/bus@0/i2c@3190000";
    dp_aux_ch2_i2c = "/bus@0/i2c@31c0000";
    dp_aux_ch3_i2c = "/bus@0/i2c@31e0000";
    
    // 時鐘配置
    clock-names = "..., dpaux0_clk, ..., sor0_clk, sor1_clk, 
                   dp_link_ref_clk, pre_sor0_clk, pre_sor1_clk, ...";
    
    reset-names = "nvdisplay_reset", "dpaux0_reset", ...;
    
    status = "okay";  // DisplayPort 已啟用
    hdcp_enabled;      // HDCP 保護已啟用
};
```

**關鍵發現**:
- ✅ DisplayPort AUX channel (dpaux0) 已配置於位址 0x155c0000
- ✅ 支援 HDMI 音訊輸出 (HDA codec)
- ✅ 4 個 I2C 通道可用於顯示器偵測
- ✅ SOR0/SOR1 (Serial Output Resource) 已啟用
- ✅ HDCP 已啟用 (支援受保護內容播放)

---

## 2. Kernel 模組配置

### 2.1 Display 相關核心模組

根據 `nvidia-kernel-oot.inc` 定義，顯示驅動已打包在 `nvidia-kernel-oot-display`:

```bash
TEGRA_OOT_DISPLAY_DRIVERS = "
    nv-kernel-module-nvidia              # NVIDIA GPU 驅動主模組
    nv-kernel-module-nvidia-drm          # DRM (Direct Rendering Manager) 接口
    nv-kernel-module-nvidia-modeset      # Mode setting 支援
    nv-kernel-module-tegra-dce           # Display Controller Engine
    nv-kernel-module-tegra-drm           # Tegra DRM 驅動
"
```

### 2.2 DRM 模組載入配置

`nvidia-drm-loadconf` 套件提供自動載入機制:

**檔案**: `/etc/modprobe.d/nvidia-drm.conf`
```bash
options nvidia-drm modeset=1 fbdev=1
```

**檔案**: `/etc/modules-load.d/nvidia-drm.conf`
```bash
nvidia-drm
```

**參數說明**:
- `modeset=1`: 啟用 kernel mode setting (KMS)，允許內核管理顯示模式
- `fbdev=1`: 啟用 fbdev 模擬層，提供 `/dev/fb0` framebuffer 裝置

### 2.3 已安裝套件 (從 local.conf)

```bash
IMAGE_INSTALL:append = "
    kernel-module-nvidia-drm      # DRM 核心模組
    nvidia-drm-loadconf           # 自動載入配置
    libdrm                        # DRM 使用者空間函式庫
"
```

---

## 3. 運行時驗證方法

### 3.1 檢查 DRM 裝置節點

當系統啟動且 DisplayPort 正常工作時，應存在以下裝置節點:

```bash
# DRM 主裝置
ls -l /dev/dri/
# 預期輸出:
# card0      -> GPU 裝置 (用於 OpenGL/Vulkan)
# renderD128 -> 無頭渲染節點

# Framebuffer 裝置 (若 fbdev=1)
ls -l /dev/fb0
```

### 3.2 檢查核心模組載入狀態

```bash
# 檢查 nvidia-drm 模組是否已載入
lsmod | grep nvidia
# 預期輸出應包含:
# nvidia_drm
# nvidia_modeset
# nvidia
# drm
# drm_kms_helper

# 檢查模組參數
cat /sys/module/nvidia_drm/parameters/modeset
# 預期輸出: Y (表示已啟用)

cat /sys/module/nvidia_drm/parameters/fbdev
# 預期輸出: Y
```

### 3.3 檢查 DRM 裝置資訊

```bash
# 使用 drmModeGetResources 查詢顯示資源
cat /sys/class/drm/card0/card0-DP-1/status
# 預期輸出:
# connected    (顯示器已連接)
# disconnected (無顯示器)

# 檢查 EDID 資訊
cat /sys/class/drm/card0/card0-DP-1/edid | hexdump -C | head -20

# 檢查支援的顯示模式
cat /sys/class/drm/card0/card0-DP-1/modes
# 範例輸出:
# 1920x1080
# 1680x1050
# 1280x1024
```

### 3.4 檢查 DisplayPort 硬體狀態

```bash
# 檢查 nvdisplay 驅動狀態
dmesg | grep -i "nvdisplay\|dpaux\|drm"
# 關鍵訊息:
# [drm] Initialized nvidia-drm 0.0.0 xxxxx for 13800000.display on minor 0
# tegra-dpaux 155c0000.dpaux: dpaux registered

# 檢查 I2C 通道 (用於 EDID 讀取)
i2cdetect -l | grep dp
# 預期輸出:
# i2c-X  i2c         nvidia-dp-aux-31b0000   I2C adapter
```

### 3.5 使用 DRM 工具測試

```bash
# 安裝 drm 測試工具 (若系統未包含)
# IMAGE_INSTALL:append = " libdrm-tests"

# 列出所有 DRM 資源 (connector, encoder, crtc)
modetest -M nvidia-drm

# 測試顯示模式設定
modetest -M nvidia-drm -s <connector_id>@<crtc_id>:<mode>
# 範例: modetest -M nvidia-drm -s 85@81:1920x1080

# 測試顯示圖案
modetest -M nvidia-drm -s <connector_id>@<crtc_id>:<mode> -P plane_id@crtc_id:640x480
```

---

## 4. 常見問題排查

### 4.1 /dev/dri/card0 不存在

**可能原因**:
1. nvidia-drm 模組未載入
2. 模組載入失敗 (相依性問題)
3. Device Tree 中 display 節點被停用

**排查步驟**:
```bash
# 檢查模組載入錯誤
journalctl -k | grep -i "nvidia\|drm\|display"

# 手動載入模組
modprobe nvidia
modprobe nvidia-modeset
modprobe nvidia-drm modeset=1 fbdev=1

# 檢查相依模組
lsmod | grep drm
# 必須先有: drm, drm_kms_helper
```

### 4.2 顯示器連接但無訊號

**可能原因**:
1. EDID 讀取失敗
2. DisplayPort 線纜問題
3. 顯示模式不支援

**排查步驟**:
```bash
# 檢查連接狀態
cat /sys/class/drm/card0-DP-1/status

# 強制偵測
echo detect > /sys/class/drm/card0-DP-1/status

# 檢查 dmesg 錯誤訊息
dmesg | grep -i "dp\|edid\|mode"

# 嘗試設定特定模式
modetest -M nvidia-drm -s <connector>@<crtc>:1024x768
```

### 4.3 /dev/fb0 不存在

**可能原因**:
- fbdev 參數未啟用

**解決方法**:
```bash
# 檢查 fbdev 參數
cat /sys/module/nvidia_drm/parameters/fbdev

# 若為 N，重新載入模組
rmmod nvidia-drm
modprobe nvidia-drm modeset=1 fbdev=1

# 確認 framebuffer 裝置
ls -l /dev/fb*
cat /sys/class/graphics/fb0/name
# 預期: nvdrmfb
```

### 4.4 DRM 權限問題

某些應用程式需要存取 `/dev/dri/card0`，確保使用者在正確的群組:

```bash
# 檢查裝置權限
ls -l /dev/dri/card0
# crw-rw----+ 1 root video 226, 0 ...

# 將使用者加入 video 群組
usermod -aG video <username>

# 或使用 udev 規則修改權限
# /etc/udev/rules.d/99-drm.rules
KERNEL=="card[0-9]*", SUBSYSTEM=="drm", MODE="0666"
```

---

## 5. EGL/OpenGL 整合

### 5.1 EGL 裝置選擇

當使用 EGL 進行 OpenGL 渲染時，系統會使用 DRM 裝置:

```c
// 應用程式範例
EGLDisplay display = eglGetDisplay((EGLNativeDisplayType)gbm_device);
// 或使用 EGL_DEFAULT_DISPLAY
```

### 5.2 GBM (Generic Buffer Manager)

若需要 wayland/weston 支援，需要 GBM:

```bash
IMAGE_INSTALL:append = " mesa-megadriver"  # 包含 GBM
```

### 5.3 測試 OpenGL via DRM

```bash
# 使用 es2gears 測試 (需安裝 mesa-demos)
es2gears_drm

# 或使用 glmark2
glmark2-drm
```

---

## 6. Weston/Wayland 支援

若要啟用圖形化桌面環境:

```bash
IMAGE_INSTALL:append = " 
    weston 
    weston-init 
    weston-examples
"

# 啟動 weston
weston --tty=1 --backend=drm-backend.so
```

---

## 7. 配置摘要

### 7.1 目前 local.conf 配置狀態

```bash
MACHINE = "p3768-0000-p3767-0004"

IMAGE_INSTALL:append = " 
    kernel-module-nvidia-drm     # ✅ 已配置
    nvidia-drm-loadconf          # ✅ 已配置
    libdrm                       # ✅ 已配置
"
```

### 7.2 自動載入機制

- ✅ `/etc/modprobe.d/nvidia-drm.conf`: modeset=1, fbdev=1
- ✅ `/etc/modules-load.d/nvidia-drm.conf`: 系統啟動時自動載入
- ✅ systemd-modules-load.service: 執行模組載入

### 7.3 DTB/DTBO 配置

- ✅ 主 DTB: `tegra234-p3768-0000+p3767-0004-nv-super.dtb`
- ✅ DisplayPort 已在 DTB 中啟用 (status = "okay")
- ✅ 無需額外 DTBO overlay

---

## 8. 執行計畫

### 8.1 編譯映像檔

```bash
cd /home/andy/proj/tegra-demo-distro
bitbake demo-image-egl
```

### 8.2 系統啟動後驗證

1. **檢查裝置節點**:
   ```bash
   ls -l /dev/dri/card0
   ls -l /dev/fb0
   ```

2. **檢查模組載入**:
   ```bash
   lsmod | grep nvidia
   cat /sys/module/nvidia_drm/parameters/{modeset,fbdev}
   ```

3. **檢查顯示器連接**:
   ```bash
   cat /sys/class/drm/card0-DP-1/status
   cat /sys/class/drm/card0-DP-1/modes
   ```

4. **測試 DRM 功能**:
   ```bash
   modetest -M nvidia-drm
   ```

5. **測試 OpenGL**:
   ```bash
   glxinfo | grep "direct rendering"  # 若有 X11
   # 或直接使用 demo-image-egl 內建的測試應用
   ```

### 8.3 預期結果

- `/dev/dri/card0`: 存在，權限為 `crw-rw----+ root:video`
- `/dev/fb0`: 存在 (若 fbdev=1)
- `nvidia-drm` 模組: 已載入，modeset=Y, fbdev=Y
- DisplayPort 狀態: `connected` (當顯示器連接時)
- 可用模式: 至少包含顯示器原生解析度

---

## 9. 其他注意事項

### 9.1 多顯示器支援

Orin Nano 支援:
- 1x DisplayPort (DP++)
- 若透過 USB-C (P3768-0000-P3767-0004 上可能需要轉接器)

### 9.2 HDMI vs DisplayPort

- P3768 載板的實體接口通常是 **HDMI type A**
- 硬體內部使用 DisplayPort 協議
- 透過 **DP++ (DisplayPort dual-mode)** 實現 HDMI 相容性
- 驅動層面統一為 `card0-DP-1`

### 9.3 效能最佳化

```bash
# 檢查 GPU 頻率
cat /sys/kernel/debug/bpmp/debug/clk/gpcclk/rate

# 設定電源模式 (最大效能)
nvpmodel -m 0
jetson_clocks  # 鎖定最高時鐘
```

---

## 10. 參考文件

1. NVIDIA Jetson Linux Developer Guide (R36.4.4)
   - Chapter: Display Configuration
   - Section: DRM/KMS Driver

2. meta-tegra 文件:
   - `repos/meta-tegra/recipes-kernel/nvidia-drm-loadconf/`
   - `repos/meta-tegra/recipes-kernel/nvidia-kernel-oot/`

3. Kernel Documentation:
   - `Documentation/gpu/drm-kms.rst`
   - `Documentation/fb/framebuffer.rst`

4. Tegra234 TRM (Technical Reference Manual):
   - Chapter 37: Display Controller (NVDISPLAY)
   - Chapter 38: DisplayPort AUX (DPAUX)

---

**結論**:

您的系統已正確配置 DisplayPort 支援:
- ✅ Device Tree 已啟用 DisplayPort 硬體
- ✅ nvidia-drm 核心模組已包含在映像中
- ✅ 自動載入配置已設定 (modeset=1, fbdev=1)
- ✅ libdrm 使用者空間函式庫已安裝

編譯並燒錄新映像檔後，系統應能正常使用 DisplayPort/HDMI 輸出。
您可以透過 `/dev/dri/card0` 和 `/dev/fb0` 操作顯示裝置。

若需要進一步的圖形化環境 (如 Wayland/Weston 或 X11)，可額外安裝對應套件。
