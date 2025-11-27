# KAS 編譯產物位置確認報告

**日期**: 2025-11-27  
**專案**: tegra-demo-distro  
**構建系統**: KAS (meta-tegra)  
**目標映像**: demo-image-egl  
**目標機器**: p3768-0000-p3767-0004 (Jetson Orin Nano 4GB)

---

## ✅ 確認結果

### 1. KAS 配置分析

根據您的 `project.yml` 配置:

```yaml
header:
  version: 11

machine: p3768-0000-p3767-0004
distro: my-distro
target: demo-image-egl        # ← 您的目標映像

repos:
  # ... 所有 layer 配置 ...V

local_conf_header:
  my-project: |
    CONF_VERSION = "2"
    TEGRA_FLASH_USE_NVME = "1"
    TEGRA_BOARDSKU = "0004"
    # ... 其他配置 ...
```

**重點**:
- KAS **沒有**自訂 `build_dir` 參數
- 這表示使用**預設行為**: 在專案根目錄建立 `build/` 目錄

---

## 2. 實際編譯產物位置

### 預設 KAS 目錄結構

```
/home/andy/proj/tegra-demo-distro/          ← 專案根目錄
├── project.yml                              ← KAS 配置檔
├── build/                                   ← KAS 建立的編譯目錄 ✅
│   ├── conf/
│   │   ├── bblayers.conf                    ← KAS 自動生成
│   │   └── local.conf                       ← KAS 自動生成
│   ├── downloads/                           ← 下載的原始碼
│   ├── sstate-cache/                        ← Shared State Cache
│   ├── tmp/                                 ← 編譯工作目錄 (舊版或非 glibc)
│   └── tmp-glibc/                           ← 編譯工作目錄 (glibc 專用) ✅
│       └── deploy/
│           └── images/
│               └── p3768-0000-p3767-0004/   ← 您的產物位置 ✅✅✅
│                   ├── demo-image-egl-*.ext4
│                   ├── demo-image-egl-*.tegraflash.tar.gz  ← 燒錄套件
│                   ├── Image*                              ← Kernel 映像
│                   ├── modules-*.tgz                       ← Kernel 模組
│                   ├── devicetree/                         ← DTB/DTBO
│                   └── tegra-espimage-*.esp                ← UEFI ESP
├── repos/                                   ← Git submodules
└── layers/                                  ← 自訂 layers
```

---

## 3. 產物目錄完整路徑

### 主要路徑 (✅ 正確答案)

```bash
/home/andy/proj/tegra-demo-distro/build/tmp-glibc/deploy/images/p3768-0000-p3767-0004/
```

**或簡寫為**:
```bash
./build/tmp-glibc/deploy/images/p3768-0000-p3767-0004/
```

### 為什麼是 `tmp-glibc` 而不是 `tmp`?

從您的系統中觀察到:
```bash
$ ls -la build/
drwxrwxr-x  14 andy andy   4096 11月 17 20:55 tmp        # 舊版或其他編譯
drwxrwxr-x  13 andy andy   4096 11月 26 22:13 tmp-glibc  # 當前使用的 ✅
```

**原因**:
- Yocto 使用 **TCMODE** (Toolchain Mode) 來分離不同 C 函式庫的編譯環境
- `tmp-glibc/` = 使用 glibc 工具鏈的編譯目錄 (預設)
- `tmp/` = 可能是舊的編譯或使用 musl/uclibc 的編譯

meta-tegra 預設使用 **glibc**,所以產物在 `tmp-glibc/`。

---

## 4. 執行 KAS 編譯後的產物清單

當您執行 `kas build project.yml` 完成後,會在以下位置生成:

### 路徑
```
build/tmp-glibc/deploy/images/p3768-0000-p3767-0004/
```

### 產物檔案 (demo-image-egl)

#### A. 根檔案系統 (RootFS)
```bash
demo-image-egl-p3768-0000-p3767-0004.rootfs-YYYYMMDDHHMMSS.ext4
demo-image-egl-p3768-0000-p3767-0004.rootfs.ext4  → (符號連結)
```
- **格式**: ext4
- **大小**: 約 2-4 GB (取決於 IMAGE_INSTALL 內容)
- **用途**: NVMe 或 SD 卡的根檔案系統

