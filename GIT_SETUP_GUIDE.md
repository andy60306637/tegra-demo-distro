# Git Repository 設定步驟

## 1. meta-my-project Layer Repository

### 初始化 Git Repository

```bash
cd /home/andy/proj/tegra-demo-distro/meta-my-project

# 初始化 git repository
git init

# 加入檔案
git add .

# 建立初始 commit
git commit -m "Initial commit: Jetson Orin Nano with DisplayPort and IMX219

- Add custom distro configuration (my-distro)
- Add l4t-launcher-extlinux.bbappend for FDT/DTBO support
- DisplayPort/HDMI support via nvidia-drm
- IMX219 camera support on CAM1 (CSI-C)
"
```

### 推送到 GitHub

```bash
# 在 GitHub 上建立新的 repository (例如: meta-jetson-orin-nano-custom)
# 然後執行:

git remote add origin git@github.com:YOUR_USERNAME/meta-jetson-orin-nano-custom.git
git branch -M main
git push -u origin main
```

### 更新 project.yml 參照

修改 `/home/andy/proj/tegra-demo-distro/project.yml`:

```yaml
repos:
  meta-my-project:
    url: "https://github.com/YOUR_USERNAME/meta-jetson-orin-nano-custom.git"
    refspec: main
    layers:
      .:
```

---

## 2. KAS Project Repository (tegra-demo-distro)

### 更新 .gitignore

先確認 `.gitignore` 檔案已經正確設定:

```bash
cd /home/andy/proj/tegra-demo-distro
cat > .gitignore << 'EOF'
# Build artifacts
build/

# Downloaded repositories (KAS will fetch these)
repos/
layers/bitbake/
layers/meta/
layers/meta-filesystems/
layers/meta-networking/
layers/meta-oe/
layers/meta-python/
layers/meta-skeleton/
layers/meta-tegra/
layers/meta-tegra-community/
layers/meta-virtualization/
layers/scripts/
layers/oe-init-build-env
layers/LICENSE

# Python
*.pyc
__pycache__/

# Editor files
*.swp
*.swo
*~
.*.swp
.vscode/
.idea/

# OS files
.DS_Store
Thumbs.db

# Temporary files
*.tmp
*.bak
*.orig
EOF
```

### 初始化 Git Repository

```bash
cd /home/andy/proj/tegra-demo-distro

# 初始化 git repository (如果還沒有的話)
git init

# 加入檔案
git add .gitignore
git add setup-env
git add project.yml
git add scripts-setup/
git add layers/meta-demo-ci/
git add layers/meta-tegra-support/
git add layers/meta-tegrademo/

# 如果有建立其他文件 (例如 README, 文檔等)
git add *.md

# 建立初始 commit
git commit -m "Initial commit: Custom tegra-demo-distro with KAS

- Add KAS project configuration (project.yml)
- Configure for Jetson Orin Nano 4GB (p3768-0000-p3767-0004)
- Include DisplayPort and IMX219 camera support
- Add setup scripts and demo layers
- Reference meta-my-project custom layer
"
```

### 推送到 GitHub

```bash
# 在 GitHub 上建立新的 repository (例如: my-tegra-demo-distro)
# 然後執行:

git remote add origin git@github.com:YOUR_USERNAME/my-tegra-demo-distro.git
git branch -M main
git push -u origin main
```

---

## 3. 驗證設定

### 測試 KAS 從 Git 重新建構

在另一個目錄測試:

```bash
# 測試目錄
mkdir -p ~/test-build
cd ~/test-build

# Clone KAS project
git clone git@github.com:YOUR_USERNAME/my-tegra-demo-distro.git
cd my-tegra-demo-distro

# KAS 會自動 clone meta-my-project 和其他 repos
kas build project.yml
```

### 清理並重新建構 (可選)

如果要在原始目錄重新開始:

```bash
cd /home/andy/proj/tegra-demo-distro

# 清理建構目錄和下載的 repos (保留 downloads 和 sstate-cache)
rm -rf build/tmp*
rm -rf repos/*
rm -rf layers/bitbake layers/meta layers/meta-*

# 保留快取以加速重建
# build/downloads/    <- 保留
# build/sstate-cache/ <- 保留

# 使用 KAS 重新建構 (會重新 clone repos)
kas build project.yml
```

---

## 4. 團隊協作建議

