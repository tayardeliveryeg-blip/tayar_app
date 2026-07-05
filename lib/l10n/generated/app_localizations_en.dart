// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Tayar - Arrived in a flash';

  @override
  String get clientOrderPriority =>
      'Your order reaches the nearest drivers, the lowest price takes priority.';

  @override
  String get driverNoOrders => 'No available orders right now.. stay ready!';

  @override
  String get driverNoRatings => 'No ratings from passengers yet.. keep it up';

  @override
  String get tabRequests => 'Requests';

  @override
  String get tabIncome => 'Income';

  @override
  String get tabRatings => 'Ratings';

  @override
  String get tabWallet => 'Wallet';

  @override
  String get errorLoadingOrders => 'An error occurred while loading orders';

  @override
  String get defaultDriverName => 'Driver';

  @override
  String get statusAvailable => 'Available Now';

  @override
  String get statusUnavailable => 'Unavailable';

  @override
  String get permissionLocationRequired =>
      'You need to allow location access first to go available';

  @override
  String get offerSentWaitingPassenger =>
      'Your offer was sent, waiting for the passenger\'s response';

  @override
  String get offerSendFailed => 'Couldn\'t send the offer, try again';

  @override
  String get arrivedAtDestination => '🎉 You\'ve arrived at the destination';

  @override
  String get endTrip => 'End Trip';

  @override
  String get startTrip => 'Start Trip';

  @override
  String get driverToggleOnline => 'Available';

  @override
  String get driverToggleOffline => 'Unavailable';

  @override
  String get mustSignInFirst => 'You need to sign in first';

  @override
  String get paymentMethodCash => 'Cash';

  @override
  String get navProfile => 'Profile';

  @override
  String get navIncome => 'Income';

  @override
  String get navRatings => 'Ratings';

  @override
  String get navWallet => 'Wallet';

  @override
  String distanceDurationLabel(String distance, int duration) {
    return '$distance km • $duration min';
  }

  @override
  String currencyEGP(String amount) {
    return '$amount EGP';
  }

  @override
  String distanceKmLabel(String distance) {
    return '$distance km';
  }

  @override
  String get offerSentAlreadyLabel =>
      'Your offer was sent, waiting for the passenger';

  @override
  String get offerCustomButton => 'Offer a different price';

  @override
  String get acceptProposedPrice => 'Accept the proposed price';

  @override
  String get setYourPriceLabel => 'Set the price you\'re offering';

  @override
  String get submitOfferButton => 'Send Offer';

  @override
  String get tripInProgressLabel => 'Trip in progress now';

  @override
  String get tripAcceptedWaitingLabel => 'Trip accepted - waiting to start';

  @override
  String get todayIncome => 'Today\'s Income';

  @override
  String get totalIncome => 'Total Income';

  @override
  String get completedTripsCount => 'Completed Trips Count';

  @override
  String ratingCountLabel(int count) {
    return 'From $count ratings';
  }

  @override
  String get availableBalance => 'Your Available Balance';

  @override
  String get totalEarningsBeforeCommission =>
      'Total Earnings (Before Commission)';

  @override
  String get companyCommission => 'Company Commission (10%)';

  @override
  String get motorcycleInfoTitle => 'Motorcycle Info';

  @override
  String get bikeModelLabel => 'Model';

  @override
  String get bikeColorLabel => 'Color';

  @override
  String get bikePlateLabel => 'Plate Number';

  @override
  String get bikeYearLabel => 'Model (Year of Manufacture)';

  @override
  String get orderDetailsTitle => 'Order Details';

  @override
  String get locationUnavailableForOrder =>
      'Location unavailable for this order';

  @override
  String get offerAtMyPriceButton => 'Offer My Price';

  @override
  String get alreadyOfferedOnOrder =>
      'You\'ve already made an offer on this order';

  @override
  String get logout => 'Logout';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirmLogoutMessage =>
      'Are you sure you want to log out of your account?';

  @override
  String get languageToggleTooltip => 'العربية / English';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get navSecurity => 'Security';

  @override
  String get navSettings => 'Settings';

  @override
  String get navHelp => 'Help';

  @override
  String get navSupport => 'Support';

  @override
  String get backToPassengerModeButton => 'Back to Passenger Mode';

  @override
  String get appLanguageLabel => 'App Language';

  @override
  String get enablePushNotifications => 'Enable App Notifications';

  @override
  String get pushNotificationsDescription =>
      'Notifications for orders, offers, and important updates';

  @override
  String get termsAndConditions => 'Terms and Conditions';

  @override
  String get termsAndConditionsBody =>
      'By using the Tayar app, you agree to its terms of use, that the service is provided directly between the passenger and the driver, and that the company only provides the connection platform.';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get privacyPolicyBody =>
      'We protect your data and only use your location while a trip is actually in progress, and we never share your data with any third party without your consent.';

  @override
  String get appVersionLabel => 'App Version';

  @override
  String get ok => 'OK';

  @override
  String get firstNameHint => 'First Name';

  @override
  String get lastNameHint => 'Last Name';

  @override
  String get birthDateHint => 'Date of Birth';

  @override
  String get phoneNumberLabel => 'Mobile Number';

  @override
  String get addressLabel => 'Address';

  @override
  String get saveButton => 'Save';

  @override
  String get fullNameRequiredError => 'Please enter your full name';

  @override
  String get saveFailedError => 'Couldn\'t save, try again';

  @override
  String get profileUpdatedSuccess => 'Profile updated successfully';

  @override
  String get changePhotoLabel => 'Change Photo';

  @override
  String get photoTooLargeError =>
      'The photo is too large, please choose a smaller one';
}
