技術專題報告：基於 OE4T 專案針對 Jetson Orin Nano 4GB (NVMe) 建構客製化 BSP 之完整解決方案1. 執行摘要與架構背景本研究報告旨在針對 NVIDIA Jetson Orin Nano 4GB NVMe 版本（模組代號 P3767-0004，搭載於 P3768 載板）在 OpenEmbedded for Tegra (OE4T/meta-tegra) 環境下的客製化 Board Support Package (BSP) 開發，提供詳盡的技術分析與實作指引。針對使用者提出的核心需求——在 demo-image-egl 專案中打通 DisplayPort (DP) 顯示介面與 IMX219 CSI 影像感測器——本報告將深入探討從硬體抽象層、核心設備樹 (Device Tree)、Overlay 機制到使用者空間 (Userspace) 驅動程式的完整整合路徑。目前的技術現狀顯示，原廠 NVIDIA JetPack (基於 Ubuntu) 透過 jetson-io 工具與預先編譯的二進位檔案，能夠順利驅動上述周邊。然而，轉移至 Yocto Project 環境時，開發者必須手動處理依賴關係、設備樹覆蓋 (Device Tree Overlays, DTBO) 的編譯與部署，以及使用者空間守護進程 (Daemons) 的配置 1。特別是 Jetson Orin Nano 4GB 版本在記憶體配置與 SKU 識別上的特殊性，若未在 Machine Configuration 中精確定義，將導致開機失敗或周邊功能異常 3。本報告將證實，雖然原廠的設備樹邏輯可以沿用，但在 Yocto 的建構系統中，必須透過 KERNEL_DEVICETREE_OVERLAYS 變數與特定的 IMAGE_INSTALL 套件組合來實現，而非依賴執行時期的動態配置工具。此外，針對 NVMe 的燒錄機制 (initrd-flash) 亦需特別配置，以確保根檔案系統 (Rootfs) 正確部署於外部儲存裝置 5。2. 硬體架構深度解析與 SKU 識別在進行 BSP 開發之前，必須精確理解目標硬體的物理特性與識別碼，因為這些參數直接決定了 Bootloader (UEFI) 與 Kernel 如何初始化系統資源。2.1 Jetson Orin Nano 4GB (P3767-0004) 之特殊性Jetson Orin Nano 系列擁有多個變體，其中 4GB 版本（P3767-0004）與 8GB 版本（P3767-0003 或 DevKit 的 P3767-0005）在硬體層面存在顯著差異。4GB 版本僅搭載 512 個 CUDA 核心（相較於 8GB 的 1024 個）且記憶體頻寬與容量減半。在軟體層面，這些差異透過 Board SKU (Stock Keeping Unit) ID 來識別。若在 Yocto 的 Machine Config 中錯誤地使用了預設的 DevKit 設定（通常預設為 SKU 0000 或 0005），Boot Component Table (BCT) 將會載入錯誤的 DRAM 參數，導致記憶體訓練失敗或系統不穩定 3。表 2.1：Jetson Orin Nano 系列模組 SKU 對照表模組型號記憶體容量SKU ID載板相容性關鍵差異Jetson Orin Nano 4GB4GB0004P3768本案目標。需特定 BCT 配置，CUDA 核心數較少。Jetson Orin Nano 8GB8GB0003P3768生產模組，記憶體配置不同。Jetson Orin Nano DevKit8GB0005P3768開發套件專用模組，包含 SD 卡插槽（4GB 模組無 SD 槽）。Jetson Orin NX 16GB16GB0000P3768/P3509核心數與記憶體完全不同。由上表可見，P3767-0004 是生產模組，通常不具備 SD 卡插槽，因此必須依賴 NVMe 或 USB 進行開機與儲存，這與 jetson-orin-nano-devkit-nvme 的 Machine 定義完全吻合 2。2.2 載板 (P3768) 與周邊介面拓撲P3768 載板提供了標準的介面佈局，對於本案關鍵的 DisplayPort 與 CSI 介面：DisplayPort (DP): 訊號直接來自 Orin SoC 的顯示控制器 (Display Controller, DC) 並透過 SOR (Serial Output Resource) 輸出。在設備樹中，這對應於 sor 節點與 dp-display 節點。原廠 BSP 的成功運作表明硬體線路無誤，Yocto 端需確保 Firmware (tegra-firmware) 正確載入以初始化 SOR。CSI Camera (IMX219): P3768 載板通常提供兩個 CSI 介面（CSI-A 與 CSI-B）。IMX219 感測器依賴 I2C 進行控制（通常是 I2C Bus 9 或 10，視 Pinmux 而定）以及 MIPI CSI-2 通道進行資料傳輸。原廠使用 tegra234-p3767-camera-p3768-imx219-dual.dtbo 來同時啟用雙鏡頭，或使用特定後綴的 DTBO 啟用單鏡頭 8。3. OE4T (Meta-Tegra) 軟體生態系統分析Meta-Tegra 層是連接 NVIDIA L4T (Linux for Tegra) 與 Yocto Project 的橋樑。為了在 demo-image-egl 中實現目標功能，必須理解其與標準 JetPack 的架構差異。3.1 Yocto 與 JetPack 的核心差異在 JetPack (Ubuntu) 環境中，NVIDIA 預載了完整的桌面環境 (GNOME) 與一系列動態配置工具（如 jetson-io）。使用者可以在執行時期 (Runtime) 透過 GUI 或 CLI 修改設備樹並重啟生效。在 Yocto 環境，特別是 demo-image-egl 這類精簡映像檔中，預設不包含 jetson-io 工具，且檔案系統可能被配置為唯讀或極簡化 10。因此，所有的硬體配置（包含 DP 與 Camera 的啟用）必須在 建構時期 (Build Time) 完成定義，而非依賴執行時期的動態調整。這是從 JetPack 轉移至 OE4T 時最大的思維轉換。3.2 核心版本演進：L4T R35 (Kernel 5.10) vs R36 (Kernel 5.15)使用者提到可以使用 JetPack 5.x (L4T R35) 或 6.x (L4T R36)。這兩個版本在 Meta-Tegra 中對應不同的分支與核心架構，這對 Device Tree Overlay 的處理有決定性影響。Kirkstone 分支 (L4T R35.x / Kernel 5.10): 使用 NVIDIA 高度客製化的 5.10 核心。Overlay 機制較為成熟，依賴 extlinux.conf 中的 FDT 或 OVERLAYS 關鍵字，或透過 UEFI 的 Capsule Update 機制 11。Scarthgap 分支 (L4T R36.x / Kernel 5.15): 這是 JetPack 6 的基礎，採用了更接近 Mainline Linux 的 5.15 核心。設備樹的結構發生了變化，許多驅動程式（包括相機感測器）被移至 Out-of-Tree (OOT) 模組中編譯 13。在此版本中，Overlay 的應用更加依賴 Bootloader (UEFI) 的載入機制，且必須確保 Overlay 二進位檔 (.dtbo) 與核心版本嚴格匹配。鑑於 JetPack 6 是未來的趨勢且提供了更新的 AI 支援，建議優先考慮基於 Scarthgap (L4T R36) 的配置，但本報告將涵蓋通用的配置邏輯。4. 建構策略：Machine 選擇與 SKU 覆寫為了正確支援 Jetson Orin Nano 4GB NVMe，第一步是建立正確的 Machine Configuration。這不應僅僅是選擇一個名稱，而是要確保底層的 BCT 與 Pinmux 設定正確。4.1 選擇正確的 Machine Target根據 OE4T 的文件與社群討論，jetson-orin-nano-devkit-nvme 是支援 NVMe 開機的正確 Machine 2。此 Machine 設定會觸發 initrd-flash 腳本生成適用於外部儲存裝置的燒錄包。配置建議 (local.conf):程式碼片段MACHINE = "jetson-orin-nano-devkit-nvme"
4.2 關鍵修正：強制指定 Board SKU由於 jetson-orin-nano-devkit-nvme 預設可能指向 8GB DevKit 模組 (SKU 0005)，對於手上的 4GB 模組 (SKU 0004)，必須在 local.conf 或自定義的 Machine 檔案中強制覆寫 TEGRA_BOARDSKU 變數。這將指導建構系統選擇正確的 BCT 檔案（如 tegra234-p3767-0004-sdram-l4t.dts）7。配置建議 (local.conf):程式碼片段# 強制指定 Orin Nano 4GB 生產模組 SKU
TEGRA_BOARDSKU = "0004"
# 確保 BCT 與 Flash Layout 對應正確
TEGRA_BUPGEN_SPECS = "fab=000;boardsku=0004;boardrev=;chipsku=00:00:00:D4;bup_type=bl;fab=000;boardsku=0004;boardrev=;bup_type=kernel"
若忽略此步驟，燒錄後的系統可能會在 BootROM 階段就因為記憶體初始化失敗而卡住，或者在 kernel 啟動時因為記憶體映射錯誤而 Panic。5. IMX219 影像感測器整合方案在 Yocto 環境中啟用 IMX219 需要兩個層面的整合：核心層（透過 Device Tree Overlay）與使用者空間層（透過 Argus Daemon 與 GStreamer）。5.1 Device Tree Overlay (DTBO) 的建構與應用使用者推測「原廠使用的 dtp (Device Tree Package) 應該可以直接沿用」是正確的，但在 OE4T 中，我們需要透過變數來指示建構系統將這些 Overlay 納入映像檔並配置 Bootloader 自動載入。在 L4T R36 (JetPack 6) 架構下，IMX219 的驅動程式與 Overlay 位於 nvidia-kernel-oot 套件中。標準的雙鏡頭 Overlay 檔案名稱為 tegra234-p3767-camera-p3768-imx219-dual.dtbo 8。配置邏輯：確認 Overlay 來源： nvidia-kernel-oot Recipe 會編譯 device-tree/overlays/ 下的原始碼生成 .dtbo。指定應用 Overlay： 使用 KERNEL_DEVICETREE_OVERLAYS 變數。此變數會被 tegra-flashvars 或 l4t-launcher 讀取，並寫入 extlinux.conf 的 OVERLAYS 欄位或 UEFI 變數中 17。配置建議 (local.conf):程式碼片段# 啟用 IMX219 雙鏡頭支援
KERNEL_DEVICETREE_OVERLAYS:append = " tegra234-p3767-camera-p3768-imx219-dual.dtbo"
注意： 請勿使用 TEGRA_PLUGIN_MANAGER_OVERLAYS，該變數主要用於舊版 L4T 的 CBoot Plugin Manager 機制，在 UEFI 架構下已逐漸被 KERNEL_DEVICETREE_OVERLAYS 取代或行為改變 11。5.2 使用者空間 (Userspace) 支援：Demo-Image-EGL 的補強demo-image-egl 是一個極簡的映像檔，僅包含基本的 DRM/EGL 支援，預設不包含 NVIDIA 的相機守護進程 nvargus-daemon 19。沒有這個 Daemon，即便 Kernel 成功載入 IMX219 驅動並產生 /dev/video0 節點，使用者也無法透過 nvarguscamerasrc 進行 ISP 加速的影像擷取，只能使用功能受限的 v4l2src（無法處理 ISP 轉換，通常輸出 RAW 數據）。為了「打通」CSI 影像，必須手動將相關套件加入映像檔。配置建議 (local.conf):程式碼片段# 安裝 Argus Camera Stack 與 GStreamer 插件
IMAGE_INSTALL:append = " \
    tegra-argus-daemon \
    tegra-mmapi \
    gstreamer1.0-plugins-tegra \
    tegra-utils-nvgpuscaling \
    cuda-libraries \
    libv4l \
    v4l-utils \
"
tegra-argus-daemon: 負責控制 ISP 與相機感測器的通訊，必須在背景執行 21。gstreamer1.0-plugins-tegra: 提供 nvarguscamerasrc, nvvidconv 等硬體加速元件。tegra-mmapi: 提供底層的多媒體 API 支援。6. DisplayPort (DP) 的啟用與 Firmware 配置DisplayPort 的啟用主要依賴於核心的 Display Controller (DC) 驅動與相關的 Firmware。在 Orin Nano DevKit 的預設 Device Tree 中，DP 通常已經被定義並啟用。如果使用者遇到「無訊號」的問題，通常不是 Device Tree 的問題，而是 Firmware 缺失或顯示伺服器配置錯誤。6.1 Firmware 完整性在 demo-image-egl 中，必須確保 GPU 與 Display 相關的 Firmware 被正確安裝。配置建議 (local.conf):程式碼片段# 確保所有必要的 Firmware 都被安裝
IMAGE_INSTALL:append = " \
    tegra-firmware-gsc \
    tegra-firmware-gpu \
    linux-firmware-nvidia-tegra \
"
這些 Firmware 負責初始化 SOR (Serial Output Resource) 並執行 Link Training。若缺失，dmesg 會顯示 bpmp 或 hsp 相關的通訊錯誤，導致螢幕黑屏 23。6.2 無視窗環境下的顯示驗證由於 demo-image-egl 沒有 X11 或 Wayland 桌面環境，DisplayPort 點亮後預設可能只顯示由 Kernel 輸出的 Console 文字，或者全黑（如果 Console 被導向至 Serial）。這並不代表 DP 未打通。使用者應使用 modetest (來自 libdrm-tests 或 drm-utils) 或 GStreamer 直接寫入 Framebuffer 來驗證 DP：Bash# 驗證 DP 是否被偵測到 (Connector status: connected)
modetest -M tegra -c
7. 整合實作：local.conf 完整配置範例綜合上述分析，以下是針對使用者的需求，在 oe4t 專案的 build/conf/local.conf 中應加入的完整配置區塊。這將轉換原廠 BSP 的邏輯至 Yocto 變數。表 7.1：關鍵配置變數總表變數名稱設定值功能說明MACHINEjetson-orin-nano-devkit-nvme指定 Orin Nano NVMe 開機模式，啟用 initrd-flash。TEGRA_BOARDSKU0004強制指定 4GB 模組，載入正確記憶體 BCT。KERNEL_DEVICETREE_OVERLAYStegra234-p3767-camera-p3768-imx219-dual.dtbo注入相機 Overlay，相當於原廠 jetson-io 的操作。IMAGE_INSTALL:appendtegra-argus-daemon...安裝相機 Daemon 與 GStreamer 插件，補足 EGL Image 的缺失。建議的 local.conf 內容：程式碼片段# --- Machine Identification ---
MACHINE = "jetson-orin-nano-devkit-nvme"
# 強制指定 P3767-0004 (Orin Nano 4GB) SKU 以確保記憶體參數正確
TEGRA_BOARDSKU = "0004"

