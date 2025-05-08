import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({Key? key}) : super(key: key);

  @override
  _UserManagementPageState createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // สำหรับเก็บข้อมูลผู้ใช้ทั้งหมด (แทนการดึงข้อมูลซ้ำๆ)
  List<DocumentSnapshot> _users = [];
  List<DocumentSnapshot> _sitters = [];
  List<DocumentSnapshot> _admins = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      // ล้างการค้นหาเมื่อเปลี่ยนแท็บ
      setState(() {
        _searchController.clear();
        _searchQuery = '';
      });
    });

    // โหลดข้อมูลเมื่อเริ่มแอพ
    _loadAllUsers();
  }

  Future<void> _loadAllUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // โหลดข้อมูลผู้ใช้ทั่วไป
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'user')
          .get();

      // โหลดข้อมูลพี่เลี้ยง
      final sittersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'sitter')
          .get();

      // โหลดข้อมูลแอดมิน
      final adminsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      setState(() {
        _users = usersSnapshot.docs;
        _sitters = sittersSnapshot.docs;
        _admins = adminsSnapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // เปิดแอปโทรศัพท์เพื่อโทรหาผู้ใช้
  Future<void> _callUser(String phone) async {
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

  // เปิดแอปอีเมลเพื่อส่งอีเมลถึงผู้ใช้
  Future<void> _emailUser(String email) async {
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่พบอีเมล')),
      );
      return;
    }

    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': 'แจ้งข้อมูลจากแอปพลิเคชันรับเลี้ยงแมว'},
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถเปิดแอปอีเมลได้')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('จัดการผู้ใช้งาน'),
        backgroundColor: Colors.deepOrange,
        actions: [
          // ปุ่มรีเฟรชข้อมูล
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAllUsers,
            tooltip: 'รีเฟรชข้อมูล',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'ผู้ใช้ทั่วไป'),
            Tab(text: 'พี่เลี้ยงแมว'),
            Tab(text: 'แอดมิน'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ช่องค้นหา
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'ค้นหาจากชื่อ อีเมล หรือเบอร์โทร',
                      prefixIcon: Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.deepOrange, width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),

                // แสดงรายการผู้ใช้งาน
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // แท็บผู้ใช้ทั่วไป
                      _buildUsersListView(_users, 'user'),

                      // แท็บพี่เลี้ยงแมว
                      _buildUsersListView(_sitters, 'sitter'),

                      // แท็บแอดมิน
                      _buildUsersListView(_admins, 'admin'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildUsersListView(List<DocumentSnapshot> docs, String role) {
    // กรองข้อมูลตามคำค้นหา
    var filteredDocs = docs;
    if (_searchQuery.isNotEmpty) {
      filteredDocs = docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString().toLowerCase();
        final email = (data['email'] ?? '').toString().toLowerCase();
        final phone = (data['phone'] ?? '').toString().toLowerCase();

        return name.contains(_searchQuery.toLowerCase()) ||
            email.contains(_searchQuery.toLowerCase()) ||
            phone.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    if (filteredDocs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'ไม่พบข้อมูลผู้ใช้งาน'
                  : 'ไม่พบข้อมูลที่ตรงกับการค้นหา',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredDocs.length,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (context, index) {
        final doc = filteredDocs[index];
        final userData = doc.data() as Map<String, dynamic>;

        return Card(
          margin: EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => _buildUserDetailDialog(userData, doc.id),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  // รูปโปรไฟล์
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: userData['photo'] != null &&
                            userData['photo'].toString().isNotEmpty &&
                            userData['photo'] != 'images/User.png'
                        ? NetworkImage(userData['photo'])
                        : null,
                    child: (userData['photo'] == null ||
                            userData['photo'].toString().isEmpty ||
                            userData['photo'] == 'images/User.png')
                        ? Icon(Icons.person, size: 30)
                        : null,
                  ),
                  SizedBox(width: 16),

                  // ข้อมูลผู้ใช้
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userData['name'] ?? 'ไม่ระบุชื่อ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        if (userData['email'] != null)
                          Text(
                            userData['email'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        if (userData['phone'] != null)
                          Text(
                            'โทร: ${userData['phone']}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        SizedBox(height: 4),

                        // แสดงสถานะสำหรับพี่เลี้ยง
                        if (role == 'sitter' && userData['status'] != null)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getStatusColor(userData['status'])
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getStatusText(userData['status']),
                              style: TextStyle(
                                color: _getStatusColor(userData['status']),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ปุ่มโทรและส่งอีเมล
                  Column(
                    children: [
                      if (userData['phone'] != null &&
                          userData['phone'].toString().isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.call, color: Colors.green),
                          onPressed: () => _callUser(userData['phone']),
                          tooltip: 'โทรหาผู้ใช้',
                        ),
                      if (userData['email'] != null &&
                          userData['email'].toString().isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.email, color: Colors.blue),
                          onPressed: () => _emailUser(userData['email']),
                          tooltip: 'ส่งอีเมลถึงผู้ใช้',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.amber;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'pending':
        return 'รอการอนุมัติ';
      case 'approved':
        return 'อนุมัติแล้ว';
      case 'rejected':
        return 'ถูกปฏิเสธ';
      default:
        return 'ไม่ระบุสถานะ';
    }
  }

  // สร้างไดอะล็อกแสดงรายละเอียดผู้ใช้
  Widget _buildUserDetailDialog(Map<String, dynamic> userData, String userId) {
    return AlertDialog(
      title: const Text('ข้อมูลผู้ใช้งาน'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundImage: userData['photo'] != null &&
                        userData['photo'].toString().isNotEmpty &&
                        userData['photo'] != 'images/User.png'
                    ? NetworkImage(userData['photo'])
                    : null,
                child: (userData['photo'] == null ||
                        userData['photo'].toString().isEmpty ||
                        userData['photo'] == 'images/User.png')
                    ? const Icon(Icons.person, size: 50)
                    : null,
              ),
            ),
            SizedBox(height: 16),

            // ข้อมูลทั่วไป
            _buildDetailItem('ชื่อ', userData['name'] ?? 'ไม่ระบุ'),
            _buildDetailItem('อีเมล', userData['email'] ?? 'ไม่ระบุ'),
            _buildDetailItem('เบอร์โทร', userData['phone'] ?? 'ไม่ระบุ'),
            _buildDetailItem('บทบาท', _getRoleText(userData['role'])),

            // ข้อมูลเฉพาะสำหรับพี่เลี้ยง
            if (userData['role'] == 'sitter')
              _buildDetailItem('สถานะ', _getStatusText(userData['status'])),

            if (userData['role'] == 'sitter' && userData['address'] != null)
              _buildDetailItem('ที่อยู่', userData['address']),

            if (userData['createdAt'] != null)
              _buildDetailItem(
                'สมัครเมื่อ',
                DateFormat('dd/MM/yyyy HH:mm')
                    .format((userData['createdAt'] as Timestamp).toDate()),
              ),

            if (userData['role'] == 'sitter' &&
                userData['rejectionReason'] != null)
              _buildDetailItem(
                  'เหตุผลที่ถูกปฏิเสธ', userData['rejectionReason']),

            // ข้อมูลเพิ่มเติม
            if (userData['additionalInfo'] != null &&
                userData['additionalInfo'].toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'ข้อมูลเพิ่มเติม',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(userData['additionalInfo']),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ปิด'),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleText(String? role) {
    switch (role) {
      case 'user':
        return 'ผู้ใช้ทั่วไป';
      case 'sitter':
        return 'พี่เลี้ยงแมว';
      case 'admin':
        return 'ผู้ดูแลระบบ';
      default:
        return 'ไม่ระบุบทบาท';
    }
  }
}
