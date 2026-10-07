import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/auth_form_parts.dart';

/// Sign-in screen (spec §9).
///
/// Field-level validation runs locally, domain failures (no such account, wrong
/// password) come back from [AuthProvider] and are shown inline. Nothing ever
/// fails silently.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onRegisterRequested});

  final VoidCallback onRegisterRequested;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    final AuthProvider auth = context.read<AuthProvider>();
    await auth.login(email: _email.text, password: _password.text);
    // On success the router swaps to the shell; on failure `auth.errorMessage`
    // is rendered by the inline error slot below.
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
            Text('Welcome back', style: text.headlineSmall),
            const SizedBox(height: AppDimensions.xs),
            Text('Sign in to open your vault.', style: text.bodyMedium),
            const SizedBox(height: AppDimensions.xl),

            AuthTextField(
              controller: _email,
              label: 'Email',
              hint: 'you@example.com',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.email],
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
              hint: 'Your password',
              icon: Icons.lock_outline_rounded,
              obscure: _obscure,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.password],
              onSubmitted: (_) => _submit(),
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
                      : const Text('SIGN IN'),
                );
              },
            ),
            const SizedBox(height: AppDimensions.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: Text(
                    'New to VibeVault?',
                    style: text.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: widget.onRegisterRequested,
                  child: const Text('Create an account'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
