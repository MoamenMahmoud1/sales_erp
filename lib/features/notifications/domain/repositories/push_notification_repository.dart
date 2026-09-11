abstract interface class PushNotificationRepository {
  Future<void> initialize();

  Future<void> setAuthenticated(bool authenticated);

  Stream<Map<String, String>> get openedNotifications;
}
