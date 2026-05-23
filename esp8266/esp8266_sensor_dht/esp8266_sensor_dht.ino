#include <ESP8266WiFi.h>
#include <WiFiUdp.h>

#define USE_REAL_SENSOR false

#if USE_REAL_SENSOR
#include <DHT.h>
#define DHT_PIN 2
#define DHT_TYPE DHT11
DHT dht(DHT_PIN, DHT_TYPE);
#endif

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
  
  Serial.println("\n===========================================");
  Serial.println("ESP8266 Temperature & Humidity Data Logger");
  Serial.println("===========================================\n");
  
  #if USE_REAL_SENSOR
  Serial.println("Mode: Real DHT11 Sensor");
  dht.begin();
  #else
  Serial.println("Mode: Simulated Data");
  #endif
  
  connectToWiFi();
  
  udp.begin(DISCOVERY_PORT);
  server.begin();
  
  Serial.println("\n=== Device Configuration ===");
  Serial.print("Device Name: ");
  Serial.println(DEVICE_NAME);
  Serial.print("Device ID: ");
  Serial.println(DEVICE_ID);
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());
  Serial.print("MAC Address: ");
  Serial.println(WiFi.macAddress());
  Serial.print("Discovery Port: ");
  Serial.println(DISCOVERY_PORT);
  Serial.print("Data Port: ");
  Serial.println(DATA_PORT);
  Serial.print("Data Interval: ");
  Serial.print(DATA_INTERVAL_MS);
  Serial.println(" ms");
  Serial.println("============================\n");
  
  Serial.println("Ready! Waiting for app connection...\n");
}

void connectToWiFi() {
  Serial.print("Connecting to: ");
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
    Serial.println("\n\n✓ WiFi Connected Successfully!");
    Serial.print("  IP Address: ");
    Serial.println(WiFi.localIP());
    Serial.print("  Signal Strength: ");
    Serial.print(WiFi.RSSI());
    Serial.println(" dBm");
    Serial.print("  Connection Time: ");
    Serial.print(attempts * 0.5);
    Serial.println(" seconds");
  } else {
    Serial.println("\n\n✗ WiFi Connection Failed!");
    Serial.println("Please check your WiFi credentials.");
    Serial.println("System will retry automatically...\n");
  }
}

void processDiscovery() {
  int packetSize = udp.parsePacket();
  if (packetSize == 0) return;
  
  char buffer[256];
  int len = udp.read(buffer, sizeof(buffer) - 1);
  if (len <= 0) return;
  buffer[len] = '\0';
  
  String request = String(buffer);
  request.trim();
  
  Serial.println("\n>>> Discovery Request Received");
  Serial.print("    From: ");
  Serial.print(udp.remoteIP().toString());
  Serial.print(":");
  Serial.println(udp.remotePort());
  Serial.print("    Message: ");
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
    
    Serial.println("    Response sent successfully");
  }
}

void handleClient(WiFiClient client) {
  if (!client.connected()) return;
  
  Serial.println("\n===========================================");
  Serial.println("        CLIENT CONNECTED");
  Serial.println("===========================================");
  connectionCount++;
  
  Serial.print("Connection #");
  Serial.println(connectionCount);
  Serial.print("Client IP: ");
  Serial.println(client.remoteIP().toString());
  Serial.print("Connected: ");
  Serial.println(millis() - bootTime);
  Serial.println("ms after boot");
  
  unsigned long connectedTime = millis();
  
  while (client.connected()) {
    if (client.available()) {
      String line = client.readStringUntil('\n');
      line.trim();
      
      if (line.length() > 0) {
        if (line == "ping") {
          Serial.println("Heartbeat (ping) received");
        } else {
          Serial.print("Command: ");
          Serial.println(line);
        }
      }
    }
    
    unsigned long now = millis();
    if (now - lastDataTime >= DATA_INTERVAL_MS) {
      lastDataTime = now;
      sendSensorData(client);
    }
    
    delay(10);
  }
  
  Serial.println("\nClient disconnected");
  Serial.println("Session duration: " + String(millis() - connectedTime) + " ms");
  Serial.println("===========================================\n");
}

void sendSensorData(WiFiClient client) {
  #if USE_REAL_SENSOR
  float h = dht.readHumidity();
  float t = dht.readTemperature();
  
  if (isnan(h) || isnan(t)) {
    Serial.println("Sensor read error!");
    return;
  }
  
  temperature = t;
  humidity = h;
  #else
  simulateData();
  #endif
  
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
  
  Serial.print("[Packet #");
  Serial.print(packetsSent);
  Serial.print("] Temperature: ");
  Serial.print(temperature, 1);
  Serial.print("°C | Humidity: ");
  Serial.print(humidity, 1);
  Serial.println("%");
  
  #if USE_REAL_SENSOR
  Serial.print("    (Actual sensor reading)");
  #else
  Serial.print("    (Simulated data)");
  #endif
  Serial.println();
}

void simulateData() {
  float tempDelta = (random(-3, 4) * 0.1);
  float humidDelta = (random(-4, 5) * 0.1);
  
  if (tempRising) {
    temperature += 0.05 + tempDelta;
    if (temperature >= 30.0) tempRising = false;
  } else {
    temperature -= 0.05 + abs(tempDelta);
    if (temperature <= 18.0) tempRising = true;
  }
  
  if (humidRising) {
    humidity += 0.05 + humidDelta;
    if (humidity >= 70.0) humidRising = false;
  } else {
    humidity -= 0.05 + abs(humidDelta);
    if (humidity <= 35.0) humidRising = true;
  }
  
  temperature = constrain(temperature, 15.0, 35.0);
  humidity = constrain(humidity, 30.0, 80.0);
}

void loop() {
  processDiscovery();
  
  WiFiClient client = server.available();
  if (client) {
    handleClient(client);
  }
  
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("\nWiFi connection lost! Reconnecting...\n");
    connectToWiFi();
  }
  
  delay(5);
}
