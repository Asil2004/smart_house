import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService extends ChangeNotifier {
  MqttServerClient? _client;
  bool isConnected = false;

  // Datchiklar va qurilmalar holati
  bool livingRoom = false;
  bool kitchen = false;
  bool bedroom = false;
  bool fan = false;
  bool doorLocked = true;
  bool securityActive = true;

  double temperature = 0.0;
  double humidity = 0.0;
  int gasLevel = 0;
  bool motionDetected = false;

  final String broker = 'broker.hivemq.com';
  final int port = 1883;
  final String subTopic = 'smarthouse/state';
  final String pubTopic = 'smarthouse/command';

  Future<void> connect() async {
    final clientId = 'FlutterClient_${DateTime.now().millisecondsSinceEpoch}';
    _client = MqttServerClient(broker, clientId);
    _client!.port = port;
    _client!.keepAlivePeriod = 20;
    _client!.logging(on: false);

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    _client!.connectionMessage = connMessage;

    try {
      debugPrint("MQTT Brokerga ulanmoqda...");
      await _client!.connect();
      isConnected = true;
      notifyListeners();
      debugPrint("MQTT muvaffaqiyatli ulandi!");

      _client!.subscribe(subTopic, MqttQos.atLeastOnce);

      _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
        final recMess = messages[0].payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        _handleIncomingState(payload);
      });
    } catch (e) {
      debugPrint("MQTT Ulanishda xatolik: $e");
      isConnected = false;
      notifyListeners();
    }
  }

  void _handleIncomingState(String jsonStr) {
    try {
      final data = jsonDecode(jsonStr);
      livingRoom = data['living_room'] ?? livingRoom;
      kitchen = data['kitchen'] ?? kitchen;
      bedroom = data['bedroom'] ?? bedroom;
      fan = data['fan'] ?? fan;
      doorLocked = data['door_locked'] ?? doorLocked;
      securityActive = data['security'] ?? securityActive;

      temperature = (data['temperature'] as num?)?.toDouble() ?? temperature;
      humidity = (data['humidity'] as num?)?.toDouble() ?? humidity;
      gasLevel = data['gas_level'] ?? gasLevel;
      motionDetected = data['motion'] ?? motionDetected;

      notifyListeners();
    } catch (e) {
      debugPrint("JSON Parse xatosi: $e");
    }
  }

  void sendCommand(String action, String target, {int value = 0}) {
    if (_client == null || !isConnected) {
      debugPrint("MQTT ulanmagan!");
      return;
    }

    final payload = jsonEncode({
      'action': action,
      'target': target,
      'value': value,
    });

    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);

    _client!.publishMessage(pubTopic, MqttQos.atLeastOnce, builder.payload!);
    debugPrint("Buyruq yuborildi: $payload");
  }
}
