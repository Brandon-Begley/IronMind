import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../theme.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_isSignUp) {
        await AuthService.signUp(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await AuthService.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }

      if (!mounted) return;
      widget.onAuthenticated();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _continueOffline() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await AuthService.continueOfflinePreview();
      if (!mounted) return;
      widget.onAuthenticated();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSignUp ? 'Create Account' : 'Welcome Back';
    final subtitle = _isSignUp
        ? 'New accounts go through onboarding once so the app can personalize everything.'
        : 'Sign in to pick up your plans, logs, and progress.';

    return Scaffold(
      backgroundColor: IronMindColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IRONMIND',
                    style: GoogleFonts.bebasNeue(
                      color: IronMindColors.textPrimary,
                      fontSize: 54,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: GoogleFonts.bebasNeue(
                      color: IronMindColors.accent,
                      fontSize: 28,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      color: IronMindColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: IronMindColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: IronMindColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _modeToggle(),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: GoogleFonts.dmSans(color: IronMindColors.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'name@example.com',
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: GoogleFonts.dmSans(color: IronMindColors.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: _isSignUp ? 'At least 6 characters' : 'Enter your password',
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            style: GoogleFonts.dmSans(
                              color: IronMindColors.alert,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(
                                    _isSignUp ? 'CREATE ACCOUNT' : 'SIGN IN',
                                    style: GoogleFonts.bebasNeue(fontSize: 20, letterSpacing: 1.5),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _continueOffline,
                            child: Text(
                              'CONTINUE OFFLINE',
                              style: GoogleFonts.bebasNeue(
                                fontSize: 18,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Offline preview uses local app storage so you can keep testing while Supabase auth is being finalized.',
                          style: GoogleFonts.dmSans(
                            color: IronMindColors.textMuted,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: IronMindColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IronMindColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AuthModeButton(
              label: 'SIGN IN',
              selected: !_isSignUp,
              onTap: () => setState(() => _isSignUp = false),
            ),
          ),
          Expanded(
            child: _AuthModeButton(
              label: 'SIGN UP',
              selected: _isSignUp,
              onTap: () => setState(() => _isSignUp = true),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AuthModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? IronMindColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.bebasNeue(
            color: selected ? IronMindColors.background : IronMindColors.textSecondary,
            fontSize: 18,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
