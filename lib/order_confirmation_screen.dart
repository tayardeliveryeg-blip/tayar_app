import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'passenger_home.dart' show TayarColors, paymentMethodDisplay;
import 'searching_offers_screen.dart';

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
  late final double _minFare; // أقل سعر مسموح بيه (مش هننزل عن حد معين)

  // ====== خانة القبول التلقائي ======
  bool _autoAccept = false;

  @override
  void initState() {
    super.initState();
    _proposedFare = widget.fare;
    _minFare = (widget.fare * 0.5)
        .roundToDouble(); // مش هننزل عن نص السعر المقترح الأساسي
  }

  void _increaseFare() {
    setState(() => _proposedFare += _step);
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
      final user = FirebaseAuth.instance.currentUser;

      // ====== بناء GeoFirePoint لكل من نقطة الالتقاط والوجهة ======
      final pickupGeoFirePoint = GeoFirePoint(
        GeoPoint(
          widget.pickupLocation.latitude,
          widget.pickupLocation.longitude,
        ),
      );
      final destinationGeoFirePoint = GeoFirePoint(
        GeoPoint(
          widget.destinationLocation.latitude,
          widget.destinationLocation.longitude,
        ),
      );

      final orderRef = await FirebaseFirestore.instance.collection('orders').add({
        'customerId': user?.uid,
        'customerName':
            user?.displayName ??
            AppLocalizations.of(context)!.defaultCustomerName,
        'customerPhone': user?.phoneNumber,
        'pickupAddress': widget.pickupAddress,
        'pickupLocation': pickupGeoFirePoint.data,
        'destinationAddress': widget.destinationAddress,
        'destinationLocation': destinationGeoFirePoint.data,
        'distanceKm': widget.distanceKm,
        'durationMin': widget.durationMin,
        'suggestedFare': widget.fare, // السعر المقترح الأصلي (من حساب المسافة)
        'proposedFare': _proposedFare, // السعر اللي الراكب حدده فعليًا
        'autoAccept': _autoAccept, // هل يقبل تلقائيًا عرض بنفس السعر المقترح؟
        'paymentMethod': widget.paymentMethod,
        'serviceType': 'passenger',
        'status':
            'searching', // searching → accepted → in_progress → completed / cancelled
        'driverId': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // ننتقل لشاشة البحث عن العروض ومتابعتها لايف
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SearchingOffersScreen(
            orderId: orderRef.id,
            proposedFare: _proposedFare,
            autoAccept: _autoAccept,
            pickupAddress: widget.pickupAddress,
            pickupLocation: widget.pickupLocation,
            destinationAddress: widget.destinationAddress,
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
      backgroundColor: TayarColors.background,
      appBar: AppBar(
        backgroundColor: TayarColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.setYourFareTitle,
          style: const TextStyle(color: Colors.white),
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
                color: TayarColors.cardDark,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _RouteRow(
                    icon: Icons.radio_button_checked,
                    iconColor: TayarColors.primary,
                    label: l10n.routeFromLabel,
                    address: widget.pickupAddress,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const SizedBox(width: 10),
                        Container(width: 2, height: 24, color: Colors.white24),
                      ],
                    ),
                  ),
                  _RouteRow(
                    icon: Icons.location_on,
                    iconColor: Colors.redAccent,
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
                color: TayarColors.cardDark,
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
                  const Divider(color: Colors.white12),
                  _DetailRow(
                    label: l10n.estimatedTimeLabel,
                    value: l10n.durationMinLabel(widget.durationMin),
                  ),
                  const Divider(color: Colors.white12),
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
                    style: const TextStyle(color: Colors.white, fontSize: 14),
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
                      _FareStepButton(icon: Icons.add, onTap: _increaseFare),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.autoSuggestedFareLabel(widget.fare.toStringAsFixed(0)),
                    style: const TextStyle(
                      color: TayarColors.textGrey,
                      fontSize: 12,
                    ),
                  ),
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
                        style: const TextStyle(
                          color: Colors.white,
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
                    : const Icon(Icons.search, color: Colors.white),
                label: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        l10n.searchForDriversButton,
                        style: const TextStyle(
                          color: Colors.white,
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
                style: const TextStyle(
                  color: TayarColors.textGrey,
                  fontSize: 12,
                ),
              ),
              Text(
                address,
                style: const TextStyle(
                  color: Colors.white,
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
            style: const TextStyle(color: TayarColors.textGrey, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
