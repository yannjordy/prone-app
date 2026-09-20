import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/main/main_screen.dart';
import '../../features/organizations/org_list_screen.dart';
import '../../features/organizations/organization_screen.dart';
import '../../features/projects/project_list_screen.dart';
import '../../features/projects/project_detail_screen.dart';
import '../../features/projects/project_connections_page.dart';
import '../../features/projects/project_actions_page.dart';
import '../../features/projects/project_workflows_page.dart';
import '../../features/projects/project_webhooks_page.dart';
import '../../features/projects/project_executions_page.dart';
import '../../features/projects/project_monitoring_page.dart';
import '../../features/projects/project_logs_page.dart';
import '../../features/projects/project_settings_page.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/settings/settings_screen.dart';

// ======================== THEME MODE ========================
ThemeMode _themeMode = ThemeMode.dark;

ThemeMode get currentThemeMode => _themeMode;

Future<void> setThemeMode(ThemeMode mode) async {
  _themeMode = mode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('theme_mode', mode.name);
}

Future<void> loadThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final name = prefs.getString('theme_mode');
  if (name != null) {
    _themeMode = ThemeMode.values.firstWhere((e) => e.name == name, orElse: () => ThemeMode.dark);
  }
}

// ======================== COLORS (PRONE) ========================
class AppColors {
  // Primary - monochrome from logo
  static const primary = Color(0xFF555555);
  static const primaryDark = Color(0xFF3A3A3A);
  static const primaryLight = Color(0xFF777777);
  static const gradient = LinearGradient(
    colors: [Color(0xFF2A2A2A), Color(0xFF3A3A3A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Dark theme (default)
  static const bg = Color(0xFF121212);
  static const bgDark = Color(0xFF0A0A0A);
  static const surface = Color(0xFF1A1A1A);
  static const surfaceLight = Color(0xFF242424);
  static const text = Color(0xF5FFFFFF);
  static const textMuted = Color(0xB3FFFFFF);
  static const textDim = Color(0x73FFFFFF);
  static const border = Color(0x14FFFFFF);
  static const borderLight = Color(0x1AFFFFFF);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFFBBF24);
  static const success = Color(0xFF22C55E);

  // Light theme
  static const lightBg = Color(0xFFF5F5F5);
  static const lightBgDark = Color(0xFFE8E8E8);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceLight = Color(0xFFF0F0F0);
  static const lightText = Color(0xF51A1A1A);
  static const lightTextMuted = Color(0xB31A1A1A);
  static const lightTextDim = Color(0x731A1A1A);
  static const lightBorder = Color(0x141A1A1A);
  static const lightBorderLight = Color(0x1A1A1A1A);
}

// ======================== THEME HELPERS ========================
class ThemeHelper {
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
  static Color bg(BuildContext context) => isDark(context) ? AppColors.bg : AppColors.lightBg;
  static Color bgDark(BuildContext context) => isDark(context) ? AppColors.bgDark : AppColors.lightBgDark;
  static Color surface(BuildContext context) => isDark(context) ? AppColors.surface : AppColors.lightSurface;
  static Color surfaceLight(BuildContext context) => isDark(context) ? AppColors.surfaceLight : AppColors.lightSurfaceLight;
  static Color text(BuildContext context) => isDark(context) ? AppColors.text : AppColors.lightText;
  static Color textMuted(BuildContext context) => isDark(context) ? AppColors.textMuted : AppColors.lightTextMuted;
  static Color textDim(BuildContext context) => isDark(context) ? AppColors.textDim : AppColors.lightTextDim;
  static Color border(BuildContext context) => isDark(context) ? AppColors.border : AppColors.lightBorder;
  static Color borderLight(BuildContext context) => isDark(context) ? AppColors.borderLight : AppColors.lightBorderLight;
}

// ======================== NOTIFICATION SERVICE ========================
class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final Map<String, int> _unreadCounts = {};
  int _totalUnread = 0;

  int get totalUnread => _totalUnread;
  int getUnreadCount(String projectId) => _unreadCounts[projectId] ?? 0;

  void addUnread(String projectId, [int count = 1]) {
    _unreadCounts[projectId] = (_unreadCounts[projectId] ?? 0) + count;
    _totalUnread = _unreadCounts.values.fold(0, (a, b) => a + b);
    notifyListeners();
  }

  void clearUnread(String projectId) {
    _unreadCounts.remove(projectId);
    _totalUnread = _unreadCounts.values.fold(0, (a, b) => a + b);
    notifyListeners();
  }

  void clearAll() {
    _unreadCounts.clear();
    _totalUnread = 0;
    notifyListeners();
  }
}

// ======================== APP ========================
class ConnectFlowApp extends StatefulWidget {
  const ConnectFlowApp({super.key});

