import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'voice_service.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool? _notificationsAllowed;
  int _nextNotificationId = 1000;

  Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (!_initialized) await init();
    if (_notificationsAllowed != null) return _notificationsAllowed!;

    final android = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await android?.requestNotificationsPermission();
    _notificationsAllowed = granted ?? true;
    return _notificationsAllowed!;
  }

  Future<void> showTaskCompleteNotification(String title, String body) async {
    if (!_initialized) await init();
    if (!await requestPermission()) return;

    // A dedicated channel: Android channels are immutable once created, so a
    // louder profile needs a new id.
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'task_alerts_v2',
          'Task Alerts',
          channelDescription: 'Audible alerts when an agent task finishes',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList(<int>[0, 400, 200, 400]),
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          styleInformation: BigTextStyleInformation(body),
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      _nextNotificationId++,
      title,
      body,
      platformChannelSpecifics,
    );

    // Speak the result as well, so a finished task is heard and not just seen.
    await SpeechFeedback.instance.announce(title, body);
  }
}
