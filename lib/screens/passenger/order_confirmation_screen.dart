import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart'
    show TayarColors, TayarThemeColors, paymentMethodDisplay, BackArrowIcon;
import 'package:tayay_app/screens/passenger/searching_offers/searching_offers_screen_screen.dart';
import 'package:tayay_app/screens/passenger/select_destination_screen.dart'
    show SelectDestinationScreen, PlaceResult;
import 'package:tayay_app/services/fare_negotiation_rules.dart';
import 'package:tayay_app/services/wallet_service.dart';
import 'package:tayay_app/theme/app_settings.dart';
import 'package:tayay_app/widgets/pin_marker.dart' show PinType;

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

  // ====== نفس مشروع/مفتاح Supabase المستخدم في sos_service.dart بالظبط -
  // مفتاح anon عام آمن يتضاف في كود العميل (client-side)، مش سري. ======
  static const String _supabaseAnonKey =
      'sb_publishable_ltwC2X3e-F6nkAiPxszdlQ_x7xTNUC3';

  // ====== نقطتا الانطلاق والوجهة بقيوا قابلين للتعديل من نفس الشاشة (بالضغط
  // على أي منهم)، فبقيوا حالة محلية بدل ما يفضلوا ثابتين من اللي وصل من
  // الشاشة اللي فاتت. بنبدأهم بالقيم اللي وصلت من الـ widget ======
  late String _pickupAddress;
  late LatLng _pickupLocation;
  late String _destinationAddress;
  late LatLng _destinationLocation;
  late double _distanceKm;
  late int _durationMin;

  // ====== السعر المقترح تلقائيًا (المعروض كـ "السعر الأساسي") - بيتغير هو
  // كمان لو الراكب عدّل نقطة الانطلاق أو الوجهة ======
  late double _baseFare;

  // ====== حجز رحلة مقدمًا (Scheduled rides): null يعني رحلة فورية زي ما
  // كان دايمًا. لو الراكب اختار "حجز لاحقًا" بنحفظ الميعاد هنا ونبعته لـ
  // createOrder كـ scheduledFor. المطابقة نفسها بتشتغل فورًا في الحالتين
  // (شوف تعليق orderType في supabase/functions/create-order) - الميعاد ده بس بيتسجل
  // كمعلومة للسائق وبيتعرض في شاشة البحث عن عروض ======
  DateTime? _scheduledFor;

  // ====== true وقت إعادة حساب المسار والسعر بعد تعديل نقطة الانطلاق أو
  // الوجهة (بنعطل التعديل والزرار الرئيسي لحد ما يخلص) ======
  bool _isUpdatingRoute = false;

  // ====== السعر المقترح من الراكب (قابل للتعديل) ======
  late double _proposedFare;
  static const double _step = 5.0; // مقدار الزيادة/النقصان لكل ضغطة

  // ====== نفس حدود المزايدة المطبّقة بعد كده في searching_offers_screen.dart
  // و offer_sheet.dart (0.5x - 1.5x من السعر الأساسي)، عشان الراكب مايقدرش
  // يرفع السعر هنا فوق السقف اللي هيتفرض عليه بعد كده في شاشة البحث عن عروض ======
  late double _minFare; // أقل سعر مسموح بيه
  late double _maxFare; // أعلى سعر مسموح بيه (قبل حد المحفظة لو موجود)

  // ====== لما الدفع يكون محفظة إلكترونية: أعلى سعر مسموح بيه هو رصيد
  // المحفظة الفعلي (بنجيبه من السيرفر عشان محدش يتلاعب بيه من الشاشة
  // اللي فاتت)، عشان الراكب مايقدرش يقترح سعر أكبر من اللي معاه فعلاً ======
  double? _walletMaxFare;

  // ====== خانة القبول التلقائي ======
  bool _autoAccept = false;

  @override
  void initState() {
    super.initState();
    _pickupAddress = widget.pickupAddress;
    _pickupLocation = widget.pickupLocation;
    _destinationAddress = widget.destinationAddress;
    _destinationLocation = widget.destinationLocation;
    _distanceKm = widget.distanceKm;
    _durationMin = widget.durationMin;
    _baseFare = widget.fare;
    _proposedFare = widget.fare;
    _minFare = FareNegotiationRules.minFareFor(widget.fare);
    _maxFare = FareNegotiationRules.maxFareFor(widget.fare);
    if (widget.paymentMethod == kWalletPaymentMethodValue) {
      _loadWalletCap();
    }
  }

  // ====== فتح شاشة اختيار مكان جديد (استلام أو وجهة) ======
  Future<void> _editPickup() async {
    if (_isUpdatingRoute) return;
    final result = await Navigator.push<PlaceResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectDestinationScreen(
          initialLocation: _pickupLocation,
          title: AppLocalizations.of(context)!.editPickupLocationTitle,
          pinType: PinType.pickup,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _pickupAddress = result.title;
      _pickupLocation = result.location;
    });
    await _recalculateRouteAndFare();
  }

  Future<void> _editDestination() async {
    if (_isUpdatingRoute) return;
    final result = await Navigator.push<PlaceResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectDestinationScreen(
          initialLocation: _destinationLocation,
          title: AppLocalizations.of(context)!.editDestinationTitle,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _destinationAddress = result.title;
      _destinationLocation = result.location;
    });
    await _recalculateRouteAndFare();
  }

  // ====== إعادة حساب المسافة والمدة والسعر بعد تغيير نقطة الانطلاق أو
  // الوجهة، بنفس منطق _fetchRoute في passenger_home.dart (OSRM مع خط مستقيم
  // بديل لو فشل الاتصال) ======
  Future<void> _recalculateRouteAndFare() async {
    setState(() => _isUpdatingRoute = true);

    double distanceKm;
    int durationMin;
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${_pickupLocation.longitude},${_pickupLocation.latitude};'
        '${_destinationLocation.longitude},${_destinationLocation.latitude}'
        '?overview=false',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) {
        throw Exception('فشل الاتصال بسيرفر المسارات');
      }
      final data = json.decode(response.body);
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) throw Exception('مفيش مسار متاح');
      final route = routes[0];
      distanceKm = (route['distance'] as num).toDouble() / 1000;
      durationMin = ((route['duration'] as num).toDouble() / 60).ceil();
    } catch (e) {
      debugPrint('❌ خطأ في إعادة حساب المسار: $e');
      final fallbackDistanceKm = const Distance().as(
        LengthUnit.Kilometer,
        _pickupLocation,
        _destinationLocation,
      );
      distanceKm = fallbackDistanceKm;
      durationMin = (fallbackDistanceKm / 30 * 60).ceil();
    }

    if (!mounted) return;
    final newFare = AppSettings.instance.estimateFare(distanceKm);
    setState(() {
      _distanceKm = distanceKm;
      _durationMin = durationMin;
      _baseFare = newFare;
      _proposedFare = newFare;
      _minFare = FareNegotiationRules.minFareFor(newFare);
      _maxFare = FareNegotiationRules.maxFareFor(newFare);
      if (_walletMaxFare != null && _proposedFare > _walletMaxFare!) {
        _proposedFare = _walletMaxFare!;
      }
      _isUpdatingRoute = false;
    });
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

  // ====== فتح تاريخ ثم وقت لاختيار معاد الرحلة المجدولة. الحدود
  // (10 دقايق كحد أدنى، AppSettings.instance.maxScheduleAdvanceDays كحد
  // أقصى) لازم تفضل مطابقة نفس الحدود اللي بيتحقق منها create-order في
  // supabase/functions/create-order وإلا السيرفر هيرفض الطلب حتى لو الواجهة سمحت بيه ======
  Future<void> _pickScheduleDateTime() async {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final minDateTime = now.add(const Duration(minutes: 10));
    final maxDateTime = now.add(
      Duration(days: AppSettings.instance.maxScheduleAdvanceDays),
    );

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledFor != null && _scheduledFor!.isAfter(minDateTime)
          ? _scheduledFor!
          : minDateTime,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: maxDateTime,
    );
    if (pickedDate == null || !mounted) return;

    final initialTime = _scheduledFor != null
        ? TimeOfDay.fromDateTime(_scheduledFor!)
        : TimeOfDay.fromDateTime(minDateTime);
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (combined.isBefore(minDateTime)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.scheduleMinLeadError)));
      return;
    }
    if (combined.isAfter(maxDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.scheduleMaxAdvanceError(
              AppSettings.instance.maxScheduleAdvanceDays,
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _scheduledFor = combined);
  }

  String _formatScheduledFor(DateTime dt) {
    return '${_twoDigits(dt.day)}/${_twoDigits(dt.month)} - '
        '${_twoDigits(dt.hour)}:${_twoDigits(dt.minute)}';
  }

  Future<void> _searchForOffers() async {
    setState(() => _isSubmitting = true);

    try {
      // ====== إنشاء الطلب بالكامل بيحصل دلوقتي على السيرفر - مش عن طريق
      // Firebase Cloud Functions (محتاجة خطة Blaze)، لكن عن طريق Supabase
      // Edge Function اسمها create-order (بديل، مجاني بالكامل - نفس فكرة
      // sos_service.dart بالظبط). السيرفر هو اللي بيحسب المسافة والسعر
      // المقترح الحقيقيين من إحداثيات نقطة الانطلاق والوجهة بس، وبيتأكد إن
      // السعر اللي الراكب حدده (proposedFare) منطقي قبل ما يكتب أي حاجة في
      // Firestore - عشان محدش يقدر يتلاعب بالمسافة أو السعر عن طريق تعديل
      // الموبايل نفسه. اسم ورقم الراكب كمان بيتجابوا من السيرفر مباشرة.
      // الكتابة في Firestore بتتم بصلاحيات Service Account (بديل Admin
      // SDK)، فمينفعش حد يعمل نفس الحاجة مباشرة من الموبايل. ======
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) {
        throw StateError('لازم تسجل الدخول الأول عشان تطلب رحلة');
      }

      final response = await http
          .post(
            Uri.parse(
              'https://pctxhemhytzaufdzuhfz.supabase.co/functions/v1/create-order',
            ),
            headers: {
              'apikey': _supabaseAnonKey,
              'Authorization': 'Bearer $_supabaseAnonKey',
              'X-Firebase-Id-Token': idToken,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'pickupAddress': _pickupAddress,
              'pickupLat': _pickupLocation.latitude,
              'pickupLng': _pickupLocation.longitude,
              'destinationAddress': _destinationAddress,
              'destinationLat': _destinationLocation.latitude,
              'destinationLng': _destinationLocation.longitude,
              'proposedFare': _proposedFare,
              'autoAccept': _autoAccept,
              'paymentMethod': widget.paymentMethod,
              if (_scheduledFor != null)
                'scheduledFor': _scheduledFor!.millisecondsSinceEpoch,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        // ====== رسالة السيرفر بتوصل هنا لو السعر غير منطقي مثلًا ======
        final errorMessage = responseData['error'] as String?;
        debugPrint(
          '❌ خطأ من create-order: ${response.statusCode} - $errorMessage',
        );
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage ?? AppLocalizations.of(context)!.submitFailedError,
            ),
          ),
        );
        return;
      }

      final orderId = responseData['orderId'] as String;

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
            pickupAddress: _pickupAddress,
            pickupLocation: _pickupLocation,
            destinationAddress: _destinationAddress,
            scheduledFor: _scheduledFor,
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
          icon: const BackArrowIcon(),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.setYourFareTitle,
          style: TextStyle(color: context.textColor),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ====== كارت المسار: من - إلى (كل صف قابل للضغط لتغييره) ======
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
                    address: _pickupAddress,
                    onTap: _editPickup,
                    isLoading: _isUpdatingRoute,
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
                    address: _destinationAddress,
                    onTap: _editDestination,
                    isLoading: _isUpdatingRoute,
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
                    value: l10n.distanceKmLabel(_distanceKm.toStringAsFixed(1)),
                  ),
                  Divider(color: context.dividerColor2),
                  _DetailRow(
                    label: l10n.estimatedTimeLabel,
                    value: l10n.durationMinLabel(_durationMin),
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
                        onTap:
                            !_isUpdatingRoute &&
                                _proposedFare - _step >= _minFare
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
                            _isUpdatingRoute ||
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
                    l10n.autoSuggestedFareLabel(_baseFare.toStringAsFixed(0)),
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

            const SizedBox(height: 16),

            // ====== كارت معاد الرحلة: دلوقتي / حجز لاحقًا ======
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.rideTimingSectionTitle,
                    style: TextStyle(color: context.textColor, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _TimingOptionChip(
                          label: l10n.rideTimingNowOption,
                          selected: _scheduledFor == null,
                          onTap: () => setState(() => _scheduledFor = null),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TimingOptionChip(
                          label: l10n.rideTimingScheduledOption,
                          selected: _scheduledFor != null,
                          onTap: _pickScheduleDateTime,
                        ),
                      ),
                    ],
                  ),
                  if (_scheduledFor != null) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _pickScheduleDateTime,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 18,
                              color: TayarColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.scheduledForLabel(
                                  _formatScheduledFor(_scheduledFor!),
                                ),
                                style: TextStyle(
                                  color: context.textColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.edit,
                              size: 16,
                              color: context.textGreyColor,
                            ),
                          ],
                        ),
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
                      checkColor: Colors.white,
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
                onPressed: (_isSubmitting || _isUpdatingRoute)
                    ? null
                    : _searchForOffers,
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
  final VoidCallback? onTap;
  final bool isLoading;

  const _RouteRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.address,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
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
                    style: TextStyle(
                      color: context.textGreyColor,
                      fontSize: 12,
                    ),
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
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: TayarColors.primary,
                ),
              )
            else if (onTap != null)
              Icon(Icons.edit, size: 16, color: context.textGreyColor),
          ],
        ),
      ),
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

// ====== شريحة اختيار "دلوقتي" / "حجز لاحقًا" في كارت معاد الرحلة ======
class _TimingOptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TimingOptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? TayarColors.primary : context.bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? TayarColors.primary : context.dividerColor2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? context.onPrimaryColor : context.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

String _twoDigits(int n) => n.toString().padLeft(2, '0');
