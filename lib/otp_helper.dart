import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

// Keys for SharedPreferences
const String _otpKey = 'otp';
const String _otpExpiryKey = 'otp_expiry';
const String _lastSendKey = 'otp_last_send';

class OtpHelper {
  // Generates a random 6-digit OTP.
  static String _generateOtp() {
    final random = Random();
    String otp = '';
    for (int i = 0; i < 6; i++) {
      otp += random.nextInt(10).toString();
    }
    return otp;
  }


  static Future<void> sendOtp(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final String otp = _generateOtp();
    final int expiryTime = DateTime.now().add(const Duration(seconds: 90)).millisecondsSinceEpoch;
    final int lastSendTime = DateTime.now().millisecondsSinceEpoch;

    // Simulate sending an email by printing to the console
    print('Simulating email send: Sending OTP $otp to $email');


    await prefs.setString(_otpKey, otp);
    await prefs.setInt(_otpExpiryKey, expiryTime);
    await prefs.setInt(_lastSendKey, lastSendTime);
  }

  // Verifies the entered OTP against the one stored in local storage.
  static Future<bool> verifyOtp(String enteredOtp) async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedOtp = prefs.getString(_otpKey);
    final int? storedExpiry = prefs.getInt(_otpExpiryKey);

    // Check if the OTP exists and if it has not expired
    if (storedOtp == null || storedExpiry == null) {
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now > storedExpiry) {
      // OTP has expired, clear it from storage
      await prefs.remove(_otpKey);
      return false;
    }

    // Check if the entered OTP matches the stored one
    return enteredOtp == storedOtp;
  }

  // Checks if enough time has passed to allow for resending the OTP.
  static Future<bool> canResend() async {
    final prefs = await SharedPreferences.getInstance();
    final int? lastSendTime = prefs.getInt(_lastSendKey);
    if (lastSendTime == null) {
      // No OTP has been sent yet, so it can be sent
      return true;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    const int cooldownPeriod = 60 * 1000; // 60 seconds in milliseconds
    return (now - lastSendTime) > cooldownPeriod;
  }
}