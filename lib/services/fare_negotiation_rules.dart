/// Shared bounds for the price-negotiation flow, used by both the
/// passenger side (searching_offers_screen.dart) and the driver side
/// (offer_sheet.dart). Tune here.
///
/// Both ratios are always applied against the order's *original* fare
/// (stored once as `initialFare` when the order is created, and never
/// overwritten afterwards) — never against the live `proposedFare`,
/// which changes every time either side adjusts the price. Anchoring to
/// a moving number would let the effective range creep upward over time.
class FareNegotiationRules {
  FareNegotiationRules._();

  /// Passenger can't drop the offer below this ratio of the original fare.
  static const double minFareRatio = 0.5;

  /// Neither side can push the price above this ratio of the original fare.
  static const double maxFareRatio = 1.5;

  static double minFareFor(double initialFare) => initialFare * minFareRatio;

  static double maxFareFor(double initialFare) => initialFare * maxFareRatio;
}
