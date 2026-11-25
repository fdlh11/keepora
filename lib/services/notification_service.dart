import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  static const String _channelId = 'keepora_maintenance_channel';
  static const String _channelName = 'Pengingat Jadwal Perawatan';
  static const String _channelDesc =
      'Notifikasi pengingat jadwal perawatan dan perbaikan barang pribadi.';

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );

    await _plugin.initialize(
      settings: initSettings,
    );

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
      await androidImpl.requestExactAlarmsPermission();
    }

    _isInitialized = true;
  }

  /// Menghasilkan ID integer unik yang stabil dari scheduleId Firestore
  int _baseIdFromScheduleId(String scheduleId) {
    return (scheduleId.hashCode & 0x3FFFFFFF) * 2;
  }

  NotificationDetails _notificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    return const NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  /// Jadwalkan pengingat H-1 dan Hari-H untuk jadwal perawatan
  Future<void> scheduleMaintenanceReminder({
    required String scheduleId,
    required String title,
    required String assetName,
    required String maintenanceType,
    required DateTime scheduledAt,
  }) async {
    try {
      await init();
      await cancelMaintenanceReminder(scheduleId);

      final now = tz.TZDateTime.now(tz.local);
      final targetTime = tz.TZDateTime.from(scheduledAt, tz.local);
      final baseId = _baseIdFromScheduleId(scheduleId);

      // 1. Pengingat H-1 (24 jam sebelum jadwal)
      final reminderH1 = targetTime.subtract(const Duration(days: 1));
      if (reminderH1.isAfter(now)) {
        await _plugin.zonedSchedule(
          id: baseId + 1,
          title: 'Pengingat Besok: $title',
          body:
              '$maintenanceType untuk $assetName dijadwalkan besok pukul ${_formatJam(scheduledAt)} WIB.',
          scheduledDate: reminderH1,
          notificationDetails: _notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: scheduleId,
        );
      }

      // 2. Pengingat Hari-H (tepat pada waktu jadwal)
      if (targetTime.isAfter(now)) {
        await _plugin.zonedSchedule(
          id: baseId,
          title: 'Waktunya $maintenanceType!',
          body: 'Jadwal "$title" untuk barang $assetName dimulai sekarang.',
          scheduledDate: targetTime,
          notificationDetails: _notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: scheduleId,
        );
      }
    } catch (e) {
      debugPrint('Gagal menjadwalkan notifikasi: $e');
    }
  }

  /// Batalkan pengingat saat jadwal dihapus, diedit, atau ditandai selesai
  Future<void> cancelMaintenanceReminder(String scheduleId) async {
    try {
      await init();
      final baseId = _baseIdFromScheduleId(scheduleId);
      await _plugin.cancel(id: baseId);
      await _plugin.cancel(id: baseId + 1);
    } catch (e) {
      debugPrint('Gagal membatalkan notifikasi: $e');
    }
  }

  /// Tes notifikasi langsung untuk memastikan izin & tampilan berfungsi
  Future<void> showTestNotification() async {
    await init();
    await _plugin.show(
      id: 999999,
      title: 'Pengingat Keepora Aktif',
      body:
          'Notifikasi pengingat perawatan barang pribadi Anda sudah siap digunakan.',
      notificationDetails: _notificationDetails(),
    );
  }

  String _formatJam(DateTime dt) {
    final jam = dt.hour.toString().padLeft(2, '0');
    final menit = dt.minute.toString().padLeft(2, '0');
    return '$jam:$menit';
  }
}