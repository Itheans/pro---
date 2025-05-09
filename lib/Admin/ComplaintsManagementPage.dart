import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ComplaintsManagementPage extends StatefulWidget {
  const ComplaintsManagementPage({Key? key}) : super(key: key);

  @override
  _ComplaintsManagementPageState createState() =>
      _ComplaintsManagementPageState();
}

class _ComplaintsManagementPageState extends State<ComplaintsManagementPage> {
  bool _isLoading = true;
  List<DocumentSnapshot> _complaints = [];
  String _selectedStatus = 'all';
  final TextEditingController _responseController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _loadComplaints() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Query query = FirebaseFirestore.instance.collection('complaints');

      if (_selectedStatus != 'all') {
        query = query.where('status', isEqualTo: _selectedStatus);
      }

      query = query.orderBy('createdAt', descending: true);

      final snapshot = await query.get();

      setState(() {
        _complaints = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading complaints: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error getting user data: $e');
    }
    return null;
  }

  Future<void> _respondToComplaint(String complaintId) async {
    final response = _responseController.text.trim();
    if (response.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('กรุณากรอกข้อความตอบกลับ')),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      // อัพเดตสถานะและการตอบกลับของปัญหา
      await FirebaseFirestore.instance
          .collection('complaints')
          .doc(complaintId)
          .update({
        'status': 'resolved',
        'adminResponse': response,
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      // เคลียร์ข้อความในฟอร์ม
      _responseController.clear();

      // โหลดข้อมูลใหม่
      _loadComplaints();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ส่งข้อความตอบกลับเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error responding to complaint: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showComplaintDetails(DocumentSnapshot complaint) async {
    final data = complaint.data() as Map<String, dynamic>;

    // ดึงข้อมูลผู้ใช้
    Map<String, dynamic>? userData;
    if (data['userId'] != null) {
      userData = await _getUserData(data['userId']);
    }

    // ดึงข้อมูลการจอง (ถ้ามี)
    Map<String, dynamic>? bookingData;
    if (data['bookingId'] != null) {
      try {
        DocumentSnapshot bookingDoc = await FirebaseFirestore.instance
            .collection('bookings')
            .doc(data['bookingId'])
            .get();

        if (bookingDoc.exists) {
          bookingData = bookingDoc.data() as Map<String, dynamic>;
        }
      } catch (e) {
        print('Error getting booking data: $e');
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('รายละเอียดปัญหา'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ข้อมูลผู้รายงาน
              if (userData != null) ...[
                Text(
                  'ข้อมูลผู้รายงาน',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: userData['photo'] != null &&
                              userData['photo'] != 'images/User.png'
                          ? NetworkImage(userData['photo'])
                          : null,
                      child: userData['photo'] == null ||
                              userData['photo'] == 'images/User.png'
                          ? Icon(Icons.person)
                          : null,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userData['name'] ?? 'ไม่ระบุชื่อ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (userData['email'] != null)
                            Text(userData['email']),
                          if (userData['phone'] != null)
                            InkWell(
                              onTap: () async {
                                final Uri phoneUri = Uri(
                                  scheme: 'tel',
                                  path: userData?['phone'],
                                );
                                if (await canLaunchUrl(phoneUri)) {
                                  await launchUrl(phoneUri);
                                }
                              },
                              child: Row(
                                children: [
                                  Icon(Icons.phone,
                                      size: 16, color: Colors.blue),
                                  SizedBox(width: 4),
                                  Text(
                                    userData['phone'],
                                    style: TextStyle(
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                Divider(height: 20),
              ],

              // ข้อมูลการจอง (ถ้ามี)
              if (bookingData != null) ...[
                Text(
                  'ข้อมูลการจอง',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 10),
                Text('รหัสการจอง: ${data['bookingId']}'),
                Text(
                    'สถานะ: ${_getBookingStatusText(bookingData['status'] ?? 'pending')}'),
                if (bookingData['createdAt'] != null)
                  Text(
                      'วันที่จอง: ${DateFormat('dd/MM/yyyy').format((bookingData['createdAt'] as Timestamp).toDate())}'),
                if (bookingData['totalPrice'] != null)
                  Text('จำนวนเงิน: ฿${bookingData['totalPrice']}'),
                Divider(height: 20),
              ],

              // รายละเอียดปัญหา
              Text(
                'รายละเอียดปัญหา',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 10),
              Text('ประเภท: ${data['type'] ?? 'ไม่ระบุ'}'),
              if (data['createdAt'] != null)
                Text(
                    'วันที่รายงาน: ${DateFormat('dd/MM/yyyy HH:mm').format((data['createdAt'] as Timestamp).toDate())}'),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(data['description'] ?? 'ไม่มีรายละเอียด'),
              ),
              SizedBox(height: 16),

              // รูปภาพหลักฐาน (ถ้ามี)
              if (data['images'] != null &&
                  (data['images'] as List).isNotEmpty) ...[
                Text(
                  'รูปภาพหลักฐาน',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 10),
                Container(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: (data['images'] as List).length,
                    itemBuilder: (context, index) {
                      final imageUrl = (data['images'] as List)[index];
                      return GestureDetector(
                        onTap: () {
                          // แสดงรูปภาพเต็มจอ
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Scaffold(
                                appBar: AppBar(
                                  backgroundColor: Colors.black,
                                  elevation: 0,
                                ),
                                backgroundColor: Colors.black,
                                body: Center(
                                  child: InteractiveViewer(
                                    child: Image.network(imageUrl),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 100,
                          margin: EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(imageUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 16),
              ],

              // การตอบกลับจากแอดมิน
              if (data['status'] == 'resolved' &&
                  data['adminResponse'] != null) ...[
                Text(
                  'การตอบกลับ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 10),
                if (data['resolvedAt'] != null)
                  Text(
                      'วันที่ตอบกลับ: ${DateFormat('dd/MM/yyyy HH:mm').format((data['resolvedAt'] as Timestamp).toDate())}'),
                SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(data['adminResponse']),
                ),
              ],

              // ฟอร์มตอบกลับ (ถ้าปัญหายังไม่ถูกแก้ไข)
              if (data['status'] == 'pending') ...[
                SizedBox(height: 20),
                Text(
                  'ตอบกลับปัญหานี้',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _responseController,
                  decoration: InputDecoration(
                    hintText: 'กรอกข้อความตอบกลับ',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('ปิด'),
          ),
          if (data['status'] == 'pending')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _respondToComplaint(complaint.id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: Text('ส่งคำตอบ'),
            ),
        ],
      ),
    );
  }

  String _getBookingStatusText(String status) {
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

  Color _getComplaintStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getComplaintStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'รอการตอบกลับ';
      case 'resolved':
        return 'แก้ไขแล้ว';
      default:
        return 'ไม่ทราบสถานะ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('จัดการปัญหาและข้อร้องเรียน'),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadComplaints,
            tooltip: 'รีเฟรชข้อมูล',
          ),
        ],
      ),
      body: Column(
        children: [
          // ตัวเลือกการกรอง
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Text('สถานะ: '),
                SizedBox(width: 8),
                ChoiceChip(
                  label: Text('ทั้งหมด'),
                  selected: _selectedStatus == 'all',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedStatus = 'all';
                      });
                      _loadComplaints();
                    }
                  },
                ),
                SizedBox(width: 8),
                ChoiceChip(
                  label: Text('รอตอบกลับ'),
                  selected: _selectedStatus == 'pending',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedStatus = 'pending';
                      });
                      _loadComplaints();
                    }
                  },
                ),
                SizedBox(width: 8),
                ChoiceChip(
                  label: Text('แก้ไขแล้ว'),
                  selected: _selectedStatus == 'resolved',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedStatus = 'resolved';
                      });
                      _loadComplaints();
                    }
                  },
                ),
              ],
            ),
          ),

          // รายการปัญหา
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _complaints.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'ไม่พบรายการปัญหา',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _complaints.length,
                        padding: EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final complaint = _complaints[index];
                          final data = complaint.data() as Map<String, dynamic>;

                          return Card(
                            margin: EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () => _showComplaintDetails(complaint),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getComplaintStatusColor(
                                                    data['status'] ?? 'pending')
                                                .withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            _getComplaintStatusText(
                                                data['status'] ?? 'pending'),
                                            style: TextStyle(
                                              color: _getComplaintStatusColor(
                                                  data['status'] ?? 'pending'),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          '${data['type'] ?? 'ไม่ระบุประเภท'}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Spacer(),
                                        if (data['createdAt'] != null)
                                          Text(
                                            DateFormat('dd/MM/yyyy').format(
                                                (data['createdAt'] as Timestamp)
                                                    .toDate()),
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      data['description'] ?? 'ไม่มีคำอธิบาย',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (data['bookingId'] != null) ...[
                                      SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.bookmark,
                                              size: 16, color: Colors.grey),
                                          SizedBox(width: 4),
                                          Text(
                                            'รหัสการจอง: ${data['bookingId']}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (data['userId'] != null) ...[
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.person,
                                              size: 16, color: Colors.grey),
                                          SizedBox(width: 4),
                                          Text(
                                            'ผู้รายงาน: ${data['userName'] ?? data['userId']}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
