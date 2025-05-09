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

  // เริ่มการทำงานตามกำหนดการ
  void startScheduledTasks() {
    // หยุดตัวจับเวลาเดิมก่อน (ถ้ามี)
    stopScheduledTasks();

    // ตั้งเวลาให้ระบบทำความสะอาดคิวทำงานทุก 30 นาที
    _bookingCleanupTimer = Timer.periodic(Duration(minutes: 30), (timer) {
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
