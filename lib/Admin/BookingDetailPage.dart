import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:myproject/Admin/NotificationService.dart';
import 'package:url_launcher/url_launcher.dart';

class BookingDetailPage extends StatefulWidget {
  final String bookingId;

  const BookingDetailPage({Key? key, required this.bookingId})
      : super(key: key);

  @override
  _BookingDetailPageState createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _bookingData;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _sitterData;
  List<Map<String, dynamic>> _catsList = [];
  final NotificationService _notificationService = NotificationService();
  TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBookingData();
  }

  Future<void> _loadBookingData() async {
    try {
      setState(() => _isLoading = true);

      // ดึงข้อมูลการจอง
      final bookingDoc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .get();

      if (!bookingDoc.exists) {
        throw Exception('ไม่พบข้อมูลการจอง');
      }

      _bookingData = bookingDoc.data() as Map<String, dynamic>;

      // ดึงข้อมูลผู้ใช้
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_bookingData!['userId'])
          .get();

      if (userDoc.exists) {
        _userData = userDoc.data() as Map<String, dynamic>;
      }

      // ดึงข้อมูลพี่เลี้ยง
      final sitterDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_bookingData!['sitterId'])
          .get();

      if (sitterDoc.exists) {
        _sitterData = sitterDoc.data() as Map<String, dynamic>;
      }

      // ดึงข้อมูลแมว
      if (_bookingData!.containsKey('catIds')) {
        final catIds = List<String>.from(_bookingData!['catIds']);
        _catsList = [];

        for (var catId in catIds) {
          final catDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(_bookingData!['userId'])
              .collection('cats')
              .doc(catId)
              .get();

          if (catDoc.exists) {
            Map<String, dynamic> catData =
                catDoc.data() as Map<String, dynamic>;
            catData['id'] = catDoc.id;
            _catsList.add(catData);
          }
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading booking data: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  Future<void> _updateBookingStatus(String newStatus) async {
    try {
      setState(() => _isLoading = true);

      String adminMessage = _messageController.text.trim().isNotEmpty
          ? _messageController.text.trim()
          : _getDefaultMessageForStatus(newStatus);

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'adminMessage': adminMessage,
      });

      // ส่งการแจ้งเตือนไปยังผู้ใช้
      await _notificationService.sendBookingStatusNotification(
        userId: _bookingData!['userId'],
        bookingId: widget.bookingId,
        status: newStatus,
        message: adminMessage,
      );

      // ส่งการแจ้งเตือนไปยังพี่เลี้ยง
      await _notificationService.sendBookingStatusNotification(
        userId: _bookingData!['sitterId'],
        bookingId: widget.bookingId,
        status: newStatus,
        message: adminMessage,
      );

      // รีเซ็ตข้อความ
      _messageController.clear();

      // โหลดข้อมูลใหม่
      _loadBookingData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('อัพเดทสถานะสำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // แสดงหน้าต่างสำหรับป้อนข้อความเพิ่มเติม
  Future<void> _showMessageDialog(String newStatus) async {
    _messageController.text = _getDefaultMessageForStatus(newStatus);

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('ข้อความแจ้งเตือน'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('กรุณาระบุข้อความที่จะส่งให้ผู้ใช้และพี่เลี้ยง:'),
                SizedBox(height: 16),
                TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'ข้อความแจ้งเตือน',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('ยกเลิก'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('ยืนยัน'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getStatusColor(newStatus),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _updateBookingStatus(newStatus);
              },
            ),
          ],
        );
      },
    );
  }

  String _getDefaultMessageForStatus(String status) {
    switch (status) {
      case 'confirmed':
        return 'การจองของคุณได้รับการยืนยันแล้ว กรุณาติดต่อพี่เลี้ยงเพื่อนัดส่งแมว';
      case 'in_progress':
        return 'แมวของคุณกำลังได้รับการดูแลโดยพี่เลี้ยง';
      case 'completed':
        return 'การบริการเสร็จสิ้น ขอบคุณที่ใช้บริการ';
      case 'cancelled':
        return 'การจองได้ถูกยกเลิก';
      default:
        return '';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.amber;
      case 'confirmed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'รอการยืนยัน';
      case 'confirmed':
        return 'ยืนยันแล้ว';
      case 'in_progress':
        return 'กำลังดูแล';
      case 'completed':
        return 'เสร็จสิ้น';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return 'ไม่ทราบสถานะ';
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'ไม่ระบุ';
    return DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate());
  }

  String _formatDates(List<dynamic> dates) {
    if (dates.isEmpty) return 'ไม่ระบุวันที่';

    final formatter = DateFormat('dd/MM/yyyy');
    final List<DateTime> dateTimes = dates
        .map((date) => date is Timestamp ? date.toDate() : DateTime.now())
        .toList();

    dateTimes.sort();

    if (dateTimes.length > 1) {
      return '${formatter.format(dateTimes.first)} - ${formatter.format(dateTimes.last)}';
    }
    return formatter.format(dateTimes.first);
  }

  // เปิดแอปโทรศัพท์เพื่อโทรหาผู้ใช้หรือพี่เลี้ยง
  Future<void> _callPhone(String phone) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่พบหมายเลขโทรศัพท์')),
      );
      return;
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถโทรออกได้')),
      );
    }
  }

  // เปิดแอปส่งข้อความเพื่อส่ง SMS
  Future<void> _sendSMS(String phone) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่พบหมายเลขโทรศัพท์')),
      );
      return;
    }

    final Uri smsUri = Uri(scheme: 'sms', path: phone);
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถส่งข้อความได้')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดการจอง'),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadBookingData,
            tooltip: 'รีเฟรชข้อมูล',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookingData == null
              ? const Center(child: Text('ไม่พบข้อมูลการจอง'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusCard(),
                      const SizedBox(height: 16),
                      _buildUserInfo(),
                      const SizedBox(height: 16),
                      _buildSitterInfo(),
                      const SizedBox(height: 16),
                      _buildBookingDetails(),
                      const SizedBox(height: 16),
                      _buildCatsList(),
                      const SizedBox(height: 24),
                      _buildAdminActions(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatusCard() {
    final status = _bookingData!['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getStatusIcon(status),
                color: statusColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'สถานะ: ${_getStatusText(status)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  if (_bookingData!.containsKey('createdAt'))
                    Text(
                      'วันที่จอง: ${_formatTimestamp(_bookingData!['createdAt'])}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  if (_bookingData!.containsKey('updatedAt'))
                    Text(
                      'อัพเดทล่าสุด: ${_formatTimestamp(_bookingData!['updatedAt'])}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'confirmed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.pets;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Widget _buildUserInfo() {
    if (_userData == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('ไม่พบข้อมูลผู้ใช้'),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text(
                  'ข้อมูลผู้จอง',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: _userData!['photo'] != null &&
                          _userData!['photo'].toString().isNotEmpty &&
                          _userData!['photo'] != 'images/User.png'
                      ? NetworkImage(_userData!['photo'])
                      : null,
                  child: (_userData!['photo'] == null ||
                          _userData!['photo'].toString().isEmpty ||
                          _userData!['photo'] == 'images/User.png')
                      ? const Icon(Icons.person, size: 30)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userData!['name'] ?? 'ไม่ระบุชื่อ',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_userData!['email'] != null)
                        Text(
                          _userData!['email'],
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      if (_userData!['phone'] != null)
                        Row(
                          children: [
                            Text(
                              _userData!['phone'],
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            SizedBox(width: 8),
                            InkWell(
                              onTap: () => _callPhone(_userData!['phone']),
                              child: Icon(Icons.call,
                                  color: Colors.green, size: 20),
                            ),
                            SizedBox(width: 8),
                            InkWell(
                              onTap: () => _sendSMS(_userData!['phone']),
                              child: Icon(Icons.message,
                                  color: Colors.blue, size: 20),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSitterInfo() {
    if (_sitterData == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('ไม่พบข้อมูลพี่เลี้ยง'),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pets, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text(
                  'ข้อมูลพี่เลี้ยง',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: _sitterData!['photo'] != null &&
                          _sitterData!['photo'].toString().isNotEmpty &&
                          _sitterData!['photo'] != 'images/User.png'
                      ? NetworkImage(_sitterData!['photo'])
                      : null,
                  child: (_sitterData!['photo'] == null ||
                          _sitterData!['photo'].toString().isEmpty ||
                          _sitterData!['photo'] == 'images/User.png')
                      ? const Icon(Icons.person, size: 30)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _sitterData!['name'] ?? 'ไม่ระบุชื่อ',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_sitterData!['email'] != null)
                        Text(
                          _sitterData!['email'],
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      if (_sitterData!['phone'] != null)
                        Row(
                          children: [
                            Text(
                              _sitterData!['phone'],
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            SizedBox(width: 8),
                            InkWell(
                              onTap: () => _callPhone(_sitterData!['phone']),
                              child: Icon(Icons.call,
                                  color: Colors.green, size: 20),
                            ),
                            SizedBox(width: 8),
                            InkWell(
                              onTap: () => _sendSMS(_sitterData!['phone']),
                              child: Icon(Icons.message,
                                  color: Colors.blue, size: 20),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingDetails() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text(
                  'รายละเอียดการจอง',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              'รหัสการจอง:',
              widget.bookingId,
            ),
            _buildDetailRow(
              'วันที่ฝากเลี้ยง:',
              _formatDates(_bookingData!['dates'] ?? []),
            ),
            _buildDetailRow(
              'จำนวนวัน:',
              '${(_bookingData!['dates'] as List?)?.length ?? 0} วัน',
            ),
            _buildDetailRow(
              'ราคารวม:',
              '฿${_bookingData!['totalPrice'] ?? 0}',
              valueColor: Colors.green,
            ),
            if (_bookingData!['adminMessage'] != null &&
                _bookingData!['adminMessage'].isNotEmpty)
              _buildDetailRow(
                'ข้อความจากแอดมิน:',
                _bookingData!['adminMessage'],
              ),
            if (_bookingData!['notes'] != null &&
                _bookingData!['notes'].isNotEmpty)
              _buildDetailRow(
                'บันทึกเพิ่มเติม:',
                _bookingData!['notes'],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatsList() {
    if (_catsList.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('ไม่พบข้อมูลแมวที่ฝากเลี้ยง'),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pets, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text(
                  'แมวที่ฝากเลี้ยง',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _catsList.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final cat = _catsList[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: cat['imagePath'] != null &&
                            cat['imagePath'].toString().isNotEmpty
                        ? NetworkImage(cat['imagePath'])
                        : null,
                    child: cat['imagePath'] == null ||
                            cat['imagePath'].toString().isEmpty
                        ? const Icon(Icons.pets)
                        : null,
                  ),
                  title: Text(cat['name'] ?? 'ไม่ระบุชื่อแมว'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cat['breed'] ?? 'ไม่ระบุสายพันธุ์'),
                      if (cat['age'] != null) Text('อายุ: ${cat['age']} ปี'),
                    ],
                  ),
                  isThreeLine: cat['age'] != null,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminActions() {
    final status = _bookingData!['status'] ?? 'pending';

    // ถ้าสถานะเป็น cancelled หรือ completed ไม่ต้องแสดงปุ่มให้อัพเดทสถานะ
    if (status == 'cancelled' || status == 'completed') {
      return Container();
    }

    // สร้าง List ของสถานะถัดไปที่สามารถอัพเดทได้
    List<Map<String, dynamic>> nextStatuses = [];

    if (status == 'pending') {
      nextStatuses = [
        {'value': 'confirmed', 'label': 'ยืนยัน', 'color': Colors.green},
        {'value': 'cancelled', 'label': 'ยกเลิก', 'color': Colors.red},
      ];
    } else if (status == 'confirmed') {
      nextStatuses = [
        {
          'value': 'in_progress',
          'label': 'เริ่มให้บริการ',
          'color': Colors.blue
        },
        {'value': 'cancelled', 'label': 'ยกเลิก', 'color': Colors.red},
      ];
    } else if (status == 'in_progress') {
      nextStatuses = [
        {'value': 'completed', 'label': 'เสร็จสิ้น', 'color': Colors.purple},
      ];
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.update, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text(
                  'อัพเดทสถานะ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: nextStatuses.map((statusItem) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton.icon(
                      onPressed: () => _showMessageDialog(statusItem['value']),
                      icon: Icon(_getIconForStatus(statusItem['value'])),
                      label: Text(statusItem['label']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: statusItem['color'],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForStatus(String status) {
    switch (status) {
      case 'confirmed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.pets;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.update;
    }
  }
}
