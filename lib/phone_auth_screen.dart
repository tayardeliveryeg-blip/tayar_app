import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'passenger_home.dart';

// ====================================================
// ====== شاشة إدخال رقم الموبايل ======
// ====================================================
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      _showError(AppLocalizations.of(context)!.phoneNumberFormatError);
      return;
    }

    setState(() => _isLoading = true);

    // تحويل الرقم المصري لصيغة دولية (+20)
    String formattedPhone = phone;
    if (formattedPhone.startsWith('0')) {
      formattedPhone = formattedPhone.substring(1);
    }
    formattedPhone = '+20$formattedPhone';

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: formattedPhone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        _navigateToHome();
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isLoading = false);
        final l10n = AppLocalizations.of(context)!;
        _showError(
          l10n.errorOccurredWithMessage(e.message ?? l10n.tryAgainLabel),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(
              verificationId: verificationId,
              phoneNumber: formattedPhone,
            ),
          ),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const PassengerHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textColor),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Text(
              l10n.phoneNumberLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.otpSendNoticeLabel,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textGreyColor, fontSize: 14),
            ),
            const SizedBox(height: 40),

            // ====== حقل رقم الموبايل ======
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.dividerColor2),
              ),
              child: Row(
                children: [
                  Text(
                    '+20',
                    style: TextStyle(color: context.textColor, fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 24, color: context.dividerColor2),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textAlign: TextAlign.right,
                      style: TextStyle(color: context.textColor, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: '01xxxxxxxxx',
                        hintStyle: TextStyle(color: context.textGreyColor),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ====== زرار إرسال الكود ======
            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TayarColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: context.onPrimaryColor,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        l10n.sendCodeButton,
                        style: TextStyle(
                          color: context.onPrimaryColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================
// ====== شاشة إدخال كود التحقق (OTP) ======
// ====================================================
class OtpVerificationScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OtpVerificationScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _showError(AppLocalizations.of(context)!.otpLengthError);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: otp,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const PassengerHomeScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      final l10n = AppLocalizations.of(context)!;
      _showError(
        e.code == 'invalid-verification-code'
            ? l10n.invalidOtpError
            : l10n.errorOccurredWithMessage(e.message ?? l10n.tryAgainLabel),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textColor),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Text(
              l10n.confirmPhoneNumberTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.otpSentToNumberLabel(widget.phoneNumber),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textGreyColor, fontSize: 14),
            ),
            const SizedBox(height: 40),

            // ====== حقل الكود ======
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.dividerColor2),
              ),
              child: TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 22,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: '------',
                  hintStyle: TextStyle(color: context.textGreyColor),
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ====== زرار التأكيد ======
            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TayarColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: context.onPrimaryColor,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        l10n.confirmButton,
                        style: TextStyle(
                          color: context.onPrimaryColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
