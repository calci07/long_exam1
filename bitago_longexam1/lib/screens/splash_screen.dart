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
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    if (!mounted) return;
    setState(() => _error = null);
    final service = UserService(widget.preferences);
    try {
      final user = await service.getUserData();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => user == null
              ? SigninScreen(
                  preferences: widget.preferences,
                  theme: widget.theme,
                )
              : HomeScreen(
                  user: user,
                  preferences: widget.preferences,
                  theme: widget.theme,
                ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      service.dispose();
    }
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
          if (_error == null)
            const CircularProgressIndicator()
          else ...[
            Text(_error!),
            TextButton(onPressed: _restore, child: const Text('Try again')),
            TextButton(
              onPressed: () async {
                final service = UserService(widget.preferences);
                try {
                  await service.signOut();
                  await _restore();
                } catch (error) {
                  if (mounted) setState(() => _error = authErrorMessage(error));
                } finally {
                  service.dispose();
                }
              },
              child: const Text('Back to login'),
            ),
          ],
        ],
      ),
    ),
  );
}
