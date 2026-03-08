import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isSignUp) {
      await auth.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      return;
    }

    await auth.signInWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: AppTheme.bgGradient(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    if (auth.isEmailVerificationPending) {
                      return _buildVerificationCard(context, auth);
                    }
                    return _buildAuthCard(context, auth);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthCard(BuildContext context, AuthProvider auth) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.buttonColor(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isSignUp ? 'Create your account' : 'Welcome back',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isSignUp
                              ? 'Use email to create your account. Google sign-in stays available as a shortcut.'
                              : 'Sign in with your email and password, or continue with Google.',
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (!auth.isFirebaseConfigured)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Firebase is not configured yet. Add the Firebase dart-defines before testing auth.',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                ),
              if (auth.errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.negative.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    auth.errorMessage!,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTheme.negative,
                    ),
                  ),
                ),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'you@example.com',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'Enter your email address';
                  }
                  if (!text.contains('@')) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: _isSignUp ? 'At least 8 characters' : null,
                ),
                validator: (value) {
                  if ((value ?? '').length < 8) {
                    return 'Use at least 8 characters';
                  }
                  return null;
                },
              ),
              if (_isSignUp) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: auth.status == AuthStatus.loading
                    ? null
                    : () => _submit(auth),
                child: auth.status == AuthStatus.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isSignUp ? 'Create account' : 'Sign in'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: auth.status == AuthStatus.loading
                    ? null
                    : auth.signInWithGoogle,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Continue with Google'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: auth.status == AuthStatus.loading
                    ? null
                    : () => setState(() => _isSignUp = !_isSignUp),
                child: Text(
                  _isSignUp
                      ? 'Already have an account? Sign in'
                      : 'Need an account? Sign up',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationCard(BuildContext context, AuthProvider auth) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Verify your email',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'We sent a verification link to ${auth.email ?? 'your email address'}. Verify the email, then refresh this screen to continue.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                auth.errorMessage!,
                style: const TextStyle(color: AppTheme.negative),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: auth.status == AuthStatus.loading
                  ? null
                  : auth.refreshEmailVerificationStatus,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('I verified my email'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: auth.status == AuthStatus.loading
                  ? null
                  : auth.sendEmailVerification,
              icon: const Icon(Icons.mark_email_unread_outlined),
              label: const Text('Resend verification email'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: auth.status == AuthStatus.loading ? null : auth.logout,
              child: const Text('Use a different account'),
            ),
          ],
        ),
      ),
    );
  }
}
