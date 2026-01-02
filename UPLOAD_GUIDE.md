# SledLink Firmware Upload Guide

This guide explains how to upload firmware to your SledLink controllers. No technical knowledge is required - just follow the steps below.

## What You'll Need

1. **Your SledLink controller** (either the Sled or Judge unit)
2. **A USB cable** (micro-USB, the same type used for many Android phones)
3. **A computer** (Windows, Mac, or Linux)
4. **An internet connection** (only needed the first time to download tools)

---

## Two Options

There are two ways to upload firmware:

| Method | Best For | What It Does |
|--------|----------|--------------|
| **Flash Pre-Compiled** | Field use, quick updates | Uses ready-to-go firmware files |
| **Compile from Source** | Developers, customization | Builds firmware from source code |

**For most users, we recommend "Flash Pre-Compiled"** - it's faster and simpler.

---

## Option 1: Flash Pre-Compiled Firmware (Recommended)

This is the **easiest method**. Use this if you downloaded a release package.

### Windows

1. **Download the SledLink release** and unzip it
2. **Double-click** `Flash Firmware (Windows).bat`
3. **Follow the prompts** on screen

### Mac / Linux

1. **Download the SledLink release** and unzip it
2. **Open Terminal** in that folder
3. **Run:**
   ```
   chmod +x flash_firmware.sh   # only needed once
   ./flash_firmware.sh
   ```
4. **Follow the prompts** on screen

---

## Option 2: Compile from Source

Use this if you need to modify the firmware or don't have pre-compiled binaries.

### Windows

1. **Download the SledLink folder** to your computer
2. **Double-click** `Upload Firmware (Windows).bat`
3. **Follow the prompts** on screen

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

### Linux

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

## What the Scripts Do

### Flash Script (Pre-Compiled)
1. **Checks for esptool** - A simple flashing tool. Installs it if needed.
2. **Asks which controller** - Sled or Judge
3. **Finds your controller** - Detects the connected USB device
4. **Flashes the firmware** - Writes the pre-compiled binary to the controller

### Upload Script (From Source)
1. **Checks for Arduino CLI** - The build tool. Installs it if needed.
2. **Sets up ESP32 support** - Downloads ESP32 tools (first time only)
3. **Asks which controller** - Sled or Judge
4. **Finds your controller** - Detects the connected USB device
5. **Compiles and uploads** - Builds from source and writes to controller

## Troubleshooting

### "No serial devices found"

- **Try a different USB cable.** Some cables are "charge only" and don't have data wires.
- **Try a different USB port** on your computer.
- **Wait a few seconds** after plugging in for drivers to load.
- **Check Device Manager** (Windows) to see if the device appears with a warning icon.

### "Upload failed"

- **Unplug and replug** the USB cable, then try again.
- **Hold the BOOT button** on the ESP32 while the upload starts, then release it.
- **Close other programs** that might be using the serial port (like Arduino IDE or PuTTY).

### Windows: "Script won't run" or security error

- **Right-click** the `.bat` file and select **"Run as administrator"**
- If Windows SmartScreen blocks it, click **"More info"** then **"Run anyway"**

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

## After Uploading

After firmware is uploaded:

1. The controller will **restart automatically**
2. The LCD should show "SledLink" and then the startup screen
3. You can use the **serial monitor** option in the script to see diagnostic output

## Need Help?

If you're still having problems:

1. **Check the USB cable** - This is the #1 cause of issues
2. **Try the other computer** if one is available
3. **Contact support** with a description of the error message you see
