# Quick Start Guide - ESP8266 Sensor Node

## Step 1: Configure WiFi (5 minutes)

Edit the file `wifi_config.h`:

```cpp
const char* WIFI_SSID = "YourActualWiFiName";
const char* WIFI_PASSWORD = "YourActualPassword";
```

## Step 2: Upload to ESP8266 (10 minutes)

### Install ESP8266 Board Support

1. Open Arduino IDE
2. Go to File → Preferences
3. Add this URL to "Additional Board Manager URLs":
   ```
   http://arduino.esp8266.com/stable/package_esp8266com_index.json
   ```
4. Go to Tools → Board → Board Manager
5. Search "ESP8266"
6. Install "ESP8266 by ESP8266 Community"

### Upload the Sketch

1. Open `esp8266_sensor.ino` in Arduino IDE
2. Go to Tools → Board → ESP8266 Boards
3. Select "NodeMCU 1.0 (ESP-12E Module)"
4. Set Tools options:
   - Upload Speed: 115200
   - CPU Frequency: 80 MHz
5. Connect ESP8266 via USB
6. Select correct Port
7. Click Upload button (→)

### Monitor Output

1. Open Serial Monitor (Tools → Serial Monitor)
2. Set baud rate to 115200
3. You should see:
   ```
   WiFi connected
   IP address: 192.168.x.x
   UDP discovery port: 4210
   TCP data port: 8080
   Device ready!
   ```

## Step 3: Connect to Flutter App (2 minutes)

### Option A: Auto Discovery (Recommended)

1. Open your Flutter data monitor app
2. Go to Connection screen
3. Select "WiFi" mode
4. Tap "Scan LAN devices"
5. Wait 4 seconds
6. Select "ESP8266 Sensor Node" from the list
7. App will connect and start receiving data

### Option B: Manual Connection

If auto discovery doesn't work:

1. Note the IP address from Serial Monitor
2. In app, select "WiFi" mode
3. Enter IP address (e.g., 192.168.1.100)
4. Enter port 8080
5. Tap Connect

## Step 4: Verify Data Reception

In your Flutter app:

- Should see real-time temperature and humidity readings
- Data updates every 2 seconds
- Check that values are changing (simulated mode)

## Troubleshooting

### "WiFi connection failed"

- Double-check WiFi name and password in wifi_config.h
- Make sure WiFi is 2.4GHz (not 5GHz)
- Check if router has MAC filtering

### "Device not found in app"

- Ensure phone/tablet is on same WiFi network
- Try manual IP entry
- Check if firewall blocks UDP port 4210
- Some routers block device-to-device broadcasts

### "Connected but no data"

- Check Serial Monitor shows "Client connected"
- Verify app shows connected status
- Try disconnecting and reconnecting

### "Data values not changing"

- Simulated data changes every 2 seconds
- Wait 10-20 seconds to see variation
- Check Serial Monitor for data transmission

## Understanding the Protocol

### Discovery Phase
- App sends UDP broadcast to port 4210
- Message: `DATA_MONITOR_DISCOVER`
- Device responds with JSON containing IP and port

### Data Phase
- App connects via TCP to port 8080
- Device sends JSON data every 2 seconds:
  ```json
  {"device_id":"esp8266_001","timestamp":1234567,"data":{"temperature":24.5,"humidity":55.3}}
  ```
- App may send heartbeat: `ping`

## Customization Options

### Change Device Name
In the sketch, modify:
```cpp
const char* DEVICE_NAME = "My Sensor";
const char* DEVICE_ID = "my_sensor_001";
```

### Change Update Interval
```cpp
const unsigned long DATA_INTERVAL = 5000; // 5 seconds
```

### Enable Real DHT11 Sensor
Use the `esp8266_sensor_dht.ino` version and change:
```cpp
#define USE_REAL_SENSOR true
```

## Next Steps

- Try the enhanced version for better debugging
- Use real DHT11/DHT22 sensor for actual measurements
- Adjust simulation parameters for different data patterns
- Integrate multiple ESP8266 devices

## Support

If issues persist:
1. Check Serial Monitor for error messages
2. Verify all connections and configurations
3. Restart both ESP8266 and app
4. Check network settings on router
