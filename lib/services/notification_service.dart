import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_target.dart';

// 🟢 ฟังก์ชันระดับ Top-level สำหรับจัดการข้อเสนอเวลาแอปอยู่ Background/Terminated
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("พบการแจ้งเตือนเบื้องหลัง: ${message.messageId}");
}

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Taps are app-wide (NotificationService is created more than once), so
  // they live in statics: NotificationTapCubit reads them.
  static final StreamController<NotificationTarget> _taps =
      StreamController<NotificationTarget>.broadcast();
  static NotificationTarget? _launchTarget;

  /// Notifications tapped while the app is running (foreground or
  /// background).
  static Stream<NotificationTarget> get taps => _taps.stream;

  /// The notification that launched the app from closed, once.
  static NotificationTarget? takeLaunchTarget() {
    final target = _launchTarget;
    _launchTarget = null;
    return target;
  }

  static void _tapped(Map<String, dynamic> data) {
    final target = NotificationTarget.fromData(data);
    if (target != null) _taps.add(target);
  }

  Future<void> initNotification() async {
    // 1. ขออนุญาตการแจ้งเตือน (สำคัญมากสำหรับ iOS และ Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true, badge: true, sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('ผู้ใช้งานอนุญาตการแจ้งเตือนเรียบร้อยแล้ว');

      // 2. ตั้งค่า Background Handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 3. ตั้งค่าระบบ Local Notification สำหรับตอนเปิดแอปอยู่ (Foreground)
      await _initLocalNotifications();

      // 4. Tapping a notification opens the screen it's about.
      await _listenForTaps();

      // 5. รับและบันทึก FCM Token ของเครื่องนี้ลงฐานข้อมูล
      await saveDeviceToken();
    }
  }

  Future<void> _listenForTaps() async {
    // App in the background: the system notification brings it forward.
    FirebaseMessaging.onMessageOpenedApp
        .listen((message) => _tapped(message.data));
    // App was closed: the tap launched it.
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      _launchTarget = NotificationTarget.fromData(initial.data);
    }
  }

  // ตั้งค่าป๊อปอัปแจ้งเตือนภายในแอป (Foreground)
  Future<void> _initLocalNotifications() async {
    // iOS shows FCM notifications itself while the app is open; tapping one
    // arrives through onMessageOpenedApp like a background tap.
    await _fcm.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true);

    // สำหรับ Android
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // 🟢 สำหรับ iOS (ต้องเพิ่มตัวนี้เข้าไปเพื่อไม่ให้แอปแครชจอขาว)
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // รวมการตั้งค่าทั้ง 2 แพลตฟอร์ม
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings, // 🟢 ใส่ค่า iOS ตรงนี้
    );

    // Android foreground notifications are shown below with the FCM data
    // as their payload; tapping one comes back here.
    await _localNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final data = _decodePayload(response.payload);
        if (data != null) _tapped(data);
      },
    );

    // ดักฟังตอนเปิดแอปอยู่แล้วมีแจ้งเตือนวิ่งเข้ามา
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _localNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'give_and_take_channel', // ID ช่อง
              'Give & Take Notifications', // ชื่อช่อง
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            // 🟢 เพิ่มการตั้งค่าแสดงผลของ iOS เข้าไปด้วย
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: jsonEncode(message.data),
        );
      }
    });
  }

  static Map<String, dynamic>? _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  // 🟢 บันทึกรหัสเครื่องลงบนคอลเลกชัน users
  Future<void> saveDeviceToken() async {
    try {
      // 🟢 ใช้ try-catch ครอบไว้ ป้องกันแอปแครชเวลาใช้ iOS Simulator
      String? token = await _fcm.getToken();
      String? uid = FirebaseAuth.instance.currentUser?.uid;

      if (token != null && uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'fcm_token': token,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint("บันทึก FCM Token สำเร็จ: $token");
      }
    } catch (e) {
      // ถ้าดึงไม่ได้ (เช่น รันบน Simulator) ให้พิมพ์บอกเฉยๆ แล้วปล่อยให้แอปทำงานต่อไป
      debugPrint("ไม่สามารถดึง FCM Token ได้ (ปกติสำหรับ iOS Simulator): $e");
    }
  }
}
