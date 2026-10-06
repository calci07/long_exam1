import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/user_service.dart';
import '../utils/validators.dart';

enum _AccountAction { username, password, delete }

class AccountActions extends StatelessWidget {
  const AccountActions({
    super.key,
    required this.user,
    required this.service,
    required this.onChanged,
    required this.onDeleted,
  });
  final User user;
  final UserService service;
  final Future<void> Function() onChanged;
  final VoidCallback onDeleted;

  Future<void> _open(BuildContext context, _AccountAction action) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _AccountDialog(user: user, service: service, action: action),
    );
    if (changed != true || !context.mounted) return;
    if (action == _AccountAction.delete) {
      onDeleted();
      return;
    }
    await onChanged();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Account updated.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user.loginType == LoginType.dummyJson) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'DummyJSON demo account. Its updates and deletions are simulated. '
          'Create a Firebase account to manage your username, password and account.',
        ),
      );
    }
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: const Text('Update username'),
          onTap: () => _open(context, _AccountAction.username),
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Change password'),
          onTap: () => _open(context, _AccountAction.password),
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Delete account'),
          onTap: () => _open(context, _AccountAction.delete),
        ),
      ],
    );
  }
}

class _AccountDialog extends StatefulWidget {
  const _AccountDialog({
    required this.user,
    required this.service,
    required this.action,
  });
  final User user;
  final UserService service;
  final _AccountAction action;
  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  final _form = GlobalKey<FormState>();
  late final _username = TextEditingController(text: widget.user.username);
  final _current = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;
  String get _title => switch (widget.action) {
    _AccountAction.username => 'Update username',
    _AccountAction.password => 'Change password',
    _AccountAction.delete => 'Delete account',
  };

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      switch (widget.action) {
        case _AccountAction.username:
          await widget.service.updateUsername(username: _username.text);
        case _AccountAction.password:
          await widget.service.resetPasswordFromCurrentPassword(
            currentPassword: _current.text,
            newPassword: _newPassword.text,
            email: widget.user.email,
          );
        case _AccountAction.delete:
          await widget.service.deleteAccount(
            email: widget.user.email,
            password: _current.text,
          );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController controller,
    String? Function(String?) validator, {
    bool secret = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: TextFormField(
      controller: controller,
      enabled: !_busy,
      obscureText: secret,
      autocorrect: false,
      enableSuggestions: !secret,
      decoration: InputDecoration(labelText: label),
      validator: validator,
    ),
  );

  @override
  void dispose() {
    for (final c in [_username, _current, _newPassword, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(_title),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 360,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.action == _AccountAction.delete)
                  const Text(
                    'Permanently delete your account and profile? This cannot be undone. Enter your current password to confirm.',
                  ),
                if (widget.action == _AccountAction.username)
                  _field('Username', _username, Validators.username)
                else
                  _field(
                    'Current password',
                    _current,
                    Validators.requiredText,
                    secret: true,
                  ),
                if (widget.action == _AccountAction.password) ...[
                  _field(
                    'New password',
                    _newPassword,
                    Validators.password,
                    secret: true,
                  ),
                  _field(
                    'Confirm new password',
                    _confirm,
                    (value) => value == _newPassword.text
                        ? null
                        : 'Passwords do not match.',
                    secret: true,
                  ),
                ],
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
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Please wait...' : _title),
        ),
      ],
    ),
  );
}
