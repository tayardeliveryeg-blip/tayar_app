import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/home/passenger_home_screen.dart' show TayarColors;
import 'package:tayay_app/theme/theme_extensions.dart'
    show AppSpacing, AppRadius, TayarThemeColors;
import 'package:tayay_app/helpers/auth_flow_helpers.dart';
import 'package:tayay_app/widgets/app_primary_button.dart';
import 'package:tayay_app/widgets/tayar_toast.dart';
import 'package:tayay_app/utils/tayar_page_route.dart';

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
    String formattedPhone = phone;
    if (formattedPhone.startsWith('0')) {
      formattedPhone = formattedPhone.substring(1);
    }
    formattedPhone = '+20$formattedPhone';

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: formattedPhone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        if (!mounted) return;
        await navigateAfterAuth(context, isNewUser: userCredential.additionalUserInfo?.isNewUser ?? false);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        final l10n = AppLocalizations.of(context)!;
        _showError(l10n.errorOccurredWithMessage(e.message ?? l10n.tryAgainLabel));
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.push(
          context,
          TayarPageRoute(
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
    TayarToast.show(context, message, type: ToastType.error);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textColor),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.phoneNumberLabel,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                color: context.textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.otpSendNoticeLabel,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: context.textGreyColor),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: context.dividerColor2),
              ),
              child: Row(
                children: [
                  Text('+20', style: textTheme.bodyLarge?.copyWith(color: context.textColor)),
                  const SizedBox(width: AppSpacing.sm),
                  Container(width: 1, height: 24, color: context.dividerColor2),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textAlign: TextAlign.right,
                      style: textTheme.bodyLarge?.copyWith(color: context.textColor),
                      decoration: InputDecoration(
                        hintText: '01xxxxxxxxx',
                        hintStyle: textTheme.bodyLarge?.copyWith(color: context.textGreyColor),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(
              onPressed: _isLoading ? null : _sendOtp,
              variant: AppButtonVariant.primary,
              size: AppButtonSize.medium,
              isLoading: _isLoading,
              child: Text(
                l10n.sendCodeButton,
                style: textTheme.labelLarge?.copyWith(
                  color: context.onPrimaryColor,
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

class OtpVerificationScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final int? resendToken;
  final bool reauthMode;

  const OtpVerificationScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    this.resendToken,
    this.reauthMode = false,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> with TickerProviderStateMixin {
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
    _entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );
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
    if (!mounted) return;
    setState(() {});
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
      final credential = PhoneAuthProvider.credential(verificationId: _verificationId, smsCode: code);
      if (widget.reauthMode) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('no-current-user');
        await user.reauthenticateWithCredential(credential);
        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;
      await navigateAfterAuth(context, isNewUser: userCredential.additionalUserInfo?.isNewUser ?? false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      _showError(e.code == 'invalid-verification-code' ? l10n.invalidOtpError : l10n.errorOccurredWithMessage(e.message ?? l10n.tryAgainLabel));
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
        if (widget.reauthMode) {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;
          await user.reauthenticateWithCredential(credential);
          if (!mounted) return;
          Navigator.pop(context, true);
          return;
        }
        final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        if (!mounted) return;
        await navigateAfterAuth(context, isNewUser: userCredential.additionalUserInfo?.isNewUser ?? false);
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
        TayarToast.show(context, l10n.codeResentMessage, type: ToastType.success);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  void _showError(String message) {
    TayarToast.show(context, message, type: ToastType.error);
  }

  Widget _buildPinBox(int index) {
    final code = _hiddenController.text;
    final digit = index < code.length ? code[index] : '';
    final isCurrent = index == code.length;
    final hasFocus = _hiddenFieldFocus.hasFocus;
    final isFilled = digit.isNotEmpty;
    final borderColor = isFilled || (isCurrent && hasFocus) ? TayarColors.primary : context.dividerColor2;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 46,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: borderColor, width: isCurrent && hasFocus ? 2 : 1),
      ),
      child: Text(
        digit,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: context.textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
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
                    style: textTheme.headlineSmall?.copyWith(color: context.textColor, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.otpSentToNumberLabel(widget.phoneNumber),
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(color: context.textGreyColor),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AnimatedBuilder(
                    animation: _shakeAnim,
                    builder: (context, child) => Transform.translate(offset: Offset(_shakeAnim.value, 0), child: child),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(_codeLength, _buildPinBox),
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
                        ? Text(l10n.resendCodeCountdown(_secondsLeft), style: textTheme.bodySmall?.copyWith(color: context.textGreyColor))
                        : Column(
                            children: [
                              Text(l10n.didntReceiveCodeLabel, style: textTheme.bodySmall?.copyWith(color: context.textGreyColor)),
                              const SizedBox(height: AppSpacing.xs),
                              TextButton(
                                onPressed: _isLoading ? null : _resendCode,
                                child: Text(
                                  l10n.resendCodeButton,
                                  style: textTheme.labelLarge?.copyWith(color: TayarColors.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppPrimaryButton(
                    onPressed: (_isLoading || _hiddenController.text.length != _codeLength) ? null : () => _verifyOtp(_hiddenController.text),
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.medium,
                    isLoading: _isLoading,
                    child: Text(
                      l10n.confirmButton,
                      style: textTheme.labelLarge?.copyWith(color: context.onPrimaryColor, fontWeight: FontWeight.bold),
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
