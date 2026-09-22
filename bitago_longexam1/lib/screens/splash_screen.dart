import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../providers/theme_provider.dart';
import '../services/user_service.dart';
import 'home_screen.dart';
import 'signin_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.preferences,
    required this.theme,
  });
  final SharedPreferences preferences;
  final ThemeProvider theme;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  void _restore() {
    if (!mounted) return;
    final service = UserService(widget.preferences);
    final user = service.restoreUser();
    service.dispose();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => user == null
            ? SigninScreen(preferences: widget.preferences, theme: widget.theme)
            : HomeScreen(
                user: user,
                preferences: widget.preferences,
                theme: widget.theme,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/nuicon.jpeg', width: 100, height: 100),
          const SizedBox(height: 16),
          const Text(appName),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
        ],
      ),
    ),
  );
}
