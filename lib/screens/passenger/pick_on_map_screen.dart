import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart' show TayarColors, TayarThemeColors;
import 'package:tayay_app/screens/passenger/select_destination_screen.dart' show PlaceResult;
import 'package:tayay_app/widgets/pin_marker.dart';
import 'package:tayay_app/widgets/map_tile_layer.dart';

/// ====== شاشة اختيار الوجهة من الخريطة ======
/// خريطة كاملة الشاشة فيها دبوس ثابت في النص، المستخدم بيحرك الخريطة لحد
/// ما الدبوس يوصل للمكان اللي عايزه، وبعدين يدوس "تم" فترجع الشاشة دي
/// PlaceResult زي بالظبط نتيجة البحث العادية.
class PickOnMapScreen extends StatefulWidget {
  // نقطة البداية اللي الخريطة تتمركز عليها لما الشاشة تفتح (مثلاً نقطة
  // الانطلاق الحالية)، ولو مفيش هنستخدم مركز مدينة العاشر من رمضان.
  final LatLng? initialLocation;

  // نوع الدبوس المعروض: انطلاق أو وجهة (بيحدد شكل الأيقونة جوه المربع)
  final PinType pinType;

  const PickOnMapScreen({
    super.key,
    this.initialLocation,
    this.pinType = PinType.destination,
  });

  @override
  State<PickOnMapScreen> createState() => _PickOnMapScreenState();
}

class _PickOnMapScreenState extends State<PickOnMapScreen> {
  final MapController _mapController = MapController();
  Timer? _debounce;

  static const LatLng _defaultCenter = LatLng(30.296, 31.742);

  late LatLng _selectedLocation = widget.initialLocation ?? _defaultCenter;

  String _addressTitle = '';
  String _addressSubtitle = '';
  bool _isLoadingAddress = true;

  AppLocalizations? _l10n;
  bool _initialFetchDone = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _l10n = AppLocalizations.of(context)!;
    if (!_initialFetchDone) {
      _initialFetchDone = true;
      _addressTitle = _l10n!.determiningAddressLabel;
      _getAddressFromCoordinates(
        _selectedLocation.latitude,
        _selectedLocation.longitude,
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // ====== بترجع الإحداثية الحقيقية اللي فعليًا تحت الدبوس في نص الشاشة ======
  LatLng _pinRealLocation(MapCamera camera) {
    final size = camera.nonRotatedSize;
    final pinOffset = Offset(size.width / 2, size.height / 2);
    return camera.offsetToCrs(pinOffset);
  }

  void _onMapEvent(MapEvent event) {
    if (event.source != MapEventSource.onDrag &&
        event.source != MapEventSource.flingAnimationController) {
      return;
    }

    setState(() {
      _selectedLocation = _pinRealLocation(event.camera);
      _isLoadingAddress = true;
      _addressTitle = _l10n!.determiningAddressLabel;
      _addressSubtitle = '';
    });

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _getAddressFromCoordinates(
        _selectedLocation.latitude,
        _selectedLocation.longitude,
      );
    });
  }

  Future<void> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final languageCode = Localizations.localeOf(context).languageCode;
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&accept-language=$languageCode',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'com.tayar.app'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        final road = (address?['road'] ?? address?['neighbourhood'] ?? '')
            .toString();
        final suburb = (address?['suburb'] ?? address?['city'] ?? '')
            .toString();

        if (!mounted) return;
        setState(() {
          _addressTitle = road.isNotEmpty ? road : _l10n!.customLocationLabel;
          _addressSubtitle = suburb;
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      debugPrint('❌ خطأ في جلب اسم العنوان: $e');
      if (!mounted) return;
      setState(() {
        _addressTitle = _l10n!.addressFetchFailed;
        _addressSubtitle = '';
        _isLoadingAddress = false;
      });
    }
  }

  void _confirmSelection() {
    Navigator.pop(
      context,
      PlaceResult(
        title: _addressTitle,
        subtitle: _addressSubtitle,
        location: _selectedLocation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: Stack(
        children: [
          // ====== الخريطة ======
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 16,
              // نفس ملحوظة minZoom في passenger_home.dart: بيمنع تكرار الخريطة
              minZoom: 4,
              onMapEvent: _onMapEvent,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              const TayarTileLayer(),
            ],
          ),

          // ====== الدبوس الثابت في نص الشاشة ======
          // نفس تقنية الـ FractionalTranslation المستخدمة في passenger_home
          // عشان طرف الدبوس (النقطة السفلية) يفضل بالظبط عند نقطة المركز
          // اللي بتحسبها _pinRealLocation، مهما اتغير طول العنوان.
          Center(
            child: FractionalTranslation(
              translation: const Offset(0, -0.5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: context.bgColor,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: TayarColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _addressTitle,
                                style:  TextStyle(
                                  color: context.textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_addressSubtitle.isNotEmpty)
                                Text(
                                  _addressSubtitle,
                                  style:  TextStyle(
                                    color: context.textGreyColor,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  PinMarker(type: widget.pinType),
                  Container(width: 2, height: 14, color: Colors.white54),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.textColor, width: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ====== زرار الرجوع: على الشمال دايمًا زي كل شاشات التطبيق ======
          Positioned(
            top: 50,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: context.bgColor.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(Icons.arrow_back, color: context.textColor),
              ),
            ),
          ),

          // ====== زرار "تم" تحت ======
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: ElevatedButton(
                onPressed: _isLoadingAddress ? null : _confirmSelection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TayarColors.primary,
                  disabledBackgroundColor: TayarColors.primary.withValues(
                    alpha: 0.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.doneButton,
                  style:  TextStyle(
                    color: context.textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}