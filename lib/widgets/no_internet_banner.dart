import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/theme/theme_extensions.dart';

// ====================================================
// ====== بانر تنبيه بانقطاع الإنترنت ======
// بيتحط مرة واحدة في builder بتاع MaterialApp (main.dart) عشان يشتغل
// فوق كل شاشات التطبيق تلقائيًا من غير ما أي شاشة تحتاج تتعامل معاه
// بنفسها. بيراقب حالة الاتصال لايف، وبيظهر/يختفي بحركة سلسة من فوق
// الشاشة أول ما الاتصال يقطع/يرجع ======
// ====================================================
class NoInternetBanner extends StatefulWidget {
  const NoInternetBanner({super.key});

  @override
  State<NoInternetBanner> createState() => _NoInternetBannerState();
}

class _NoInternetBannerState extends State<NoInternetBanner> {
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _subscription = Connectivity().onConnectivityChanged.listen(
      _updateStatus,
    );
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _updateStatus(result);
    } catch (_) {
      // ====== لو الفحص نفسه فشل، منعرضش تنبيه غلط؛ الـ stream هيمسك أي
      // تغيير حقيقي بعد كده ======
    }
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final offline =
        results.isEmpty ||
        results.every((r) => r == ConnectivityResult.none);
    if (!mounted) return;
    setState(() => _isOffline = offline);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: IgnorePointer(
          // ====== وقت الاختفاء منعزلش لمس الشاشة اللي وراه ======
          ignoring: !_isOffline,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            offset: _isOffline ? Offset.zero : const Offset(0, -1.5),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _isOffline ? 1 : 0,
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: TayarColors.error,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(
                          context,
                        )!.noInternetConnectionMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
