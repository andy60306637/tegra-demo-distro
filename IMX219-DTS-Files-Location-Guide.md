# IMX219 Device Tree 原始檔案位置指南

## 檔案位置總覽

IMX219 的 DTS 原始檔案在您的專案中**確實存在**,它們由 `nvidia-kernel-oot` 套件在編譯時解壓縮到 build 目錄中。

### 主要檔案位置

```
build/tmp/work/p3768_0000_p3767_0004-oe4t-linux/nvidia-kernel-oot/36.4.4/
└── nvidia-kernel-oot/hardware/nvidia/t23x/nv-public/overlay/
    ├── tegra234-camera-rbpcv2-imx219.dtsi           (761 行, 26KB)  ← 核心感測器定義
    ├── tegra234-p3767-camera-p3768-imx219-A.dts     (470 行, 16KB)  ← CAM0 單相機
    ├── tegra234-p3767-camera-p3768-imx219-C.dts     (465 行, 15KB)  ← CAM1 單相機 ✅ 您使用的
    ├── tegra234-p3767-camera-p3768-imx219-dual.dts  (61 行, 1.5KB)  ← 雙相機配置
    ├── tegra234-p3767-camera-p3768-imx219-imx477.dts (605 行, 20KB) ← IMX219+IMX477 混合
    └── tegra234-p3767-camera-p3768-imx477-imx219.dts (704 行, 24KB) ← IMX477+IMX219 混合
```

## 檔案結構說明

### 1. 核心檔案: `tegra234-camera-rbpcv2-imx219.dtsi`

這是**最重要的檔案**,包含 IMX219 感測器的完整定義:

```dts
// 主要內容包含:
- 5 種感測器模式定義 (mode0 ~ mode4)
  - mode0: 3280x2464 @ 21fps (全解析度)
  - mode1: 3280x2464 @ 21fps (備用)
  - mode2: 1920x1080 @ 30fps (1080p)
  - mode3: 1640x1232 @ 30fps
  - mode4: 1280x720 @ 60fps (720p)

- 感測器參數:
  - I2C 地址: 0x10
  - MIPI CSI-2: 2-lane
  - Pixel format: 10-bit RAW Bayer (RGGB)
  - 曝光範圍: 13µs ~ 683ms
  - 增益範圍: 1x ~ 16x

- VI (Video Input) 配置
- CSI (Camera Serial Interface) 配置
- 電源管理配置
```

**檔案路徑**:
```bash
build/tmp/work/p3768_0000_p3767_0004-oe4t-linux/nvidia-kernel-oot/36.4.4/nvidia-kernel-oot/hardware/nvidia/t23x/nv-public/overlay/tegra234-camera-rbpcv2-imx219.dtsi
```

### 2. 您目前使用的檔案: `tegra234-p3767-camera-p3768-imx219-C.dts`

這是 **CAM1 (CSI-C 接口)** 的配置檔案:

```dts
/dts-v1/;
/plugin/;

// GPIO 定義
#define CAM0_RST	TEGRA234_MAIN_GPIO(H, 3)
#define CAM0_PWDN	TEGRA234_MAIN_GPIO(H, 6)
#define CAM1_PWDN	TEGRA234_MAIN_GPIO(AC, 0)  // ← CAM1 電源控制
#define CAM_I2C_MUX 	TEGRA234_AON_GPIO(CC, 3)

/ {
	overlay-name = "Camera IMX219-C";
	jetson-header-name = "Jetson 24pin CSI Connector";
	compatible = JETSON_COMPATIBLE_P3768;

	// 片段定義:
	fragment@0: VI (Video Input) 配置
		- port-index = <2>  // CSI-C
		- bus-width = <2>   // 2-lane
	
	fragment@1: Tegra Camera Platform
		- num_csi_lanes = <4>
		- max_lane_speed = <1500000>  // 1.5 Gbps/lane
		- 頻寬計算參數
	
	fragment@2: I2C Mux 配置
		- mux-gpios = <&gpio_aon CAM_I2C_MUX>
		- i2c@1: CAM1 通道
			- rbpcv2_imx219_c@10
				- reg = <0x10>  // I2C 地址
				- reset-gpios = <&gpio CAM1_PWDN>
	
	fragment@3: CSI 接收器配置
		- csi_chan1: channel@1
		- port-index = <2>  // CSI-C
}
```

