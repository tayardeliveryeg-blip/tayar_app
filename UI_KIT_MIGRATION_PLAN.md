# TAYAR UI Kit Migration Plan

## Phase 1 — Central UI Kit stabilization
- [ ] AppPrimaryButton: add/standardize outline variant
- [ ] AppPrimaryButton: variant-aware loading indicator
- [ ] Remove repeated external styleFrom overrides where possible

## Phase 2 — Migration priorities
### High
- passenger_profile_screen.dart
- driver_profile_screen.dart
- phone_auth_screen.dart
- passenger_wallet_screen.dart
- driver_wallet_tab.dart
- trip_tracking_screen.dart
- trip_chat_screen.dart
- select_destination_screen.dart
- onboarding_screen.dart

### Cleanup
- passenger_home.dart
- searching_offers_screen.dart
- order_confirmation_screen.dart
- create_delivery_order_screen.dart
- driver_home_screen.dart
- driver_income_tab.dart
- active_trip_card.dart
- driver_home_drawer.dart

## Rules
- Use AppPrimaryButton for standard app actions.
- Use AppCard for actual card surfaces; do not force specialized map/chat/OTP UI into it.
- Use TayarToast instead of SnackBar for app feedback.
- Use TayarShimmer for content loading where a skeleton is appropriate.
- Use EmptyState for empty collections.
- Prefer AppSpacing, AppRadius, AppShadows and Theme text styles over repeated local constants.
- Preserve specialized UI behavior for maps, OTP, chat bubbles, social login and custom bottom sheets.
