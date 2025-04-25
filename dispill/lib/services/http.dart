import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dispill/models/notification.dart';

class HttpService {
  String baseUrl = "http://dispillalar.work.gd";
  Future<List<Notifications>> getNotifications(String email) async {
    final url = Uri.parse(baseUrl + "/update-notifications?email=$email");
    final List<Notifications> notifications = [];

    try {
      // Send GET request
      final response = await http.get(url);

      // Check for a successful response
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        if (jsonResponse['notifications'] != null) {
          final Map<String, dynamic> notificationsData =
              jsonResponse['notifications'];

          // Parse each notification
          notificationsData.forEach((key, value) {
            notifications.add(
              Notifications(
                value['tabletName'] ?? '',
                value['takeTime'] ?? '',
                value['takeDuration'] ?? '',
                value['missed'] ?? false,
                value['afterFood'] ?? false,
                key ?? '',
                (value['dosage'] ?? 0).toDouble(),
              ),
            );
          });
        }
      } else {
        print("Failed to fetch notifications: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching notifications: $e");
    }

    return notifications;
  }

  Future<bool> registerFcmToken(String email, String token) async {
    final url =
        Uri.parse('$baseUrl/user/register-token?email=$email&token=$token');

    try {
      final response = await http.post(url);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        print('FCM token registered successfully: ${jsonResponse['status']}');
        return true;
      } else {
        print('Failed to register FCM token: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error registering FCM token: $e');
      return false;
    }
  }
}