**關鍵特徵**:
- 使用 `i2c@1` (I2C mux 通道 1)
- GPIO `CAM1_PWDN` (AC.0) 控制電源
- CSI port-index = 2 (對應 CSI-C 接口)
- devnode = "video0"

**檔案路徑**:
```bash
build/tmp/work/p3768_0000_p3767_0004-oe4t-linux/nvidia-kernel-oot/36.4.4/nvidia-kernel-oot/hardware/nvidia/t23x/nv-public/overlay/tegra234-p3767-camera-p3768-imx219-C.dts
```

### 3. CAM0 版本: `tegra234-p3767-camera-p3768-imx219-A.dts`

類似 C 版本,但用於 CAM0 (CSI-A 接口):

```dts
差異:
- overlay-name = "Camera IMX219-A"
- port-index = <1>  // CSI-A (vs. CSI-C 的 <2>)
- i2c@0: CAM0 通道 (vs. CAM1 的 i2c@1)
- reset-gpios = <&gpio CAM0_PWDN>  // GPIO H.6
- csi_chan0: channel@0
```

### 4. 雙相機版本: `tegra234-p3767-camera-p3768-imx219-dual.dts`

同時啟用 CAM0 和 CAM1:

```dts
/ {
	overlay-name = "Camera Dual IMX219";
	compatible = JETSON_COMPATIBLE_P3768;

	// 包含完整的雙相機配置
	#include "tegra234-camera-rbpcv2-imx219.dtsi"
	
	// 設定兩個 I2C mux 通道
	fragment-imx219@2 {
		// 啟用 i2c@0 (CAM0)
		// 啟用 i2c@1 (CAM1)
	}
}
```

**使用場景**: 
- 需要同時使用兩個 IMX219 相機
- devnode: video0 (CAM0), video1 (CAM1)
- sensor-id: 0, 1

## 檔案內容範例

### 感測器模式定義 (從 DTSI 中)

```dts
mode0 {  // 3280x2464 @ 21fps
	mclk_khz = "24000";
	num_lanes = "2";
	tegra_sinterface = "serial_c";  // CAM1 使用 serial_c
	phy_mode = "DPHY";
	discontinuous_clk = "yes";
	dpcm_enable = "false";
	cil_settletime = "0";
	
	active_w = "3280";
	active_h = "2464";
	mode_type = "bayer";
	pixel_phase = "rggb";
	csi_pixel_bit_depth = "10";
	readout_orientation = "90";
	line_length = "3448";
	inherent_gain = "1";
	mclk_multiplier = "9.33";
	pix_clk_hz = "182400000";
	
	gain_factor = "16";
	framerate_factor = "1000000";
	exposure_factor = "1000000";
	min_gain_val = "16";      // 1x
	max_gain_val = "256";     // 16x
	step_gain_val = "1";
	default_gain = "16";
	min_hdr_ratio = "1";
	max_hdr_ratio = "1";
	min_framerate = "2000000";   // 2 fps
	max_framerate = "21000000";  // 21 fps
	step_framerate = "1";
	default_framerate = "21000000";
	min_exp_time = "13";         // 13 µs
	max_exp_time = "683709";     // 683 ms
	step_exp_time = "1";
	default_exp_time = "2495";   // 2.495 ms
	embedded_metadata_height = "2";
};

mode2 {  // 1920x1080 @ 30fps
	// ... 類似結構但參數不同
	active_w = "1920";
	active_h = "1080";
	max_framerate = "30000000";  // 30 fps
	// ...
};

mode4 {  // 1280x720 @ 60fps
	active_w = "1280";
	active_h = "720";
	max_framerate = "60000000";  // 60 fps
	// ...
};
```

### I2C 與 GPIO 配置

