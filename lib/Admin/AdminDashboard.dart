import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:myproject/Admin/AdminNotificationsPage%20.dart';
import 'package:myproject/Admin/AdminSettingsPage.dart';
import 'package:myproject/Admin/SitterVerificationPage.dart';
import 'package:myproject/Admin/BookingManagementPage.dart';
import 'package:myproject/Admin/BookingDetailPage.dart';
import 'package:myproject/Admin/BookingManagementPage.dart';
import 'package:myproject/Admin/SitterVerificationPage.dart';
import 'package:myproject/Admin/UserManagementPage.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _isLoading = true;
  int _totalUsers = 0;
  int _totalSitters = 0;
  int _pendingSitters = 0;
  int _totalBookings = 0;
  int _pendingBookings = 0;
  int _completedBookings = 0;
  double _totalRevenue = 0;
  List<DocumentSnapshot> _recentBookings = [];
  int _pendingNotifications = 0;
  // ข้อมูลเพิ่มเติมสำหรับแสดงในหน้า Dashboard
  double _thisWeekRevenue = 0;
  double _lastWeekRevenue = 0;
  int _thisWeekBookings = 0;
  int _lastWeekBookings = 0;
  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // โหลดข้อมูลผู้ใช้
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      // โหลดข้อมูลผู้รับเลี้ยงแมว
      final sittersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'sitter')
          .get();

      // โหลดข้อมูลผู้รับเลี้ยงแมวที่รอการอนุมัติ
      final pendingSittersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'sitter')
          .where('status', isEqualTo: 'pending')
          .get();

      // โหลดข้อมูลการจอง
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      // โหลดข้อมูลการจองที่รอดำเนินการ
      final pendingBookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('status', isEqualTo: 'pending')
          .get();

      // โหลดข้อมูลการจองที่เสร็จสิ้น
      final completedBookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('status', isEqualTo: 'completed')
          .get();

      // โหลดข้อมูลการแจ้งเตือนที่ยังไม่ได้อ่าน
      final notificationsSnapshot = await FirebaseFirestore.instance
          .collection('admin_notifications')
          .where('isRead', isEqualTo: false)
          .get();

      // คำนวณรายได้ทั้งหมด
      double totalRevenue = 0;
      for (var doc in completedBookingsSnapshot.docs) {
        Map<String, dynamic> data = doc.data();
        if (data.containsKey('totalPrice')) {
          totalRevenue += (data['totalPrice'] is int)
              ? (data['totalPrice'] as int).toDouble()
              : (data['totalPrice'] as double);
        }
      }

      setState(() {
        _totalUsers = usersSnapshot.docs.length;
        _totalSitters = sittersSnapshot.docs.length;
        _pendingSitters = pendingSittersSnapshot.docs.length;
        _totalBookings = bookingsSnapshot.docs.length;
        _pendingBookings = pendingBookingsSnapshot.docs.length;
        _completedBookings = completedBookingsSnapshot.docs.length;
        _totalRevenue = totalRevenue;
        _recentBookings = bookingsSnapshot.docs;
        _pendingNotifications = notificationsSnapshot.docs.length;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e')),
      );
    }
    // คำนวณรายได้และจำนวนการจองในสัปดาห์นี้และสัปดาห์ที่แล้ว
    DateTime now = DateTime.now();
    DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    DateTime startOfLastWeek = startOfWeek.subtract(Duration(days: 7));
    DateTime endOfLastWeek = startOfWeek.subtract(Duration(days: 1));

    Timestamp startOfWeekTimestamp = Timestamp.fromDate(startOfWeek);
    Timestamp startOfLastWeekTimestamp = Timestamp.fromDate(startOfLastWeek);
    Timestamp endOfLastWeekTimestamp = Timestamp.fromDate(endOfLastWeek);

// จำนวนการจองในสัปดาห์นี้
    final thisWeekBookingsSnapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('createdAt', isGreaterThanOrEqualTo: startOfWeekTimestamp)
        .get();

// จำนวนการจองในสัปดาห์ที่แล้ว
    final lastWeekBookingsSnapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('createdAt', isGreaterThanOrEqualTo: startOfLastWeekTimestamp)
        .where('createdAt', isLessThan: startOfWeekTimestamp)
        .get();

