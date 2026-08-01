import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tayay_app/screens/passenger/passenger_home.dart' show TayarColors, TayarThemeColors;
import 'package:tayay_app/screens/passenger/pick_on_map_screen.dart' show PickOnMapScreen;
import 'package:tayay_app/widgets/pin_marker.dart' show PinType;
import 'package:tayay_app/l10n/generated/app_localizations.dart';

/// نتيجة بحث واحدة (مكان مقترح)
class PlaceResult {
  final String title; // اسم المكان الأساسي (شارع/معلم)
  final String subtitle; // تفاصيل إضافية (حي/مدينة)
  final LatLng location;

  PlaceResult({
    required this.title,
    required this.subtitle,
    required this.location,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'subtitle': subtitle,
    'lat': location.latitude,
    'lon': location.longitude,
  };

  factory PlaceResult.fromJson(Map<String, dynamic> json) => PlaceResult(
    title: json['title'] as String,
    subtitle: json['subtitle'] as String,
    location: LatLng(
      (json['lat'] as num).toDouble(),
      (json['lon'] as num).toDouble(),
    ),
  );
}

/// شاشة اختيار الوجهة - بيرجع PlaceResult لما المستخدم يختار مكان
class SelectDestinationScreen extends StatefulWidget {
  // نقطة الانطلاق الحالية (لو موجودة)، بنستخدمها كمركز بداية لشاشة "اختار
  // من الخريطة" عشان المستخدم يبدأ من حوالين نفسه بدل مركز المدينة الثابت.
  final LatLng? initialLocation;

  // عنوان مخصص للشاشة (اختياري) - لو فاضي بيستخدم النص الافتراضي
  // "عايز تروح فين؟"، ولو محدد (زي حالة اختيار مكان تسليم طلب توصيل)
  // بيظهر بدله.
  final String? title;

  // نوع الدبوس المعروض في شاشة "اختار من الخريطة": انطلاق أو وجهة
  final PinType pinType;

  const SelectDestinationScreen({
    super.key,
    this.initialLocation,
    this.title,
    this.pinType = PinType.destination,
  });

  @override
  State<SelectDestinationScreen> createState() =>
      _SelectDestinationScreenState();
}

class _SelectDestinationScreenState extends State<SelectDestinationScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<PlaceResult> _results = [];
  List<PlaceResult> _recentSearches = [];
  bool _isLoading = false;
  String? _error;

  static const String _prefsKey = 'tayar_recent_searches';
  static const int _maxRecentItems = 8;