# --- Device Tree Overlays ---
# 對應原廠 BSP 中的 IMX219 Dual Camera Overlay
# 確保檔案名稱與 nvidia-kernel-oot 生成的一致
KERNEL_DEVICETREE_OVERLAYS:append = " tegra234-p3767-camera-p3768-imx219-dual.dtbo"

# --- Userspace Packages for Camera & Display ---
# demo-image-egl 預設缺少相機支援套件，需手動補齊
IMAGE_INSTALL:append = " \
    tegra-argus-daemon \
    tegra-mmapi \
    gstreamer1.0-plugins-tegra \
    tegra-utils-nvgpuscaling \
    cuda-libraries \
    libv4l \
    v4l-utils \
    tegra-firmware-gsc \
    tegra-firmware-gpu \
"

# --- Optional: Tools for Debugging ---
IMAGE_INSTALL:append = " i2c-tools libdrm-tests"
8. 燒錄機制：NVMe 與 Initrd Flash 的細節針對 Orin Nano NVMe 版本，傳統的 doflash.sh 可能無法正確處理外部儲存裝置的分割與寫入。OE4T 提供了 initrd-flash 機制，這與 NVIDIA 的 l4t_initrd_flash.sh 對應 24。8.1 建構與燒錄流程建構映像檔：執行 bitbake demo-image-egl。建構完成後，會在 tmp/deploy/images/jetson-orin-nano-devkit-nvme/ 目錄下生成一個 .tegraflash.tar.gz 壓縮檔。準備燒錄環境：將開發板設定為 Recovery Mode（短路 FC REC 與 GND，並上電）。確保 USB 傳輸線連接至主機。執行 Initrd Flash：解壓縮 tegraflash 包並執行燒錄腳本。注意，針對 NVMe，必須使用 initrd-flash 腳本而非 doflash.sh。Bashtar xf demo-image-egl-jetson-orin-nano-devkit-nvme.tegraflash.tar.gz
cd Linux_for_Tegra
sudo./initrd-flash
技術細節： 此腳本會首先透過 USB 將一個微型的 Linux 系統 (Initrd) 載入 Jetson 的 RAM 中執行。接著，主機端會透過 USB (RNDIS/Network) 將根檔案系統 (Rootfs) 傳輸給這個微型系統，由它負責對 NVMe SSD 進行分割與寫入 5。若燒錄過程中出現 "Waiting for USB storage device" 錯誤，通常代表 Initrd 中的 USB Device Mode 驅動未正確啟動，或主機端的 udev 規則未設定正確。9. 驗證與故障排除指南燒錄完成後，系統應能從 NVMe 啟動。以下是針對 DP 與 IMX219 的驗證步驟。9.1 驗證 DisplayPort (DP)由於 demo-image-egl 沒有桌面，請觀察螢幕是否有 Console 輸出。若無：檢查 Kernel Log: dmesg | grep "dp" 或 dmesg | grep "tegradc". 尋找 Link Training 成功或失敗的訊息。檢查 Firmware: 確認 /lib/firmware/nvidia 下是否有相關檔案。測試訊號: 使用 modetest -M tegra -s <connector_id>:<mode> 強制輸出 Color Bar 測試圖樣。9.2 驗證 IMX219 Camera這是最關鍵的步驟，分為 Kernel 層與 User 層。Kernel I2C 探測：Bashdmesg | grep "imx219"
若顯示 imx219 9-0010: probe success (Bus 編號可能不同)，代表 Overlay 已成功載入且 I2C 通訊正常。常見錯誤： 若顯示 probe failed 或無訊息，請檢查 /boot/extlinux/extlinux.conf (或 UEFI 變數)，確認 KERNEL_DEVICETREE_OVERLAYS 中的 dtbo 檔案名稱是否正確被寫入設定檔 26。Argus Daemon 狀態：Bashsystemctl status nvargus-daemon
必須顯示 active (running)。若未執行，請手動啟動：sudo systemctl start nvargus-daemon。若啟動失敗，檢查 /var/log/syslog 是否有 EGL 初始化錯誤，這通常意味著 GPU 驅動或 Firmware 有問題 28。GStreamer 串流測試：使用以下指令測試相機並將影像輸出到 DP 螢幕 (透過 nv3dsink 或 nveglglessink)：Bashgst-launch-1.0 nvarguscamerasrc! 'video/x-raw(memory:NVMM), width=1920, height=1080'! nvvidconv! nv3dsink
若能看到影像，則代表從底層 DTBO 到上層 Argus 的整合完全成功。10. 結論要在 OE4T 的 demo-image-egl 專案中「打通」Jetson Orin Nano 4GB 的 DP 與 IMX219，核心在於精確的 Machine 定義與建構時期的靜態配置。原廠的 DTP 檔案 (tegra234-p3767-camera-p3768-imx219-dual.dtbo) 確實可以直接沿用，但必須透過 KERNEL_DEVICETREE_OVERLAYS 變數在建構時注入，並配合 TEGRA_BOARDSKU="0004" 來確保硬體初始化參數正確。此外，使用者必須手動將 tegra-argus-daemon 等閉源驅動元件加入映像檔，以補足 demo-image-egl 在多媒體支援上的空白。透過遵循本報告提出的配置策略與燒錄流程，即可在 Yocto 環境中重現原廠 BSP 的硬體支援能力。