// คำนวณรายได้
    double thisWeekRev = 0;
    double lastWeekRev = 0;

    for (var doc in thisWeekBookingsSnapshot.docs) {
      Map<String, dynamic> data = doc.data();
      if (data.containsKey('totalPrice')) {
        thisWeekRev += (data['totalPrice'] is int)
            ? (data['totalPrice'] as int).toDouble()
            : (data['totalPrice'] as double);
      }
    }

    for (var doc in lastWeekBookingsSnapshot.docs) {
      Map<String, dynamic> data = doc.data();
      if (data.containsKey('totalPrice')) {
        lastWeekRev += (data['totalPrice'] is int)
            ? (data['totalPrice'] as int).toDouble()
            : (data['totalPrice'] as double);
      }
    }

    setState(() {
      _thisWeekBookings = thisWeekBookingsSnapshot.docs.length;
      _lastWeekBookings = lastWeekBookingsSnapshot.docs.length;
      _thisWeekRevenue = thisWeekRev;
      _lastWeekRevenue = lastWeekRev;
    });
  }

  Widget _buildComparisonCard(String title, String value, String change,
      Color changeColor, IconData icon) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                Icon(
                  icon,
                  color: Colors.deepOrange,
                  size: 20,
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 5),
            Row(
              children: [
                Icon(
                  change.contains('-')
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  color: changeColor,
                  size: 14,
                ),
                SizedBox(width: 4),
                Text(
                  change,
                  style: TextStyle(
                    color: changeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  ' vs สัปดาห์ที่แล้ว',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('แดชบอร์ดผู้ดูแลระบบ'),
        backgroundColor: Colors.deepOrange,
        actions: [
          if (_pendingNotifications > 0)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.notifications),
                  onPressed: () {
                    // แสดงการแจ้งเตือน
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminNotificationsPage(),
                      ),
                    ).then((_) => _loadDashboardData());
                  },
                  tooltip: 'การแจ้งเตือน',
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _pendingNotifications.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'รีเฟรชข้อมูล',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ข้อความต้อนรับ
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    color: Colors.deepOrange.shade50,
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.deepOrange,
                            radius: 25,
                            child: Icon(
                              Icons.admin_panel_settings,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ยินดีต้อนรับ, แอดมิน!',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepOrange.shade800,
                                  ),
                                ),
                                Text(
                                  DateFormat('EEEE, d MMMM yyyy')
                                      .format(DateTime.now()),
                                  style: TextStyle(
                                    color: Colors.deepOrange.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_pendingSitters > 0)
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          SitterVerificationPage()),
                                ).then((_) => _loadDashboardData());
                              },
                              icon: Icon(Icons.pending_actions),
                              label: Text('$_pendingSitters คำขอรออนุมัติ'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  // สรุปข้อมูลสำคัญ
                  Text(
                    'ภาพรวมระบบ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  GridView.count(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.5,
                    children: [
                      // การ์ดผู้ใช้ทั้งหมด
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => UserManagementPage()),
                          ).then((_) => _loadDashboardData());
                        },
                        child: _buildStatCard(
                          'ผู้ใช้ทั้งหมด',
                          _totalUsers.toString(),
                          Icons.people,
                          Colors.blue,
                        ),
                      ),

                      // การ์ดผู้รับเลี้ยงแมว
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => SitterVerificationPage()),
                          ).then((_) => _loadDashboardData());
                        },
                        child: _buildStatCard(
                          'ผู้รับเลี้ยงแมว',
                          _totalSitters.toString(),
                          Icons.pets,
                          Colors.deepOrange,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  // รายการคำขอล่าสุด
                  if (_pendingSitters > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'คำขอเป็นผู้รับเลี้ยงแมวรออนุมัติ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      SitterVerificationPage()),
                            ).then((_) => _loadDashboardData());
                          },
                          child: Text('ดูทั้งหมด'),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'คำขอรออนุมัติ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '$_pendingSitters รายการ',
                                  style: TextStyle(
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.warning, color: Colors.amber),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'มีคำขอเป็นผู้รับเลี้ยงแมวรออนุมัติ $_pendingSitters รายการ กรุณาตรวจสอบและดำเนินการโดยเร็ว',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          SitterVerificationPage()),
                                ).then((_) => _loadDashboardData());
                              },
                              icon: Icon(Icons.arrow_forward),
                              label: Text('ไปที่หน้าตรวจสอบและอนุมัติ'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                                foregroundColor: Colors.white,
                                minimumSize: Size(double.infinity, 45),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
// เพิ่มเมนูตั้งค่าระบบ
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => AdminSettingsPage()),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.settings,
                                color: Colors.grey.shade700,
                                size: 30,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ตั้งค่าระบบ',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'ตั้งค่าการทำงานอัตโนมัติและการจัดการข้อมูล',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // รายการจองล่าสุด
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'การจองล่าสุด',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // นำไปยังหน้าจัดการการจองทั้งหมด
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BookingManagementPage(),
                            ),
                          ).then((_) => _loadDashboardData());
                        },
                        child: Text('ดูทั้งหมด'),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  _recentBookings.isEmpty
                      ? Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 2,
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                'ไม่มีการจองล่าสุด',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Column(
                          children: _recentBookings.map((booking) {
                            Map<String, dynamic> bookingData =
                                booking.data() as Map<String, dynamic>;
                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 2,
                              margin: EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getStatusColor(
                                      bookingData['status'] ?? 'pending'),
                                  child: Icon(
                                    _getStatusIcon(
                                        bookingData['status'] ?? 'pending'),
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  'การจองรหัส ${booking.id.substring(0, 8)}...',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'สถานะ: ${_getStatusText(bookingData['status'] ?? 'pending')}' +
                                      '\nวันที่: ${bookingData['createdAt'] != null ? DateFormat('dd/MM/yyyy').format((bookingData['createdAt'] as Timestamp).toDate()) : 'ไม่ระบุ'}',
                                ),
                                trailing: Text(
                                  '฿${bookingData['totalPrice'] ?? 0}',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                onTap: () {
                                  // นำไปยังหน้ารายละเอียดการจอง
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BookingDetailPage(
                                        bookingId: booking.id,
                                      ),
                                    ),
                                  ).then((_) => _loadDashboardData());
                                },
                              ),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                Icon(
                  icon,
                  color: color,
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.amber;
      case 'confirmed':
        return Colors.blue;
      case 'in_progress':
        return Colors.indigo;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending_actions;
      case 'confirmed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.pets;
      case 'completed':
        return Icons.task_alt;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'รอการยืนยัน';
      case 'confirmed':
        return 'ยืนยันแล้ว';
      case 'in_progress':
        return 'กำลังให้บริการ';
      case 'completed':
        return 'เสร็จสิ้น';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return 'ไม่ทราบสถานะ';
    }
  }
}
//     }
//   @override  