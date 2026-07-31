import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart'
    show TayarColors, TayarThemeColors, paymentMethodDisplay;
import 'package:tayay_app/screens/passenger/searching_offers_screen.dart';
import 'package:tayay_app/services/fare_negotiation_rules.dart';
import 'package:tayay_app/services/wallet_service.dart';

class OrderConfirmationScreen extends StatefulWidget {
  final String pickupAddress;
  final LatLng pickupLocation;
  final String destinationAddress;
  final LatLng destinationLocation;
  final double distanceKm;
  final int durationMin;
  final double fare;
  final String paymentMethod;

  const OrderConfirmationScreen({
    super.key,
    required this.pickupAddress,
    required this.pickupLocation,
    required this.destinationAddress,
    required this.destinationLocation,
    required this.distanceKm,
    required this.durationMin,
    required this.fare,
    required this.paymentMethod,
  });

  @override
  State<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  bool _isSubmitting = false;

  // ====== السعر المقترح من الراكب (قابل للتعديل) ======
  late double _proposedFare;
  static const double _step = 5.0; // مقدار الزيادة/النقصان لكل ضغطة

  // ====== نفس حدود المزايدة المطبّقة بعد كده في searching_offers_screen.dart
  // و offer_sheet.dart (0.5x - 1.5x من السعر الأساسي)، عشان الراكب مايقدرش
  // يرفع السعر هنا فوق السقف اللي هيتفرض عليه بعد كده في شاشة البحث عن عروض ======
  late final double _minFare; // أقل سعر مسموح بيه
  late final double _maxFare; // أعلى سعر مسموح بيه (قبل حد المحفظة لو موجود)

  // ====== لما الدفع يكون محفظة إلكترونية: أعلى سعر مسموح بيه هو رصيد
  // المحفظة الفعلي (بنجيبه من السيرفر عشان محدش يتلاعب بيه من الشاشة
  // اللي فاتت)، عشان الراكب مايقدرش يقترح سعر أكبر من اللي معاه فعلاً ======
  double? _walletMaxFare;

  // ====== خانة القبول التلقائي ======
  bool _autoAccept = false;

  @override
  void initState() {
    super.initState();
    _proposedFare = widget.fare;
    _minFare = FareNegotiationRules.minFareFor(widget.fare);
    _maxFare = FareNegotiationRules.maxFareFor(widget.fare);
    if (widget.paymentMethod == kWalletPaymentMethodValue) {
      _loadWalletCap();
    }
  }

