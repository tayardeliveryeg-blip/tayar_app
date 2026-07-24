import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'l10n/generated/app_localizations.dart';
import 'passenger_home.dart' show TayarColors, TayarThemeColors;
import 'theme_extensions.dart' show AppSpacing, AppRadius;

// ====================================================
// ====== شاشة تأكيد كود OTP لربط رقم موبايل بحساب مسجّل دخول
// بالفعل (بجوجل مثلًا) — مختلفة عن OtpVerificationScreen في
// phone_auth_screen.dart اللي بتعمل تسجيل دخول (signInWithCredential)؛
// هنا بنعمل linkWithCredential على نفس الحساب الحالي، عشان يبقى
// عنده phone_number claim حقيقي وموثّق في الـ Auth token — وده اللي
// قاعدة isPreInvitedMatch في firestore.rules بتعتمد عليه ======
// ====================================================
class MobileLinkOtpScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final int? resendToken;

  const MobileLinkOtpScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    this.resendToken,
  });

  @override
  State<MobileLinkOtpScreen> createState() => _MobileLinkOtpScreenState();
}

class _MobileLinkOtpScreenState extends State<MobileLinkOtpScreen>
    with TickerProviderStateMixin {
  static const int _codeLength = 6;
  static const int _resendSeconds = 60;

  late String _verificationId;
  int? _resendToken;

  final FocusNode _hiddenFieldFocus = FocusNode();
  final TextEditingController _hiddenController = TextEditingController();

  bool _isLoading = false;
  bool _isAutoVerifying = false;

  Timer? _timer;
  int _secondsLeft = _resendSeconds;

  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

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
    _fadeAnim = CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic));
    _entranceController.forward();

    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);

    _hiddenController.addListener(_onCodeChanged);
    _startResendTimer();

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
    setState(() {});
    final code = _hiddenController.text;
    if (code.length == _codeLength && !_isLoading && !_isAutoVerifying) {
      _isAutoVerifying = true;
      _verifyAndLink(code);
    }
  }

  Future<void> _verifyAndLink(String code) async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: code,
      );
      await FirebaseAuth.instance.currentUser!.linkWithCredential(credential);
      // ====== لازم نجدد التوكن بعد الربط عشان يظهر فيه phone_number
      // claim على طول؛ من غيرها قاعدة isPreInvitedMatch هتفضل شايفة
      // التوكن القديم اللي مفيهوش الرقم لحد ما يتجدد لوحده ======
      await FirebaseAuth.instance.currentUser?.getIdToken(true);

      if (!mounted) return;
      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      _showError(
        e.code == 'invalid-verification-code'
            ? l10n.invalidOtpError
            : e.code == 'credential-already-in-use'
                ? l10n.credentialAlreadyInUseError
                : l10n.errorOccurredWithMessage(e.message ?? l10n.tryAgainLabel),
      );
      if (e.code == 'credential-already-in-use') {
        // ====== الرقم متسجل بحساب تاني: مفيش داعي يفضل يحاول يبعت
        // كود تاني بنفس الرقم، الأنسب يرجع يعدّل الرقم ======
        Navigator.pop(context, false);
      } else {
        _clearAndShake();
      }
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
        try {
          await FirebaseAuth.instance.currentUser!.linkWithCredential(credential);
          await FirebaseAuth.instance.currentUser?.getIdToken(true);
          if (!mounted) return;
          Navigator.pop(context, true);
        } on FirebaseAuthException catch (e) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          _showError(
            e.code == 'credential-already-in-use'
                ? l10n.credentialAlreadyInUseError
                : l10n.errorOccurredWithMessage(e.message ?? l10n.tryAgainLabel),
          );
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showError(l10n.errorOccurredWithMessage(e.message ?? l10n.tryAgainLabel));
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
          SnackBar(content: Text(l10n.codeResentMessage), backgroundColor: TayarColors.primary),
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
            ? [BoxShadow(color: TayarColors.primary.withValues(alpha: 0.18), blurRadius: 8, spreadRadius: 1)]
            : null,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 120),
        child: Text(
          digit,
          key: ValueKey(digit),
          style: TextStyle(color: context.textColor, fontSize: 24, fontWeight: FontWeight.bold),
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    l10n.confirmPhoneNumberTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.textColor, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.otpSentToNumberLabel(widget.phoneNumber),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.textGreyColor, fontSize: 14),
                  ),
                  const SizedBox(height: 40),
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
                          children: List.generate(_codeLength, (i) => _buildPinBox(i)),
                        ),
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
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: _secondsLeft > 0
                        ? Text(
                            l10n.resendCodeCountdown(_secondsLeft),
                            style: TextStyle(color: context.textGreyColor, fontSize: 13),
                          )
                        : Column(
                            children: [
                              Text(
                                l10n.didntReceiveCodeLabel,
                                style: TextStyle(color: context.textGreyColor, fontSize: 13),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              TextButton(
                                onPressed: _isLoading ? null : _resendCode,
                                child: Text(
                                  l10n.resendCodeButton,
                                  style: const TextStyle(color: TayarColors.primary, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      onPressed: (_isLoading || _hiddenController.text.length != _codeLength)
                          ? null
                          : () => _verifyAndLink(_hiddenController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TayarColors.primary,
                        disabledBackgroundColor: TayarColors.primary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: context.onPrimaryColor, strokeWidth: 2),
                            )
                          : Text(
                              l10n.confirmButton,
                              style: TextStyle(color: context.onPrimaryColor, fontSize: 18, fontWeight: FontWeight.bold),
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
