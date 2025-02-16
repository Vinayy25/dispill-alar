import 'package:dispill/services/http.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_launcher_icons/logger.dart' as log;

class AuthStateProvider extends ChangeNotifier {
  bool isAuthenticated = false;
  AuthStateProvider() {
    checkAuthStatus();
  }
  var user = FirebaseAuth.instance.currentUser;
  
  void setAuthenticated(bool value) {
    isAuthenticated = value;
    notifyListeners();
  }

  void checkAuthStatus() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null) {
        isAuthenticated = false;
        print("my State: $isAuthenticated");
      
        notifyListeners();
      } else {

        isAuthenticated = true;
        getFCMToken(user.email!);
        notifyListeners();
      }
    });
  }
      Future<void> getFCMToken(String email) async {
  String token = await FirebaseMessaging.instance.getToken()??"";
  print("FCM Token: $token");

  HttpService().registerFcmToken(email, token);
}

}
