import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../services/user_service.dart';
import '../widgets/custom_dialogs.dart';
import 'signin_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.preferences,
    required this.theme,
  });
  final SharedPreferences preferences;
  final ThemeProvider theme;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  Future<void> _signOut() async {
    if (_busy || !await CustomDialogs.confirmSignOut(context) || !mounted) {
      return;
    }
    setState(() => _busy = true);
    final service = UserService(widget.preferences);
    try {
      await service.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => SigninScreen(
            preferences: widget.preferences,
            theme: widget.theme,
          ),
        ),
        (_) => false,
      );
    } catch (_) {
      if (mounted) {
        CustomDialogs.message(context, 'Could not sign out. Please try again.');
      }
    } finally {
      service.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: widget.theme,
          builder: (context, _) => DropdownButtonFormField<ThemeMode>(
            initialValue: widget.theme.mode,
            decoration: const InputDecoration(labelText: 'Theme'),
            items: const [
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text('System default'),
              ),
              DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
              DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
            ],
            onChanged: (mode) async {
              if (mode == null) return;
              try {
                await widget.theme.setMode(mode);
              } catch (_) {
                if (context.mounted) {
                  CustomDialogs.message(
                    context,
                    'Could not save your preference.',
                  );
                }
              }
            },
          ),
        ),
        const SizedBox(height: 32),
        OutlinedButton.icon(
          onPressed: _busy ? null : _signOut,
          icon: const Icon(Icons.logout),
          label: Text(_busy ? 'Signing out...' : 'Sign out'),
        ),
      ],
    ),
  );
}
