import 'package:dispill/alert_dialog.dart';
import 'package:dispill/states/settings_state.dart';

import 'package:dispill/utils.dart';
import 'package:dispill/widgets/home_screen_widgets.dart';
import 'package:dispill/widgets/settings_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}


class _SettingScreenState extends State<SettingScreen> {

@override
  void initState() {
    // TODO: implement initState

   
    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    // int snoozeLength = 5;

    return Scaffold(
      backgroundColor: const Color.fromRGBO(214, 255, 255, 1),
      extendBody: true,
    
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color.fromRGBO(90, 150, 150, 75 / 100),
        title: const AppLargeText(
          text: "Settings",
          fontsize: 25,
          color: Colors.white,
        ),
      ),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.only(left: 18.0, right: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                height: 40,
              ),
              const AppLargeText(
                text: 'medications and measurements',
                fontsize: 14,
              ),
              const SizedBox(
                height: 30,
              ),
              GestureDetector(
                onTap: () {
                  showDialog(
                      context: context,
                      builder: (context) {
                        return popUpBox(
                            context, medicineswidget(), 200, 100, 'Medicines');
                      });
                },
                child: const AppText(
                  text: 'medicines',
                  fontsize: 17,
                ),
              ),
              const SizedBox(
                height: 40,
              ),
              const AppLargeText(
                text: 'Notifications',
                fontsize: 14,
              ),
              const SizedBox(
                height: 20,
              ),
              const AppLargeText(
                text: 'notifications troubleshooting',
                fontsize: 17,
              ),
              const AppText(
                text: "Don't you receive notifications?",
                fontsize: 12,
              ),
              const AppText(
                text: "click for details",
                fontsize: 12,
              ),
              const SizedBox(
                height: 20,
              ),
              const AppText(
                text: 'Snooze Length',
                fontsize: 17,
              ),
              const SizedBox(
                height: 20,
              ),
              Consumer<SettingsProvider>(
                builder: ((context, provider, child) => Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        GestureDetector(
                            onTap: () {
                              provider.toggleSnooze(0);
                            },
                            child: settingsCurvedBox(
                                3,
                                provider.currentSnoozeLength,
                                (provider.currentSnoozeLength ==
                                        provider.snoozeLength[0])
                                    ? true
                                    : false)),
                        const SizedBox(
                          width: 20,
                        ),
                        GestureDetector(
                            onTap: () => provider.toggleSnooze(1),
                            child: settingsCurvedBox(
                                5,
                                provider.currentSnoozeLength,
                                (provider.currentSnoozeLength ==
                                        provider.snoozeLength[1])
                                    ? true
                                    : false)),
                        const SizedBox(
                          width: 20,
                        ),
                        GestureDetector(
                            onTap: () {
                              provider.toggleSnooze(2);
                            },
                            child: settingsCurvedBox(
                                10,
                                provider.currentSnoozeLength,
                                (provider.currentSnoozeLength ==
                                        provider.snoozeLength[2])
                                    ? true
                                    : false))
                      ],
                    )),
              ),
              const SizedBox(
                height: 20,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AppText(
                    text: 'Show notifications on screen',
                    fontsize: 17,
                  ),
                  Consumer<SettingsProvider>(builder: (context, provider, child) {
                    return CupertinoSwitch(
                        value: provider.notificationsStatus,
                        onChanged: (value) {
                          provider.toggleNotificationState();
                        });
                  })
                ],
              ),
              const SizedBox(
                height: 20,
              ),
              const AppText(
                text: 'Sound',
                fontsize: 17,
              ),
              const SizedBox(
                height: 20,
              ),
              Consumer<SettingsProvider>(
                builder: ((context, provider, child) => Row(
                      children: [
                        GestureDetector(
                            onTap: () {
                              provider.toggleSound(0);
                            },
                            child: settingsCurvedBoxSound(
                                'Bell',
                                (provider.currentSound == provider.sounds[0])
                                    ? true
                                    : false)),
                        const SizedBox(
                          width: 20,
                        ),
                        GestureDetector(
                            onTap: () => provider.toggleSound(1),
                            child: settingsCurvedBoxSound(
                                'Buzz',
                                (provider.currentSound == provider.sounds[1])
                                    ? true
                                    : false)),
                        const SizedBox(
                          width: 20,
                        ),
                        GestureDetector(
                            onTap: () => provider.toggleSound(2),
                            child: settingsCurvedBoxSound(
                                'Bubble',
                                (provider.currentSound == provider.sounds[2])
                                    ? true
                                    : false))
                      ],
                    )),
              ),
              const SizedBox(
                height: 20,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AppText(
                    text: 'Vibrate',
                    fontsize: 17,
                  ),  
                  Consumer<SettingsProvider>(builder: (context, provider, child) {
                    return CupertinoSwitch(
                        value: provider.vibrateStatus,
                        onChanged: (value) {
                          provider.toggleVibrateState();
                        });
                  }),
                ],
              ),
              const SizedBox(
                height: 20,
              ),
              GestureDetector(
                onTap: () {
                  showDialog(
                      context: context,
                      builder: (context) {
                        return popUpBox(
                            context, themeWidget(), 200, 100, 'Theme');
                      });
                },
                child: const AppText(
                  text: 'Theme',
                  fontsize: 17,
                ),
              ),
              const SizedBox(
                height: 30,
              ),
              const AppText(
                text: 'Set the time',
                fontsize: 14,
                fontWeight: FontWeight.bold,
              ),
              const SizedBox(
                height: 20,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
 Consumer<SettingsProvider>(builder: (context, provider, child) {
  return
                  GestureDetector(
                    onTap: () async {
                       TimeOfDay? selectedTime=  await showTimePicker(
                      context: context, initialTime:provider.night);
                    if(selectedTime!=null){
                      provider.morningTime(selectedTime);
                    }
                    },
                    child: Column(
                      children: [
                        const AppText(
                          text: "Morning",
                          fontsize: 17,
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                                                timePicker(provider.morning.hourOfPeriod, provider.morning.minute, (provider.morning.hour>12)?'PM':'AM') 

                      ],
                    ),
 );}),

  Consumer<SettingsProvider>(builder: (context, provider, child) {
  return
                  GestureDetector(
                    onTap: () async {
                     TimeOfDay? selectedTime=  await showTimePicker(
                      context: context, initialTime:provider.night);



                    if(selectedTime!=null){
                      provider.afternoonTime(selectedTime);
                    }
                    },
                    child: Column(
                      children: [
                        const AppText(
                          text: "Afternoon",
                          fontsize: 17,
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        timePicker(provider.afternoon.hourOfPeriod, provider.afternoon.minute, (provider.afternoon.hour>12)?'PM':'AM') 
                      ],
                    ),
                  );}),
                   Consumer<SettingsProvider>(builder: (context, provider, child) {
                  return
                  GestureDetector(
                    onTap: () async {
                    TimeOfDay? selectedTime=  await showTimePicker(
                      context: context, initialTime:provider.night);



                    if(selectedTime!=null){
                      provider.nightTime(selectedTime);
                    }
                    },

                    child: Column(
                      children: [
                        const AppText(
                          text: "Night",
                          fontsize: 17,
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                                                timePicker(provider.night.hourOfPeriod, provider.night.minute, (provider.night.hour>12)?'PM':'AM') 

                      ],
                    ),
                  );}),
                ],
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
