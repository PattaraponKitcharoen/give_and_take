import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// 🟢 ฟังก์ชันระดับ Top-level สำหรับจัดการข้อเสนอเวลาแอปอยู่ Background/Terminated
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("พบการแจ้งเตือนเบื้องหลัง: ${message.messageId}");
}

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initNotification() async {
    // 1. ขออนุญาตการแจ้งเตือน (สำคัญมากสำหรับ iOS และ Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true, badge: true, sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('ผู้ใช้งานอนุญาตการแจ้งเตือนเรียบร้อยแล้ว');
      
      // 2. ตั้งค่า Background Handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 3. ตั้งค่าระบบ Local Notification สำหรับตอนเปิดแอปอยู่ (Foreground)
      await _initLocalNotifications();

      // 4. รับและบันทึก FCM Token ของเครื่องนี้ลงฐานข้อมูล
      await saveDeviceToken();
    }
  }

  // ตั้งค่าป๊อปอัปแจ้งเตือนภายในแอป (Foreground)
  Future<void> _initLocalNotifications() async {
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
    
    await _localNotificationsPlugin.initialize(initSettings);

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
        );
      }
    });
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
        print("บันทึก FCM Token สำเร็จ: $token");
      }
    } catch (e) {
      // ถ้าดึงไม่ได้ (เช่น รันบน Simulator) ให้พิมพ์บอกเฉยๆ แล้วปล่อยให้แอปทำงานต่อไป
      print("ไม่สามารถดึง FCM Token ได้ (ปกติสำหรับ iOS Simulator): $e");
    }
  }
}