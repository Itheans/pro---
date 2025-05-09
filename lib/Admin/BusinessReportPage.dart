import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class BusinessReportPage extends StatefulWidget {
  const BusinessReportPage({Key? key}) : super(key: key);

  @override
  _BusinessReportPageState createState() => _BusinessReportPageState();
}

class _BusinessReportPageState extends State<BusinessReportPage> {
  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _endDate = DateTime.now();

  // สถิติต่างๆ
  double _totalRevenue = 0;
  int _totalBookings = 0;
  int _activeUsers = 0;
  int _activeSitters = 0;

  // ข้อมูลกราฟ
  List<FlSpot> _revenueData = [];
  List<FlSpot> _bookingsData = [];

  // ข้อมูลการจัดอันดับ
  List<Map<String, dynamic>> _topSitters = [];
  List<Map<String, dynamic>> _topLocations = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. ดึงข้อมูลการจองทั้งหมดในช่วงเวลา
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_endDate))
          .get();

      // 2. คำนวณรายได้ทั้งหมดและจำนวนการจอง
      _totalRevenue = 0;
      _totalBookings = bookingsSnapshot.docs.length;

      // แผนที่เก็บรายได้ตามวัน
      Map<String, double> dailyRevenue = {};
      Map<String, int> dailyBookings = {};
      Map<String, int> sitterBookings = {};
      Map<String, double> sitterRevenue = {};
      Map<String, int> locationBookings = {};

      // วนลูปข้อมูลการจอง
      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();

        // คำนวณรายได้
        if (data['totalPrice'] != null) {
          double price = (data['totalPrice'] is int)
              ? (data['totalPrice'] as int).toDouble()
              : (data['totalPrice'] as double);
          _totalRevenue += price;

          // บันทึกวันที่
          if (data['createdAt'] != null) {
            String dateStr = DateFormat('yyyy-MM-dd')
                .format((data['createdAt'] as Timestamp).toDate());

            // สะสมรายได้รายวัน
            dailyRevenue[dateStr] = (dailyRevenue[dateStr] ?? 0) + price;
            dailyBookings[dateStr] = (dailyBookings[dateStr] ?? 0) + 1;
          }
        }

        // นับจำนวนการจองตาม sitter
        if (data['sitterId'] != null) {
          String sitterId = data['sitterId'];
          sitterBookings[sitterId] = (sitterBookings[sitterId] ?? 0) + 1;

          if (data['totalPrice'] != null) {
            double price = (data['totalPrice'] is int)
                ? (data['totalPrice'] as int).toDouble()
                : (data['totalPrice'] as double);
            sitterRevenue[sitterId] = (sitterRevenue[sitterId] ?? 0) + price;
          }
        }

        // นับจำนวนการจองตามพื้นที่
        if (data['location'] != null) {
          String location = data['location'];
          locationBookings[location] = (locationBookings[location] ?? 0) + 1;
        }
      }

      // 3. นับจำนวนผู้ใช้และพี่เลี้ยงที่แอคทีฟ (มีการทำธุรกรรมในช่วงเวลาที่กำหนด)
      Set<String> activeUserIds = {};
      Set<String> activeSitterIds = {};

      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        if (data['userId'] != null) {
          activeUserIds.add(data['userId']);
        }
        if (data['sitterId'] != null) {
          activeSitterIds.add(data['sitterId']);
        }
      }

      _activeUsers = activeUserIds.length;
      _activeSitters = activeSitterIds.length;

      // 4. แปลงข้อมูลเป็นรูปแบบสำหรับกราฟ
      _revenueData = [];
      _bookingsData = [];

      // สร้าง list ของวันที่ในช่วงเวลาที่เลือก
      List<DateTime> dateRange = [];
      DateTime current = _startDate;
      while (current.isBefore(_endDate) || current.isAtSameMomentAs(_endDate)) {
        dateRange.add(current);
        current = current.add(Duration(days: 1));
      }

      // สร้าง data points สำหรับกราฟ
      int i = 0;
      for (var date in dateRange) {
        String dateStr = DateFormat('yyyy-MM-dd').format(date);
        _revenueData.add(FlSpot(i.toDouble(), dailyRevenue[dateStr] ?? 0));
        _bookingsData.add(
            FlSpot(i.toDouble(), (dailyBookings[dateStr] ?? 0).toDouble()));
        i++;
      }

      // 5. ดึงข้อมูลพี่เลี้ยงยอดนิยม
      _topSitters = [];
      for (var entry in sitterBookings.entries) {
        if (entry.value > 0) {
          DocumentSnapshot sitterDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(entry.key)
              .get();

          if (sitterDoc.exists) {
            Map<String, dynamic> sitterData =
                sitterDoc.data() as Map<String, dynamic>;
            _topSitters.add({
              'id': entry.key,
              'name': sitterData['name'] ?? 'ไม่ระบุชื่อ',
              'photo': sitterData['photo'],
              'bookings': entry.value,
              'revenue': sitterRevenue[entry.key] ?? 0,
            });
          }
        }
      }

      // เรียงลำดับตามจำนวนการจอง
      _topSitters.sort((a, b) => b['bookings'].compareTo(a['bookings']));
      if (_topSitters.length > 5) {
        _topSitters = _topSitters.sublist(0, 5);
      }

      // 6. ดึงข้อมูลพื้นที่ยอดนิยม
      _topLocations = [];
      for (var entry in locationBookings.entries) {
        _topLocations.add({
          'location': entry.key,
          'bookings': entry.value,
        });
      }

      // เรียงลำดับตามจำนวนการจอง
      _topLocations.sort((a, b) => b['bookings'].compareTo(a['bookings']));
      if (_topLocations.length > 5) {
        _topLocations = _topLocations.sublist(0, 5);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.deepOrange,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('รายงานธุรกิจ'),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: _selectDateRange,
            tooltip: 'เลือกช่วงเวลา',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
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
                  // แสดงช่วงเวลาที่เลือก
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.date_range, color: Colors.deepOrange),
                        SizedBox(width: 8),
                        Text(
                          'ช่วงเวลา: ${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        TextButton.icon(
                          onPressed: _selectDateRange,
                          icon: Icon(Icons.edit, size: 16),
                          label: Text('เปลี่ยน'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),

                  // สรุปข้อมูลสำคัญ
                  Text(
                    'ภาพรวมธุรกิจ',
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
                      _buildStatCard(
                        'รายได้ทั้งหมด',
                        '฿${NumberFormat('#,##0.00').format(_totalRevenue)}',
                        Icons.monetization_on,
                        Colors.green,
                      ),
                      _buildStatCard(
                        'จำนวนการจอง',
                        '$_totalBookings รายการ',
                        Icons.calendar_today,
                        Colors.blue,
                      ),
                      _buildStatCard(
                        'ผู้ใช้ที่ใช้งาน',
                        '$_activeUsers คน',
                        Icons.people,
                        Colors.purple,
                      ),
                      _buildStatCard(
                        'พี่เลี้ยงที่ใช้งาน',
                        '$_activeSitters คน',
                        Icons.pets,
                        Colors.deepOrange,
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  // กราฟรายได้รายวัน
                  Text(
                    'รายได้รายวัน',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    height: 200,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: _revenueData.isEmpty
                        ? Center(child: Text('ไม่มีข้อมูลในช่วงเวลาที่เลือก'))
                        : LineChart(
                            LineChartData(
                              gridData: FlGridData(show: false),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      if (value.toInt() %
                                              (_revenueData.length ~/ 5 + 1) ==
                                          0) {
                                        int index = value.toInt();
                                        if (index >= 0 &&
                                            index < _revenueData.length) {
                                          DateTime date = _startDate
                                              .add(Duration(days: index));
                                          return Text(
                                            DateFormat('d/M').format(date),
                                            style: TextStyle(fontSize: 10),
                                          );
                                        }
                                      }
                                      return Text('');
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        '฿${value.toInt()}',
                                        style: TextStyle(fontSize: 10),
                                      );
                                    },
                                    reservedSize: 40,
                                  ),
                                ),
                                topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              borderData: FlBorderData(show: true),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _revenueData,
                                  isCurved: true,
                                  color: Colors.green,
                                  barWidth: 3,
                                  dotData: FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: Colors.green.withOpacity(0.1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  SizedBox(height: 20),

                  // กราฟจำนวนการจองรายวัน
                  Text(
                    'จำนวนการจองรายวัน',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    height: 200,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: _bookingsData.isEmpty
                        ? Center(child: Text('ไม่มีข้อมูลในช่วงเวลาที่เลือก'))
                        : LineChart(
                            LineChartData(
                              gridData: FlGridData(show: false),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      if (value.toInt() %
                                              (_bookingsData.length ~/ 5 + 1) ==
                                          0) {
                                        int index = value.toInt();
                                        if (index >= 0 &&
                                            index < _bookingsData.length) {
                                          DateTime date = _startDate
                                              .add(Duration(days: index));
                                          return Text(
                                            DateFormat('d/M').format(date),
                                            style: TextStyle(fontSize: 10),
                                          );
                                        }
                                      }
                                      return Text('');
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        value.toInt().toString(),
                                        style: TextStyle(fontSize: 10),
                                      );
                                    },
                                    reservedSize: 30,
                                  ),
                                ),
                                topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              borderData: FlBorderData(show: true),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _bookingsData,
                                  isCurved: true,
                                  color: Colors.blue,
                                  barWidth: 3,
                                  dotData: FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: Colors.blue.withOpacity(0.1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  SizedBox(height: 20),

                  // พี่เลี้ยงยอดนิยม
                  Text(
                    'พี่เลี้ยงยอดนิยม',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: _topSitters.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                                child: Text('ไม่มีข้อมูลในช่วงเวลาที่เลือก')),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: _topSitters.length,
                            itemBuilder: (context, index) {
                              final sitter = _topSitters[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: sitter['photo'] != null &&
                                          sitter['photo'] != 'images/User.png'
                                      ? NetworkImage(sitter['photo'])
                                      : null,
                                  child: sitter['photo'] == null ||
                                          sitter['photo'] == 'images/User.png'
                                      ? Icon(Icons.person)
                                      : null,
                                ),
                                title: Text(sitter['name']),
                                subtitle: Text('${sitter['bookings']} รายการ'),
                                trailing: Text(
                                  '฿${NumberFormat('#,##0').format(sitter['revenue'])}',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
