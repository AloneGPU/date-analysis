#include <ESP8266WiFi.h>
#include <WiFiUdp.h>
#include "wifi_config.h"

const uint16_t DISCOVERY_PORT = 4210;
const uint16_t DATA_PORT = 8080;
const char* DEVICE_NAME = "ESP8266 Sensor Node";
const char* DEVICE_ID = "esp8266_001";

WiFiUDP udp;
WiFiServer server(DATA_PORT);

unsigned long lastDataSendTime = 0;
const unsigned long DATA_INTERVAL = 2000;

float temperature = 20.0;
float humidity = 50.0;
bool temperatureRising = true;
bool humidityRising = false;

void setup() {
  Serial.begin(115200);
  delay(10);
  
  Serial.println();
  Serial.print("Connecting to ");
  Serial.println(WIFI_SSID);
  
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  Serial.println("");
  Serial.println("WiFi connected");
  Serial.println("IP address: ");
  Serial.println(WiFi.localIP());
  
  udp.begin(DISCOVERY_PORT);
  server.begin();
  
  Serial.println("UDP discovery port: " + String(DISCOVERY_PORT));
  Serial.println("TCP data port: " + String(DATA_PORT));
  Serial.println("Device ready!");
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
  
  if (request == "DATA_MONITOR_DISCOVER") {
    Serial.println("Discovery request received from: " + udp.remoteIP().toString());
    
    String reply = "{";
    reply += "\"type\":\"data_monitor_device\",";
    reply += "\"name\":\"" + String(DEVICE_NAME) + "\",";
    reply += "\"deviceId\":\"" + String(DEVICE_ID) + "\",";
    reply += "\"host\":\"" + WiFi.localIP().toString() + "\",";
    reply += "\"port\":" + String(DATA_PORT);
    reply += "}";
    
    udp.beginPacket(udp.remoteIP(), udp.remotePort());
    udp.write((const uint8_t*)reply.c_str(), reply.length());
    udp.endPacket();
    
    Serial.println("Discovery reply sent");
  }
}

void handleClient(WiFiClient client) {
  if (!client.connected()) return;
  
  while (client.connected()) {
    if (client.available()) {
      String line = client.readStringUntil('\n');
      line.trim();
      
      if (line == "ping") {
        Serial.println("Heartbeat received");
      }
    }
    
    unsigned long currentTime = millis();
    if (currentTime - lastDataSendTime >= DATA_INTERVAL) {
      lastDataSendTime = currentTime;
      sendSensorData(client);
    }
    
    delay(10);
  }
}

void sendSensorData(WiFiClient client) {
  updateSimulatedData();
  
  unsigned long timestamp = millis();
  
  String data = "{";
  data += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
  data += "\"timestamp\":" + String(timestamp) + ",";
  data += "\"data\":{";
  data += "\"temperature\":" + String(temperature, 1) + ",";
  data += "\"humidity\":" + String(humidity, 1);
  data += "}}";
  
  client.println(data);
  
  Serial.print("Sent data: ");
  Serial.print("Temperature = ");
  Serial.print(temperature, 1);
  Serial.print("°C, Humidity = ");
  Serial.print(humidity, 1);
  Serial.println("%");
}

void updateSimulatedData() {
  if (temperatureRising) {
    temperature += random(0, 3) * 0.1;
    if (temperature >= 30.0) temperatureRising = false;
  } else {
    temperature -= random(0, 3) * 0.1;
    if (temperature <= 18.0) temperatureRising = true;
  }
  
  if (humidityRising) {
    humidity += random(0, 4) * 0.1;
    if (humidity >= 70.0) humidityRising = false;
  } else {
    humidity -= random(0, 4) * 0.1;
    if (humidity <= 35.0) humidityRising = true;
  }
  
  temperature = constrain(temperature, 15.0, 35.0);
  humidity = constrain(humidity, 30.0, 80.0);
}

void loop() {
  handleDiscovery();
  
  WiFiClient client = server.available();
  if (client) {
    Serial.println("Client connected");
    handleClient(client);
    Serial.println("Client disconnected");
  }
  
  delay(10);
}
