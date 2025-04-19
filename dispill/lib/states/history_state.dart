import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dispill/models/firebase_model.dart';
import 'package:dispill/models/data_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistoryState extends ChangeNotifier {
  // Date range
  DateTime startDate = DateTime.now().subtract(const Duration(days: 6));
  DateTime endDate = DateTime.now();

  // Range preset
  String currentRange = "Week"; // Week, Month, 3 Months, Year

  // History data - map of date strings to period statuses
  Map<String, Map<String, dynamic>> historyData = {};

  // Medication details - to show tablet names in history
  Map<String, Map<String, dynamic>> medicationDetails = {};

  // Statistics
  int takenCount = 0;
  int missedCount = 0;
  int lateCount = 0;
  int adherenceRate = 0;

  // Loading state
  bool isLoading = false;
  String errorMessage = '';

  // Firebase service
  final FirebaseService _firebaseService = FirebaseService();

  HistoryState() {
    fetchHistory();
    fetchMedicationDetails();
  }

  // Fetch medication details to display names with history entries
  Future<void> fetchMedicationDetails() async {
    try {
      DocumentSnapshot snapshot = await _firebaseService.getPrescription();

      if (snapshot.exists) {
        Map<String, dynamic> prescriptionData =
            snapshot.data() as Map<String, dynamic>;

        medicationDetails.clear();

        prescriptionData.forEach((key, value) {
          if (value is Map<String, dynamic> && value['tabletName'] != null) {
            String tabletName = value['tabletName'];
            Map<String, dynamic> frequency =
                value['frequency'] as Map<String, dynamic>;

            frequency.forEach((period, isActive) {
              if (isActive == true) {
                if (!medicationDetails.containsKey(period)) {
                  medicationDetails[period] = {};
                }
                medicationDetails[period]?[key] = {
                  'tabletName': tabletName,
                  'dosage': value['dosage'],
                  'beforeFood': value['beforeFood'],
                };
              }
            });
          }
        });
      }
    } catch (e) {
      errorMessage = 'Failed to load medication details: $e';
    }
  }

  // Fetch history for the current date range
  Future<void> fetchHistory() async {
    if (_firebaseService.user == null) {
      errorMessage = 'No user logged in';
      return;
    }

    isLoading = true;
    errorMessage = '';
    notifyListeners();

    try {
      historyData.clear();
      takenCount = 0;
      missedCount = 0;
      lateCount = 0;

      // Generate all dates in the range
      List<DateTime> datesInRange = [];
      DateTime current = startDate;
      while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
        datesInRange.add(current);
        current = current.add(const Duration(days: 1));
      }

      // Fetch intake history from Firestore for each date
      for (DateTime date in datesInRange) {
        String dateString = date.toIso8601String().split('T')[0];

        DocumentSnapshot historyDoc = await FirebaseFirestore.instance
            .collection('USER')
            .doc(_firebaseService.user?.email)
            .collection('intake_history')
            .doc(dateString)
            .get();

        if (historyDoc.exists) {
          Map<String, dynamic> dayData =
              historyDoc.data() as Map<String, dynamic>;
          historyData[dateString] = dayData;

          // Update statistics
          ['morning', 'afternoon', 'night'].forEach((period) {
            if (dayData.containsKey(period)) {
              var periodData = dayData[period];
              bool taken = false;
              bool missed = false;

              if (periodData is Map<String, dynamic>) {
                taken = periodData['taken'] ?? false;

                // Consider it "missed" if notification_sent is true but not taken
                missed = !taken && (periodData['notification_sent'] ?? false);

                // Consider it "late" if missed_notification_sent is true but still taken
                bool late =
                    taken && (periodData['missed_notification_sent'] ?? false);

                if (taken) takenCount++;
                if (missed) missedCount++;
                if (late) lateCount++;
              } else if (periodData is bool) {
                // Handle legacy format
                taken = periodData;
                if (taken) takenCount++;
              }
            }
          });
        }
      }

      // Calculate adherence rate
      int totalDoses = takenCount + missedCount;
      adherenceRate =
          totalDoses > 0 ? ((takenCount / totalDoses) * 100).round() : 0;
    } catch (e) {
      errorMessage = 'Failed to load history data: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Change date range and refresh data
  void setDateRange(String preset) {
    currentRange = preset;
    DateTime now = DateTime.now();

    switch (preset) {
      case "Week":
        startDate = now.subtract(const Duration(days: 6));
        endDate = now;
        break;
      case "Month":
        startDate = DateTime(now.year, now.month - 1, now.day);
        endDate = now;
        break;
      case "3 Months":
        startDate = DateTime(now.year, now.month - 3, now.day);
        endDate = now;
        break;
      case "Year":
        startDate = DateTime(now.year - 1, now.month, now.day);
        endDate = now;
        break;
    }

    fetchHistory();
  }

  // Set custom date range
  void setCustomDateRange(DateTime start, DateTime end) {
    startDate = start;
    endDate = end;
    currentRange = "Custom";
    fetchHistory();
  }

  // Format data for the list view
  List<Map<String, dynamic>> getListData() {
    List<Map<String, dynamic>> result = [];

    // Sort dates in reverse order (newest first)
    List<String> sortedDates = historyData.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    for (String dateStr in sortedDates) {
      DateTime date = DateTime.parse(dateStr);
      String displayDate = date.isAtSameMomentAs(
              DateTime.now().subtract(const Duration(days: 1)))
          ? "Yesterday"
          : date.isAtSameMomentAs(DateTime.now())
              ? "Today"
              : DateFormat('EEE, MMM d').format(date);

      Map<String, dynamic> dayData = historyData[dateStr]!;
      List<Map<String, dynamic>> medications = [];

      // Process each period (morning, afternoon, night)
      ['morning', 'afternoon', 'night'].forEach((period) {
        if (dayData.containsKey(period)) {
          var periodData = dayData[period];
          bool taken = false;

          if (periodData is Map<String, dynamic>) {
            taken = periodData['taken'] ?? false;
          } else if (periodData is bool) {
            taken = periodData;
          }

          // Only add to the list if medication was scheduled for this period
          if (medicationDetails.containsKey(period)) {
            medicationDetails[period]!.forEach((medicId, medDetails) {
              // Determine timing based on period
              String time;
              switch (period) {
                case 'morning':
                  time = '09:00 AM';
                  break;
                case 'afternoon':
                  time = '01:30 PM';
                  break;
                case 'night':
                  time = '09:30 PM';
                  break;
                default:
                  time = '12:00 PM';
              }

              medications.add({
                'name': medDetails['tabletName'],
                'time': time,
                'taken': taken,
                'dosage': '${medDetails['dosage']}mg',
                'period': period,
              });
            });
          }
        }
      });

      if (medications.isNotEmpty) {
        result.add({
          'date': displayDate,
          'medications': medications,
        });
      }
    }

    return result;
  }

  // Format data for chart view (weekly data)
  List<Map<String, dynamic>> getWeeklyChartData() {
    List<Map<String, dynamic>> result = [];

    // Get last 7 days
    for (int i = 6; i >= 0; i--) {
      DateTime date = DateTime.now().subtract(Duration(days: i));
      String dateStr = date.toIso8601String().split('T')[0];
      String dayName = DateFormat('E').format(date); // Mon, Tue, etc.

      int takenCount = 0;
      int missedCount = 0;
      int lateCount = 0;

      if (historyData.containsKey(dateStr)) {
        Map<String, dynamic> dayData = historyData[dateStr]!;

        ['morning', 'afternoon', 'night'].forEach((period) {
          if (dayData.containsKey(period)) {
            var periodData = dayData[period];
            bool taken = false;
            bool missed = false;
            bool late = false;

            if (periodData is Map<String, dynamic>) {
              taken = periodData['taken'] ?? false;
              missed = !taken && (periodData['notification_sent'] ?? false);
              late = taken && (periodData['missed_notification_sent'] ?? false);
            } else if (periodData is bool) {
              taken = periodData;
            }

            // Only count if medication was scheduled for this period
            if (medicationDetails.containsKey(period) &&
                medicationDetails[period]!.isNotEmpty) {
              if (taken) takenCount++;
              if (missed) missedCount++;
              if (late) lateCount++;
            }
          }
        });
      }

      result.add({
        'day': dayName,
        'taken': takenCount,
        'missed': missedCount,
        'late': lateCount,
      });
    }

    return result;
  }

  // Calculate adherence rate for a specific period
  Map<String, int> getPeriodAdherenceRates() {
    Map<String, int> periodRates = {
      'morning': 0,
      'afternoon': 0,
      'night': 0,
    };

    Map<String, int> periodTaken = {
      'morning': 0,
      'afternoon': 0,
      'night': 0,
    };

    Map<String, int> periodTotal = {
      'morning': 0,
      'afternoon': 0,
      'night': 0,
    };

    historyData.forEach((dateStr, dayData) {
      ['morning', 'afternoon', 'night'].forEach((period) {
        if (dayData.containsKey(period) &&
            medicationDetails.containsKey(period) &&
            medicationDetails[period]!.isNotEmpty) {
          var periodData = dayData[period];
          bool taken = false;

          if (periodData is Map<String, dynamic>) {
            taken = periodData['taken'] ?? false;
          } else if (periodData is bool) {
            taken = periodData;
          }

          periodTotal[period] = (periodTotal[period] ?? 0) + 1;
          if (taken) {
            periodTaken[period] = (periodTaken[period] ?? 0) + 1;
          }
        }
      });
    });

    periodRates.forEach((period, _) {
      if (periodTotal[period]! > 0) {
        periodRates[period] =
            ((periodTaken[period]! / periodTotal[period]!) * 100).round();
      }
    });

    return periodRates;
  }
}
