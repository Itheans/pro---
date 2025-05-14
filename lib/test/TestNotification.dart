import 'package:flutter/material.dart';
import 'package:myproject/Local_Noti/NotiClass.dart';
import 'package:myproject/Admin/NotificationService.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TestNotificationScreen extends StatelessWidget {
  final NotifiationServices _localNoti = NotifiationServices();
  final NotificationService _firebaseNoti = NotificationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ทดสอบการแจ้งเตือน'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                _localNoti.sendCustomNotification(
                  title: 'ทดสอบการแจ้งเตือนในแอป',
                  body: 'นี่คือการทดสอบการแจ้งเตือนภายในแอป',
                );
              },
              child: Text('ทดสอบการแจ้งเตือนในแอป'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await _firebaseNoti.sendBookingStatusNotification(
                    userId: user.uid,
                    bookingId: 'test_booking_id',
                    status: 'pending',
                    message: 'นี่คือการทดสอบการแจ้งเตือน Firebase',
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อน')),
                  );
                }
              },
              child: Text('ทดสอบการแจ้งเตือน Firebase'),
            ),
          ],
        ),
      ),
    );
  }
}
