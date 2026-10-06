import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../services/user_service.dart';
import '../models/user.dart';
import '../utils/validators.dart';
import 'signup_screen.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_font.dart';
import '../widgets/custom_textformfield.dart';
import 'home_screen.dart';

class SigninScreen extends StatefulWidget {
  const SigninScreen({
    super.key,
    required this.preferences,
    required this.theme,
  });
  final SharedPreferences preferences;
  final ThemeProvider theme;
  @override
  State<SigninScreen> createState() => _SigninScreenState();
}

class _SigninScreenState extends State<SigninScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  late final _service = UserService(widget.preferences);
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  LoginType _loginType = LoginType.firebase;

  Future<void> _signIn() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      User? user;
      if (_loginType == LoginType.firebase) {
        await _service.signIn1(email: _username.text, password: _password.text);
        user = await _service.getUserData();
      } else {
        user = await _service.signIn(_username.text, _password.text);
      }
      if (user == null) throw const SignInException('Please sign in again.');
      final signedInUser = user;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            user: signedInUser,
            preferences: widget.preferences,
            theme: widget.theme,
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AutofillGroup(
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset('assets/images/nuicon.jpeg', height: 104),
                    const SizedBox(height: 24),
                    Text('Welcome back', style: CustomFont.heading(context)),
                    const SizedBox(height: 8),
                    const Text('Sign in to Bitago Long Exam 1'),
                    const SizedBox(height: 32),
                    SegmentedButton<LoginType>(
                      segments: const [
                        ButtonSegment(
                          value: LoginType.firebase,
                          label: Text('Firebase'),
                        ),
                        ButtonSegment(
                          value: LoginType.dummyJson,
                          label: Text('DummyJSON'),
                        ),
                      ],
                      selected: {_loginType},
                      onSelectionChanged: _busy
                          ? null
                          : (selection) => setState(() {
                              _loginType = selection.single;
                              _error = null;
                              _username.clear();
                              _password.clear();
                              _form.currentState?.reset();
                            }),
                    ),
                    const SizedBox(height: 16),
                    CustomTextFormField(
                      controller: _username,
                      label: _loginType == LoginType.firebase
                          ? 'Email address'
                          : 'Username',
                      validator: _loginType == LoginType.firebase
                          ? Validators.email
                          : Validators.requiredText,
                      autofillHints: const [AutofillHints.username],
                    ),
                    const SizedBox(height: 16),
                    CustomTextFormField(
                      controller: _password,
                      label: 'Password',
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _signIn(),
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    CustomButton(
                      label: 'Sign in',
                      busy: _busy,
                      onPressed: _signIn,
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SignupScreen(
                                  preferences: widget.preferences,
                                  theme: widget.theme,
                                ),
                              ),
                            ),
                      child: const Text('Create a Firebase account'),
                    ),
                    if (_loginType == LoginType.dummyJson)
                      const Text(
                        'DummyJSON is a demo service. Use its sample credentials, not your personal password.',
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