```dts
cam_i2cmux {
	status = "okay";
	compatible = "i2c-mux-gpio";
	#address-cells = <1>;
	#size-cells = <0>;
	mux-gpios = <&gpio_aon CAM_I2C_MUX GPIO_ACTIVE_HIGH>;
	i2c-parent = <&cam_i2c>;
	
	i2c@0 {  // CAM0
		rbpcv2_imx219_a@10 {
			status = "disabled";  // C 版本中停用
		};
	};
	
	i2c@1 {  // CAM1 ✅
		status = "okay";
		reg = <1>;
		#address-cells = <1>;
		#size-cells = <0>;
		
		rbpcv2_imx219_c@10 {
			reset-gpios = <&gpio CAM1_PWDN GPIO_ACTIVE_HIGH>;
			compatible = "sony,imx219";
			reg = <0x10>;  // I2C 從設備地址
			devnode = "video0";
			physical_w = "3.680";
			physical_h = "2.760";
			sensor_model = "imx219";
			use_sensor_mode_id = "true";
			
			// ... mode0 ~ mode4 定義
			
			ports {
				#address-cells = <1>;
				#size-cells = <0>;
				port@0 {
					reg = <0>;
					rbpcv2_imx219_out1: endpoint {
						port-index = <2>;  // CSI-C
						bus-width = <2>;
						remote-endpoint = <&rbpcv2_imx219_csi_in1>;
					};
				};
			};
		};
	};
};
```

### VI 與 CSI 數據路徑

```dts
// 數據流向: Sensor → CSI → VI → 應用程式

tegra-capture-vi {
	num-channels = <1>;
	ports {
		vi_port1: port@1 {
			reg = <0>;
			rbpcv2_imx219_vi_in1: endpoint {
				port-index = <2>;  // CSI-C
				bus-width = <2>;
				remote-endpoint = <&rbpcv2_imx219_csi_out1>;
			};
		};
	};
};

nvcsi@15a00000 {
	num-channels = <1>;
	csi_chan1: channel@1 {
		reg = <0>;
		ports {
			csi_chan1_port0: port@0 {  // CSI 輸入
				rbpcv2_imx219_csi_in1: endpoint@2 {
					port-index = <2>;
					bus-width = <2>;
					remote-endpoint = <&rbpcv2_imx219_out1>;
				};
			};
			csi_chan1_port1: port@1 {  // CSI 輸出
				rbpcv2_imx219_csi_out1: endpoint@3 {
					remote-endpoint = <&rbpcv2_imx219_vi_in1>;
				};
			};
		};
	};
};
```

## 如何查看完整內容

### 方法 1: 直接查看編譯後的原始碼

```bash
cd /home/andy/proj/tegra-demo-distro

# 查看您使用的 CAM1 配置
cat build/tmp/work/p3768_0000_p3767_0004-oe4t-linux/nvidia-kernel-oot/36.4.4/nvidia-kernel-oot/hardware/nvidia/t23x/nv-public/overlay/tegra234-p3767-camera-p3768-imx219-C.dts

# 查看核心感測器定義
cat build/tmp/work/p3768_0000_p3767_0004-oe4t-linux/nvidia-kernel-oot/36.4.4/nvidia-kernel-oot/hardware/nvidia/t23x/nv-public/overlay/tegra234-camera-rbpcv2-imx219.dtsi

# 使用編輯器
vim build/tmp/work/p3768_0000_p3767_0004-oe4t-linux/nvidia-kernel-oot/36.4.4/nvidia-kernel-oot/hardware/nvidia/t23x/nv-public/overlay/tegra234-p3767-camera-p3768-imx219-C.dts
```

### 方法 2: 查看編譯後的二進位檔案 (反編譯)

```bash
# 反編譯 DTBO
dtc -I dtb -O dts \
    build/tmp/work/p3768_0000_p3767_0004-oe4t-linux/nvidia-kernel-oot-dtb/36.4.4/deploy-nvidia-kernel-oot-dtb/devicetree/tegra234-p3767-camera-p3768-imx219-C.dtbo \
    -o imx219-C-decompiled.dts

# 查看反編譯結果
cat imx219-C-decompiled.dts
```

### 方法 3: 在運行時系統中查看

系統啟動後,Device Tree 會載入到 procfs:

```bash
# 查看相機節點
ls /proc/device-tree/cam_i2cmux/i2c@1/rbpcv2_imx219_c@10/

# 讀取特定屬性
cat /proc/device-tree/cam_i2cmux/i2c@1/rbpcv2_imx219_c@10/compatible
# 輸出: sony,imx219

cat /proc/device-tree/cam_i2cmux/i2c@1/rbpcv2_imx219_c@10/reg
# 輸出: 0x10 (I2C 地址)

# 查看所有屬性
find /proc/device-tree/cam_i2cmux/i2c@1/rbpcv2_imx219_c@10/ -type f | head -20
```

