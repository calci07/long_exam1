import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../services/user_service.dart';
import '../utils/validators.dart';
import '../widgets/custom_button.dart';
import 'home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({
    super.key,
    required this.preferences,
    required this.theme,
  });
  final SharedPreferences preferences;
  final ThemeProvider theme;
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _age = TextEditingController();
  final _contact = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late final _service = UserService(widget.preferences);
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.createAccount(
        email: _email.text,
        password: _password.text,
        fName: _first.text,
        lName: _last.text,
        age: int.parse(_age.text.trim()),
        contactNo: _contact.text,
        username: _username.text,
      );
      final user = await _service.getUserData();
      if (!mounted) return;
      if (user == null) throw const SignInException('Please sign in again.');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            user: user,
            preferences: widget.preferences,
            theme: widget.theme,
          ),
        ),
        (_) => false,
      );
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _first,
      _last,
      _age,
      _contact,
      _username,
      _email,
      _password,
      _confirm,
    ]) {
      controller.dispose();
    }
    _service.dispose();
    super.dispose();
  }

  Widget _field(
    String label,
    TextEditingController controller,
    String? Function(String?) validator, {
    bool secret = false,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      enabled: !_busy,
      decoration: InputDecoration(labelText: label),
      obscureText: secret,
      keyboardType: keyboard,
      validator: validator,
      autocorrect: !secret,
      enableSuggestions: !secret,
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create account')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Sign up with Firebase',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                _field('First name (fName)', _first, Validators.name),
                _field('Last name (lName)', _last, Validators.name),
                _field(
                  'Age',
                  _age,
                  Validators.age,
                  keyboard: TextInputType.number,
                ),
                _field(
                  'Contact number',
                  _contact,
                  Validators.contactNo,
                  keyboard: TextInputType.phone,
                ),
                _field('Username', _username, Validators.username),
                _field(
                  'Email address',
                  _email,
                  Validators.email,
                  keyboard: TextInputType.emailAddress,
                ),
                _field(
                  'Password',
                  _password,
                  Validators.password,
                  secret: true,
                ),
                _field(
                  'Confirm password',
                  _confirm,
                  (value) => value == _password.text
                      ? null
                      : 'Passwords do not match.',
                  secret: true,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                CustomButton(
                  label: 'Create account',
                  busy: _busy,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
