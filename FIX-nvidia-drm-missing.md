# DisplayPort 問題臨時修復方案

**問題**: `nvidia-drm` 模組未自動載入,導致 DisplayPort 無法使用

---

## 🚨 臨時修復 (當前系統)

在重新編譯映像之前,您可以在當前系統上手動配置:

### 1. 建立 modprobe 配置

```bash
# 在 Jetson 上執行
cat > /etc/modprobe.d/nvidia-drm.conf << EOF
options nvidia-drm modeset=1 fbdev=1
EOF
```

### 2. 建立 modules-load 配置

```bash
# 在 Jetson 上執行
cat > /etc/modules-load.d/nvidia-drm.conf << EOF
nvidia-drm
EOF
```

### 3. 手動載入模組

```bash
# 方法 A: 使用 modprobe
modprobe nvidia-drm modeset=1 fbdev=1

# 方法 B: 如果上面失敗,先載入相依模組
modprobe drm
modprobe drm_kms_helper
modprobe nvidia
modprobe nvidia-drm modeset=1 fbdev=1
```

### 4. 驗證載入成功

```bash
# 檢查模組是否載入
lsmod | grep nvidia_drm

# 檢查 modeset 參數
cat /sys/module/nvidia_drm/parameters/modeset
# 應輸出: Y

cat /sys/module/nvidia_drm/parameters/fbdev
# 應輸出: Y

# 檢查 DisplayPort
ls -la /sys/class/drm/
# 應看到 card0-DP-1 或 card0-HDMI-A-1

# 檢查連接狀態
cat /sys/class/drm/card0-DP-1/status
# 應輸出: connected
```

### 5. 重啟系統

```bash
reboot
```

重啟後,nvidia-drm 應該會自動載入。

---

## ✅ 永久修復 (重新編譯)

已更新 `project.yml` 配置:

### 修改內容

```yaml
IMAGE_INSTALL:append = " \
    tegra-argus-daemon \
    tegra-mmapi \
    gstreamer1.0-plugins-tegra \
    cuda-libraries \
    libv4l \
    v4l-utils \
    tegra-firmware \
    nvidia-drm-loadconf \          # ← 新增: modprobe 配置
    kernel-module-nvidia-drm \     # ← 新增: nvidia-drm 模組
"

# Enable nvidia-drm with modeset for DisplayPort/HDMI support
KERNEL_ARGS:append = " nvidia-drm.modeset=1 nvidia-drm.fbdev=1"  # ← 新增: kernel 參數
```

### 重新編譯步驟

```bash
# 1. 清理 l4t-launcher-extlinux (因為要更新 KERNEL_ARGS)
cd build
source ../layers/oe-init-build-env .
bitbake -c cleansstate l4t-launcher-extlinux
cd ..

# 2. 重新編譯映像
kas build project.yml
```

### 編譯完成後驗證

```bash
# 檢查 extlinux.conf 是否包含 nvidia-drm 參數
cd build/tmp-glibc/deploy/images/p3768-0000-p3767-0004
mkdir -p /tmp/esp-mount
sudo mount -o loop tegra-espimage-*.esp /tmp/esp-mount
cat /tmp/esp-mount/boot/extlinux/extlinux.conf

# 應在 APPEND 行看到:
# APPEND ${cbootargs} ... nvidia-drm.modeset=1 nvidia-drm.fbdev=1

sudo umount /tmp/esp-mount
```

### 重新燒錄後驗證

系統啟動後:

```bash
# 檢查 modprobe 配置
cat /etc/modprobe.d/nvidia-drm.conf
# 應輸出: options nvidia-drm modeset=1 fbdev=1

# 檢查 modules-load 配置
cat /etc/modules-load.d/nvidia-drm.conf
# 應輸出: nvidia-drm

# 檢查模組已載入
lsmod | grep nvidia_drm
cat /sys/module/nvidia_drm/parameters/modeset  # 應為 Y
cat /sys/class/drm/card0-DP-1/status           # 應為 connected
```

---

## 🔍 為什麼需要這些配置?

### 1. `nvidia-drm-loadconf` 套件

- 安裝 `/etc/modprobe.d/nvidia-drm.conf` - 設定 modeset=1 和 fbdev=1
- 安裝 `/etc/modules-load.d/nvidia-drm.conf` - 開機時自動載入 nvidia-drm
- 來自 meta-tegra 的官方套件

### 2. `kernel-module-nvidia-drm`

- 確保 nvidia-drm.ko 模組包含在 rootfs 中
- 通常由 kernel recipe 自動提供,但明確指定更保險

### 3. `KERNEL_ARGS:append`

- 在 kernel 命令列添加 `nvidia-drm.modeset=1 nvidia-drm.fbdev=1`
- 即使 modprobe 配置失效,kernel 參數仍會生效
- 雙重保障機制

### 配置層級

```
Kernel 命令列參數 (extlinux.conf)
    ↓
modprobe 配置 (/etc/modprobe.d/nvidia-drm.conf)
    ↓
modules-load 配置 (/etc/modules-load.d/nvidia-drm.conf)
    ↓
nvidia-drm 模組載入並啟用 modeset
    ↓
/sys/class/drm/card0-DP-1/ 出現
    ↓
DisplayPort 可用 ✅
```

---

## 📝 相關檔案

### 已修改
- `project.yml` - 添加 nvidia-drm-loadconf 和 kernel 參數

### 來自 meta-tegra
- `repos/meta-tegra/recipes-kernel/nvidia-drm-loadconf/nvidia-drm-loadconf_1.0.bb`
- `repos/meta-tegra/recipes-kernel/nvidia-drm-loadconf/nvidia-drm-loadconf/nvidia-drm-modprobe.conf`

### 系統中的檔案 (編譯後)
- `/etc/modprobe.d/nvidia-drm.conf`
- `/etc/modules-load.d/nvidia-drm.conf`
- `/boot/extlinux/extlinux.conf` (包含 nvidia-drm.modeset=1)

---

## ✅ 總結

**臨時方案**: 在當前系統手動建立配置檔並載入模組  
**永久方案**: 已更新 project.yml,重新編譯後自動配置  

重新編譯並燒錄後,DisplayPort 將正常工作! 🎉
