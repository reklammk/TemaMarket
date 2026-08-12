// notification_service.dart — STUB
// flutter_local_notifications iOS 26 Beta'da Swift runtime başlamadan önce
// NULL pointer erişimi yaparak SIGSEGV crash'e yol açıyordu.
// Plugin kaldırıldı, bu sınıf geriye dönük uyumluluk için boş stub olarak bırakıldı.

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _isInitialized = false;

  Future<void> initNotification() async {
    _isInitialized = true; // no-op
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // no-op — bildirim sistemi kaldırıldı
  }
}
