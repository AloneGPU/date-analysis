# ESP8266 Temperature and Humidity Sensor

This is an ESP8266 sketch that generates simulated temperature and humidity data and sends it to your data monitor app via WiFi.

## Features

- Connects to WiFi network
- UDP discovery protocol (compatible with your Flutter app)
- TCP data server for continuous data transmission
- Simulated temperature and humidity data with realistic variation

## Files

- `wifi_config.h` - WiFi configuration (SSID and password)
- `esp8266_sensor/esp8266_sensor.ino` - Main Arduino sketch

## Setup Instructions

### 1. Configure WiFi Credentials

Edit `wifi_config.h`:

```cpp
#ifndef WIFI_CONFIG_H
#define WIFI_CONFIG_H

const char* WIFI_SSID = "Your_WiFi_SSID";
const char* WIFI_PASSWORD = "Your_WiFi_Password";

#endif
```

Replace `Your_WiFi_SSID` and `Your_WiFi_Password` with your actual WiFi credentials.

### 2. Install Required Libraries

In Arduino IDE, install these libraries:
- ESP8266 (Board package)
- No additional libraries needed (uses built-in WiFi libraries)

### 3. Configure Arduino IDE

1. Go to File → Preferences
2. Add this URL to "Additional Board Manager URLs":
   ```
   http://arduino.esp8266.com/stable/package_esp8266com_index.json
   ```
3. Go to Tools → Board → Board Manager
4. Install "ESP8266 by ESP8266 Community"

### 4. Select Board and Upload

1. Go to Tools → Board → ESP8266 Boards
2. Select "NodeMCU 1.0 (ESP-12E Module)" or "Generic ESP8266 Module"
3. Configure these settings:
   - Upload Speed: 115200
   - CPU Frequency: 80 MHz
   - Flash Size: 4M (1M SPIFFS)
4. Connect your ESP8266 via USB
5. Select the correct Port
6. Click Upload

### 5. Monitor Serial Output

1. Open Serial Monitor (Tools → Serial Monitor)
2. Set baud rate to 115200
3. You should see:
   ```
   Connecting to Your_WiFi_SSID
   WiFi connected
   IP address: 192.168.x.x
   UDP discovery port: 4210
   TCP data port: 8080
   Device ready!
   ```

## Connection to Flutter App

### Using LAN Discovery

1. Open your Flutter data monitor app
2. Go to Connection screen
3. Select "WiFi" communication mode
4. Tap "Scan LAN devices"
5. You should see "ESP8266 Sensor Node" appear in the device list
6. Select the device
7. The app will connect and start receiving data

### Manual Connection

If discovery doesn't work:

1. Note the IP address shown in Serial Monitor (e.g., 192.168.1.100)
2. In the app, enter the IP address manually
3. Set port to 8080
4. Tap Connect

## Data Format

The ESP8266 sends data in this JSON format every 2 seconds:

```json
{"device_id":"esp8266_001","timestamp":1234567,"data":{"temperature":24.5,"humidity":55.3}}
```

## Customization

### Change Device Name

In `esp8266_sensor.ino`, modify:

```cpp
const char* DEVICE_NAME = "ESP8266 Sensor Node";
const char* DEVICE_ID = "esp8266_001";
```

### Change Data Interval

Modify the interval (in milliseconds):

```cpp
const unsigned long DATA_INTERVAL = 2000; // 2 seconds
```

### Change Simulated Data Range

In `updateSimulatedData()`:

```cpp
if (temperature >= 30.0) temperatureRising = false;  // Max temperature
if (temperature <= 18.0) temperatureRising = true; // Min temperature

if (humidity >= 70.0) humidityRising = false;       // Max humidity
if (humidity <= 35.0) humidityRising = true;        // Min humidity
```

## Troubleshooting

### Device Not Found in App

1. Make sure phone/tablet and ESP8266 are on the same WiFi network
2. Check Serial Monitor for connection status
3. Try manual IP address entry
4. Ensure no firewall blocking UDP port 4210

### Connection Drops

1. Check WiFi signal strength
2. Move ESP8266 closer to router
3. Check Serial Monitor for error messages

### No Data Received

1. Verify TCP connection is established
2. Check app's connection status indicator
3. Look at Serial Monitor for "Client connected" message

## Using Real Sensors (Optional)

To use real DHT11/DHT22 sensors instead of simulated data:

1. Connect DHT sensor:
   - VCC → 3.3V
   - GND → GND
   - DATA → D4 (GPIO2)

2. Install DHT library in Arduino IDE

3. Replace `updateSimulatedData()` with actual sensor reading:

```cpp
#include <DHT.h>
DHT dht(D4, DHT11);

void setup() {
  dht.begin();
}

void updateSimulatedData() {
  temperature = dht.readTemperature();
  humidity = dht.readHumidity();
}
```

## License

This code is provided as part of your data monitoring system project.

## Support

For issues with the ESP8266 code, check:
- Arduino IDE serial monitor for error messages
- WiFi connectivity
- Network firewall settings