  @override
  State<ConnectFlowApp> createState() => _ConnectFlowAppState();
}

class _ConnectFlowAppState extends State<ConnectFlowApp> {
  @override
  void initState() {
    super.initState();
    loadThemeMode();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Prone',
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: _themeMode,
      routerConfig: _router,
    );
  }
}

// ======================== THEMES ========================
final _darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.bg,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.primary,
    secondary: AppColors.primaryDark,
    surface: AppColors.surface,
    background: AppColors.bg,
  ),
  textTheme: GoogleFonts.interTextTheme(const TextTheme(
    displayLarge: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
    headlineLarge: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
    headlineMedium: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(color: AppColors.text, fontWeight: FontWeight.w500),
    bodyLarge: TextStyle(color: AppColors.text),
    bodyMedium: TextStyle(color: AppColors.textMuted),
    bodySmall: TextStyle(color: AppColors.textDim),
  )),
  dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
);

final _lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.lightBg,
  colorScheme: const ColorScheme.light(
    primary: AppColors.primary,
    secondary: AppColors.primaryDark,
    surface: AppColors.lightSurface,
    background: AppColors.lightBg,
  ),
  textTheme: GoogleFonts.interTextTheme(const TextTheme(
    displayLarge: TextStyle(color: AppColors.lightText, fontWeight: FontWeight.w700),
    headlineLarge: TextStyle(color: AppColors.lightText, fontWeight: FontWeight.w600),
    headlineMedium: TextStyle(color: AppColors.lightText, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(color: AppColors.lightText, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(color: AppColors.lightText, fontWeight: FontWeight.w500),
    bodyLarge: TextStyle(color: AppColors.lightText),
    bodyMedium: TextStyle(color: AppColors.lightTextMuted),
    bodySmall: TextStyle(color: AppColors.lightTextDim),
  )),
  dividerTheme: const DividerThemeData(color: AppColors.lightBorder, thickness: 1),
);

// ======================== ROUTER ========================
final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    ShellRoute(
      builder: (_, __, child) => MainScreen(child: child),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const OrgListScreen()),
        GoRoute(path: '/organizations', builder: (_, __) => const OrgListScreen()),
        GoRoute(path: '/organization/:orgId', builder: (_, state) => OrganizationScreen(orgId: state.pathParameters['orgId']!)),
        GoRoute(path: '/projects', builder: (_, __) => const ProjectListScreen()),
        GoRoute(
          path: '/projects/:projectId',
          builder: (_, state) => ProjectDetailScreen(projectId: state.pathParameters['projectId']!),
          routes: [
            GoRoute(path: 'connections', builder: (_, state) => ProjectConnectionsPage(projectId: state.pathParameters['projectId']!)),
            GoRoute(path: 'actions', builder: (_, state) => ProjectActionsPage(projectId: state.pathParameters['projectId']!)),
            GoRoute(path: 'workflows', builder: (_, state) => ProjectWorkflowsPage(projectId: state.pathParameters['projectId']!)),
            GoRoute(path: 'webhooks', builder: (_, state) => ProjectWebhooksPage(projectId: state.pathParameters['projectId']!)),
            GoRoute(path: 'executions', builder: (_, state) => ProjectExecutionsPage(projectId: state.pathParameters['projectId']!)),
            GoRoute(path: 'monitoring', builder: (_, state) => ProjectMonitoringPage(projectId: state.pathParameters['projectId']!)),
            GoRoute(path: 'logs', builder: (_, state) => ProjectLogsPage(projectId: state.pathParameters['projectId']!)),
            GoRoute(path: 'settings', builder: (_, state) => ProjectSettingsPage(projectId: state.pathParameters['projectId']!)),
          ],
        ),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      ],
    ),
  ],
);
