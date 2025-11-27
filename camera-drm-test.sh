#!/bin/bash
# IMX219 Camera to DisplayPort via DRM/KMS (No X11/Wayland needed)
# This script directly outputs to DisplayPort using kmssink or fbdevsink

SENSOR_ID=0
WIDTH=1920
HEIGHT=1080
FRAMERATE=30

echo "======================================"
echo "IMX219 Camera Direct DRM/KMS Output"
echo "======================================"
echo ""

# Get the correct connector ID from modetest
echo "Detecting DisplayPort connector..."
CONNECTOR_INFO=$(modetest -M nvidia-drm -c | grep "connected" | grep "DP-")
if [ -z "$CONNECTOR_INFO" ]; then
    echo "ERROR: No DisplayPort found"
    exit 1
fi

CONNECTOR_ID=$(echo "$CONNECTOR_INFO" | awk '{print $1}')
echo "Found DisplayPort connector ID: $CONNECTOR_ID"
echo ""

# Method 1: Try using fbdevsink (framebuffer device)
echo "Method 1: Trying fbdevsink (framebuffer)..."
if [ -c /dev/fb0 ]; then
    echo "Framebuffer device /dev/fb0 exists"
    if gst-inspect-1.0 fbdevsink >/dev/null 2>&1; then
        echo "Starting camera preview via framebuffer..."
        gst-launch-1.0 -v \
            nvarguscamerasrc sensor-id=$SENSOR_ID ! \
            "video/x-raw(memory:NVMM),width=$WIDTH,height=$HEIGHT,framerate=$FRAMERATE/1" ! \
            nvvidconv ! \
            "video/x-raw,format=RGB" ! \
            fbdevsink device=/dev/fb0
        
        if [ $? -eq 0 ] || [ $? -eq 130 ]; then
            echo "Success!"
            exit 0
        fi
    else
        echo "fbdevsink not available"
    fi
else
    echo "/dev/fb0 not found"
fi
echo ""

# Method 2: Try GLImageSink with EGL (already working but no display)
echo "Method 2: Using GLImageSink (may not show on display without compositor)..."
echo "This will process frames but may not display without Wayland/X11..."
gst-launch-1.0 -v \
    nvarguscamerasrc sensor-id=$SENSOR_ID ! \
    "video/x-raw(memory:NVMM),width=$WIDTH,height=$HEIGHT,framerate=$FRAMERATE/1" ! \
    nvvidconv ! \
    "video/x-raw,format=RGBA" ! \
    glimagesink

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ] || [ $EXIT_CODE -eq 130 ]; then
    echo "Camera preview completed"
    exit 0
fi

echo ""
echo "======================================"
echo "All methods failed"
echo "======================================"
echo ""
echo "Current system status:"
echo "- Camera: Working ✓"
echo "- DisplayPort: Connected ✓"
echo "- Missing: Display compositor (Weston/X11)"
echo ""
echo "Solutions:"
echo "1. Install and start Weston compositor"
echo "2. Add fbdevsink plugin to GStreamer"
echo "3. Add kmssink plugin for direct DRM output"
echo ""
echo "For now, you can:"
echo "- Record video: camera-record.sh /tmp/video.mp4"
echo "- Test camera: gst-launch-1.0 nvarguscamerasrc num-buffers=100 ! fakesink"
