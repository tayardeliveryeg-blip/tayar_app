import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/become_vendor_screen.dart';
import 'package:tayay_app/screens/passenger/create_delivery_order_screen.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart'
    show TayarColors, TayarThemeColors;
import 'package:tayay_app/services/vendor_service.dart';

/// ====== شاشة "شركاؤنا التجاريين": بتعرض كل المحلات اللي اتأكدت كشريك
/// تجاري (بعد ما الأدمن ينشرها من تاب Vendor Requests)، مرتبة حسب الأقرب
/// للراكب لو موقعه متاح. كل محل معاه زرار "اطلب توصيل" بيفتح شاشة طلب
/// التوصيل بنقطة الاستلام متملية أوتوماتيك بموقع المحل ======
class VendorPartnersScreen extends StatefulWidget {
  const VendorPartnersScreen({super.key});

  @override
  State<VendorPartnersScreen> createState() => _VendorPartnersScreenState();
}

class _VendorPartnersScreenState extends State<VendorPartnersScreen> {
  LatLng? _userLocation;
  static const Distance _distanceCalc = Distance();

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
  }

  // ====== موقع المستخدم بس عشان نرتب المحلات بالأقرب - مش لازم يبقى دقيق
  // 100%، فبنكتفي بآخر موقع معروف بسرعة من غير ما نطلب إذن جديد ======
  Future<void> _loadUserLocation() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        setState(() {
          _userLocation = LatLng(last.latitude, last.longitude);
        });
      }
    } catch (_) {
      // ====== مفيش موقع متاح - هيتعرض الدليل من غير ترتيب حسب المسافة ======
    }
  }

  void _becomeVendor() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BecomeVendorScreen()),
    );
  }

  void _orderFrom(VendorPartner partner) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateDeliveryOrderScreen(
          initialPickupLocation: partner.location,
          initialPickupAddress: partner.storeName,
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'مطعم':
        return Icons.restaurant;
      case 'سوبر ماركت':
        return Icons.local_grocery_store;
      case 'صيدلية':
        return Icons.local_pharmacy;
      default:
        return Icons.storefront;
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
        iconTheme: IconThemeData(color: context.textColor),
        title: Text(
          loc.vendorPartnersScreenTitle,
          style: TextStyle(color: context.textColor),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<VendorPartner>>(
              stream: streamVendorPartners(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: TayarColors.primary,
                    ),
                  );
                }
                final partners = List<VendorPartner>.from(
                  snapshot.data ?? const [],
                );
                if (partners.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        loc.noVendorPartnersYetMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.textGreyColor,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  );
                }

                if (_userLocation != null) {
                  partners.sort((a, b) {
                    final da = _distanceCalc.as(
                      LengthUnit.Kilometer,
                      _userLocation!,
                      a.location,
                    );
                    final db = _distanceCalc.as(
                      LengthUnit.Kilometer,
                      _userLocation!,
                      b.location,
                    );
                    return da.compareTo(db);
                  });
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: partners.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final partner = partners[index];
                    final distanceKm = _userLocation == null
                        ? null
                        : _distanceCalc.as(
                            LengthUnit.Kilometer,
                            _userLocation!,
                            partner.location,
                          );

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: TayarColors.primary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _iconForType(partner.businessType),
                              color: TayarColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  partner.storeName,
                                  style: TextStyle(
                                    color: context.textColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  distanceKm == null
                                      ? vendorBusinessTypeDisplay(
                                          loc,
                                          partner.businessType,
                                        )
                                      : loc.vendorDistanceAwayLabel(
                                          vendorBusinessTypeDisplay(
                                            loc,
                                            partner.businessType,
                                          ),
                                          distanceKm.toStringAsFixed(1),
                                        ),
                                  style: TextStyle(
                                    color: context.textGreyColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _orderFrom(partner),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TayarColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              loc.orderFromVendorButton,
                              style: TextStyle(
                                color: context.onPrimaryColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // ====== زرار ثابت تحت القايمة عشان أي حد يقدر يقدّم كشريك تجاري
          // من غير ما يحتاج يدور عليه في الشريط الجانبي ======
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: OutlinedButton.icon(
                onPressed: _becomeVendor,
                icon: const Icon(
                  Icons.storefront_outlined,
                  color: TayarColors.primary,
                ),
                label: Text(loc.becomeVendorDrawerLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: TayarColors.primary,
                  side: const BorderSide(color: TayarColors.primary),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
