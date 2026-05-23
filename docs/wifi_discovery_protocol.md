# WiFi Discovery Protocol

This document describes the LAN discovery protocol used by the app when the user chooses WiFi communication and taps "Scan LAN devices".

The goal is to discover only embedded data devices that are willing to communicate with this host app. It is not a WiFi SSID scan and it does not connect to routers or hotspots.

## App Discovery Request

- Transport: UDP broadcast
- Destination address: `255.255.255.255`
- Destination port: `4210` by default
- Extra destination port: the port typed in the WiFi port field, if it is different from `4210`
- Payload encoding: UTF-8 text
- Payload:

```text
DATA_MONITOR_DISCOVER
```

The app listens for replies for about 4 seconds.

## Device Discovery Reply

The embedded device should reply by UDP to the source IP and source port of the discovery request.

Recommended JSON reply:

```json
{
  "type": "data_monitor_device",
  "name": "ESP32 Sensor Node",
  "deviceId": "sensor_001",
  "host": "192.168.1.100",
  "port": 8080
}
```

Fields:

| Field | Required | Description |
| --- | --- | --- |
| `type` | Yes | Must be `data_monitor_device`. |
| `name` | No | Display name shown in the app device list. |
| `deviceId` | No | Device identifier shown in the app list. |
| `host` | No | TCP server IP address. If omitted, the app uses the UDP sender IP. |
| `port` | Yes | TCP data port used after the user selects and connects. |

Legacy text reply is also accepted:

```text
DATA_MONITOR_DEVICE,name=ESP32 Sensor Node,deviceId=sensor_001,host=192.168.1.100,port=8080
```

## Data Connection After Selection

After the user selects a discovered device, the app fills the WiFi host and port fields, then connects with TCP.

Each sensor data message should be one JSON object followed by a newline:

```json
{"device_id":"sensor_001","timestamp":1640000000000,"data":{"temperature":25.5,"humidity":60.0}}
```

The app also sends this heartbeat over TCP about every 30 seconds:

```text
ping
```

The device may ignore it or reply with its own heartbeat message.

## ESP32 Arduino Example

```cpp
#include <WiFi.h>
#include <WiFiUdp.h>

const char* ssid = "your-ssid";
const char* password = "your-password";

const uint16_t discoveryPort = 4210;
const uint16_t dataPort = 8080;

WiFiUDP udp;
WiFiServer server(dataPort);

void setup() {
  Serial.begin(115200);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
  }

  udp.begin(discoveryPort);
  server.begin();
}

void handleDiscovery() {
  int packetSize = udp.parsePacket();
  if (packetSize <= 0) return;

  char buffer[128];
  int len = udp.read(buffer, sizeof(buffer) - 1);
  if (len <= 0) return;
  buffer[len] = '\0';

  String request = String(buffer);
  request.trim();
  if (request != "DATA_MONITOR_DISCOVER") return;

  String reply = "{";
  reply += "\"type\":\"data_monitor_device\",";
  reply += "\"name\":\"ESP32 Sensor Node\",";
  reply += "\"deviceId\":\"sensor_001\",";
  reply += "\"host\":\"" + WiFi.localIP().toString() + "\",";
  reply += "\"port\":" + String(dataPort);
  reply += "}";

  udp.beginPacket(udp.remoteIP(), udp.remotePort());
  udp.write((const uint8_t*)reply.c_str(), reply.length());
  udp.endPacket();
}

void handleClient() {
  WiFiClient client = server.available();
  if (!client) return;

  while (client.connected()) {
    String data = "{\"device_id\":\"sensor_001\",\"timestamp\":";
    data += String(millis());
    data += ",\"data\":{\"temperature\":25.5,\"humidity\":60.0}}";
    client.println(data);
    delay(1000);
  }
}

void loop() {
  handleDiscovery();
  handleClient();
}
```

## Troubleshooting

- The phone or PC and the embedded device must be on the same LAN.
- Some routers block broadcast between wireless clients. Disable AP/client isolation if discovery does not work.
- On Windows, allow the EXE through the firewall for private networks.
- If discovery fails but TCP works, manually type the device IP and port.
- If the device uses a different discovery port, type that port into the app's WiFi port field before scanning.