  // مركز منطقة العاشر من رمضان تقريبًا - بنستخدمه عشان نرجّح نتائج البحث القريبة
  static const double _biasLat = 30.296;
  static const double _biasLon = 31.742;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ====== تحميل سجل البحث المحفوظ على الجهاز ======
  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKey) ?? [];
      final places = raw
          .map((s) {
            try {
              return PlaceResult.fromJson(
                json.decode(s) as Map<String, dynamic>,
              );
            } catch (_) {
              return null;
            }
          })
          .whereType<PlaceResult>()
          .toList();
      if (!mounted) return;
      setState(() => _recentSearches = places);
    } catch (e) {
      debugPrint('❌ خطأ في تحميل سجل البحث: $e');
    }
  }

  // ====== حفظ مكان جديد في سجل البحث (أحدث حاجة فوق، بدون تكرار) ======
  Future<void> _saveRecentSearch(PlaceResult place) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updated = [
        place,
        ..._recentSearches.where(
          (p) => p.title != place.title || p.subtitle != place.subtitle,
        ),
      ].take(_maxRecentItems).toList();

      await prefs.setStringList(
        _prefsKey,
        updated.map((p) => json.encode(p.toJson())).toList(),
      );
      if (!mounted) return;
      setState(() => _recentSearches = updated);
    } catch (e) {
      debugPrint('❌ خطأ في حفظ سجل البحث: $e');
    }
  }

  // ====== لما المستخدم يختار مكان (سواء من نتايج البحث أو من السجل) ======
  void _selectPlace(PlaceResult place) {
    _saveRecentSearch(place);
    Navigator.pop(context, place);
  }

  // ====== فتح شاشة اختيار الوجهة من الخريطة ======
  Future<void> _openPickOnMap() async {
    final result = await Navigator.push<PlaceResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PickOnMapScreen(
          initialLocation: widget.initialLocation,
          pinType: widget.pinType,
        ),
      ),
    );
    if (result != null) {
      _selectPlace(result);
    }
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }
    setState(() => _isLoading = true);
    _debounce = Timer(
      const Duration(milliseconds: 450),
      () => _search(query.trim()),
    );
  }

  Future<void> _search(String query) async {
    try {
      // بندور في المصدرين مع بعض في نفس الوقت (مش واحد بديل التاني)
      // عشان لو مكان معين موجود في مصدر وناقص من التاني، يفضل يظهر
      final results = await Future.wait([
        _searchPhoton(query),
        _searchNominatim(query),
      ]);

      final photonResults = results[0];
      final nominatimResults = results[1];

      // دمج النتائج مع إزالة التكرار (حسب تقارب الاسم + الموقع)
      final merged = <PlaceResult>[...photonResults];
      for (final candidate in nominatimResults) {
        final isDuplicate = merged.any(
          (existing) =>
              existing.title.trim() == candidate.title.trim() &&
              (existing.location.latitude - candidate.location.latitude).abs() <
                  0.002 &&
              (existing.location.longitude - candidate.location.longitude)
                      .abs() <
                  0.002,
        );
        if (!isDuplicate) merged.add(candidate);
      }

      // نفضّل النتائج اللي جوه حدود مدينة العاشر من رمضان، ولو مفيش نتيجة جواها
      // خالص، نرجع نعرض كل النتائج (عشان مننزلش عدد النتائج لصفر لغير سبب)
      final insideCity = merged
          .where(
            (p) =>
                p.location.latitude <= 30.38 &&
                p.location.latitude >= 30.20 &&
                p.location.longitude >= 31.60 &&
                p.location.longitude <= 31.85,
          )
          .toList();
      final finalResults = insideCity.isNotEmpty ? insideCity : merged;

      if (!mounted) return;
      setState(() {
        _results = finalResults;
        _isLoading = false;
        _error = finalResults.isEmpty
            ? AppLocalizations.of(context)!.noMatchingResultsError
            : null;
      });
    } catch (e) {
      debugPrint('❌ خطأ في البحث عن مكان: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = AppLocalizations.of(context)!.searchFailedTryAgainError;
      });
    }
  }

  Future<List<PlaceResult>> _searchPhoton(String query) async {
    try {
      final url = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}'
        '&lat=$_biasLat&lon=$_biasLon&zoom=15&limit=15&lang=ar',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return [];
      return _parsePhotonResponse(response.body);
    } catch (e) {
      debugPrint('❌ خطأ في بحث Photon: $e');
      return [];
    }
  }

  List<PlaceResult> _parsePhotonResponse(String body) {
    final data = json.decode(body);
    final features = data['features'] as List? ?? [];
    return features.map((f) {
      final props = f['properties'] ?? {};
      final coords = f['geometry']?['coordinates'] ?? [0, 0];
      final name = props['name'] ?? '';
      final street = props['street'] ?? '';
      final city = props['city'] ?? props['county'] ?? '';
      final title = name.toString().isNotEmpty
          ? name.toString()
          : street.toString();
      final subtitle = [street, city]
          .where((s) => s.toString().isNotEmpty && s.toString() != title)
          .join('، ');
      return PlaceResult(
        title: title.isNotEmpty
            ? title
            : AppLocalizations.of(context)!.unknownPlaceLabel,
        subtitle: subtitle,
        location: LatLng(
          (coords[1] as num).toDouble(),
          (coords[0] as num).toDouble(),
        ),
      );
    }).toList();
  }

  Future<List<PlaceResult>> _searchNominatim(String query) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}'
        '&limit=15&accept-language=ar'
        // مربع حدود مدينة العاشر من رمضان تقريبًا، مع تقييد صارم (bounded=1)
        // عشان النتائج تكون من جوه المدينة بالأساس
        '&viewbox=31.60,30.38,31.85,30.20&bounded=1',
      );
      final response = await http
          .get(url, headers: {'User-Agent': 'com.tayar.app'})
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return [];

      final List data = json.decode(response.body);
      return data.map((item) {
        final display = (item['display_name'] ?? '').toString();
        final parts = display.split('،');
        final title = parts.isNotEmpty ? parts.first.trim() : display;
        final subtitle = parts.length > 1
            ? parts.sublist(1).join('،').trim()
            : '';
        return PlaceResult(
          title: title.isNotEmpty
              ? title
              : AppLocalizations.of(context)!.unknownPlaceLabel,
          subtitle: subtitle,
          location: LatLng(
            double.parse(item['lat']),
            double.parse(item['lon']),
          ),
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ خطأ في بحث Nominatim: $e');
      return [];
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
          icon: Icon(Icons.arrow_back, color: context.textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title ?? loc.whereDoYouWantToGoTitle,
          style: TextStyle(color: context.textColor),
        ),
      ),
      body: Column(
        children: [
          // ====== حقل البحث + زرار اختار من الخريطة (أيقونة بس) جوه نفس الخانة ======
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: context.textGreyColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: _onQueryChanged,
                      style: TextStyle(color: context.textColor, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: loc.searchPlaceHint,
                        hintStyle: TextStyle(color: context.textGreyColor),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: TayarColors.primary,
                        ),
                      ),
                    ),
                  // ====== زرار اختار من الخريطة: أيقونة بس من غير نص، بعد
                  // ما كان ListTile منفصل تحت خانة البحث ======
                  IconButton(
                    icon: const Icon(Icons.map, color: TayarColors.primary),
                    tooltip: loc.pickFromMapLabel,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _openPickOnMap,
                  ),
                ],
              ),
            ),
          ),
          Divider(color: context.dividerColor2, height: 1),

          // ====== النتائج أو سجل البحث ======
          Expanded(child: _buildResultsArea()),
        ],
      ),
    );
  }

  Widget _buildResultsArea() {
    final loc = AppLocalizations.of(context)!;
    // الخانة فاضية → نعرض سجل البحث لو موجود
    if (_controller.text.trim().isEmpty) {
      if (_recentSearches.isEmpty) {
        return Center(
          child: Text(
            loc.startTypingToSearchLabel,
            style: TextStyle(color: context.textGreyColor),
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              loc.recentSearchesLabel,
              style: TextStyle(
                color: context.textGreyColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ..._recentSearches.map(
            (place) => ListTile(
              leading: Icon(Icons.history, color: context.textGreyColor),
              title: Text(
                place.title,
                style: TextStyle(color: context.textColor, fontSize: 15),
              ),
              subtitle: place.subtitle.isNotEmpty
                  ? Text(
                      place.subtitle,
                      style: TextStyle(
                        color: context.textGreyColor,
                        fontSize: 14,
                      ),
                    )
                  : null,
              onTap: () => _selectPlace(place),
            ),
          ),
        ],
      );
    }

    // فيه خطأ (مفيش نتائج أو فشل البحث)
    if (_error != null) {
      return Center(
        child: Text(_error!, style: TextStyle(color: context.textGreyColor)),
      );
    }

    // نتايج البحث الحية
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (_, _) =>
          Divider(color: context.dividerColor2, height: 1),
      itemBuilder: (context, index) {
        final place = _results[index];
        return ListTile(
          leading: Icon(
            widget.pinType == PinType.pickup ? Icons.location_on : Icons.flag,
            color: TayarColors.primary,
          ),
          title: Text(
            place.title,
            style: TextStyle(color: context.textColor, fontSize: 15),
          ),
          subtitle: place.subtitle.isNotEmpty
              ? Text(
                  place.subtitle,
                  style: TextStyle(color: context.textGreyColor, fontSize: 14),
                )
              : null,
          onTap: () => _selectPlace(place),
        );
      },
    );
  }
}