  Future<void> _loadWalletCap() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final balance = await getPassengerWalletBalance(uid);
      if (!mounted) return;
      setState(() {
        _walletMaxFare = balance;
        if (_proposedFare > balance) {
          _proposedFare = balance;
        }
      });
    } catch (_) {}
  }

  void _increaseFare() {
    setState(() {
      final bool underNegotiationCap = _proposedFare + _step <= _maxFare;
      final bool underWalletCap =
          _walletMaxFare == null || _proposedFare + _step <= _walletMaxFare!;
      if (underNegotiationCap && underWalletCap) {
        _proposedFare += _step;
      }
    });
  }

  void _decreaseFare() {
    setState(() {
      if (_proposedFare - _step >= _minFare) {
        _proposedFare -= _step;
      }
    });
  }

  Future<void> _searchForOffers() async {
    setState(() => _isSubmitting = true);

    try {
      // ====== إنشاء الطلب بالكامل بيحصل دلوقتي على السيرفر (Cloud Function
      // اسمها createOrder). السيرفر هو اللي بيحسب المسافة والسعر المقترح
      // الحقيقيين من إحداثيات نقطة الانطلاق والوجهة بس، وبيتأكد إن السعر
      // اللي الراكب حدده (proposedFare) منطقي قبل ما يكتب أي حاجة في
      // Firestore - عشان محدش يقدر يتلاعب بالمسافة أو السعر عن طريق تعديل
      // الموبايل نفسه. اسم ورقم الراكب كمان بيتجابوا من السيرفر مباشرة. ======
      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('createOrder');

      final result = await callable.call<Map<String, dynamic>>({
        'pickupAddress': widget.pickupAddress,
        'pickupLat': widget.pickupLocation.latitude,
        'pickupLng': widget.pickupLocation.longitude,
        'destinationAddress': widget.destinationAddress,
        'destinationLat': widget.destinationLocation.latitude,
        'destinationLng': widget.destinationLocation.longitude,
        'proposedFare': _proposedFare,
        'autoAccept': _autoAccept,
        'paymentMethod': widget.paymentMethod,
      });

      final orderId = result.data['orderId'] as String;

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // ننتقل لشاشة البحث عن العروض ومتابعتها لايف
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SearchingOffersScreen(
            orderId: orderId,
            proposedFare: _proposedFare,
            autoAccept: _autoAccept,
            pickupAddress: widget.pickupAddress,
            pickupLocation: widget.pickupLocation,
            destinationAddress: widget.destinationAddress,
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      // ====== رسالة السيرفر بتوصل هنا لو السعر غير منطقي مثلًا (invalid-argument) ======
      debugPrint('❌ خطأ من createOrder: ${e.code} - ${e.message}');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? AppLocalizations.of(context)!.submitFailedError,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ خطأ في إرسال الطلب: $e');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.submitFailedError),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.setYourFareTitle,
          style: TextStyle(color: context.textColor),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ====== كارت المسار: من - إلى ======
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _RouteRow(
                    icon: Icons.location_on,
                    iconColor: TayarColors.primary,
                    label: l10n.routeFromLabel,
                    address: widget.pickupAddress,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const SizedBox(width: 10),
                        Container(
                          width: 2,
                          height: 24,
                          color: context.dividerColor2,
                        ),
                      ],
                    ),
                  ),
                  _RouteRow(
                    icon: Icons.flag,
                    iconColor: TayarColors.primary,
                    label: l10n.routeToLabel,
                    address: widget.destinationAddress,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ====== كارت تفاصيل الرحلة ======
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _DetailRow(
                    label: l10n.distanceLabel,
                    value: l10n.distanceKmLabel(
                      widget.distanceKm.toStringAsFixed(1),
                    ),
                  ),
                  Divider(color: context.dividerColor2),
                  _DetailRow(
                    label: l10n.estimatedTimeLabel,
                    value: l10n.durationMinLabel(widget.durationMin),
                  ),
                  Divider(color: context.dividerColor2),
                  _DetailRow(
                    label: l10n.paymentMethodLabel,
                    value: paymentMethodDisplay(context, widget.paymentMethod),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ====== كارت السعر القابل للتعديل ======
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TayarColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: TayarColors.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    l10n.suggestedFareForDriversLabel,
                    style: TextStyle(color: context.textColor, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _FareStepButton(
                        icon: Icons.remove,
                        onTap: _proposedFare - _step >= _minFare
                            ? _decreaseFare
                            : null,
                      ),
                      SizedBox(
                        width: 140,
                        child: Text(
                          l10n.currencyEGP(_proposedFare.toStringAsFixed(0)),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: TayarColors.primary,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _FareStepButton(
                        icon: Icons.add,
                        onTap:
                            (_proposedFare + _step > _maxFare) ||
                                (_walletMaxFare != null &&
                                    _proposedFare + _step > _walletMaxFare!)
                            ? null
                            : _increaseFare,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.autoSuggestedFareLabel(widget.fare.toStringAsFixed(0)),
                    style: TextStyle(
                      color: context.textGreyColor,
                      fontSize: 12,
                    ),
                  ),
                  if (_walletMaxFare != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.walletMaxFareCapLabel(
                        _walletMaxFare!.toStringAsFixed(0),
                      ),
                      style: TextStyle(
                        color: context.textGreyColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Spacer(),

            // ====== خانة القبول التلقائي (فوق زرار البحث عن عروض) ======
            InkWell(
              onTap: () => setState(() => _autoAccept = !_autoAccept),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: _autoAccept,
                      activeColor: TayarColors.primary,
                      onChanged: (value) =>
                          setState(() => _autoAccept = value ?? false),
                    ),
                    Expanded(
                      child: Text(
                        l10n.autoAcceptCheckboxLabel,
                        style: TextStyle(
                          color: context.textColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ====== زرار البحث عن عروض ======
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _searchForOffers,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TayarColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _isSubmitting
                    ? const SizedBox.shrink()
                    : Icon(Icons.search, color: context.onPrimaryColor),
                label: _isSubmitting
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: context.onPrimaryColor,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        l10n.searchForDriversButton,
                        style: TextStyle(
                          color: context.textColor,
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

// ====== زرار +/- لتعديل السعر ======
class _FareStepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _FareStepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled
              ? TayarColors.primary
              : TayarColors.primary.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String address;

  const _RouteRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: context.textGreyColor, fontSize: 12),
              ),
              Text(
                address,
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: context.textGreyColor, fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(
              color: context.textColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
