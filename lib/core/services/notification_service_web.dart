import 'package:shared_preferences/shared_preferences.dart';
import 'dart:html' as html;

class PushNotificationService {
  static bool _permissionGranted = false;
  static bool _initialized = false;

  static bool get permissionGranted => _permissionGranted;
  static bool get isSupported => html.Notification.supported;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    final savedPermission = prefs.getBool('push_notification_permission');

    if (isSupported) {
      final currentPermission = html.Notification.permission;
      if (currentPermission == 'granted') {
        _permissionGranted = true;
      } else if (currentPermission == 'default' && savedPermission == true) {
        final result = await html.Notification.requestPermission();
        _permissionGranted = result == 'granted';
      } else {
        _permissionGranted = currentPermission == 'granted';
      }
    }

    await prefs.setBool('push_notification_permission', _permissionGranted);
  }

  static Future<bool> requestPermission() async {
    if (!isSupported) return false;

    final result = await html.Notification.requestPermission();
    _permissionGranted = result == 'granted';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_notification_permission', _permissionGranted);

    return _permissionGranted;
  }

  static Future<void> revokePermission() async {
    _permissionGranted = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_notification_permission', false);
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    String? icon,
    String? tag,
  }) async {
    if (!_permissionGranted || !isSupported) return;

    html.Notification(
      title,
      body: body,
      icon: icon ?? '/favicon.png',
      tag: tag ?? 'prone-notification',
    );
  }

  static Future<void> showBackendAlert({
    required String projectName,
    required String status,
    required String type,
  }) async {
    if (!_permissionGranted) return;

    await showNotification(
      title: '$projectName - $status',
      body: 'Backend status mis a jour',
      tag: 'backend-status-$projectName',
    );
  }

  static Future<void> showMemberAlert({
    required String projectName,
    required String memberName,
    required String action,
  }) async {
    if (!_permissionGranted) return;

    await showNotification(
      title: '$projectName - Membre',
      body: '$memberName $action',
      tag: 'member-$projectName',
    );
  }

  static Future<void> showSecurityAlert({
    required String projectName,
    required String level,
    required String message,
  }) async {
    if (!_permissionGranted) return;

    await showNotification(
      title: 'Alerte securite - $projectName',
      body: '[$level] $message',
      tag: 'security-$projectName',
    );
  }
}
