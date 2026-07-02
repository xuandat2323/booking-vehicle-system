import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebasePhoneService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Verifies a phone number. 
  /// The [phoneNumber] should be in E.164 format (e.g. +84987654321).
  Future<void> verifyPhone({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(FirebaseAuthException exception) onFailed,
    required Function(PhoneAuthCredential credential) onAutoVerified,
    required Function(String verificationId) onTimeout,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('FirebasePhoneService: Auto verification completed');
          onAutoVerified(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('FirebasePhoneService: Verification failed: ${e.message}');
          onFailed(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('FirebasePhoneService: Code sent to $phoneNumber');
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('FirebasePhoneService: Auto retrieval timeout');
          onTimeout(verificationId);
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      debugPrint('FirebasePhoneService: Error in verifyPhoneNumber: $e');
      rethrow;
    }
  }

  /// Exchanges [verificationId] and [smsCode] for a Firebase ID Token.
  Future<String?> getFirebaseIdToken({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      
      // Sign in with the credential
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      
      if (user != null) {
        // Get the ID token
        final idToken = await user.getIdToken();
        return idToken;
      }
      return null;
    } catch (e) {
      debugPrint('FirebasePhoneService: Failed to get ID token: $e');
      rethrow;
    }
  }
}
