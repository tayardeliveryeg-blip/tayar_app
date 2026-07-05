import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'passenger_home.dart' show TayarColors;
import 'pick_on_map_screen.dart' show PickOnMapScreen;

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

  const SelectDestinationScreen({super.key, this.initialLocation});

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
        builder: (_) =>
            PickOnMapScreen(initialLocation: widget.initialLocation),
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
        _error = finalResults.isEmpty ? 'مفيش نتائج مطابقة' : null;
      });
    } catch (e) {
      debugPrint('❌ خطأ في البحث عن مكان: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'تعذر البحث حاليًا، حاول تاني';
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
        title: title.isNotEmpty ? title : 'مكان غير معروف',
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
          title: title.isNotEmpty ? title : 'مكان غير معروف',
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
    return Scaffold(
      backgroundColor: TayarColors.background,
      appBar: AppBar(
        backgroundColor: TayarColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'عايز تروح فين؟',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // ====== حقل البحث ======
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: TayarColors.cardDark,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: TayarColors.textGrey),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: _onQueryChanged,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: const InputDecoration(
                        hintText: 'اكتب اسم الشارع أو المكان...',
                        hintStyle: TextStyle(color: TayarColors.textGrey),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: TayarColors.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ====== زرار اختار من الخريطة (ثابت وظاهر دايمًا) ======
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: TayarColors.cardDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.map, color: TayarColors.primary),
              ),
              title: const Text(
                'اختار من الخريطة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: _openPickOnMap,
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // ====== النتائج أو سجل البحث ======
          Expanded(child: _buildResultsArea()),
        ],
      ),
    );
  }

  Widget _buildResultsArea() {
    // الخانة فاضية → نعرض سجل البحث لو موجود
    if (_controller.text.trim().isEmpty) {
      if (_recentSearches.isEmpty) {
        return const Center(
          child: Text(
            'ابدأ الكتابة عشان تدور على مكان',
            style: TextStyle(color: TayarColors.textGrey),
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'عمليات البحث الأخيرة',
              style: TextStyle(
                color: TayarColors.textGrey,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ..._recentSearches.map(
            (place) => ListTile(
              leading: const Icon(Icons.history, color: TayarColors.textGrey),
              title: Text(
                place.title,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              subtitle: place.subtitle.isNotEmpty
                  ? Text(
                      place.subtitle,
                      style: const TextStyle(
                        color: TayarColors.textGrey,
                        fontSize: 13,
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
        child: Text(
          _error!,
          style: const TextStyle(color: TayarColors.textGrey),
        ),
      );
    }

    // نتايج البحث الحية
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (_, __) =>
          const Divider(color: Colors.white12, height: 1),
      itemBuilder: (context, index) {
        final place = _results[index];
        return ListTile(
          leading: const Icon(
            Icons.location_on_outlined,
            color: TayarColors.primary,
          ),
          title: Text(
            place.title,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          subtitle: place.subtitle.isNotEmpty
              ? Text(
                  place.subtitle,
                  style: const TextStyle(
                    color: TayarColors.textGrey,
                    fontSize: 13,
                  ),
                )
              : null,
          onTap: () => _selectPlace(place),
        );
      },
    );
  }
}
