import 'package:dispill/auth/auth_screen.dart';
import 'package:dispill/home/edit_prescription.dart';
import 'package:dispill/home/home_screen.dart';
import 'package:dispill/home/manage_device.dart';
import 'package:dispill/home/refill_history.dart';
import 'package:dispill/home/report.dart';
import 'package:dispill/home/settings.dart';
import 'package:dispill/registeration/connect_device.dart';
import 'package:dispill/registeration/loading_screen.dart';
import 'package:dispill/registeration/tablet_verification.dart';
import 'package:dispill/registeration/upload_prescription.dart';
import 'package:dispill/registeration/welcome_screen.dart';
import 'package:flutter/material.dart';

final Map<String, WidgetBuilder> routes = {
  '/welcomeScreen': (context) => const WelcomeScreen(),
  '/connectDevice': (context) => const ConnectDeviceScreen(),
  '/prescriptionScreen': (context) => const PrescriptionScreen(),
  '/loading': (context) => const LoadingScreen(),
  '/completed': (context) => const CompletedScreen(),
  '/tabletVerification': (context) => const TabletVerification(),

  '/editPrescription': (context) => const EditPrescriptionScreen(),
  '/settings': (context) => const SettingScreen(),
  '/registrationScreen': (context) => const RegistrationScreen(),
  '/loginScreen': (context) => const LoginScreen(),
  '/refillHistory': (context) => const PillRefillHistory(),
  '/manageDevice': (context) => const ManageDevice(),
  '/report': (context) => const ReportScreen()
};
