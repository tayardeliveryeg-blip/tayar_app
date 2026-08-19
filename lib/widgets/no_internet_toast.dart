import 'package:flutter/material.dart';

import 'package:tayay_app/l10n/generated/app_localizations.dart';

// ====================================================
// ====== رسالة "مفيش إنترنت" مركزية ومؤقتة (زي تطبيقات زي Uber/Careem) ======
// بتتحط فوق الشاشة الحالية بـ Overlay مباشرة (من غير Navigator.push)،
// فمفيش أي تنقل بيحصل خالص - الزرار اللي داس عليه المستخدم بيفضل واقف
// في مكانه. الرسالة نفسها IgnorePointer (منعزلش لمس باقي الشاشة)،
// بتفيد-إن، تقعد شوية كفاية للقراءة، وبعدين بتفيد-آوت لوحدها من غير
// أي زرار "تمام" أو تفاعل مطلوب من المستخدم - عشان تبقى واضحة من غير
// ما "تزعج". لو فيه رسالة ظاهرة بالفعل مبنعرضش فوقها واحدة تانية. ======
// ====================================================
OverlayEntry? _activeNoInternetEntry;

void showNoInternetToast(BuildContext context) {
  if (_activeNoInternetEntry != null) return;

  final loc = AppLocalizations.of(context)!;
  final overlayState = Overlay.of(context, rootOverlay: true);

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _NoInternetToast(
      message: loc.noInternetConnectionMessage,
      onDismissed: () {
        if (_activeNoInternetEntry == entry) {
          _activeNoInternetEntry = null;
          entry.remove();
        }
      },
    ),
  );
  _activeNoInternetEntry = entry;
  overlayState.insert(entry);
}

class _NoInternetToast extends StatefulWidget {
  const _NoInternetToast({required this.message, required this.onDismissed});

  final String message;
  final VoidCallback onDismissed;

  @override
  State<_NoInternetToast> createState() => _NoInternetToastState();
}

class _NoInternetToastState extends State<_NoInternetToast> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    // ====== فيد-إن بعد أول فريم (مينفعش نغيّر الحالة جوه initState نفسها) ======
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _visible = true);
    });
    // ====== تختفي لوحدها بعد ما تفضل ظاهرة وقت كافي للقراءة ======
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      setState(() => _visible = false);
      Future.delayed(const Duration(milliseconds: 250), widget.onDismissed);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.center,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: _visible ? 1 : 0,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              scale: _visible ? 1 : 0.94,
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 56),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
