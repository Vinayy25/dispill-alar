import 'package:dispill/states/history_state.dart';
import 'package:dispill/utils.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class CheckHistory extends StatefulWidget {
  const CheckHistory({super.key});

  @override
  State<CheckHistory> createState() => _CheckHistoryState();
}

class _CheckHistoryState extends State<CheckHistory>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HistoryState>(
      builder: (context, historyState, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            elevation: 0,
            title: const Text(
              "Medication History",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            centerTitle: true,
            backgroundColor: const Color(0xFF5A9797),
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () {
                  // Show filter options
                },
              )
            ],
          ),
          body: historyState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Date Range Selector
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5A9797),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 0,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Date range display
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.date_range, color: Colors.white),
                              const SizedBox(width: 10),
                              Text(
                                "${DateFormat('MMM d').format(historyState.startDate)} - ${DateFormat('MMM d').format(historyState.endDate)}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_drop_down,
                                    color: Colors.white),
                                onPressed: () {
                                  // Show date range picker
                                },
                              ),
                            ],
                          ),

                          // Range buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildRangeButton(historyState, "Week"),
                              _buildRangeButton(historyState, "Month"),
                              _buildRangeButton(historyState, "3 Months"),
                              _buildRangeButton(historyState, "Year"),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Summary card
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              spreadRadius: 2,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Medication Adherence",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _getAdherenceColor(
                                        historyState.adherenceRate),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Text(
                                    "${historyState.adherenceRate}%",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildSummaryItem(
                                    "Taken",
                                    "${historyState.takenCount}",
                                    Icons.check_circle,
                                    Colors.green),
                                _buildSummaryItem(
                                    "Missed",
                                    "${historyState.missedCount}",
                                    Icons.cancel,
                                    Colors.red),
                                _buildSummaryItem(
                                    "Late",
                                    "${historyState.lateCount}",
                                    Icons.access_time,
                                    Colors.orange),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Tab Bar
                    TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF5A9797),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: const Color(0xFF5A9797),
                      tabs: const [
                        Tab(icon: Icon(Icons.list_alt), text: "List"),
                        Tab(icon: Icon(Icons.calendar_today), text: "Calendar"),
                        Tab(icon: Icon(Icons.bar_chart), text: "Chart"),
                      ],
                    ),

                    // Tab Views
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // List View
                          _buildListView(historyState),

                          // Calendar View
                          const Center(child: Text("Calendar View")),

                          // Chart View
                          _buildChartView(historyState),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildRangeButton(HistoryState historyState, String text) {
    bool isSelected = historyState.currentRange == text;
    return GestureDetector(
      onTap: () {
        historyState.setDateRange(text);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Colors.white,
            width: 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? const Color(0xFF5A9797) : Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Color _getAdherenceColor(int rate) {
    if (rate >= 85) return Colors.green;
    if (rate >= 70) return Colors.orange;
    return Colors.red;
  }

  Widget _buildListView(HistoryState historyState) {
    final List<Map<String, dynamic>> historyItems = historyState.getListData();

    if (historyItems.isEmpty) {
      return const Center(child: Text("No medication history available"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: historyItems.length,
      itemBuilder: (context, index) {
        final item = historyItems[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                item["date"],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            ...List.generate(
              item["medications"].length,
              (idx) => _buildMedicationItem(item["medications"][idx]),
            ),
            const Divider(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildMedicationItem(Map<String, dynamic> medication) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: medication["taken"]
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              medication["taken"] ? Icons.check : Icons.close,
              color: medication["taken"] ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication["name"],
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${medication["dosage"]} · ${medication["time"]}",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.navigate_next,
            color: Colors.grey[400],
          ),
        ],
      ),
    );
  }

  Widget _buildChartView(HistoryState historyState) {
    final chartData = historyState.getWeeklyChartData();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Legend
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem("Taken", Colors.green),
                const SizedBox(width: 20),
                _buildLegendItem("Missed", Colors.red),
                const SizedBox(width: 20),
                _buildLegendItem("Late", Colors.orange),
              ],
            ),
          ),

          // Chart
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 4,
                barTouchData: BarTouchData(
                  enabled: true,
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        switch (value.toInt()) {
                          case 0:
                            return const Text('Mon');
                          case 1:
                            return const Text('Tue');
                          case 2:
                            return const Text('Wed');
                          case 3:
                            return const Text('Thu');
                          case 4:
                            return const Text('Fri');
                          case 5:
                            return const Text('Sat');
                          case 6:
                            return const Text('Sun');
                          default:
                            return const Text('');
                        }
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) {
                          return const Text('');
                        }
                        return Text(value.toInt().toString());
                      },
                      reservedSize: 30,
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  checkToShowHorizontalLine: (value) => value % 1 == 0,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: const Color(0xffe7e8ec),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(
                  show: false,
                ),
                barGroups: chartData.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final data = entry.value;
                  return _makeGroupData(
                    idx,
                    data['taken'].toDouble(),
                    data['missed'].toDouble(),
                    data['late'].toDouble(),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeGroupData(
    int x,
    double taken,
    double missed,
    double late,
  ) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: taken,
          color: Colors.green,
          width: 12,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(3),
            topRight: Radius.circular(3),
          ),
        ),
        BarChartRodData(
          toY: missed,
          color: Colors.red,
          width: 12,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(3),
            topRight: Radius.circular(3),
          ),
        ),
        BarChartRodData(
          toY: late,
          color: Colors.orange,
          width: 12,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(3),
            topRight: Radius.circular(3),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
