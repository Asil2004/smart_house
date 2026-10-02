# 🏡 Aqlli Uy (Smart House) - Ovozli Boshqaruv Tizimi

ESP32 mikrokontrolleri, Google Gemini AI yordamchisi va smartfon (APK) orqali to'liq o'zbek tilida erkin muloqot va ovozli boshqaruv tizimi.

---

## 🏗️ 1. Loyiha Arxitekturasi

```mermaid
flowchart TD
    User([Foydalanuvchi Ovozli Buyrug'i 🗣️]) --> MobileApp[Smartfon APK / Veb Ilova]
    MobileApp --> STT[Ovoz Tanish (STT)]
    STT --> NLU[Gemini AI / Mahalliy Intent Tahlili]
    NLU --> Comm[Aloqa Kanali: MQTT Broker / Local WebSockets]
    Comm --> ESP32[ESP32 Boshqaruvchi Platasi / Virtual Simulyator]
    
    subgraph Ijrochi Qurilmalar va Sensorlar
        ESP32 --> Relays[Relelar: Chiroqlar va Rozetkalar]
        ESP32 --> Servo[Servo Motor: Aqlli Eshik Qulfi]
        ESP32 --> Buzzer[Buzzer: Xavfsizlik Signali]
        DHT[DHT11/DHT22 Harorat & Namlik] --> ESP32
        MQ2[MQ-2 Gaz & Tutun Datchigi] --> ESP32
        PIR[PIR Harakat Datchigi] --> ESP32
    end
```

---

## ❓ Server uchun GitHub kerakmi?

> [!CAUTION]
> **QAT'IY JAVOB: YO'Q, server uchun GitHub KERAK EMAS!**
> 1. **GitHub nima o'zi?** — GitHub faqat loyihaning kodlarini saqlash (Git ombori) xizmatidir. U orqali real-vaqtda ovozli ma'lumotlarni qabul qilish, aqlli uy bilan 24/7 aloqa qilish **MUMKIN EMAS**.
> 2. **Tizim qanday qilib serversiz ishlaydi?**
>    - **Smartfon ilovasida kiritilgan API Key orqali:** Smartfoningiz to'g'ridan-to'g'ri Gemini AI xizmatiga ulanadi. O'rtaga alohida shaxsiy server o'rnatish shart emas!
>    - **ESP32 bilan aloqa:** Smartfon va ESP32 to'g'ridan-to'g'ri bepul **MQTT Cloud Broker (HiveMQ)** yoki **Mahalliy Wi-Fi** orqali bog'lanadi.
> 3. **GitHub faqat bitta narsada yordam beradi (ixtiyoriy):**
>    - Agar kompyuteringizda Android Studio bo'lmasa, GitHub Actions (CI/CD) koddan bepul `.apk` faylni avtomatik yig'ib berishi mumkin. Lekin server sifatida umuman kerak emas!

---

## ⚙️ 2. Tizim Imkoniyatlari

1. **API Key kiritish maydoni:** Gemini AI tizimingizning maxfiy kalitini xavfsiz kiritish va saqlash.
2. **Erkin Muloqot va Aqlli Boshqaruv:** Qotib qolgan kalit so'zlarsiz, xohlagan usulda gapiring ("Mehmonxonani yoq", "Eshikni och", "Amir Temur haqida aytib ber", "Bugun havo qanday?").
3. **Virtual Demo Simulyator:** ESP32 platangiz bo'lmasa ham to'liq vizual va ovozli sinovdan o'tkazish.
4. **Tarmoq tanlash:** Bepul Internet MQTT yoki Internet bo'lmaganida Uy Wi-Fi si orqali to'g'ridan-to'g'ri ishlash.

---

## 🔌 3. Ulanish Sxemasi (ESP32 Pinout)

| Komponent | ESP32 Pini | Tavsif |
| :--- | :--- | :--- |
| **Rele 1 (Mehmonxona chirog'i)** | `GPIO 23` | Raqamli chiqish (Active LOW/HIGH) |
| **Rele 2 (Oshxona chirog'i)** | `GPIO 22` | Raqamli chiqish |
| **Rele 3 (Yotoqxona chirog'i)** | `GPIO 21` | Raqamli chiqish |
| **Rele 4 (Ventilyator/Konditsioner)**| `GPIO 19` | Raqamli chiqish |
| **DHT11 / DHT22** | `GPIO 4` | Harorat va namlik datchigi (Data) |
| **MQ-2 Gaz / Tutun** | `GPIO 34` | Analog / Raqamli kirish (A0 yoki D0) |
| **PIR Harakat datchigi** | `GPIO 18` | Raqamli kirish |
| **Servo Motor (Eshik qulfi)** | `GPIO 13` | PWM signal pini |
| **Xavfsizlik Buzzeri** | `GPIO 25` | Ovozli signal chiqishi |

---

## 🗣️ 4. O'zbek Tilidagi Ovozli Buyruqlar Lug'ati

Aqlli yordamchi quyidagi asosiy buyruqlar va erkin jumlalarni taniydi:

- **Chiroqlar:**
  - *"Mehmonxona chirog'ini yoq"* / *"Mehmonxona chirog'ini o'chir"*
  - *"Oshxona chirog'ini yoq"* / *"Oshxona chirog'ini o'chir"*
  - *"Hamma chiroqlarni yoq"* / *"Hamma chiroqlarni o'chir"*
- **Xavfsizlik & Eshik:**
  - *"Eshikni och"* / *"Eshikni qulfla"*
  - *"Xavfsizlik tizimini yoq"* / *"Xavfsizlikni o'chir"*
- **Ma'lumot olish & Erkin Muloqot:**
  - *"Uyda harorat qanday?"* / *"Harorat va namlikni ayt"*
  - *"Salom, qandaysan?"* / *"Menga biror qiziq fakt aytib ber"*
