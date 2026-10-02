/**
 * -------------------------------------------------------------
 * Aqlli Uy (Smart House) - ESP32 Asosiy Dastur Kodi
 * Muallif: Aqlli Uy Ovozli Boshqaruv Tizimi
 * Vazifasi: Ovozli va mobil ilova orqali boshqariladigan aqlli uy
 * -------------------------------------------------------------
 */

#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include <ESP32Servo.h>

// ================= Wi-Fi Sozlamalari =================
const char* WIFI_SSID = "UYINGIZ_WIFI_NOMI";
const char* WIFI_PASSWORD = "WIFI_PAROLI";

// ================= MQTT Broker Sozlamalari =================
// Masalan, bepul HiveMQ Cloud yoki EMQX brokeri (yoki shaxsiy broker)
const char* MQTT_BROKER = "broker.hivemq.com";
const int   MQTT_PORT   = 1883;
const char* MQTT_TOPIC_SUB = "smarthouse/command";   // Buyruqlarni qabul qilish
const char* MQTT_TOPIC_PUB = "smarthouse/state";     // Datchiklar va holatni yuborish

// ================= PINLARNI BELGILASH =================
#define RELAY_LIVING_ROOM  23   // Mehmonxona chirog'i
#define RELAY_KITCHEN      22   // Oshxona chirog'i
#define RELAY_BEDROOM      21   // Yotoqxona chirog'i
#define RELAY_FAN          19   // Ventilyator / Sovutgich

#define DHTPIN             4    // DHT11/DHT22 signali
#define DHTTYPE            DHT11 

#define MQ2_PIN            34   // Gaz va tutun datchigi (Analog)
#define PIR_PIN            18   // PIR harakat datchigi
#define SERVO_PIN          13   // Aqlli eshik qulfi
#define BUZZER_PIN         25   // Xavfsizlik signali (Buzzer)

// ================= OBYEKTLAR VA O'ZGARUVCHILAR =================
WiFiClient espClient;
PubSubClient client(espClient);
DHT dht(DHTPIN, DHTTYPE);
Servo doorServo;

// Tizim holatlari
bool state_living_room = false;
bool state_kitchen = false;
bool state_bedroom = false;
bool state_fan = false;
bool door_locked = true;
bool security_active = true;

// Vaqt hisoblagichlari
unsigned long lastSensorPublish = 0;
const long SENSOR_INTERVAL = 3000; // Har 3 sekundda holat yuborish

// ================= FUNKSIYA E'LONLARI =================
void setupWiFi();
void reconnectMQTT();
void callback(char* topic, byte* payload, unsigned int length);
void handleCommand(String action, String target, int value);
void publishHouseState();
void checkSensorsAndAlerts();

void setup() {
  Serial.begin(115200);
  Serial.println("\n--- Aqlli Uy Tizimi Ishga Tushmoqda ---");

  // Chiqish pinlarini sozlash
  pinMode(RELAY_LIVING_ROOM, OUTPUT);
  pinMode(RELAY_KITCHEN, OUTPUT);
  pinMode(RELAY_BEDROOM, OUTPUT);
  pinMode(RELAY_FAN, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);

  // Relelarni boshlang'ich holatda o'chirish (Odatda relelar LOW da yoqiladi, HIGH da o'chadi)
  digitalWrite(RELAY_LIVING_ROOM, HIGH);
  digitalWrite(RELAY_KITCHEN, HIGH);
  digitalWrite(RELAY_BEDROOM, HIGH);
  digitalWrite(RELAY_FAN, HIGH);
  digitalWrite(BUZZER_PIN, LOW);

  // Kirish pinlarini sozlash
  pinMode(MQ2_PIN, INPUT);
  pinMode(PIR_PIN, INPUT);

  // Datchiklar va Servoni ishga tushirish
  dht.begin();
  doorServo.attach(SERVO_PIN);
  doorServo.write(0); // Eshik qulflangan holatda (0 gradus)

  // Tarmoq ulanishlari
  setupWiFi();
  client.setServer(MQTT_BROKER, MQTT_PORT);
  client.setCallback(callback);
}

void loop() {
  if (!client.connected()) {
    reconnectMQTT();
  }
  client.loop();

  // Datchiklar va xavfsizlikni tekshirish
  checkSensorsAndAlerts();

  // Vaqti-vaqti bilan barcha datchik ma'lumotlarini mobil ilovaga yuborib turish
  unsigned long now = millis();
  if (now - lastSensorPublish > SENSOR_INTERVAL) {
    lastSensorPublish = now;
    publishHouseState();
  }
}