### Branch 策略

```bash
# 開發新功能時建立 branch
git checkout -b feature/add-new-sensor

# 完成後 merge 回 main
git checkout main
git merge feature/add-new-sensor
git push
```

### Pull Request 流程

1. Fork repository 到個人 GitHub
2. Clone fork 到本地
3. 建立 feature branch
4. Commit 修改
5. Push 到個人 fork
6. 在 GitHub 上建立 Pull Request

### Tag 發布版本

```bash
# 建立 tag
git tag -a v1.0.0 -m "Release v1.0.0: Initial stable release"

# 推送 tag
git push origin v1.0.0
```

---

## 5. 更新 project.yml 完整範例

確保 `project.yml` 正確參照 GitHub repositories:

```yaml
header:
  version: 14

machine: p3768-0000-p3767-0004
distro: my-distro
target: demo-image-egl

repos:
  meta-tegra:
    url: "https://github.com/OE4T/meta-tegra.git"
    refspec: scarthgap-l4t-r36.4
    layers:
      .:

  openembedded-core:
    url: "https://github.com/openembedded/openembedded-core.git"
    refspec: scarthgap
    layers:
      meta:

  meta-openembedded:
    url: "https://github.com/openembedded/meta-openembedded.git"
    refspec: scarthgap
    layers:
      meta-oe:
      meta-python:
      meta-filesystems:
      meta-networking:

  meta-virtualization:
    url: "https://github.com/openembedded/meta-virtualization.git"
    refspec: scarthgap

  meta-tegra-community:
    url: "https://github.com/OE4T/meta-tegra-community.git"
    refspec: scarthgap
    layers:
      meta-tegra-support:

  # 你的客製化 layer (已推送到 GitHub)
  meta-my-project:
    url: "https://github.com/YOUR_USERNAME/meta-jetson-orin-nano-custom.git"
    refspec: main
    layers:
      .:

local_conf_header:
  standard: |
    CONF_VERSION = "2"
    PACKAGE_CLASSES = "package_deb"
    SANITY_TESTED_DISTROS = ""
    
  my-project: |
    # Flash to NVMe
    TEGRA_FLASH_USE_NVME = "1"
    TEGRA_BOARDSKU = "0004"
    
    # DisplayPort/HDMI support
    IMAGE_INSTALL:append = " nvidia-drm-loadconf kernel-module-nvidia-drm"
    KERNEL_ARGS:append = " nvidia-drm.modeset=1 nvidia-drm.fbdev=1"
    
    # Camera and multimedia
    IMAGE_INSTALL:append = " tegra-argus-daemon tegra-mmapi v4l-utils gstreamer1.0-plugins-tegra"
    
    # Device Tree configuration
    UBOOT_EXTLINUX_FDT = "devicetree/tegra234-p3768-0000+p3767-0004-nv-super.dtb"
    UBOOT_EXTLINUX_FDTOVERLAYS = "devicetree/tegra234-p3767-camera-p3768-imx219-C.dtbo"
```

---

## 6. 常見問題

### Q: KAS 會不會覆蓋我本地的 meta-my-project?

A: 不會,如果目錄已存在且是 Git repository,KAS 會使用現有的目錄。如果要強制更新:

```bash
kas checkout --update project.yml
```

### Q: 如何分享 downloads 和 sstate-cache 給團隊?

A: 可以設定共享目錄或使用 HTTP server:

```yaml
local_conf_header:
  shared-cache: |
    DL_DIR = "/shared/yocto/downloads"
    SSTATE_DIR = "/shared/yocto/sstate-cache"
```

### Q: 如何在 CI/CD 中使用?

A: 使用 Docker 或 GitHub Actions:

```yaml
# .github/workflows/build.yml
name: Build Yocto Image
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/siemens/kas/kas:latest
    steps:
      - uses: actions/checkout@v3
      - name: Build with KAS
        run: kas build project.yml
```

---

## 完成!

現在你的 repositories 已經準備好:
1. ✅ `meta-my-project` - 客製化 layer
2. ✅ `tegra-demo-distro` - KAS 專案設定

團隊成員只需要:
```bash
git clone https://github.com/YOUR_USERNAME/my-tegra-demo-distro.git
cd my-tegra-demo-distro
kas build project.yml
```

KAS 會自動下載所有依賴的 layers 並建構完整的映像檔。
