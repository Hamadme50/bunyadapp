/// Everything that points the app at a server lives here, and nowhere else.
///
/// Change [kServerUrl] to your Bunyad installation and the whole app follows —
/// screens never build a URL themselves, they ask [Api] for one.
library;

// ═══════════════════════════════════════════════════════════════════════════
//  The server
// ═══════════════════════════════════════════════════════════════════════════

/// Where Bunyad is running, with no trailing slash.
///
/// The default is the Android emulator's route to the host machine — `10.0.2.2`
/// is the emulator's alias for the computer it runs on, so a backend started
/// with `mvn spring-boot:run` is reachable without changing anything.
///
/// Point it at your own server for a real build:
///
///   * a phone on the same Wi-Fi   `http://192.168.1.20:8383`
///   * behind Tomcat               `http://192.168.1.20:8080/bunyad`
///   * in production               `https://bunyad.example.com`
///
/// It can also be overridden at build time without editing this file:
///
///   flutter build apk --dart-define=BUNYAD_SERVER_URL=https://bunyad.example.com
const String kServerUrl = String.fromEnvironment(
  'BUNYAD_SERVER_URL',
  defaultValue: 'https://bunyadapp.com',
);

/// The API root. Everything the app calls hangs off this.
const String kApiUrl = '$kServerUrl/api';

/// How long the app waits on a request before giving up.
const Duration kConnectTimeout = Duration(seconds: 20);
const Duration kReceiveTimeout = Duration(seconds: 40);

/// Photo uploads carry megabytes over a site's mobile signal.
const Duration kUploadTimeout = Duration(minutes: 3);

// ═══════════════════════════════════════════════════════════════════════════
//  The app
// ═══════════════════════════════════════════════════════════════════════════

const String kAppName = 'Bunyad';
const String kAppTagline = 'Expense book';

/// Key the bearer token is filed under in secure storage.
const String kTokenKey = 'bunyad.token';

/// How many expenses one page of a stage timeline holds. Matches the web app
/// and the server's own default.
const int kPageSize = 40;

/// Units the expense form suggests for a quantity, and the project form for a
/// plot size. Both are free text — these are only shortcuts.
const List<String> kQuantityUnits = [
  'bags', 'pcs', 'nos', 'trolleys', 'trips', 'man-days', 'sq ft', 'kanal', 'marla', 'sets',
];

const List<String> kPlotSizeUnits = ['Marla', 'Kanal', 'Sq ft', 'Sq yd', 'Acre', 'Bigha'];

/// The ladder a new project starts with, before the owner edits it.
const List<String> kDefaultStages = [
  'Plot',
  'Foundations',
  'Ground Floor Grey',
  '2nd Floor Grey',
  '3rd Floor Grey',
  'Finishing Ground Floor',
  'Finishing 2nd Floor',
  'Finishing 3rd Floor',
];

// ═══════════════════════════════════════════════════════════════════════════
//  Every endpoint
// ═══════════════════════════════════════════════════════════════════════════

/// The API surface, in the same order as the server's own routing table.
///
/// Paths are relative to [kApiUrl] — the Dio client carries the base URL, so
/// these stay readable and there is exactly one place a route is spelled out.
class Api {
  const Api._();

  // ── auth ────────────────────────────────────────────────────────────────

  /// Signs in and returns the long-lived bearer token this app uses. The web
  /// app's `/auth/login` sets a cookie instead; this one hands over the token.
  static const String token = '/auth/token';

  /// Creates an account and returns the same token, so joining signs you in.
  static const String register = '/auth/register';

  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String password = '/auth/password';

  // ── projects ────────────────────────────────────────────────────────────

  /// The dashboard: every project the user can see, plus the portfolio totals.
  static const String projects = '/projects';

  static String project(String id) => '/projects/$id';
  static String members(String id) => '/projects/$id/members';
  static String member(String id, String userId) => '/projects/$id/members/$userId';
  static String leave(String id) => '/projects/$id/leave';

  // ── expense heads ───────────────────────────────────────────────────────

  static String heads(String id) => '/projects/$id/heads';
  static String head(String id, String headId) => '/projects/$id/heads/$headId';

  // ── stages ──────────────────────────────────────────────────────────────

  static String stages(String id) => '/projects/$id/stages';
  static String stage(String id, String stageId) => '/projects/$id/stages/$stageId';
  static String stageOrder(String id) => '/projects/$id/stages/order';

  // ── expenses ────────────────────────────────────────────────────────────

  static String expenses(String id, String stageId) => '/projects/$id/stages/$stageId/expenses';
  static String expense(String expenseId) => '/expenses/$expenseId';
  static String moveExpense(String expenseId) => '/expenses/$expenseId/move';

  // ── files ───────────────────────────────────────────────────────────────

  static const String files = '/files';

  /// Absolute, because these go to an image widget rather than through Dio.
  static String fileUrl(String fileId) => '$kApiUrl/files/${Uri.encodeComponent(fileId)}';
  static String thumbnailUrl(String fileId) =>
      '$kApiUrl/files/${Uri.encodeComponent(fileId)}/thumbnail';

  // ── people ──────────────────────────────────────────────────────────────

  static const String adminUsers = '/admin/users';
  static String adminUser(String id) => '/admin/users/$id';
  static String adminUserPassword(String id) => '/admin/users/$id/password';
  static String userSearch(String q) => '/users/search?q=${Uri.encodeQueryComponent(q)}';

  static const String health = '/health';
}