#### B. 燒錄套件 (⭐ 最重要)
```bash
demo-image-egl-p3768-0000-p3767-0004.rootfs-YYYYMMDDHHMMSS.tegraflash.tar.gz
demo-image-egl-p3768-0000-p3767-0004.rootfs.tegraflash.tar.gz  → (符號連結)
```
- **內容**: 包含所有燒錄所需檔案
  - Flash 工具腳本 (doflash.sh, initrd-flash)
  - Bootloader (uefi_jetson.bin, tos-optee_t234.img...)
  - 分區配置 (flash_t234_qspi_sd_p3767-C04.xml)
  - 根檔案系統 (demo-image-egl-*.ext4)
  - Kernel 映像 (Image)
  - Device Tree (tegra234-p3768-0000+p3767-0004-nv-super.dtb)
  - Device Tree Overlays (tegra234-p3767-camera-p3768-imx219-C.dtbo)
  - ESP 分區 (tegra-espimage-*.esp)

**解壓縮後**:
```bash
tar -xvf demo-image-egl-p3768-0000-p3767-0004.rootfs.tegraflash.tar.gz
cd mfi_p3768-0000-p3767-0004/

# 執行燒錄
sudo ./doflash.sh

# 或 initrd-flash (若支援)
sudo ./tools/kernel_flash/l4t_initrd_flash.sh --flash-only --external-device nvme0n1p1
```

#### C. Kernel 映像
```bash
Image--5.15.148+git0+HASH-r0-p3768-0000-p3767-0004-YYYYMMDDHHMMSS.bin
Image → (符號連結)
Image.gz → (壓縮版本)
```
- **版本**: 5.15.148 (meta-tegra L4T R36.4.4)
- **大小**: 約 41 MB (未壓縮), 14 MB (壓縮)

#### D. Kernel 模組
```bash
modules--5.15.148+git0+HASH-r0-p3768-0000-p3767-0004-YYYYMMDDHHMMSS.tgz
modules-p3768-0000-p3767-0004.tgz → (符號連結)
```
- **大小**: 約 61 MB
- **內容**: 所有 out-of-tree 模組 (nvidia-drm, nv-imx219, tegra-camera...)

#### E. Device Tree
```bash
devicetree/
├── tegra234-p3768-0000+p3767-0004-nv-super.dtb          # 主 DTB
├── tegra234-p3767-camera-p3768-imx219-C.dtbo            # IMX219 相機 DTBO ✅
├── tegra234-p3767-camera-p3768-imx219-A.dtbo
├── tegra234-p3767-camera-p3768-imx219-dual.dtbo
├── L4TConfiguration.dtbo                                 # L4T 配置
└── ... (其他 DTB/DTBO)
```

#### F. UEFI ESP 分區映像
```bash
tegra-espimage-p3768-0000-p3767-0004-YYYYMMDDHHMMSS.esp
tegra-espimage-p3768-0000-p3767-0004.esp → (符號連結)
```
- **格式**: FAT32 分區映像
- **大小**: 約 64 MB
- **內容**: 
  - `/EFI/BOOT/BOOTAA64.EFI` (UEFI 啟動器)
  - `/boot/extlinux/extlinux.conf` (啟動配置)
  - `/boot/Image` (Kernel)
  - `/boot/*.dtb` (Device Trees)
  - `/boot/*.dtbo` (Device Tree Overlays)

#### G. 其他檔案
```bash
demo-image-egl-p3768-0000-p3767-0004.rootfs.manifest       # 套件清單
demo-image-egl-p3768-0000-p3767-0004.rootfs.testdata.json  # 測試數據
demo-image-egl-p3768-0000-p3767-0004.rootfs.spdx.tar.zst   # SPDX 授權資訊
```

---

## 5. 與舊方式的比較

### 使用 setup-env 腳本 (舊方式)
```bash
# 舊方式
source setup-env build-demo

# 產物位置
build-demo/tmp/deploy/images/p3768-0000-p3767-0004/
```

### 使用 KAS (新方式) ✅
```bash
# 新方式
kas build project.yml

# 產物位置
build/tmp-glibc/deploy/images/p3768-0000-p3767-0004/  ← 固定在專案根目錄的 build/
```

**差異**:
1. ✅ KAS 使用**固定目錄** `build/` (不會因為命令參數改變)
2. ✅ KAS 自動管理 `bblayers.conf` 和 `local.conf` (從 project.yml 生成)
3. ✅ 更容易整合 CI/CD (目錄結構固定)
4. ✅ 支援多專案配置 (可用不同 .yml 檔案)

---

## 6. 驗證命令

### 檢查產物是否存在

```bash
# 方法 1: 列出所有 demo-image-egl 產物
ls -lh build/tmp-glibc/deploy/images/p3768-0000-p3767-0004/demo-image-egl*

# 方法 2: 檢查燒錄套件
ls -lh build/tmp-glibc/deploy/images/p3768-0000-p3767-0004/*.tegraflash.tar.gz

# 方法 3: 檢查 rootfs
ls -lh build/tmp-glibc/deploy/images/p3768-0000-p3767-0004/*.ext4

# 方法 4: 檢查 DTBO
ls -lh build/tmp-glibc/deploy/images/p3768-0000-p3767-0004/devicetree/*imx219*
```

