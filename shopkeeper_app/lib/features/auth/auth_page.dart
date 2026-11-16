import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class AuthPage extends StatefulWidget {
  final bool register, reset;
  const AuthPage({super.key, this.register = false, this.reset = false});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController(), password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false, accepted = false;
  String message = '';
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    if (widget.register && (!accepted || password.text.length < 8)) {
      setState(
        () => message =
            'Use at least 8 password characters and accept the privacy notice.',
      );
      return;
    }
    setState(() {
      busy = true;
      message = '';
    });
    try {
      if (widget.reset) {
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: email.text.trim(),
        );
        if (mounted) {
          setState(
            () => message =
                'If this account exists, a password-reset email has been requested. In emulator mode, open the reset link shown in the emulator terminal.',
          );
        }
      } else if (widget.register) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => message = e.message ?? 'Authentication failed.');
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => message = 'Cannot connect. Check the Firebase setup and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: PageBody(
      maxWidth: 470,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 35),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: Colors.white,
                    size: 35,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'RepairProof',
                style: TextStyle(
                  fontSize: 31,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const Text(
                'Every repair has a record.',
                style: TextStyle(color: primary),
              ),
              const SizedBox(height: 36),
              Text(
                widget.reset
                    ? 'Reset your password'
                    : widget.register
                    ? 'Create your shop account'
                    : 'Welcome back.',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.reset
                    ? 'We will send a link to your registered email.'
                    : 'Manage your repairs, from first handover to final receipt.',
                style: const TextStyle(color: Color(0xFF61786A)),
              ),
              const SizedBox(height: 26),
              field(
                email,
                'Email',
                max: 160,
                keyboard: TextInputType.emailAddress,
              ),
              if (!widget.reset)
                field(password, 'Password', obscure: true, max: 128),
              if (widget.register)
                CheckboxListTile(
                  value: accepted,
                  onChanged: (v) => setState(() => accepted = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'I have read the privacy notice and will record customer permission.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              if (message.isNotEmpty) notice(message),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Text(
                  busy
                      ? 'Please wait…'
                      : widget.reset
                      ? 'Send reset email'
                      : widget.register
                      ? 'Create account'
                      : 'Sign in',
                ),
              ),
              const SizedBox(height: 12),
              if (!widget.register && !widget.reset)
                TextButton(
                  onPressed: () => Get.toNamed('/reset'),
                  child: const Text('Forgot password?'),
                ),
              TextButton(
                onPressed: () => Get.offAllNamed(
                  widget.register || widget.reset ? '/login' : '/register',
                ),
                child: Text(
                  widget.register || widget.reset
                      ? 'Back to sign in'
                      : 'New shop? Create an account',
                ),
              ),
              TextButton(
                onPressed: () => Get.toNamed('/privacy'),
                child: const Text('Privacy & account deletion'),
              ),
              if (AppConfig.emulators)
                notice(
                  'Local emulator mode · Use fictitious test data only. No cloud project is connected.',
                ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    ),
  );
}
