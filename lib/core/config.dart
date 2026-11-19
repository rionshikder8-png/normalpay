/// Central configuration. The backend origin is configurable at pairing time and
/// persisted natively; these are only defaults.
class ApsConfig {
  static const String defaultBaseUrl = 'https://aps.adverune.store';
  static const String checkoutUrl = 'https://pay.adverune.store';
  static const String brandName = 'Adverune Payment System';
  static const String shortName = 'APS';
  static const String appName = 'APS Reader';
  static const String tagline = 'Powered by Adverune';
  static const String description = 'Payment Monitoring & Real-time Alerts';

  // Existing, verified endpoints.
  static const String registerPath = '/api/device-register.php';
  static const String pingPath = '/api/device-ping.php';
  static const String ingestPath = '/api/sms-ingest.php';

  // Endpoints that do NOT exist yet on the backend. See docs/BACKEND-CONTRACT.md.
  static const String statsPath = '/api/reader-stats.php';
  static const String transactionsPath = '/api/reader-transactions.php';
  static const String notificationsPath = '/api/reader-notifications.php';
  static const String fcmTokenPath = '/api/device-fcm-token.php';
  static const String referencePath = '/api/reader-reference.php';

  static const String appVersionFallback = '2.0.0';
}