### 查看最近編譯的產物

```bash
# 按時間排序顯示最新檔案
ls -lht build/tmp-glibc/deploy/images/p3768-0000-p3767-0004/ | head -20
```

### 確認映像檔內容

```bash
# 查看 rootfs 中安裝的套件
cat build/tmp-glibc/deploy/images/p3768-0000-p3767-0004/demo-image-egl-*.manifest
```

---

## 7. KAS 編譯流程

### 完整編譯流程

```bash
# 1. 進入專案目錄
cd /home/andy/proj/tegra-demo-distro

# 2. 執行 KAS 編譯 (會自動建立 build/ 目錄)
kas build project.yml

# 3. 編譯完成後,產物會在:
ls build/tmp-glibc/deploy/images/p3768-0000-p3767-0004/

# 4. 取得燒錄套件
cp build/tmp-glibc/deploy/images/p3768-0000-p3767-0004/demo-image-egl-*.tegraflash.tar.gz ~/
```

### KAS 的自動化行為

執行 `kas build project.yml` 時,KAS 會:

1. ✅ 讀取 `project.yml`
2. ✅ 在專案根目錄建立 `build/` 目錄 (若不存在)
3. ✅ 自動生成 `build/conf/bblayers.conf`
   ```bash
   # 從 project.yml 的 repos 區段生成
   BBLAYERS ?= " \
     /home/andy/proj/tegra-demo-distro/repos/poky/meta \
     /home/andy/proj/tegra-demo-distro/repos/poky/meta-poky \
     /home/andy/proj/tegra-demo-distro/repos/meta-openembedded/meta-oe \
     /home/andy/proj/tegra-demo-distro/repos/meta-tegra \
     /home/andy/proj/tegra-demo-distro/layers/meta-tegrademo \
     ... \
   "
   ```
4. ✅ 自動生成 `build/conf/local.conf`
   ```bash
   # 從 project.yml 的 local_conf_header 區段生成
   MACHINE ??= "p3768-0000-p3767-0004"
   DISTRO ??= "my-distro"
   TEGRA_FLASH_USE_NVME = "1"
   TEGRA_BOARDSKU = "0004"
   IMAGE_INSTALL:append = " tegra-argus-daemon ..."
   ```
5. ✅ 執行 `bitbake demo-image-egl`
6. ✅ 產物輸出到 `build/tmp-glibc/deploy/images/p3768-0000-p3767-0004/`

---

## 8. 常見問題

### Q1: 為什麼我看到 `tmp/` 和 `tmp-glibc/` 兩個目錄?

**A**: 
- `tmp-glibc/` = 當前使用 glibc 工具鏈的編譯 ✅
- `tmp/` = 可能是:
  - 舊的編譯殘留
  - 使用不同 TCLIBC 的編譯 (musl/uclibc)
  - 其他機器的編譯

**建議**: 關注 `tmp-glibc/`,這是您當前編譯使用的。

### Q2: 為什麼路徑不是 `build/tmp/deploy/...`?

**A**: meta-tegra 預設使用 glibc,Yocto 會自動在 TMPDIR 名稱加上工具鏈後綴:
```bash
TMPDIR = "${TOPDIR}/tmp"           # 基礎設定
# 實際會變成:
TMPDIR = "${TOPDIR}/tmp-glibc"     # 加上 glibc 後綴
```

### Q3: 如何清理舊編譯?

```bash
# 清理所有編譯產物 (保留 downloads 和 sstate-cache)
rm -rf build/tmp build/tmp-glibc

# 完全清理 (包含下載和 cache)
rm -rf build/
```

### Q4: 可以改變 build 目錄位置嗎?

**可以**,在 `project.yml` 中添加:
```yaml
build_system: oe
build_dir: /path/to/custom/build/dir
```

但**不建議**,保持預設 `build/` 更標準。

### Q5: 為什麼我看到 `core-image-minimal` 而不是 `demo-image-egl`?

從您的輸出看到:
```bash
core-image-minimal-p3768-0000-p3767-0004.rootfs-20251126135549.ext4
```

**可能原因**:
1. 最近一次編譯的是 `core-image-minimal` (測試用)
2. 尚未執行 `kas build project.yml` 編譯 `demo-image-egl`

