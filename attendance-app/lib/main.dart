import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  final appState = await AppState.create();
  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: const FledgeAttendanceApp(),
    ),
  );
}

class FledgeAttendanceApp extends StatelessWidget {
  const FledgeAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return MaterialApp(
      title: "CNEST FLEDGE '26 Attendance",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      navigatorKey: app.navigatorKey,
      home: app.session == null ? const LoginScreen() : const HomeScreen(),
    );
  }
}
