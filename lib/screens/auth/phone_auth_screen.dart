import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart' show TayarColors, TayarThemeColors;
import 'package:tayay_app/theme/theme_extensions.dart' show AppSpacing, AppRadius;
import 'package:tayay_app/helpers/auth_flow_helpers.dart';

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
        final userCredential = await FirebaseAuth.instance
            .signInWithCredential(credential);
        if (!mounted) return;
        await navigateAfterAuth(
          context,
          isNewUser: userCredential.additionalUserInfo?.isNewUser ?? false,
        );
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
              resendToken: resendToken,
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
  final int? resendToken;

  const OtpVerificationScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    this.resendToken,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
    with TickerProviderStateMixin {
  static const int _codeLength = 6;
  static const int _resendSeconds = 60;

  // آخر verificationId معتمد (بيتغيّر بعد إعادة الإرسال)
  late String _verificationId;
  int? _resendToken;

  // حقل واحد مخفي بياخد الإدخال الحقيقي (ودعم الـ autofill) + كنترولر
  // منفصل لكل خانة عشان العرض بس
  final FocusNode _hiddenFieldFocus = FocusNode();
  final TextEditingController _hiddenController = TextEditingController();

  bool _isLoading = false;
  bool _isAutoVerifying = false;
  Timer? _timer;
  int _secondsLeft = _resendSeconds;

  // ====== أنيميشن دخول الشاشة ======
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ====== أنيميشن الاهتزاز عند الخطأ ======
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _resendToken = widget.resendToken;

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );
    _entranceController.forward();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);

    _hiddenController.addListener(_onCodeChanged);
    _startResendTimer();

    // فوكس تلقائي على الحقل المخفي فور فتح الشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _hiddenFieldFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hiddenController.removeListener(_onCodeChanged);
    _hiddenController.dispose();
    _hiddenFieldFocus.dispose();
    _entranceController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _onCodeChanged() {
    setState(() {}); // تحديث شكل الخانات مع كل حرف
    final code = _hiddenController.text;
    if (code.length == _codeLength && !_isLoading && !_isAutoVerifying) {
      _isAutoVerifying = true;
      _verifyOtp(code);
    }
  }

  Future<void> _verifyOtp(String code) async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: code,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      if (!mounted) return;
      await navigateAfterAuth(
        context,
        isNewUser: userCredential.additionalUserInfo?.isNewUser ?? false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      _showError(
        e.code == 'invalid-verification-code'
            ? l10n.invalidOtpError
            : l10n.errorOccurredWithMessage(e.message ?? l10n.tryAgainLabel),
      );
      _clearAndShake();
    } finally {
      _isAutoVerifying = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearAndShake() {
    _hiddenController.clear();
    _shakeController.forward(from: 0);
    HapticFeedback.mediumImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _hiddenFieldFocus.requestFocus();
    });
  }

  Future<void> _resendCode() async {
    if (_secondsLeft > 0) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() => _isLoading = true);
    _hiddenController.clear();

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.phoneNumber,
      forceResendingToken: _resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        final userCredential = await FirebaseAuth.instance
            .signInWithCredential(credential);
        if (!mounted) return;
        await navigateAfterAuth(
          context,
          isNewUser: userCredential.additionalUserInfo?.isNewUser ?? false,
        );
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showError(
          l10n.errorOccurredWithMessage(e.message ?? l10n.tryAgainLabel),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _verificationId = verificationId;
          _resendToken = resendToken;
        });
        _startResendTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.codeResentMessage),
            backgroundColor: TayarColors.primary,
          ),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ====== خانة رقم واحدة من خانات الكود ======
  Widget _buildPinBox(int index) {
    final code = _hiddenController.text;
    final digit = index < code.length ? code[index] : '';
    final isCurrent = index == code.length;
    final hasFocus = _hiddenFieldFocus.hasFocus;
    final isFilled = digit.isNotEmpty;

    final Color borderColor = isFilled
        ? TayarColors.primary
        : (isCurrent && hasFocus)
            ? TayarColors.primary
            : context.dividerColor2;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 46,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: borderColor,
          width: (isFilled || (isCurrent && hasFocus)) ? 2 : 1,
        ),
        boxShadow: (isCurrent && hasFocus)
            ? [
                BoxShadow(
                  color: TayarColors.primary.withValues(alpha: 0.18),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 120),
        child: Text(
          digit,
          key: ValueKey(digit),
          style: TextStyle(
            color: context.textColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    l10n.confirmPhoneNumberTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.otpSentToNumberLabel(widget.phoneNumber),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.textGreyColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ====== خانات الكود + حقل مخفي للـ autofill ======
                  AnimatedBuilder(
                    animation: _shakeAnim,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(_shakeAnim.value, 0),
                      child: child,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            _codeLength,
                            (i) => _buildPinBox(i),
                          ),
                        ),
                        // حقل حقيقي شفاف فوق الخانات: بياخد الإدخال
                        // والـ autofill من رسالة الـ SMS تلقائيًا
                        Opacity(
                          opacity: 0.0,
                          child: TextField(
                            controller: _hiddenController,
                            focusNode: _hiddenFieldFocus,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: _codeLength,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              counterText: '',
                              border: InputBorder.none,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ====== إعادة الإرسال + العداد ======
                  Center(
                    child: _secondsLeft > 0
                        ? Text(
                            l10n.resendCodeCountdown(_secondsLeft),
                            style: TextStyle(
                              color: context.textGreyColor,
                              fontSize: 13,
                            ),
                          )
                        : Column(
                            children: [
                              Text(
                                l10n.didntReceiveCodeLabel,
                                style: TextStyle(
                                  color: context.textGreyColor,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              TextButton(
                                onPressed: _isLoading ? null : _resendCode,
                                child: Text(
                                  l10n.resendCodeButton,
                                  style: const TextStyle(
                                    color: TayarColors.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ====== زرار التأكيد ======
                  SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      onPressed: (_isLoading ||
                              _hiddenController.text.length != _codeLength)
                          ? null
                          : () => _verifyOtp(_hiddenController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TayarColors.primary,
                        disabledBackgroundColor:
                            TayarColors.primary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
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
          ),
        ),
      ),
    );
  }
}
