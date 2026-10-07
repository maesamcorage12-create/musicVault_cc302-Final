import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/auth_form_parts.dart';

/// Registration screen (spec §8).
///
/// Validation order matches the spec: username required, valid email, password
/// of at least 6 characters, matching confirmation, and finally "email not
/// already registered" which is checked against storage on submit.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.onLoginRequested});

  final VoidCallback onLoginRequested;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    final AuthProvider auth = context.read<AuthProvider>();
    final bool ok = await auth.register(
      username: _username.text,
      email: _email.text,
      password: _password.text,
      confirmPassword: _confirm.text,
    );
    if (!ok && mounted) {
      // Re-run validation so the duplicate-email error from the provider shows
      // on the field that caused it, not only in the inline slot.
      form.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Create your vault', style: text.headlineSmall),
            const SizedBox(height: AppDimensions.xs),
            Text('It takes less than a minute.', style: text.bodyMedium),
            const SizedBox(height: AppDimensions.xl),

            AuthTextField(
              controller: _username,
              label: 'Username',
              hint: 'How should we greet you?',
              icon: Icons.person_outline_rounded,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.nickname],
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Username is required.';
                }
                if (value.trim().length < 2) {
                  return 'Username must be at least 2 characters.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.lg),

            AuthTextField(
              controller: _email,
              label: 'Email',
              hint: 'you@example.com',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newUsername],
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email is required.';
                }
                if (!AuthProvider.isValidEmail(value)) {
                  return 'Enter a valid email address.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.lg),

            AuthTextField(
              controller: _password,
              label: 'Password',
              hint: 'At least 6 characters',
              icon: Icons.lock_outline_rounded,
              obscure: _obscure,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newPassword],
              onChanged: (_) => setState(() {}),
              suffix: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required.';
                }
                if (value.length < AuthProvider.minPasswordLength) {
                  return 'Password must be at least '
                      '${AuthProvider.minPasswordLength} characters.';
                }
                return null;
              },
            ),
            if (_password.text.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppDimensions.md),
              PasswordStrengthBar(password: _password.text),
            ],
            const SizedBox(height: AppDimensions.lg),

            AuthTextField(
              controller: _confirm,
              label: 'Confirm password',
              hint: 'Type it again',
              icon: Icons.lock_reset_rounded,
              obscure: _obscureConfirm,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.newPassword],
              onSubmitted: (_) => _submit(),
              suffix: IconButton(
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password.';
                }
                if (value != _password.text) {
                  return 'Passwords do not match.';
                }
                return null;
              },
            ),

            Consumer<AuthProvider>(
              builder: (BuildContext context, AuthProvider auth, _) {
                if (auth.errorMessage == null) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: AppDimensions.lg),
                  child: InlineError(message: auth.errorMessage!),
                );
              },
            ),

            const SizedBox(height: AppDimensions.xl),
            Consumer<AuthProvider>(
              builder: (BuildContext context, AuthProvider auth, _) {
                return FilledButton(
                  onPressed: auth.busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: VibeColors.electricBlue,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.lg,
                    ),
                  ),
                  child: auth.busy
                      ? const AuthButtonSpinner()
                      : const Text('CREATE ACCOUNT'),
                );
              },
            ),
            const SizedBox(height: AppDimensions.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: Text(
                    'Already have an account?',
                    style: text.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: widget.onLoginRequested,
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
