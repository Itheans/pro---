import 'dart:async';
import 'package:myproject/Admin/BookingCleanupService.dart';

class ScheduledTasksManager {
  Timer? _bookingCleanupTimer;
  final BookingCleanupService _cleanupService = BookingCleanupService();
  static final ScheduledTasksManager _instance =
      ScheduledTasksManager._internal();

  // Singleton pattern
  factory ScheduledTasksManager() {
    return _instance;
  }

  ScheduledTasksManager._internal();

  // แก้ไขเวลาในฟังก์ชัน startScheduledTasks
  void startScheduledTasks() {
    // หยุดตัวจับเวลาเดิมก่อน (ถ้ามี)
    stopScheduledTasks();

    // เปลี่ยนจาก 30 นาทีเป็น 5 นาที
    _bookingCleanupTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      _cleanupService.runCleanupTasks();
    });

    print('Scheduled tasks started');
  }

  // หยุดการทำงานตามกำหนดการ
  void stopScheduledTasks() {
    _bookingCleanupTimer?.cancel();
    _bookingCleanupTimer = null;
    print('Scheduled tasks stopped');
  }

  // สั่งให้ทำงานทันที
  Future<void> runTasksNow() async {
    await _cleanupService.runCleanupTasks();
    print('Tasks run manually');
  }
}
