import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';
import '../widgets/custom_button.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _verificationCheckTimer;
  Timer? _resendCountdownTimer;

  bool _isEmailVerified = false;
  bool _emailSentOnce = false;
  int _countdown = 60;

  @override
  void initState() {
    super.initState();

    _isEmailVerified = FirebaseAuth.instance.currentUser!.emailVerified;
    if (!_isEmailVerified && !_emailSentOnce) {
      _emailSentOnce = true;
      _sendVerificationEmail();
      _verificationCheckTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _checkEmailVerified(),
      );
    }
  }

  @override
  void dispose() {
    _verificationCheckTimer?.cancel();
    _resendCountdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.sendEmailVerification();

        setState(() {
          _countdown = 60;
        });
        _startResendTimer();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent!')),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to send verification email.';
      if (e.code == 'too-many-requests') {
        message = 'Too many requests. Please wait a few minutes before trying again.';
        setState(() {
          _countdown = 120; // Extend cooldown to 2 minutes
        });
        _startResendTimer();
      }
      print('FirebaseAuthException: ${e.code} - ${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      print('Error sending verification email: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unexpected error occurred.')),
      );
    }
  }

  void _startResendTimer() {
    _resendCountdownTimer?.cancel();
    _resendCountdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (_countdown > 0) {
          setState(() {
            _countdown--;
          });
        } else {
          timer.cancel();
        }
      },
    );
  }

  Future<void> _checkEmailVerified() async {
    await FirebaseAuth.instance.currentUser?.reload();
    final user = FirebaseAuth.instance.currentUser;

    setState(() {
      _isEmailVerified = user?.emailVerified ?? false;
    });

    if (_isEmailVerified) {
      _verificationCheckTimer?.cancel();
      _resendCountdownTimer?.cancel();
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email', style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).primaryColor,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.email_outlined,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 24),
            Text(
              "Check Your Inbox",
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              "We have sent a verification link to your email address. Please click the link to activate your account.",
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            CustomButton(
              text: _countdown > 0
                  ? "Resend Link in $_countdown s"
                  : "Resend Verification Link",
              onPressed: _countdown > 0 ? null : _sendVerificationEmail,
              isLoading: false,
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                FirebaseAuth.instance.signOut();
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: Text(
                "Cancel and Go to Login",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
