// Ported from the MockAuthRepository object inside ui/screens/LoginScreen.kt

class MockAuthRepository {
  MockAuthRepository._();

  // Simulates hitting a "send OTP" endpoint
  static Future<String> sendOtp(String mobileNumber) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    return '0000'; // fixed demo OTP so it's easy to show without real SMS
  }

  // Simulates hitting a "verify OTP" endpoint
  static Future<bool> verifyOtp({
    required String mobileNumber,
    required String otp,
    required String expectedOtp,
  }) async {
    await Future.delayed(const Duration(milliseconds: 900));
    return otp == expectedOtp;
  }
}
