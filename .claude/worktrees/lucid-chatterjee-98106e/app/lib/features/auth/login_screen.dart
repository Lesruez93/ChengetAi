import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

/// MVP auth stub.
///
/// There is no real Supabase project/keys wired into this demo (see the
/// backend's `SUPABASE_*` settings, all empty by default), so this screen
/// intentionally does NOT call `supabase_flutter`. It exists to show the
/// intended auth UX and screen structure; "Log In" and "Continue as guest"
/// both just navigate to the home shell. Swapping in real Supabase auth
/// later means: add `supabase_flutter` to pubspec.yaml, initialize it in
/// `main.dart` with real project URL/anon key, and replace `_submit()`
/// below with `Supabase.instance.client.auth.signInWithPassword(...)`.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Icon(Icons.shield_moon_outlined, size: 56, color: AppColors.brandPrimary),
                  const SizedBox(height: 16),
                  const Text(
                    'ChengetAI',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.brandPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'AI scam & fraud protection for Zimbabwe',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 36),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                    validator: (String? v) =>
                        (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                    validator: (String? v) => (v == null || v.length < 4) ? 'Enter your password' : null,
                  ),
                  const SizedBox(height: 22),
                  ElevatedButton(onPressed: _submit, child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text('Log In'),
                  )),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Continue as Guest'),
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: () => context.go('/signup'),
                    child: const Text("Don't have an account? Sign up"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
