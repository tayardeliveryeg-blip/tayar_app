import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';

import 'package:tayay_app/screens/passenger/passenger_home.dart'
    show TayarColors, TayarThemeColors, paymentMethodDisplay;
import 'package:tayay_app/screens/passenger/select_destination_screen.dart'
    show SelectDestinationScreen, PlaceResult;
import 'package:tayay_app/widgets/pin_marker.dart' show PinType;
import 'package:tayay_app/widgets/tayar_toast.dart';
import 'package:tayay_app/screens/passenger/searching_offers/searching_offers_screen_screen.dart';
import 'package:tayay_app/theme/app_settings.dart';
import 'package:tayay_app/screens/passenger/create_delivery_order_widgets/location_pick_row.dart';
import 'package:tayay_app/screens/passenger/create_delivery_order_widgets/labeled_text_field.dart';
import 'package:tayay_app/screens/passenger/create_delivery_order_widgets/route_summary_card.dart';
import 'package:tayay_app/screens/passenger/create_delivery_order_widgets/payment_method_sheet.dart';
import 'package:tayay_app/widgets/app_card.dart';
import 'package:tayay_app/widgets/app_primary_button.dart';
import 'package:tayay_app/utils/tayar_page_route.dart';

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

class _CreateDeliveryOrderScreenState extends State<CreateDeliveryOrderScreen> {
  LatLng? _pickupLocation;
  String? _pickupAddress;
  LatLng? _dropoffLocation;
  String? _dropoffAddress;

  final TextEditingController _pickupDetailsController =
      TextEditingController();
  final TextEditingController _dropoffDetailsController =
      TextEditingController();
  final TextEditingController _senderPhoneController = TextEditingController();
  final TextEditingController _receiverPhoneController =
      TextEditingController();

  String _paymentMethod = 'كاش';

  double? _distanceKm;
  int? _durationMin;
  bool _isCalculatingRoute = false;
  bool _isSubmitting = false;

  double get _estimatedFare {
    if (_distanceKm == null) return 0;
    return AppSettings.instance.estimateFare(_distanceKm!);
  }

  @override
  void initState() {
    super.initState();
    _pickupLocation = widget.initialPickupLocation;
    _pickupAddress = widget.initialPickupAddress;
    _senderPhoneController.text =
        FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
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
      TayarPageRoute(
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
      TayarPageRoute(
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
    final selected = await showDeliveryPaymentMethodSheet(
      context,
      currentMethod: _paymentMethod,
      estimatedFare: _estimatedFare,
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
      TayarToast.show(context, loc.fillAllFieldsError, type: ToastType.warning);
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

      final orderRef = await FirebaseFirestore.instance.collection('orders').add(
        {
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
          // ====== ثابتة من لحظة إنشاء الطلب ومتتغيرش تاني، عكس proposedFare
          // اللي بتتحدث كل مرة أي طرف يغيّر السعر. دي المرجع اللي بيتحسب
          // عليه حد أقصى/أدنى المفاوضة (شوف fare_negotiation_rules.dart) ======
          'initialFare': fare,
          'autoAccept': false,
          'paymentMethod': _paymentMethod,
          'serviceType': 'delivery',
          'status': 'searching',
          'driverId': null,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      Navigator.pushReplacement(
        context,
        TayarPageRoute(
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
      TayarToast.show(context, loc.submitFailedError, type: ToastType.error);
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
        title: Text(
          loc.deliveryOrderTitle,
          style: TextStyle(color: context.textColor),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ====== كارت المسار: استلام + تسليم ======
            AppCard(
              padding: const EdgeInsets.all(16),
              radius: 16,
              child: Column(
                children: [
                  LocationPickRow(
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
                        Container(
                          width: 2,
                          height: 24,
                          color: context.dividerColor2,
                        ),
                      ],
                    ),
                  ),
                  LocationPickRow(
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
            LabeledTextField(
              label: loc.pickupAddressDetailsLabel,
              hint: loc.pickupAddressDetailsHint,
              controller: _pickupDetailsController,
            ),
            const SizedBox(height: 12),

            // ====== تفاصيل عنوان التسليم ======
            LabeledTextField(
              label: loc.deliveryAddressDetailsLabel,
              hint: loc.deliveryAddressDetailsHint,
              controller: _dropoffDetailsController,
            ),
            const SizedBox(height: 12),

            // ====== رقم موبايل المُرسل ======
            LabeledTextField(
              label: loc.senderPhoneLabel,
              hint: loc.phoneNumberHint,
              controller: _senderPhoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // ====== رقم موبايل المُستلم ======
            LabeledTextField(
              label: loc.receiverPhoneLabel,
              hint: loc.phoneNumberHint,
              controller: _receiverPhoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // ====== طريقة الدفع ======
            AppCard(
              onTap: _showPaymentMethodSheet,
              padding: const EdgeInsets.all(16),
              radius: 16,
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
                      style: TextStyle(
                        color: context.textGreyColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    paymentMethodDisplay(context, _paymentMethod),
                    style: TextStyle(
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
            const SizedBox(height: 16),

            // ====== كارت المسافة/الوقت/السعر (بيظهر بعد ما نحدد الموقعين) ======
            RouteSummaryCard(
              isCalculating: _isCalculatingRoute,
              distanceKm: _distanceKm,
              estimatedFare: _estimatedFare,
            ),
            const SizedBox(height: 20),

            // ====== زرار حفظ الطلب ======
            SizedBox(
              height: 54,
              child: AppPrimaryButton(
                onPressed: _canSubmit ? _saveOrder : null,
                isLoading: _isSubmitting,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TayarColors.primary,
                  disabledBackgroundColor: TayarColors.primary.withValues(
                    alpha: 0.4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  loc.saveOrderButton,
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
