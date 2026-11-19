import 'package:flutter/material.dart';

import 'core/api.dart';
import 'core/config.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'screens/root_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = SessionStore();
  final api = ApiClient(baseUrl: AppConfig.apiBase);
  final token = await session.loadToken();
  runApp(StudentElectionApp(session: session, api: api, initialToken: token));
}

/// Application entry point.
class StudentElectionApp extends StatelessWidget {
  final SessionStore session;
  final ApiClient api;
  final String? initialToken;

  const StudentElectionApp({
    super.key,
    required this.session,
    required this.api,
    required this.initialToken,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: RootScreen(session: session, api: api, initialToken: initialToken),
    );
  }
}
