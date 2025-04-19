import 'package:dispill/home/check_history.dart';
import 'package:dispill/home/home_screen.dart';
import 'package:dispill/main.dart';
import 'package:dispill/models/auth_model.dart';
import 'package:dispill/colors.dart';
import 'package:dispill/home/edit_prescription.dart';
import 'package:dispill/registeration/upload_prescription.dart';
import 'package:dispill/states/auth_state.dart';

import 'package:dispill/states/prescription_state.dart';
import 'package:dispill/states/settings_state.dart';
import 'package:dispill/utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeNotificationBlock extends StatelessWidget {
  final String pillIcon;
  final String statusName;
  final String tabletName;
  final double tabletDosage;
  final bool beforeFood;
  final String timeOfDay;
  final TimeOfDay timeToTake;
  final VoidCallback? onTakenPressed; // Add this callback

  const HomeNotificationBlock({
    super.key,
    required this.tabletName,
    required this.pillIcon,
    required this.statusName,
    required this.tabletDosage,
    required this.beforeFood,
    required this.timeOfDay,
    required this.timeToTake,
    this.onTakenPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMissed = statusName.contains('alert');
    final Color cardColor = isMissed
        ? const Color(0xFFFFF3F3) // Light red background for missed
        : Colors.white;
    final Color accentColor = isMissed
        ? const Color(0xFFE53935) // Red accent for missed
        : const Color(0xff28AA93); // Green for normal

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          )
        ],
        border: isMissed
            ? Border.all(color: accentColor.withOpacity(0.5), width: 1.5)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Left section - Pill icon with background
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Image.asset(
                  pillIcon,
                  height: 30,
                  width: 30,
                ),
              ),
            ),

            // Middle section - Medication info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Medication name with status badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            tabletName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines:
                                2, // Allow two lines for longer medication names
                            overflow:
                                TextOverflow.visible, // Don't use ellipsis
                          ),
                        ),
                        if (isMissed)
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'MISSED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Dosage info
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${tabletDosage.toInt()} tablet${tabletDosage > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          beforeFood ? 'Before meal' : 'After meal',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Time info row
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: accentColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${timeToTake.hour}:${timeToTake.minute.toString().padLeft(2, '0')} ${timeToTake.period.toString().substring(10, 12).toUpperCase()}",
                          style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (timeOfDay.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              timeOfDay,
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Right section - Action button
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isMissed
                    ? Colors.red.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: isMissed
                  ? IconButton(
                      icon: const Icon(Icons.notification_important,
                          color: Colors.red),
                      onPressed: onTakenPressed,
                    )
                  : IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: onTakenPressed,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget emptyGreyContainer(String time) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 20, top: 20),
        child: AppLargeText(
          text: time,
        ),
      ),
      Container(
        margin: const EdgeInsets.only(left: 20, top: 10),
        height: 52,
        width: 279,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xffD9D9D9)),
      ),
      Container(
        margin: const EdgeInsets.only(left: 20, top: 10),
        height: 52,
        width: 279,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xffD9D9D9)),
      ),
    ],
  );
}

Widget myDrawer(BuildContext context) {
  return Drawer(
    width: 300,
    child: ListView(
      children: [
        const DrawerHeader(
          decoration: BoxDecoration(
            color: tertiaryColor,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppLargeText(
                text: 'Pill Reminder',
                fontsize: 17.6,
              )
            ],
          ),
        ),
        GestureDetector(
          onTap: () async => Navigator.of(context)
              .push(MaterialPageRoute(builder: (context) => LandingPage())),
          child: const DrawerContainer(
              text: "Home",
              leading: Icon(Icons.home, color: Colors.black),
              route: ''),
        ),
        Consumer<PrescriptionStateProvider>(
            builder: (context, provider, child) {
          return GestureDetector(
            onTap: () {
              // provider.fetchPrescription();
              // provider.fetchFreeslots();
              // provider.fetchStoreDetails();
              Navigator.of(context).push(_createRouteForEditPrescription());
            },
            child: const DrawerContainer(
                text: "Edit Prescription",
                leading: ImageIcon(AssetImage('assets/images/pills.png')),
                route: ''),
          );
        }),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const CheckHistory()));
          },
          child: const DrawerContainer(
              text: "Check History",
              leading: Icon(Icons.history, color: Colors.black),
              route: ''),
        ),
        GestureDetector(
          onTap: () async {
            String userEmail = FirebaseAuth.instance.currentUser!.email!;

            Navigator.of(context).pushNamed('/settings');
          },
          child: const DrawerContainer(
              text: "Settings",
              leading: Icon(Icons.settings, color: Colors.black),
              route: ''),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 20.0, bottom: 20, left: 5, right: 5),
          child: Divider(
            color: Colors.black,
            thickness: 1,
          ),
        ),
        Consumer<SettingsProvider>(builder: (context, provider, child) {
          return GestureDetector(
            onTap: () {
              Navigator.of(context).pushNamed('/manageDevice');
            },
            child: const DrawerContainer(
                text: "Manage Device",
                leading: Icon(Icons.phone_android),
                route: ''),
          );
        }),
        const DrawerContainer(
            text: "Contact",
            leading: Icon(Icons.contact_phone_rounded),
            route: ''),
        const DrawerContainer(
            text: "Customer support",
            leading: Icon(Icons.support_agent_rounded),
            route: ''),
        GestureDetector(
            onTap: () {
              Navigator.of(context).pushNamed('/report');
            },
            child: const DrawerContainer(
              text: "Report",
              leading: Icon(Icons.report),
              route: '',
            )),
        GestureDetector(
          onTap: () async {
            final bool res = await AuthService().signOut(context);
            // res == true
            //     ? provider.setAuthenticated(false)
            //     : print('unable to logout');
          },
          child: Container(
            margin: const EdgeInsets.only(left: 30, right: 30, top: 100),
            height: 52,
            width: 235,
            decoration: BoxDecoration(
                color: const Color.fromRGBO(45, 163, 155, 73 / 100),
                borderRadius: BorderRadius.circular(11)),
            child: const Center(
              child: AppLargeText(
                text: 'Log out',
                fontsize: 23,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Route _createRouteForEditPrescription() {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) =>
        const EditPrescriptionScreen(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      var begin = const Offset(0.0, 1);
      var end = Offset.zero;
      var curve = Curves.decelerate;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
  );
}
