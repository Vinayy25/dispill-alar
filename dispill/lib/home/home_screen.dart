import 'package:animate_do/animate_do.dart';
import 'package:dispill/home/check_history.dart';
import 'package:dispill/home/edit_prescription.dart';
import 'package:dispill/models/firebase_model.dart';
import 'package:dispill/services/http.dart';
import 'package:dispill/states/auth_state.dart';
import 'package:dispill/states/device_parameters_state.dart';
import 'package:dispill/states/notification_state.dart';
import 'package:dispill/states/prescription_state.dart';
import 'package:dispill/states/settings_state.dart';
import 'package:dispill/states/history_state.dart';
import 'package:dispill/utils.dart';
import 'package:dispill/widgets/home_screen_widgets.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

List<String> weekday = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday'
];

List<String> month = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December'
];

class Homescreen extends StatefulWidget {
  Homescreen({
    super.key,
  });

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoaded = false;
  late AnimationController _animationController;
  late TabController _insightsTabController;
  bool _showHealthInsights = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _insightsTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _insightsTabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notificationState =
            Provider.of<NotificationState>(context, listen: false);

        try {
          // Call the method without chaining catchError
          notificationState
              .getNotifications(FirebaseService().email.toString());
        } catch (error) {
          // Handle the error here
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Network error: Unable to fetch notifications'),
              backgroundColor: Colors.red,
            ),
          );
        }

        // Also fetch history data for stats display
        try {
          Provider.of<HistoryState>(context, listen: false).fetchHistory();
        } catch (error) {
          // Handle history fetch error
        }
      });
      _isLoaded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    final String name = FirebaseService().username.toString();
    final DateTime now = DateTime.now();

    final notificationState = Provider.of<NotificationState>(context);
    final historyState = Provider.of<HistoryState>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      key: _scaffoldKey,
      drawer: myDrawer(context),
      extendBody: true,
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(206, 246, 246, 52 / 100),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
          icon: const Icon(
            Icons.menu,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            color: Colors.black,
            tooltip: 'Notifications',
            onPressed: () {
              // Show notifications or navigate to notifications page
            },
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => CheckHistory()));
            },
            icon: const Icon(Icons.calendar_month),
            color: Colors.black,
            tooltip: 'Calendar',
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: const Color(0xFF5A9797),
            onRefresh: () async {
              notificationState
                  .getNotifications(FirebaseService().email.toString());
              await Provider.of<HistoryState>(context, listen: false)
                  .fetchHistory();
            },
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Header with greeting
                    _buildHeader(width, name, now),

                    const SizedBox(height: 20),

                    // Health stats summary card
                    AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Column(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showHealthInsights = !_showHealthInsights;
                                  });
                                  if (_showHealthInsights) {
                                    _animationController.forward();
                                  } else {
                                    _animationController.reverse();
                                  }
                                },
                                child:
                                    _buildStatsSummary(context, historyState),
                              ),

                              // Expanded insights panel
                              ClipRect(
                                child: SizeTransition(
                                  sizeFactor: _animationController,
                                  child: _buildExpandedInsights(historyState),
                                ),
                              ),
                            ],
                          );
                        }),

                    const SizedBox(height: 24),

                    // Today's Schedule section with schedule indicator
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text(
                                "Today's Schedule",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff0E0A56),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _getScheduleStatusColor(
                                          notificationState
                                              .notifications.isEmpty)
                                      .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  notificationState.notifications.isEmpty
                                      ? "All Done"
                                      : "${notificationState.notifications.length} Pending",
                                  style: TextStyle(
                                    color: _getScheduleStatusColor(
                                        notificationState
                                            .notifications.isEmpty),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!notificationState.isLoading &&
                              notificationState.notifications.isNotEmpty)
                            TextButton(
                              onPressed: () => Navigator.pushNamed(
                                  context, '/check-history'),
                              child: const Text(
                                "See All",
                                style: TextStyle(
                                  color: Color(0xFF5A9797),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Notifications section
                    if (notificationState.isLoading)
                      _buildLoadingState(height)
                    else if (notificationState.notifications.isEmpty)
                      _buildEnhancedEmptyState(context)
                    else
                      _buildNotificationsList(notificationState, context),

                    const SizedBox(height: 24),

                    // Quick actions section
                    _buildQuickActions(context),

                    const SizedBox(height: 24),

                    // Health tips carousel
                    _buildHealthTipsCarousel(),

                    const SizedBox(height: 24),

                    // Adherence streak section
                    _buildAdherenceStreak(historyState),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build Header method
  Widget _buildHeader(double width, String name, DateTime now) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello, ${name.split(" ")[0]}!",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff0E0A56),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "It's ${weekday[now.weekday - 1]}, ${month[now.month - 1]} ${now.day}",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : "U",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5A9797),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Stats Summary method
  Widget _buildStatsSummary(BuildContext context, HistoryState historyState) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _showHealthInsights
            ? const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              )
            : BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Health Summary",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff0E0A56),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF5A9797).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _showHealthInsights
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: const Color(0xFF5A9797),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard(
                context,
                "Adherence",
                "${historyState.adherenceRate}%",
                Icons.check_circle,
                _getAdherenceColor(historyState.adherenceRate),
              ),
              _buildStatCard(
                context,
                "Taken",
                historyState.takenCount.toString(),
                Icons.local_pharmacy,
                const Color(0xFF5A9797),
              ),
              _buildStatCard(
                context,
                "Missed",
                historyState.missedCount.toString(),
                Icons.warning_amber,
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper for stats summary
  Widget _buildStatCard(BuildContext context, String label, String value,
      IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        )
      ],
    );
  }

  // Helper for adherence color
  Color _getAdherenceColor(int rate) {
    if (rate >= 85) return Colors.green;
    if (rate >= 70) return Colors.orange;
    return Colors.red;
  }

  // Loading state method
  Widget _buildLoadingState(double height) {
    return Skeletonizer(
      enabled: true,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: List.generate(
              3,
              (index) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                height: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 100,
                                height: 12,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                  )),
        ),
      ),
    );
  }

  // Notifications List method
  Widget _buildNotificationsList(
      NotificationState notificationState, BuildContext context) {
    return Column(
      children: notificationState.notifications.asMap().entries.map((entry) {
        final index = entry.key;
        final notification = entry.value;

        return HomeNotificationBlock(
          tabletName: notification.tabletName,
          pillIcon: (index % 2 == 0)
              ? 'assets/images/pink_pills1.png'
              : 'assets/images/blue_pills1.png',
          statusName: notification.missed
              ? 'assets/images/alert1.png'
              : 'assets/images/taken1.png',
          tabletDosage: notification.dosage,
          beforeFood: !notification.afterFood,
          timeOfDay: notification.period,
          timeToTake: TimeOfDay(
            hour: int.parse(notification.takeTime.split(":")[0]),
            minute: int.parse(notification.takeTime.split(":")[1]),
          ),
          onTakenPressed: () async {
            // Mark notification as taken using the period info
            String period = notification.period;

            if (period.isNotEmpty) {
              // Call the provider method to mark as taken
              await Provider.of<PrescriptionStateProvider>(context,
                      listen: false)
                  .markMedicationTaken(period);

              // Refresh notifications after marking as taken
              notificationState
                  .getNotifications(FirebaseService().email.toString());

              // Show confirmation
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Medication marked as taken'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        );
      }).toList(),
    );
  }

  // Quick Actions method
  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 20, right: 20, bottom: 12),
          child: Text(
            "Quick Actions",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xff0E0A56),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildQuickActionButton(
              context,
              Icons.add_circle_outline,
              "Add\nMed",
              const Color(0xFF5A9797),
              () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => EditPrescriptionScreen())),
            ),
            _buildQuickActionButton(
                context,
                Icons.history,
                "View\nHistory",
                Colors.blue.shade700,
                () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => CheckHistory()))),
            _buildQuickActionButton(
              context,
              Icons.settings,
              "App\nSettings",
              Colors.orange,
              () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
      ],
    );
  }

  // Helper for quick action buttons
  Widget _buildQuickActionButton(BuildContext context, IconData icon,
      String label, Color color, VoidCallback onPressed) {
    return Column(
      children: [
        InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  // Helper function for schedule status color
  Color _getScheduleStatusColor(bool allDone) {
    return allDone ? Colors.green : Colors.orange;
  }

  // Enhanced empty state with more helpful content
  Widget _buildEnhancedEmptyState(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeInDown(
            child: Icon(
              Icons.check_circle_outline,
              size: 120,
              color: const Color(0xFF5A9797),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "You're all caught up!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xff0E0A56),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "You've taken all your scheduled medications for today. Great job maintaining your health routine!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildEmptyStateButton(
                context,
                "View History",
                Icons.history,
                Colors.purple.shade700,
                () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => CheckHistory())),
              ),
              const SizedBox(width: 5),
              _buildEmptyStateButton(
                context,
                "Add Medication",
                Icons.add,
                const Color(0xFF5A9797),
                () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => EditPrescriptionScreen())),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Button for empty state actions
  Widget _buildEmptyStateButton(BuildContext context, String label,
      IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  // Adherence streak section
  Widget _buildAdherenceStreak(HistoryState historyState) {
    // Calculate streak (this would come from actual data in production)
    int streak = 5; // Placeholder value

    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5A9797), Color(0xFF3D7575)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5A9797).withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Your Adherence Streak",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Icon(Icons.local_fire_department, color: Colors.orange),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    "$streak",
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "DAYS",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w300,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "Congratulations! Keep taking your medications as prescribed to maintain your streak.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Expanded health insights panel
  Widget _buildExpandedInsights(HistoryState historyState) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            controller: _insightsTabController,
            labelColor: const Color(0xFF5A9797),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF5A9797),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: "Daily Schedule"),
              Tab(text: "Weekly Stats"),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: MediaQuery.of(context).size.height *
                0.15, // More responsive than fixed 120px
            child: TabBarView(
              controller: _insightsTabController,
              children: [
                // Daily schedule tab
                _buildDailyInsights(),

                // Weekly stats tab
                _buildWeeklyInsights(historyState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Daily insights with schedule breakdown
  Widget _buildDailyInsights() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildTimeSlotCard("Morning", 2, 0),
        _buildTimeSlotCard("Afternoon", 1, 1),
        _buildTimeSlotCard("Evening", 1, 0),
      ],
    );
  }

  // Weekly insights with adherence chart
  Widget _buildWeeklyInsights(HistoryState historyState) {
    // This would use historyState.getWeeklyChartData() in production
    return Center(
      child: Text(
        "Weekly Adherence: ${historyState.adherenceRate}%",
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xff0E0A56),
        ),
      ),
    );
  }

  // Time slot card for daily insights
  Widget _buildTimeSlotCard(String timeSlot, int total, int missed) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: missed > 0
            ? Colors.red.withOpacity(0.1)
            : const Color(0xFF5A9797).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            timeSlot,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: missed > 0 ? Colors.red : const Color(0xFF5A9797),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                missed > 0 ? Icons.warning : Icons.check_circle,
                color: missed > 0 ? Colors.red : const Color(0xFF5A9797),
                size: 18,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  "$total medications",
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (missed > 0)
            Text(
              "$missed missed",
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  // Health tips carousel with multiple tips
  Widget _buildHealthTipsCarousel() {
    List<Map<String, dynamic>> tips = [
      {
        'title': 'Medication Timing',
        'content':
            'Taking your medication at the same time every day helps maintain consistent levels in your bloodstream.',
        'icon': Icons.access_time,
      },
      {
        'title': 'Stay Hydrated',
        'content':
            'Drink plenty of water when taking medications to help your body absorb them properly.',
        'icon': Icons.water_drop,
      },
      {
        'title': 'Check Interactions',
        'content':
            'Always check with your doctor about potential interactions between medications.',
        'icon': Icons.warning_amber,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 20, right: 20, bottom: 12),
          child: Text(
            "Health Tips",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xff0E0A56),
            ),
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: tips.length,
            itemBuilder: (context, index) {
              return Container(
                width: 260,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF5A9797).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(tips[index]['icon'],
                          color: const Color(0xFF5A9797)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tips[index]['title'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xff0E0A56),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tips[index]['content'],
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
