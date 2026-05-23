#include <ESP8266WiFi.h>
#include <WiFiUdp.h>

#define WIFI_SSID "Your_WiFi_SSID"
#define WIFI_PASSWORD "Your_WiFi_Password"

#define DISCOVERY_PORT 4210
#define DATA_PORT 8080
#define DEVICE_NAME "ESP8266 Sensor Node"
#define DEVICE_ID "esp8266_001"
#define DATA_INTERVAL_MS 2000

WiFiUDP udp;
WiFiServer server(DATA_PORT);

unsigned long lastDataTime = 0;
float temperature = 22.5;
float humidity = 55.0;
bool tempRising = true;
bool humidRising = false;

unsigned long bootTime;
int connectionCount = 0;
int packetsSent = 0;

void setup() {
  Serial.begin(115200);
  bootTime = millis();
  
  Serial.println("\n\n=================================");
  Serial.println("ESP8266 Temperature & Humidity Sensor");
  Serial.println("=================================\n");
  
  connectToWiFi();
  
  udp.begin(DISCOVERY_PORT);
  server.begin();
  
  Serial.println("\n=== Network Configuration ===");
  Serial.print("Device Name: ");
  Serial.println(DEVICE_NAME);
  Serial.print("Device ID: ");
  Serial.println(DEVICE_ID);
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());
  Serial.print("Discovery Port (UDP): ");
  Serial.println(DISCOVERY_PORT);
  Serial.print("Data Port (TCP): ");
  Serial.println(DATA_PORT);
  Serial.print("Data Interval: ");
  Serial.print(DATA_INTERVAL_MS);
  Serial.println(" ms");
  Serial.println("===============================\n");
  
  Serial.println("System ready! Waiting for connections...\n");
}

void connectToWiFi() {
  Serial.print("Connecting to WiFi: ");
  Serial.println(WIFI_SSID);
  
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n\n✓ WiFi Connected!");
    Serial.print("  IP: ");
    Serial.println(WiFi.localIP());
    Serial.print("  Signal: ");
    Serial.print(WiFi.RSSI());
    Serial.println(" dBm");
  } else {
    Serial.println("\n\n✗ WiFi Connection Failed!");
    Serial.println("Check your credentials and try again.");
    while(1) {
      delay(1000);
    }
  }
}

void processDiscoveryRequest() {
  int packetSize = udp.parsePacket();
  if (packetSize == 0) return;
  
  char buffer[256];
  int len = udp.read(buffer, sizeof(buffer) - 1);
  if (len <= 0) return;
  buffer[len] = '\0';
  
  String request = String(buffer);
  request.trim();
  
  Serial.print("Discovery request from ");
  Serial.print(udp.remoteIP().toString());
  Serial.print(":");
  Serial.print(udp.remotePort());
  Serial.print(" - ");
  Serial.println(request);
  
  if (request == "DATA_MONITOR_DISCOVER") {
    String reply = "{";
    reply += "\"type\":\"data_monitor_device\",";
    reply += "\"name\":\"" + String(DEVICE_NAME) + "\",";
    reply += "\"deviceId\":\"" + String(DEVICE_ID) + "\",";
    reply += "\"host\":\"" + WiFi.localIP().toString() + "\",";
    reply += "\"port\":" + String(DATA_PORT);
    reply += "}";
    
    udp.beginPacket(udp.remoteIP(), udp.remotePort());
    udp.write(reply.c_str());
    udp.endPacket();
    
    Serial.println("Discovery response sent");
  }
}

void handleClient(WiFiClient client) {
  if (!client.connected()) return;
  
  Serial.println("\n--- Client Connected ---");
  connectionCount++;
  Serial.print("Connection #");
  Serial.println(connectionCount);
  
  while (client.connected()) {
    if (client.available()) {
      String line = client.readStringUntil('\n');
      line.trim();
      
      if (line.length() > 0) {
        if (line == "ping") {
          Serial.println("Heartbeat received (ping)");
        } else {
          Serial.print("Received: ");
          Serial.println(line);
        }
      }
    }
    
    unsigned long now = millis();
    if (now - lastDataTime >= DATA_INTERVAL_MS) {
      lastDataTime = now;
      sendData(client);
    }
    
    delay(10);
  }
  
  Serial.println("Client disconnected");
}

void sendData(WiFiClient client) {
  updateSensorValues();
  
  unsigned long timestamp = millis();
  
  String data = "{";
  data += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
  data += "\"timestamp\":" + String(timestamp) + ",";
  data += "\"data\":{";
  data += "\"temperature\":" + String(temperature, 1) + ",";
  data += "\"humidity\":" + String(humidity, 1);
  data += "}}";
  
  client.println(data);
  packetsSent++;
  
  Serial.print("[");
  Serial.print(packetsSent);
  Serial.print("] Sent: T=");
  Serial.print(temperature, 1);
  Serial.print("°C, H=");
  Serial.print(humidity, 1);
  Serial.println("%");
}

void updateSensorValues() {
  float tempChange = (random(0, 6) * 0.1) - 0.25;
  float humidChange = (random(0, 8) * 0.1) - 0.35;
  
  temperature += tempChange;
  if (temperature >= 30.0) tempRising = false;
  else if (temperature <= 18.0) tempRising = true;
  
  humidity += humidChange;
  if (humidity >= 70.0) humidRising = false;
  else if (humidity <= 35.0) humidRising = true;
  
  if (tempRising) temperature += 0.05;
  else temperature -= 0.05;
  
  if (humidRising) humidity += 0.05;
  else humidity -= 0.05;
  
  temperature = constrain(temperature, 15.0, 35.0);
  humidity = constrain(humidity, 30.0, 80.0);
}

void loop() {
  processDiscoveryRequest();
  
  WiFiClient client = server.available();
  if (client) {
    handleClient(client);
  }
  
  delay(5);
}
