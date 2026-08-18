import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart'
    show paymentMethodDisplay;
import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/widgets/app_card.dart';
import 'package:tayay_app/widgets/app_primary_button.dart';
import 'package:tayay_app/widgets/pin_marker.dart';
import 'package:tayay_app/widgets/map_tile_layer.dart';
import 'package:tayay_app/screens/driver/driver_home_widgets/offer_sheet.dart'
    show StepButton;
import 'package:tayay_app/screens/driver/driver_home_widgets/order_request_card.dart'
    show formatScheduledForDisplay;
import 'package:tayay_app/services/fare_negotiation_rules.dart';

// ====== شاشة تفاصيل طلب الرحلة: خريطة بالنقطتين + واجهة المزايدة ======
// (كانت قبل كده private class جوه driver_home_screen.dart واتقسمت في ملف منفصل)
class TripRequestDetailScreen extends StatefulWidget {
  final String orderId;
  final String pickupAddress;
  final String destinationAddress;
  final GeoPoint? pickupLocation;
  final GeoPoint? destinationLocation;
  final double distanceKm;
  final int durationMin;
  final double proposedFare;
  final String paymentMethod;
  final bool alreadyOffered;
  final DateTime? scheduledFor;
  final VoidCallback? onQuickAccept;
  final ValueChanged<double>? onCustomOffer;

  const TripRequestDetailScreen({
    super.key,
    required this.orderId,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.pickupLocation,
    required this.destinationLocation,
    required this.distanceKm,
    required this.durationMin,
    required this.proposedFare,
    required this.paymentMethod,
    required this.alreadyOffered,
    this.scheduledFor,
    this.onQuickAccept,
    this.onCustomOffer,
  });

  @override
  State<TripRequestDetailScreen> createState() =>
      TripRequestDetailScreenState();
}

class TripRequestDetailScreenState extends State<TripRequestDetailScreen> {
  List<LatLng> _routePoints = [];
  late double _price;

  // ====== نفس الحدود المطبّقة في offer_sheet.dart، محسوبة على
  // widget.proposedFare بتاعة الطلب وقت فتح الشاشة (السعر الأصلي قبل أي
  // مزايدة من السائق ده)، مش على _price المتغيّرة ======
  double get _minPrice => FareNegotiationRules.minFareFor(widget.proposedFare);
  double get _maxPrice => FareNegotiationRules.maxFareFor(widget.proposedFare);

  @override
  void initState() {
    super.initState();
    _price = widget.proposedFare;
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    final pickup = widget.pickupLocation;
    final dest = widget.destinationLocation;
    if (pickup == null || dest == null) return;

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${pickup.longitude},${pickup.latitude};'
        '${dest.longitude},${dest.latitude}'
        '?overview=full&geometries=geojson',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return;

      final json = jsonDecode(response.body);
      final coords =
          json['routes'][0]['geometry']['coordinates'] as List<dynamic>;
      final points = coords
          .map(
            (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
          )
          .toList();

      if (mounted) setState(() => _routePoints = points);
    } catch (e) {
      debugPrint('⚠️ تعذر جلب المسار: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickup = widget.pickupLocation;
    final dest = widget.destinationLocation;
    final hasLocations = pickup != null && dest != null;

    final center = hasLocations
        ? LatLng(
            (pickup.latitude + dest.latitude) / 2,
            (pickup.longitude + dest.longitude) / 2,
          )
        : const LatLng(30.2854, 31.7414); // مركز افتراضي (العاشر من رمضان)

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textColor),
        title: Text(
          AppLocalizations.of(context)!.orderDetailsTitle,
          style: TextStyle(color: context.textColor),
        ),
      ),
      body: Column(
        children: [
          // ====== الخريطة: نقطة الانطلاق (A) والوجهة (B) ======
          Expanded(
            flex: 3,
            child: hasLocations
                ? FlutterMap(
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 13,
                      minZoom: 4,
                      cameraConstraint: tayarMapCameraConstraint,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      const TayarTileLayer(),
                      const TayarMapAttribution(),
                      if (_routePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints,
                              color: TayarColors.primary,
                              strokeWidth: 4,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(pickup.latitude, pickup.longitude),
                            width: 40,
                            height: 40,
                            child: const PinMarker(
                              type: PinType.pickup,
                              size: 40,
                            ),
                          ),
                          Marker(
                            point: LatLng(dest.latitude, dest.longitude),
                            width: 40,
                            height: 40,
                            child: const PinMarker(
                              type: PinType.destination,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Center(
                    child: Text(
                      AppLocalizations.of(context)!.locationUnavailableForOrder,
                      style: TextStyle(color: context.textGreyColor),
                    ),
                  ),
          ),

          // ====== كارت العنوانين + واجهة المزايدة ======
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    radius: AppRadius.lg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.scheduledFor != null) ...[
                          AppCard(
                            color: TayarColors.primary.withValues(
                              alpha: 0.15,
                            ),
                            radius: AppRadius.sm,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xxs,
                            ),
                            showShadow: false,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  color: TayarColors.primary,
                                  size: 13,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.scheduledForLabel(
                                    formatScheduledForDisplay(
                                      widget.scheduledFor!,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    color: TayarColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: TayarColors.primary,
                              size: 16,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                widget.pickupAddress,
                                style: TextStyle(color: context.textColor),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          child: SizedBox(
                            height: 14,
                            child: VerticalDivider(
                              color: context.dividerColor2,
                              thickness: 2,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.flag,
                              color: TayarColors.primary,
                              size: 16,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                widget.destinationAddress,
                                style: TextStyle(color: context.textColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppLocalizations.of(
                                context,
                              )!.distanceDurationLabel(
                                widget.distanceKm.toStringAsFixed(1),
                                widget.durationMin,
                              ),
                              style: TextStyle(
                                color: context.textGreyColor,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              paymentMethodDisplay(
                                context,
                                widget.paymentMethod,
                              ),
                              style: TextStyle(
                                color: context.textGreyColor,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ====== واجهة المزايدة (زيادة/نقصان السعر) ======
                  if (!widget.alreadyOffered) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        StepButton(
                          icon: Icons.remove,
                          onTap: _price <= _minPrice
                              ? null
                              : () {
                                  setState(() => _price -= 5);
                                },
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(
                            AppLocalizations.of(
                              context,
                            )!.currencyEGP(_price.toStringAsFixed(0)),
                            textAlign: TextAlign.center,
                            style: TayarStatTextStyles.statSmall,
                          ),
                        ),
                        StepButton(
                          icon: Icons.add,
                          onTap: _price >= _maxPrice
                              ? null
                              : () => setState(() => _price += 5),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              widget.onCustomOffer?.call(_price);
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.lg,
                              ),
                              side: const BorderSide(
                                color: TayarColors.primary,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(
                                context,
                              )!.offerAtMyPriceButton,
                              style: TextStyle(color: TayarColors.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppPrimaryButton(
                            onPressed: () {
                              widget.onQuickAccept?.call();
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TayarColors.primary,
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.lg,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.acceptProposedPrice,
                              style: TextStyle(color: context.onPrimaryColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.alreadyOfferedOnOrder,
                          style: TextStyle(color: context.textGreyColor),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
