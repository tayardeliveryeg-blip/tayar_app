import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';

import 'passenger_home.dart' show TayarColors, TayarThemeColors, paymentMethodDisplay;
import 'select_destination_screen.dart' show SelectDestinationScreen, PlaceResult;
import 'pin_marker.dart' show PinType;
import 'searching_offers_screen.dart';

/// ====== شاشة إنشاء طلب "وصل طلباتي" (توصيل طرد/بضاعة) ======
/// بتاخد مكان استلام + مكان تسليم + تفاصيل العناوين + أرقام موبايل
/// المُرسل والمُستلم، وبعدين تحفظ الطلب وتفتح شاشة البحث عن عروض
/// (نفس منطق شاشة الراكب العادية).
class CreateDeliveryOrderScreen extends StatefulWidget {
  final LatLng? initialPickupLocation;
  final String? initialPickupAddress;

  const CreateDeliveryOrderScreen({
    super.key,
    this.initialPickupLocation,
    this.initialPickupAddress,
  });

  @override
  State<CreateDeliveryOrderScreen> createState() =>
      _CreateDeliveryOrderScreenState();
}

class _CreateDeliveryOrderScreenState
    extends State<CreateDeliveryOrderScreen> {
  LatLng? _pickupLocation;
  String? _pickupAddress;
  LatLng? _dropoffLocation;
  String? _dropoffAddress;

  final TextEditingController _pickupDetailsController =
      TextEditingController();
  final TextEditingController _dropoffDetailsController =
      TextEditingController();
  final TextEditingController _senderPhoneController =
      TextEditingController();
  final TextEditingController _receiverPhoneController =
      TextEditingController();

  String _paymentMethod = 'كاش';

  double? _distanceKm;
  int? _durationMin;
  bool _isCalculatingRoute = false;
  bool _isSubmitting = false;

  double get _estimatedFare {
    if (_distanceKm == null) return 0;
    return 10 + (5 * _distanceKm!);
  }

  @override
  void initState() {
    super.initState();
    _pickupLocation = widget.initialPickupLocation;
    _pickupAddress = widget.initialPickupAddress;
    _senderPhoneController.text = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
  }

  @override
  void dispose() {
    _pickupDetailsController.dispose();
    _dropoffDetailsController.dispose();
    _senderPhoneController.dispose();
    _receiverPhoneController.dispose();
    super.dispose();
  }

  Future<void> _selectPickupLocation() async {
    final result = await Navigator.push<PlaceResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectDestinationScreen(
          initialLocation: _pickupLocation ?? _dropoffLocation,
          title: AppLocalizations.of(context)!.selectPickupLocationTitle,
          pinType: PinType.pickup,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _pickupLocation = result.location;
        _pickupAddress = result.title;
      });
      _maybeCalculateRoute();
    }
  }

  Future<void> _selectDropoffLocation() async {
    final result = await Navigator.push<PlaceResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectDestinationScreen(
          initialLocation: _dropoffLocation ?? _pickupLocation,
          title: AppLocalizations.of(context)!.selectDeliveryLocationTitle,
          pinType: PinType.destination,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _dropoffLocation = result.location;
        _dropoffAddress = result.title;
      });
      _maybeCalculateRoute();
    }
  }

  // ====== لو الاتنين (استلام + تسليم) متحددين، بنحسب المسافة/الوقت ======
  Future<void> _maybeCalculateRoute() async {
    if (_pickupLocation == null || _dropoffLocation == null) return;
    setState(() => _isCalculatingRoute = true);

    double distanceKm;
    int durationMin;
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${_pickupLocation!.longitude},${_pickupLocation!.latitude};'
        '${_dropoffLocation!.longitude},${_dropoffLocation!.latitude}'
        '?overview=false',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes[0];
          distanceKm = (route['distance'] as num).toDouble() / 1000;
          durationMin = ((route['duration'] as num).toDouble() / 60).ceil();
        } else {
          throw Exception('مفيش مسار متاح');
        }
      } else {
        throw Exception('فشل الاتصال بسيرفر المسارات');
      }
    } catch (e) {
      debugPrint('❌ خطأ في جلب المسار، هنستخدم خط مستقيم: $e');
      final fallbackDistanceKm = const Distance().as(
        LengthUnit.Kilometer,
        _pickupLocation!,
        _dropoffLocation!,
      );
      distanceKm = fallbackDistanceKm;
      durationMin = (fallbackDistanceKm / 30 * 60).ceil();
    }

    if (!mounted) return;
    setState(() {
      _distanceKm = distanceKm;
      _durationMin = durationMin;
      _isCalculatingRoute = false;
    });
  }

  Future<void> _showPaymentMethodSheet() async {
    final loc = AppLocalizations.of(context)!;
    final options = <Map<String, dynamic>>[
      {'value': 'كاش', 'icon': Icons.payments_outlined},
      {
        'value': 'محفظة إلكترونية',
        'icon': Icons.account_balance_wallet_outlined,
      },
      {'value': 'إنستاباي', 'icon': Icons.bolt_outlined},
    ];

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    loc.choosePaymentMethodTitle,
                    style:  TextStyle(
                      color: context.textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...options.map((option) {
                final value = option['value'] as String;
                final label = paymentMethodDisplay(sheetContext, value);
                final isSelected = value == _paymentMethod;
                return ListTile(
                  onTap: () => Navigator.pop(sheetContext, value),
                  leading: Icon(
                    option['icon'] as IconData,
                    color: isSelected
                        ? TayarColors.primary
                        : context.textGreyColor,
                  ),
                  title: Text(
                    label,
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_circle,
                          color: TayarColors.primary,
                        )
                      : null,
                );
              }),
            ],
          ),
        ),
      ),
    );

    if (selected != null) {
      setState(() => _paymentMethod = selected);
    }
  }

  bool get _canSubmit =>
      _pickupLocation != null &&
      _dropoffLocation != null &&
      _senderPhoneController.text.trim().isNotEmpty &&
      _receiverPhoneController.text.trim().isNotEmpty &&
      !_isSubmitting &&
      !_isCalculatingRoute;

  Future<void> _saveOrder() async {
    final loc = AppLocalizations.of(context)!;
    if (!_canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.fillAllFieldsError)),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;

      final pickupGeoFirePoint = GeoFirePoint(
        GeoPoint(_pickupLocation!.latitude, _pickupLocation!.longitude),
      );
      final dropoffGeoFirePoint = GeoFirePoint(
        GeoPoint(_dropoffLocation!.latitude, _dropoffLocation!.longitude),
      );

      final fare = _estimatedFare;

      final orderRef = await FirebaseFirestore.instance.collection('orders').add({
        'customerId': user?.uid,
        'customerName': user?.displayName ?? loc.defaultCustomerName,
        'customerPhone': user?.phoneNumber,
        'pickupAddress': _pickupAddress ?? '',
        'pickupLocation': pickupGeoFirePoint.data,
        'pickupAddressDetails': _pickupDetailsController.text.trim(),
        'destinationAddress': _dropoffAddress ?? '',
        'destinationLocation': dropoffGeoFirePoint.data,
        'deliveryAddressDetails': _dropoffDetailsController.text.trim(),
        'senderPhone': _senderPhoneController.text.trim(),
        'receiverPhone': _receiverPhoneController.text.trim(),
        'distanceKm': _distanceKm ?? 0,
        'durationMin': _durationMin ?? 0,
        'suggestedFare': fare,
        'proposedFare': fare,
        'autoAccept': false,
        'paymentMethod': _paymentMethod,
        'serviceType': 'delivery',
        'status': 'searching',
        'driverId': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SearchingOffersScreen(
            orderId: orderRef.id,
            proposedFare: fare,
            autoAccept: false,
            pickupAddress: _pickupAddress ?? '',
            pickupLocation: _pickupLocation!,
            destinationAddress: _dropoffAddress ?? '',
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ خطأ في حفظ طلب التوصيل: $e');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.submitFailedError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        leading: IconButton(
          icon:  Icon(Icons.arrow_forward, color: context.textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.deliveryOrderTitle,
          style:  TextStyle(color: context.textColor),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ====== كارت المسار: استلام + تسليم ======
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _LocationPickRow(
                    icon: Icons.location_on,
                    iconColor: TayarColors.primary,
                    label: loc.pickupLocationLabel,
                    address: _pickupAddress,
                    onTap: _selectPickupLocation,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const SizedBox(width: 10),
                        Container(width: 2, height: 24, color: context.dividerColor2),
                      ],
                    ),
                  ),
                  _LocationPickRow(
                    icon: Icons.flag,
                    iconColor: TayarColors.primary,
                    label: loc.deliveryLocationLabel,
                    address: _dropoffAddress,
                    onTap: _selectDropoffLocation,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ====== تفاصيل عنوان الاستلام ======
            _LabeledTextField(
              label: loc.pickupAddressDetailsLabel,
              hint: loc.pickupAddressDetailsHint,
              controller: _pickupDetailsController,
            ),
            const SizedBox(height: 12),

            // ====== تفاصيل عنوان التسليم ======
            _LabeledTextField(
              label: loc.deliveryAddressDetailsLabel,
              hint: loc.deliveryAddressDetailsHint,
              controller: _dropoffDetailsController,
            ),
            const SizedBox(height: 12),

            // ====== رقم موبايل المُرسل ======
            _LabeledTextField(
              label: loc.senderPhoneLabel,
              hint: loc.phoneNumberHint,
              controller: _senderPhoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // ====== رقم موبايل المُستلم ======
            _LabeledTextField(
              label: loc.receiverPhoneLabel,
              hint: loc.phoneNumberHint,
              controller: _receiverPhoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // ====== طريقة الدفع ======
            InkWell(
              onTap: _showPaymentMethodSheet,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      color: TayarColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        loc.paymentMethodLabel,
                        style:  TextStyle(
                          color: context.textGreyColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      paymentMethodDisplay(context, _paymentMethod),
                      style:  TextStyle(
                        color: context.textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                     Icon(
                      Icons.chevron_left,
                      color: context.textGreyColor,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ====== كارت المسافة/الوقت/السعر (بيظهر بعد ما نحدد الموقعين) ======
            if (_isCalculatingRoute)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: CircularProgressIndicator(color: TayarColors.primary),
                ),
              )
            else if (_distanceKm != null)
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          loc.distanceLabel,
                          style:  TextStyle(
                            color: context.textGreyColor,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          loc.distanceKmLabel(_distanceKm!.toStringAsFixed(1)),
                          style:  TextStyle(
                            color: context.textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                     Divider(color: context.dividerColor2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          loc.estimatedFareLabel,
                          style:  TextStyle(
                            color: context.textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          loc.currencyEGP(_estimatedFare.toStringAsFixed(0)),
                          style: const TextStyle(
                            color: TayarColors.primary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // ====== زرار حفظ الطلب ======
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _canSubmit ? _saveOrder : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TayarColors.primary,
                  disabledBackgroundColor: TayarColors.primary.withValues(
                    alpha: 0.4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmitting
                    ?  SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: context.textColor,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        loc.saveOrderButton,
                        style:  TextStyle(
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

// ====== صف اختيار موقع (استلام/تسليم) - بيتحول لزرار قابل للضغط ======
class _LocationPickRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? address;
  final VoidCallback onTap;

  const _LocationPickRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.address,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Row(
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
                  style:  TextStyle(
                    color: context.textGreyColor,
                    fontSize: 12,
                  ),
                ),
                Text(
                  address ?? loc.tapToSelectLocationLabel,
                  style: TextStyle(
                    color: address != null ? context.textColor : context.textGreyColor,
                    fontSize: 15,
                    fontWeight: address != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
           Icon(Icons.chevron_left, color: context.textGreyColor, size: 20),
        ],
      ),
    );
  }
}

// ====== خانة نص بعنوان فوقها (تفاصيل عنوان / رقم موبايل) ======
class _LabeledTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const _LabeledTextField({
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              label,
              style:  TextStyle(color: context.textGreyColor, fontSize: 12),
            ),
          ),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            style:  TextStyle(color: context.textColor, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:  TextStyle(color: context.textGreyColor),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}