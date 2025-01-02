import 'package:dispill/models/notification.dart';
import 'package:dispill/services/http.dart';
import 'package:flutter/material.dart';

class NotificationState extends ChangeNotifier {
  List<Notifications> notifications = [];
  bool isLoading = false;
  bool shoudlFetchNotification = false;
  String email = "";

  void getNotifications(String email) async {
    isLoading = true;
    notifyListeners();
    // Simulate a network request
   notifications = await HttpService().getNotifications(email);
   isLoading = false;
   notifyListeners();
  }
}
