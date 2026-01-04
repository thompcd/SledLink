# SledLink Firmware Upload Guide

This guide explains how to upload firmware to your SledLink controllers. No technical knowledge is required - just follow the steps below.

## Getting SledLink

The latest SledLink release package is available on GitHub:

**[Download Latest Release](https://github.com/thompcd/SledLink/releases/latest)**

Each release includes:
- Arduino source code for both controllers
- Upload scripts for Windows, Mac, and Linux
- This guide

---

## What You'll Need

1. **Your SledLink controller** (either the Sled or Judge unit)
2. **A USB cable** (micro-USB, the same type used for many Android phones)
3. **A Windows computer**
4. **No internet connection needed** for flashing!

---

## Upload Your Firmware

Firmware is compiled fresh from source code during upload. This ensures compatibility with your system and allows for easy customization.

---

### Windows

1. **Download the SledLink folder** to your computer from GitHub
2. **Extract the ZIP file** to a convenient location
3. **Double-click** `Upload Firmware (Windows).bat` in the main folder
4. **Follow the prompts** on screen
5. The compilation and upload happens automatically

### Mac

1. **Download the SledLink folder** to your computer
2. **Open Terminal** (press Cmd+Space, type "Terminal", press Enter)
3. **Navigate to the SledLink folder:**
   ```
   cd ~/Downloads/SledLink
   ```
   (Replace `~/Downloads/SledLink` with wherever you saved it)
4. **Make the script executable** (only needed once):
   ```
   chmod +x upload_firmware.sh
   ```
5. **Run the script:**
   ```
   ./upload_firmware.sh
   ```
6. **Follow the prompts** on screen

### Linux - Compile from Source

1. **Download the SledLink folder** to your computer
2. **Open a terminal** in that folder
3. **Make the script executable** (only needed once):
   ```
   chmod +x upload_firmware.sh
   ```
4. **Run the script:**
   ```
   ./upload_firmware.sh
   ```
5. **Follow the prompts** on screen

---

### How Upload Works

1. **Checks for Arduino CLI** - The build tool. Installs it if needed.
2. **Sets up ESP32 support** - Downloads ESP32 tools (first time only, ~500MB)
3. **Asks which controller** - Sled or Judge
4. **Finds your controller** - Detects the connected USB device
5. **Compiles and uploads** - Builds fresh firmware from source and writes to your controller

---

## Troubleshooting

### "No serial devices found"

Your controller might not be connected or recognized by Windows.

Try these in order:

1. **Different USB cable** - Some cables are "charge-only" and don't carry data
2. **Different USB port** - Try another port on your computer
3. **Wait a few seconds** after plugging in for Windows to recognize the device
4. **Check Device Manager:**
   - Press `Win+X`, select "Device Manager"
   - Look for your device under "Ports (COM & LPT)"
   - If it shows a warning icon, you need USB drivers (see "USB Driver Issues" below)

### "Upload failed" or timeout error

1. **Hold the BOOT button** on the ESP32 board during the first 5 seconds of upload
   - The upload tool will tell you when it's starting
   - You can release BOOT after it begins
2. **Try a different USB cable** (charge-only cables won't work)
3. **Try a different USB port**
4. **Close other programs** that might be using the serial port (Arduino IDE, PuTTY, etc.)
5. **Try restarting your computer**

### Windows: "Script won't run" or security error

- **Right-click** `Upload Firmware (Windows).bat` and select **"Run as administrator"**
- If Windows SmartScreen blocks it, click **"More info"** then **"Run anyway"**
- **Temporary solution:** Run from Command Prompt: `"Upload Firmware (Windows).bat"`

### USB Driver Issues

If Windows doesn't recognize your device:

**CP210x drivers** (for some ESP32 boards):
- Download: [CP210x USB to UART Bridge VCP Drivers](https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers)
- Install and restart your computer

**CH340 drivers** (for other ESP32 boards):
- Download: CH340 drivers (search "CH340 driver Windows")
- Install and restart your computer

If you're not sure which driver you need, try one - it won't hurt to have both installed.

### Mac: "Permission denied"

Run this command first:
```
chmod +x upload_firmware.sh
```

### Mac: "Developer cannot be verified"

If macOS says the script can't be opened:
1. Open **System Preferences** → **Security & Privacy**
2. Click **"Allow Anyway"** next to the blocked app message
3. Try running the script again

### Linux: "Permission denied" or dialout group

If you get permission errors accessing the serial port:
```
sudo usermod -a -G dialout $USER
```
Then **log out and back in** for the change to take effect.

## Which Controller is Which?

### Sled Controller
- Goes **on the sled**
- Has the **measuring wheel encoder** connected
- **Sends** distance data wirelessly

### Judge Controller
- Stays at the **judge's table**
- **Receives** and displays distance
- No encoder connected

## After Flashing or Uploading Firmware

After your controller has been updated (whether using flash or compile method):

1. The controller will **restart automatically**
2. The LCD should show "SledLink" and then the startup screen
3. Your system is ready to use!
4. For compile-from-source method: You can use the **serial monitor** option in the script to see diagnostic output

## Need Help?

If you're still having problems:

1. **Check the USB cable** - This is the #1 cause of issues
2. **Try the other computer** if one is available
3. **Contact support** with a description of the error message you see
