import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:alana/features/onboarding/data/onboarding_repository.dart';

enum NotificationPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  unknown,
}

class NotificationPermissionState {
  const NotificationPermissionState({
    required this.status,
    required this.requested,
  });

  final NotificationPermissionStatus status;
  final bool requested;

  bool get granted => status == NotificationPermissionStatus.granted;

  bool get blocked => requested && !granted;

  bool get canRequest => !requested && !granted;
}

class NotificationPermissionController
    extends AsyncNotifier<NotificationPermissionState> {
  static const _requestedKey = 'notification_permission_requested';

  @override
  Future<NotificationPermissionState> build() async {
    final status = await _status();
    final prefs = ref.read(sharedPreferencesProvider);
    return NotificationPermissionState(
      status: status,
      requested: prefs.getBool(_requestedKey) ?? false,
    );
  }

  Future<bool> request() async {
    await ref.read(sharedPreferencesProvider).setBool(_requestedKey, true);
    final status = await _requestStatus();
    final next = NotificationPermissionState(status: status, requested: true);
    state = AsyncData(next);
    return next.granted;
  }

  Future<void> refresh() async {
    final status = await _status();
    final prefs = ref.read(sharedPreferencesProvider);
    state = AsyncData(
      NotificationPermissionState(
        status: status,
        requested: prefs.getBool(_requestedKey) ?? false,
      ),
    );
  }

  Future<bool> openSettings() => openAppSettings();

  Future<NotificationPermissionStatus> _status() async {
    try {
      return _fromPermission(await Permission.notification.status);
    } catch (_) {
      return NotificationPermissionStatus.unknown;
    }
  }

  Future<NotificationPermissionStatus> _requestStatus() async {
    try {
      return _fromPermission(await Permission.notification.request());
    } catch (_) {
      return NotificationPermissionStatus.denied;
    }
  }

  NotificationPermissionStatus _fromPermission(PermissionStatus status) {
    if (status.isGranted) return NotificationPermissionStatus.granted;
    if (status.isPermanentlyDenied) {
      return NotificationPermissionStatus.permanentlyDenied;
    }
    if (status.isRestricted) return NotificationPermissionStatus.restricted;
    if (status.isDenied) return NotificationPermissionStatus.denied;
    return NotificationPermissionStatus.unknown;
  }
}

final notificationPermissionProvider =
    AsyncNotifierProvider<
      NotificationPermissionController,
      NotificationPermissionState
    >(() => NotificationPermissionController());