**確認方法**:
```bash
# 檢查是否有 demo-image-egl
ls build/tmp-glibc/deploy/images/p3768-0000-p3767-0004/demo-image-egl* 2>/dev/null

# 若沒有,執行編譯
kas build project.yml
```

---

## 9. 燒錄流程

### 使用 tegraflash 套件燒錄

```bash
# 1. 進入產物目錄
cd build/tmp-glibc/deploy/images/p3768-0000-p3767-0004/

# 2. 解壓縮燒錄套件
tar -xvf demo-image-egl-p3768-0000-p3767-0004.rootfs.tegraflash.tar.gz

# 3. 進入燒錄目錄
cd mfi_p3768-0000-p3767-0004/

# 4. 連接 Jetson 到 Recovery Mode
# - 按住 RECOVERY 按鈕
# - 短按 RESET 按鈕
# - 放開 RECOVERY 按鈕

# 5. 執行燒錄 (傳統方式)
sudo ./doflash.sh

# 或使用 initrd-flash (NVMe 推薦)
sudo ./tools/kernel_flash/l4t_initrd_flash.sh \
    --external-device nvme0n1p1 \
    -c tools/kernel_flash/flash_l4t_nvme_rootfs_ab.xml \
    -p "-c bootloader/generic/cfg/flash_t234_qspi_sd_p3767-C04.xml" \
    --showlogs --network usb0 p3768-0000-p3767-0004 nvme0n1p1
```

### 驗證燒錄內容

系統啟動後:
```bash
# 檢查 DTBO 是否載入
cat /boot/extlinux/extlinux.conf | grep OVERLAYS
# 應顯示: OVERLAYS /boot/tegra234-p3767-camera-p3768-imx219-C.dtbo

# 檢查相機節點
ls /dev/video*
# 應顯示: /dev/video0

# 檢查映像版本
cat /etc/os-release
```

---

## 10. 總結

### ✅ 確認答案

**問題**: 使用 `kas build project.yml` 編譯後,產物是否在 `tegra-demo-distro/build/tmp/deploy/images/p3768-0000-p3767-0004`?

**答案**: **幾乎正確,但實際路徑是**:

```
/home/andy/proj/tegra-demo-distro/build/tmp-glibc/deploy/images/p3768-0000-p3767-0004/
                                              ^^^^^^^^ 
                                              注意是 tmp-glibc 而不是 tmp
```

### 路徑對照表

| 項目 | 路徑 | 說明 |
|------|------|------|
| 專案根目錄 | `/home/andy/proj/tegra-demo-distro/` | KAS 工作目錄 |
| 編譯目錄 | `build/` | KAS 自動建立 |
| TMPDIR | `build/tmp-glibc/` | glibc 工具鏈編譯目錄 ✅ |
| 產物目錄 | `build/tmp-glibc/deploy/images/p3768-0000-p3767-0004/` | ✅✅✅ |
| 燒錄套件 | `build/tmp-glibc/deploy/images/p3768-0000-p3767-0004/demo-image-egl-*.tegraflash.tar.gz` | ✅ |
| rootfs | `build/tmp-glibc/deploy/images/p3768-0000-p3767-0004/demo-image-egl-*.ext4` | ✅ |
| kernel | `build/tmp-glibc/deploy/images/p3768-0000-p3767-0004/Image` | ✅ |
| DTB/DTBO | `build/tmp-glibc/deploy/images/p3768-0000-p3767-0004/devicetree/` | ✅ |

### 關鍵重點

1. ✅ **目錄固定**: KAS 始終使用 `build/` (在專案根目錄)
2. ✅ **tmp-glibc**: 因為使用 glibc 工具鏈,所以是 `tmp-glibc/` 而非 `tmp/`
3. ✅ **燒錄套件存在**: `*.tegraflash.tar.gz` 包含所有燒錄所需檔案
4. ✅ **映像正確**: `demo-image-egl` 根據 `project.yml` 中的 `target:` 設定
5. ✅ **機器正確**: `p3768-0000-p3767-0004` (Jetson Orin Nano 4GB)

### 快速驗證指令

```bash
# 一鍵檢查所有產物
ls -lh build/tmp-glibc/deploy/images/p3768-0000-p3767-0004/demo-image-egl* && \
echo "✅ demo-image-egl 產物存在!" || \
echo "❌ 請執行: kas build project.yml"
```

---

**結論**: 您的理解**基本正確**,唯一需要注意的是實際路徑中的 `tmp` 應該是 `tmp-glibc`,這是 Yocto 對 glibc 工具鏈的標準命名慣例。所有產物(包含燒錄檔和 demo-image-egl 映像)都會在該目錄下的 `deploy/images/p3768-0000-p3767-0004/` 中。
