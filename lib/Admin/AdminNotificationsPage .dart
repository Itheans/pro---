import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:myproject/Admin/SitterVerificationPage.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({Key? key}) : super(key: key);

  @override
  _AdminNotificationsPageState createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  bool _isLoading = true;
  List<DocumentSnapshot> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('admin_notifications')
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        _notifications = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notifications: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดการแจ้งเตือน: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('admin_notifications')
          .doc(notificationId)
          .update({'isRead': true});

      setState(() {
        // อัพเดตสถานะการอ่านในรายการปัจจุบัน
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          Map<String, dynamic> data =
              _notifications[index].data() as Map<String, dynamic>;
          data['isRead'] = true;
        }
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      // สร้าง batch update
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var notification in _notifications) {
        Map<String, dynamic> data = notification.data() as Map<String, dynamic>;
        if (data['isRead'] == false) {
          batch.update(notification.reference, {'isRead': true});
        }
      }

      await batch.commit();

      // อัพเดตสถานะการอ่านในรายการปัจจุบัน
      setState(() {
        for (int i = 0; i < _notifications.length; i++) {
          Map<String, dynamic> data =
              _notifications[i].data() as Map<String, dynamic>;
          data['isRead'] = true;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ทำเครื่องหมายอ่านแล้วทั้งหมดสำเร็จ')),
      );
    } catch (e) {
      print('Error marking all notifications as read: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('การแจ้งเตือน'),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: Icon(Icons.done_all),
            onPressed: _markAllAsRead,
            tooltip: 'ทำเครื่องหมายอ่านแล้วทั้งหมด',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadNotifications,
            tooltip: 'รีเฟรช',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'ไม่มีการแจ้งเตือน',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _notifications.length,
                  padding: EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    final data = notification.data() as Map<String, dynamic>;

                    final bool isRead = data['isRead'] ?? false;
                    final String type = data['type'] ?? '';
                    final Timestamp? timestamp = data['timestamp'];

                    return Dismissible(
                      key: Key(notification.id),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.only(right: 20),
                        child: Icon(
                          Icons.delete,
                          color: Colors.white,
                        ),
                      ),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) async {
                        try {
                          await FirebaseFirestore.instance
                              .collection('admin_notifications')
                              .doc(notification.id)
                              .delete();

                          setState(() {
                            _notifications.removeAt(index);
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('ลบการแจ้งเตือนสำเร็จ')),
                          );
                        } catch (e) {
                          print('Error deleting notification: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('เกิดข้อผิดพลาดในการลบ: $e')),
                          );
                        }
                      },
                      child: Card(
                        elevation: isRead ? 1 : 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isRead
                                ? Colors.transparent
                                : Colors.deepOrange.shade200,
                            width: isRead ? 0 : 1,
                          ),
                        ),
                        margin: EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isRead
                                ? Colors.grey.shade200
                                : Colors.deepOrange.shade100,
                            child: Icon(
                              _getNotificationIcon(type),
                              color: isRead
                                  ? Colors.grey.shade700
                                  : Colors.deepOrange,
                            ),
                          ),
                          title: Text(
                            _getNotificationTitle(type, data),
                            style: TextStyle(
                              fontWeight:
                                  isRead ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            timestamp != null
                                ? DateFormat('dd/MM/yyyy HH:mm')
                                    .format(timestamp.toDate())
                                : 'ไม่ระบุเวลา',
                            style: TextStyle(
                              fontSize: 12,
                            ),
                          ),
                          trailing: isRead
                              ? null
                              : Icon(
                                  Icons.circle,
                                  color: Colors.deepOrange,
                                  size: 12,
                                ),
                          onTap: () {
                            if (!isRead) {
                              _markAsRead(notification.id);
                            }

                            // นำไปยังหน้าที่เกี่ยวข้อง
                            if (type == 'new_sitter') {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        SitterVerificationPage()),
                              );
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'new_sitter':
        return Icons.person_add;
      case 'new_booking':
        return Icons.calendar_today;
      case 'report':
        return Icons.report_problem;
      case 'booking_expired': // เพิ่มประเภทใหม่
        return Icons.timer_off; // ใช้ไอคอนนาฬิกาที่มีเครื่องหมายปิด
      default:
        return Icons.notifications;
    }
  }

  String _getNotificationTitle(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'new_sitter':
        return 'ผู้รับเลี้ยงแมวใหม่รออนุมัติ: ${data['userName'] ?? 'ไม่ระบุชื่อ'}';
      case 'new_booking':
        return 'มีการจองใหม่';
      case 'report':
        return 'มีรายงานปัญหาใหม่';
      case 'booking_expired': // เพิ่มประเภทใหม่
        return 'คำขอการจองหมดเวลา';
      default:
        return 'การแจ้งเตือนใหม่';
    }
  }
}