## 原始來源

這些 DTS 檔案來自 NVIDIA 的 `nvidia-kernel-oot` 套件,源碼位於:

```
repos/meta-tegra/recipes-kernel/nvidia-kernel-oot/nvidia-kernel-oot_36.4.4.bb
```

原始壓縮檔在編譯時由 Yocto 下載並解壓縮:

```bash
# 下載目錄
build/downloads/nvidia-kernel-oot-36.4.4-src.tbz2

# 解壓縮後的位置
build/tmp/work/.../nvidia-kernel-oot/36.4.4/nvidia-kernel-oot/
```

## 如果要修改 DTS

### 選項 1: 建立自訂 DTBO (推薦)

```bash
# 1. 在您的 layer 中建立新檔案
mkdir -p layers/meta-tegrademo/recipes-bsp/device-tree/files/

# 2. 複製並修改原始 DTS
cp build/tmp/work/.../overlay/tegra234-p3767-camera-p3768-imx219-C.dts \
   layers/meta-tegrademo/recipes-bsp/device-tree/files/tegra234-p3767-camera-p3768-imx219-C-custom.dts

# 3. 修改參數 (例如改變解析度或幀率)
vim layers/meta-tegrademo/recipes-bsp/device-tree/files/tegra234-p3767-camera-p3768-imx219-C-custom.dts

# 4. 建立 recipe
vim layers/meta-tegrademo/recipes-bsp/device-tree/custom-camera-dtb_1.0.bb
```

### 選項 2: 使用 bbappend 修改

```bash
# 建立 bbappend
vim layers/meta-tegrademo/recipes-kernel/nvidia-kernel-oot/nvidia-kernel-oot-dtb_%.bbappend
```

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://custom-imx219-patch.patch"
```

## 檔案對照表

| 檔案名稱 | 用途 | CSI Port | I2C 通道 | Video 節點 |
|---------|------|----------|---------|-----------|
| `tegra234-camera-rbpcv2-imx219.dtsi` | 核心定義 | - | - | - |
| `tegra234-p3767-camera-p3768-imx219-A.dts` | CAM0 單相機 | CSI-A (1) | i2c@0 | video0 |
| `tegra234-p3767-camera-p3768-imx219-C.dts` ✅ | CAM1 單相機 | CSI-C (2) | i2c@1 | video0 |
| `tegra234-p3767-camera-p3768-imx219-dual.dts` | 雙相機 | 1 & 2 | i2c@0/1 | video0/1 |

## 相關命令

```bash
# 列出所有 DTS 檔案
find build/tmp/work/p3768_0000_p3767_0004-oe4t-linux/nvidia-kernel-oot/36.4.4/nvidia-kernel-oot/hardware/nvidia/t23x/nv-public/overlay/ -name "*.dts" -o -name "*.dtsi"

# 搜尋特定內容
grep -r "sony,imx219" build/tmp/work/p3768_0000_p3767_0004-oe4t-linux/nvidia-kernel-oot/36.4.4/nvidia-kernel-oot/hardware/nvidia/t23x/nv-public/overlay/

# 統計行數
wc -l build/tmp/work/p3768_0000_p3767_0004-oe4t-linux/nvidia-kernel-oot/36.4.4/nvidia-kernel-oot/hardware/nvidia/t23x/nv-public/overlay/tegra234-*imx219*

# 查看編譯後的 DTBO 大小
ls -lh build/tmp/work/p3768_0000_p3767_0004-oe4t-linux/nvidia-kernel-oot-dtb/36.4.4/deploy-nvidia-kernel-oot-dtb/devicetree/*imx219*
```

## 總結

✅ **DTS 原始檔案確實存在**於您的專案中  
✅ 位於 `build/tmp/work/.../nvidia-kernel-oot/36.4.4/nvidia-kernel-oot/hardware/nvidia/t23x/nv-public/overlay/`  
✅ 您使用的是 `tegra234-p3767-camera-p3768-imx219-C.dts` (465 行)  
✅ 核心定義在 `tegra234-camera-rbpcv2-imx219.dtsi` (761 行)  
✅ 可直接查看、修改、或建立自訂版本  

這些檔案包含了 IMX219 相機的完整硬體配置,包括感測器模式、時序參數、GPIO 控制、I2C 通訊、以及與 Tegra234 SoC 的連接方式。