// Wi-Fi ga ulanish
void setupWiFi() {
  delay(10);
  Serial.printf("\nWi-Fi tarmog'iga ulanmoqda: %s", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\nWi-Fi muvaffaqiyatli ulandi!");
  Serial.print("ESP32 IP manzili: ");
  Serial.println(WiFi.localIP());
}

// MQTT brokerga qayta ulanish
void reconnectMQTT() {
  while (!client.connected()) {
    Serial.print("MQTT Brokerga ulanish kutilmoqda...");
    String clientId = "ESP32SmartHouse-" + String(random(0xffff), HEX);
    
    if (client.connect(clientId.c_str())) {
      Serial.println("MQTT Ulandi!");
      client.subscribe(MQTT_TOPIC_SUB);
      Serial.printf("Buyruqlar mavzusiga (%s) a'zo bo'lindi.\n", MQTT_TOPIC_SUB);
    } else {
      Serial.print("Ulanishda xato, rc=");
      Serial.print(client.state());
      Serial.println(". 4 soniyadan so'ng qayta uriniladi...");
      delay(4000);
    }
  }
}

// Mobil ilovadan / Ovozli agentdan kelgan xabarlarni qabul qilish
void callback(char* topic, byte* payload, unsigned int length) {
  String message = "";
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  Serial.printf("\n[MQTT KELDI] Mavzu: %s | Xabar: %s\n", topic, message.c_str());

  // JSON formatidagi buyruqni o'qish
  StaticJsonDocument<256> doc;
  DeserializationError error = deserializeJson(doc, message);

  if (error) {
    Serial.print("JSON xatolik: ");
    Serial.println(error.c_str());
    return;
  }

  String action = doc["action"] | ""; // masalan: "ON", "OFF", "OPEN", "CLOSE"
  String target = doc["target"] | ""; // masalan: "living_room", "kitchen", "door", "all"
  int value = doc["value"] | 0;

  handleCommand(action, target, value);
}

// Buyruqlarni bajarish mexanizmi
void handleCommand(String action, String target, int value) {
  Serial.printf("Buyruq bajarilmoqda -> Harakat: %s, Mo'ljal: %s\n", action.c_str(), target.c_str());

  if (target == "living_room") {
    state_living_room = (action == "ON");
    digitalWrite(RELAY_LIVING_ROOM, state_living_room ? LOW : HIGH);
  } 
  else if (target == "kitchen") {
    state_kitchen = (action == "ON");
    digitalWrite(RELAY_KITCHEN, state_kitchen ? LOW : HIGH);
  }
  else if (target == "bedroom") {
    state_bedroom = (action == "ON");
    digitalWrite(RELAY_BEDROOM, state_bedroom ? LOW : HIGH);
  }
  else if (target == "fan") {
    state_fan = (action == "ON");
    digitalWrite(RELAY_FAN, state_fan ? LOW : HIGH);
  }
  else if (target == "all_lights") {
    bool turnOn = (action == "ON");
    state_living_room = turnOn;
    state_kitchen = turnOn;
    state_bedroom = turnOn;
    digitalWrite(RELAY_LIVING_ROOM, turnOn ? LOW : HIGH);
    digitalWrite(RELAY_KITCHEN, turnOn ? LOW : HIGH);
    digitalWrite(RELAY_BEDROOM, turnOn ? LOW : HIGH);
  }
  else if (target == "door") {
    if (action == "OPEN") {
      doorServo.write(90); // Eshikni ochish
      door_locked = false;
      Serial.println("Eshik ochildi!");
    } else if (action == "CLOSE") {
      doorServo.write(0);  // Eshikni qulflash
      door_locked = true;
      Serial.println("Eshik qulflandi!");
    }
  }
  else if (target == "security") {
    security_active = (action == "ON");
    Serial.printf("Xavfsizlik tizimi: %s\n", security_active ? "FAOL" : "O'CHIRILGAN");
  }

  // O'zgarishni darhol qaytarib yuborish
  publishHouseState();
}

// Datchiklar va xavfsizlik tekshiruvi
void checkSensorsAndAlerts() {
  int gasValue = analogRead(MQ2_PIN);
  int motion = digitalRead(PIR_PIN);

  // Agar gaz miqdori kritik darajadan oshsa (masalan, 1500 dan yuqori)
  if (gasValue > 1500) {
    tone(BUZZER_PIN, 1000); // Signal berish
    Serial.println("DIQQAT: UYDA GAZ SIZIB CHIQISHI ANIQLANDI!");
  } 
  // Agar xavfsizlik rejimi yoniq bo'lsa va harakat aniqlansa
  else if (security_active && motion == HIGH && door_locked) {
    tone(BUZZER_PIN, 2000, 200); // Qisqa ogohlantiruvchi signal
    Serial.println("Xavfsizlik: Begona harakat aniqlandi!");
  } 
  else {
    noTone(BUZZER_PIN);
  }
}

// Barcha holatlarni JSON qilib MQTT orqali uzatish
void publishHouseState() {
  float temp = dht.readTemperature();
  float hum = dht.readHumidity();
  int gasValue = analogRead(MQ2_PIN);
  int motion = digitalRead(PIR_PIN);

  StaticJsonDocument<300> doc;
  doc["living_room"] = state_living_room;
  doc["kitchen"]     = state_kitchen;
  doc["bedroom"]     = state_bedroom;
  doc["fan"]         = state_fan;
  doc["door_locked"] = door_locked;
  doc["security"]    = security_active;
  
  doc["temperature"] = isnan(temp) ? 0.0 : temp;
  doc["humidity"]    = isnan(hum) ? 0.0 : hum;
  doc["gas_level"]   = gasValue;
  doc["motion"]      = (motion == HIGH);

  char buffer[320];
  serializeJson(doc, buffer);
  client.publish(MQTT_TOPIC_PUB, buffer);
}
