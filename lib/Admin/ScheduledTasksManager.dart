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

  void startScheduledTasks() {
    // หยุดตัวจับเวลาเดิมก่อน (ถ้ามี)
    stopScheduledTasks();

    // ตั้งเวลาให้ทำงานทุก 1 นาที เพื่อตรวจสอบบ่อยขึ้น
    _bookingCleanupTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      _cleanupService.runCleanupTasks();
    });

    print('Scheduled tasks started with 1 minute interval');
  }

  void stopScheduledTasks() {
    _bookingCleanupTimer?.cancel();
    _bookingCleanupTimer = null;
    print('Scheduled tasks stopped');
  }

  Future<void> runTasksNow() async {
    await _cleanupService.runCleanupTasks();
    print('Tasks run manually');
  }
}
