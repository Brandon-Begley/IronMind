import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../services/supabase_service.dart';

class AuthTestScreen extends StatefulWidget {
  @override
  State<AuthTestScreen> createState() => _AuthTestScreenState();
}

class _AuthTestScreenState extends State<AuthTestScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _status = 'Ready to test';
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService().signUp(
        _emailController.text,
        _passwordController.text,
      );
      setState(() {
        _status = '✅ Sign up successful!\nUser: ${response.user?.email}';
      });
    } catch (e) {
      setState(() => _status = '❌ Sign up failed:\n$e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService().signIn(
        _emailController.text,
        _passwordController.text,
      );
      setState(() {
        _status = '✅ Sign in successful!\nUser: ${response.user?.email}';
      });
    } catch (e) {
      setState(() => _status = '❌ Sign in failed:\n$e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await SupabaseService().signOut();
      setState(() => _status = '✅ Signed out');
    } catch (e) {
      setState(() => _status = '❌ Sign out failed:\n$e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: IronMindTheme.bg,
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            // IronMind Logo (matching app style)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'IRON',
                  style: GoogleFonts.bebasNeue(
                    color: IronMindTheme.accent,
                    fontSize: 32,
                    letterSpacing: 3,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'MIND',
                  style: GoogleFonts.bebasNeue(
                    color: IronMindTheme.textPrimary,
                    fontSize: 32,
                    letterSpacing: 3,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Supabase Connection Test',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: IronMindTheme.text2,
              ),
            ),
            const SizedBox(height: 48),

            // Email Input
            TextField(
              controller: _emailController,
              style: const TextStyle(color: IronMindTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Email',
                hintStyle: const TextStyle(color: IronMindTheme.text3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: IronMindTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: IronMindTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: IronMindTheme.accent),
                ),
                filled: true,
                fillColor: IronMindTheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Password Input
            TextField(
              controller: _passwordController,
              obscureText: true,
              style: const TextStyle(color: IronMindTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: const TextStyle(color: IronMindTheme.text3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: IronMindTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: IronMindTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: IronMindTheme.accent),
                ),
                filled: true,
                fillColor: IronMindTheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Sign Up Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: IronMindTheme.accent,
                  disabledBackgroundColor: IronMindTheme.text3,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            IronMindTheme.bg,
                          ),
                        ),
                      )
                    : const Text(
                        'Sign Up',
                        style: TextStyle(
                          color: IronMindTheme.bg,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Sign In Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: IronMindTheme.surface2,
                  disabledBackgroundColor: IronMindTheme.text3,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: IronMindTheme.accent),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            IronMindTheme.accent,
                          ),
                        ),
                      )
                    : const Text(
                        'Sign In',
                        style: TextStyle(
                          color: IronMindTheme.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Sign Out Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _signOut,
                style: ElevatedButton.styleFrom(
                  backgroundColor: IronMindTheme.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Sign Out',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),

            // Status Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: IronMindTheme.surface2,
                border: Border.all(color: IronMindTheme.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: IronMindTheme.text2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _status,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: IronMindTheme.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
