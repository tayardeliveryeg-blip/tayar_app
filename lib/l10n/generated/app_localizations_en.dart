// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Tayar - Instantly There';

  @override
  String get noInternetConnectionMessage => 'No internet connection';

  @override
  String get clientOrderPriority =>
      'Sent to nearby drivers; best price gets priority';

  @override
  String get driverNoOrders => 'No orders available';

  @override
  String get driverOfflineHint =>
      'You\'re offline. Tap \"Online\" to see orders';

  @override
  String get driverNoRatings => 'No ratings yet';

  @override
  String get newDriverLabel => 'New driver';

  @override
  String get newRiderLabel => 'New rider';

  @override
  String get tabRequests => 'Requests';

  @override
  String get tabIncome => 'Income';

  @override
  String get tabRatings => 'Ratings';

  @override
  String get tabWallet => 'Wallet';

  @override
  String get errorLoadingOrders => 'Failed to load orders';

  @override
  String get defaultDriverName => 'Driver';

  @override
  String get statusAvailable => 'Available';

  @override
  String get statusUnavailable => 'Unavailable';

  @override
  String get permissionLocationRequired => 'Allow location access to go online';

  @override
  String get offerSentWaitingPassenger =>
      'Offer sent, waiting for the passenger';

  @override
  String get offerSendFailed => 'Couldn\'t send offer, try again';

  @override
  String get arrivedAtDestination => 'You\'ve arrived at your destination';

  @override
  String get endTrip => 'End Trip';

  @override
  String get startTrip => 'Start Trip';

  @override
  String get driverToggleOnline => 'Online';

  @override
  String get driverToggleOffline => 'Offline';

  @override
  String get mustSignInFirst => 'Sign in first';

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
    return 'EGP $amount';
  }

  @override
  String distanceKmLabel(String distance) {
    return '$distance km';
  }

  @override
  String get offerSentAlreadyLabel => 'Offer sent, waiting for the passenger';

  @override
  String get offerCustomButton => 'Different price';

  @override
  String get acceptProposedPrice => 'Accept proposed price';

  @override
  String get setYourPriceLabel => 'Set your price';

  @override
  String get submitOfferButton => 'Submit Offer';

  @override
  String get tripInProgressLabel => 'Trip in progress';

  @override
  String get tripAcceptedWaitingLabel => 'Trip accepted - waiting to start';

  @override
  String get todayIncome => 'Today\'s Income';

  @override
  String get totalIncome => 'Total Income';

  @override
  String get completedTripsCount => 'Completed Trips';

  @override
  String ratingCountLabel(int count) {
    return 'from $count ratings';
  }

  @override
  String get availableBalance => 'Available Balance';

  @override
  String get bikePlateLabel => 'Plate Number';

  @override
  String get orderDetailsTitle => 'Order Details';

  @override
  String get locationUnavailableForOrder =>
      'Location unavailable for this order';

  @override
  String get offerAtMyPriceButton => 'Offer my price';

  @override
  String get alreadyOfferedOnOrder => 'You\'ve already offered on this order';

  @override
  String get logout => 'Log Out';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirmLogoutMessage => 'Log out of your account?';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get navSecurity => 'Safety';

  @override
  String get navSettings => 'Settings';

  @override
  String get navHelp => 'Help';

  @override
  String get navSupport => 'Support';

  @override
  String get backToPassengerModeButton => 'Back to Passenger Mode';

  @override
  String get appLanguageLabel => 'Language';

  @override
  String get useDeviceLanguageLabel => 'Use device language';

  @override
  String get appThemeLabel => 'Appearance';

  @override
  String get darkModeLabel => 'Dark Mode';

  @override
  String get lightModeLabel => 'Light Mode';

  @override
  String get useDeviceThemeLabel => 'Use device setting';

  @override
  String get enablePushNotifications => 'Enable app notifications';

  @override
  String get pushNotificationsDescription => 'Order, offer, and update alerts';

  @override
  String get termsAndConditions => 'Terms & Conditions';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get privacyPolicyBody =>
      'We protect your data and only access your location during an active trip. We never share your data without consent.';

  @override
  String get appVersionLabel => 'App Version';

  @override
  String get ok => 'OK';

  @override
  String get firstNameHint => 'Name';

  @override
  String get lastNameHint => 'Last Name';

  @override
  String get birthDateHint => 'Date of Birth';

  @override
  String get phoneNumberLabel => 'Phone Number';

  @override
  String get addressLabel => 'City';

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
  String get choosePhotoSourceTitle => 'Choose photo source';

  @override
  String get chooseFromGalleryLabel => 'Choose from gallery';

  @override
  String get takePhotoLabel => 'Take a photo';

  @override
  String get editPhotoTitle => 'Edit Photo';

  @override
  String get editPhotoHint =>
      'Pinch to zoom and drag to position the photo inside the circle';

  @override
  String get photoTooLargeError => 'Photo too large, choose a smaller one';

  @override
  String get invalidPhoneNumberError =>
      'Invalid phone number, please enter a valid Egyptian number';

  @override
  String get locatingAddress => 'Locating address...';

  @override
  String get addressUnknown => 'Unknown location';

  @override
  String get addressFetchFailed => 'Couldn\'t get address';

  @override
  String get paymentMethodWallet => 'My Wallet';

  @override
  String get paymentMethodInstapay => 'InstaPay';

  @override
  String get choosePaymentMethodTitle => 'Choose Payment Method';

  @override
  String get fromLabel => 'Where from';

  @override
  String get serviceRideMe => 'Ride Me';

  @override
  String get serviceDeliverOrders => 'Deliver My Orders';

  @override
  String get deliveryOrderTitle => 'Delivery Order';

  @override
  String get pickupLocationLabel => 'Pickup Location';

  @override
  String get deliveryLocationLabel => 'Delivery Location';

  @override
  String get tapToSelectLocationLabel => 'Tap to select location';

  @override
  String get pickupAddressDetailsLabel => 'Pickup Address Details';

  @override
  String get pickupAddressDetailsHint => 'e.g. 2nd floor, next to the pharmacy';

  @override
  String get deliveryAddressDetailsLabel => 'Delivery Address Details';

  @override
  String get deliveryAddressDetailsHint =>
      'e.g. 2nd floor, next to the pharmacy';

  @override
  String get senderPhoneLabel => 'Sender\'s Phone Number';

  @override
  String get receiverPhoneLabel => 'Receiver\'s Phone Number';

  @override
  String get phoneNumberHint => '01xxxxxxxxx';

  @override
  String get saveOrderButton => 'Save Order';

  @override
  String get fillAllFieldsError =>
      'Please select locations and fill required fields';

  @override
  String get estimatedFareLabel => 'Suggested Fare';

  @override
  String get selectPickupLocationTitle => 'Select Pickup Location';

  @override
  String get selectDeliveryLocationTitle => 'Select Delivery Location';

  @override
  String get paymentMethodLabel => 'Payment Method';

  @override
  String get confirmButton => 'Confirm';

  @override
  String durationMinLabel(int duration) {
    return '$duration min';
  }

  @override
  String get defaultUserName => 'User';

  @override
  String get driverModeButton => 'Driver Mode';

  @override
  String get orderHistoryLabel => 'Order History';

  @override
  String get myScheduledRidesLabel => 'Scheduled Rides';

  @override
  String get noScheduledRidesTitle => 'No scheduled rides';

  @override
  String get noScheduledRidesSubtitle =>
      'Rides you book in advance will show up here';

  @override
  String get cancelScheduledRideTitle => 'Cancel scheduled ride?';

  @override
  String get cancelScheduledRideBody =>
      'This ride will be cancelled permanently and can\'t be undone';

  @override
  String get scheduledRideCancelledSuccess => 'Scheduled ride cancelled';

  @override
  String get driverRegistrationTitle => 'Driver Registration';

  @override
  String get closeButton => 'Close';

  @override
  String get termsAgreementPrefix => 'I agree to the ';

  @override
  String get termsAndConditionsLinkText => 'Terms and Conditions';

  @override
  String get termsAgreementRequiredError =>
      'You must agree to the Terms and Conditions to continue';

  @override
  String get termsAndConditionsTitle => 'Terms and Conditions';

  @override
  String get termsAndConditionsBody =>
      'By using the Tayar app (as a rider, driver, or vendor partner), you agree to be fully bound by the Terms and Conditions published at b10-app-1e682.web.app/terms.html. In short: Tayar is a matching platform only, not a transport company, and drivers are independent users, not employees. Fares are negotiable within a set range, cancellation fees apply after a free grace period, and a commission is deducted from drivers per trip. Please review the full text at the link above, or from Settings > Terms and Conditions.';

  @override
  String get submitApplicationSuccessTitle => 'Application sent!';

  @override
  String get submitApplicationSuccessBody =>
      'We\'ll review your details within 24 hours and notify you once approved.';

  @override
  String get submitFailedError => 'Couldn\'t submit, try again';

  @override
  String get applicationUnderReviewBanner =>
      'Your application is under review. We\'ll notify you soon.';

  @override
  String get registrationIntroText =>
      'Upload your personal and vehicle details. We\'ll review within 24 hours.';

  @override
  String get sectionPersonalInfo => 'Personal Information';

  @override
  String get sectionDrivingLicense => 'Driving License';

  @override
  String get sectionPersonalDocuments => 'Personal Documents';

  @override
  String get sectionBikeInfo => 'Bike Information';

  @override
  String get applicationUnderReviewButton => 'Application Under Review';

  @override
  String get continueButton => 'Continue';

  @override
  String get sectionCompleteLabel => 'Information completed';

  @override
  String get sectionIncompleteLabel => 'Fill in required information';

  @override
  String get optionalLabel => 'Optional';

  @override
  String get personalPhotoLabel => 'Personal Photo';

  @override
  String get prefilledFromPassengerProfileHint =>
      'We filled this in from your passenger profile - feel free to edit it';

  @override
  String get licensePhotoUploadRequired =>
      'Please upload license photo and expiry date';

  @override
  String get licenseExpiryHint => 'Expiry Date';

  @override
  String get criminalRecordUploadRequired =>
      'Please upload criminal record and ID number';

  @override
  String get criminalRecordFrontLabel => 'Criminal Record Document';

  @override
  String get criminalRecordBackLabel => 'Criminal Record (Back)';

  @override
  String get idNumberHint => 'ID Number';

  @override
  String get bikeInfoRequiredError => 'Please complete basic Bike info';

  @override
  String get bikePhotoLabel => 'Bike Photo';

  @override
  String get bikeLicensePhotoLabel => 'Bike License';

  @override
  String get bikeBrandHint => 'Bike Brand';

  @override
  String get bikeModelHint => 'Bike Model';

  @override
  String get bikeColorHint => 'Bike Color';

  @override
  String get bikeYearHint => 'Year of Manufacture';

  @override
  String get helpScreenTitle => 'Help';

  @override
  String get faqOrderTripQuestion => 'How do I request a trip?';

  @override
  String get faqOrderTripAnswer =>
      'From the home screen, pick your start and destination, check the suggested price, and send. Nearby drivers will send offers to choose from.';

  @override
  String get faqPricingQuestion => 'How is the price determined?';

  @override
  String get faqPricingAnswer =>
      'Price is based on actual distance. You can raise or lower it while negotiating with drivers.';

  @override
  String get faqPaymentMethodsQuestion => 'What payment methods are available?';

  @override
  String get faqPaymentMethodsAnswer =>
      'Pay cash to the driver, via e-wallet, or InstaPay — choose when confirming your order.';

  @override
  String get faqNoAcceptQuestion =>
      'No one is accepting my request, what should I do?';

  @override
  String get faqNoAcceptAnswer =>
      'Try raising the price, especially at peak times or in remote areas, to attract nearby drivers.';

  @override
  String get faqBecomeDriverQuestion =>
      'How do I become a driver on the Tayar app?';

  @override
  String get faqBecomeDriverAnswer =>
      'Choose \"Driver Mode\" from the side menu and complete registration (info, license, Bike). You can accept orders after review.';

  @override
  String get faqDriverEarningsQuestion => 'How are driver earnings calculated?';

  @override
  String get faqDriverEarningsAnswer =>
      'You keep 90% of each trip; the company takes 10%. Track earnings in the \"Income\" tab.';

  @override
  String get faqDeliverPackageQuestion =>
      'Can I deliver a package instead of doing a passenger trip?';

  @override
  String get faqDeliverPackageAnswer =>
      'Yes — use \"Package Delivery\" to send a package without joining the trip. Same negotiation system applies.';

  @override
  String get faqTripProblemQuestion =>
      'What should I do if a problem occurs during a trip?';

  @override
  String get faqTripProblemAnswer =>
      'Contact support directly from the \"Support\" screen in the side menu.';

  @override
  String get chooseYourRideSubtitle => 'Choose the ride that suits you';

  @override
  String get continueWithGoogleButton => 'Continue with Google';

  @override
  String get continueWithAppleButton => 'Continue with Apple';

  @override
  String get continueWithPhoneButton => 'Continue with Phone';

  @override
  String get loginTermsAgreementNotice =>
      'By joining, you agree to the terms of use and privacy policy';

  @override
  String get loginAgreementPrefix => 'By continuing, you agree to the ';

  @override
  String get termsOfUseLinkText => 'Terms of Use';

  @override
  String get loginAgreementConnector => ' and ';

  @override
  String get loginAgreementRequiredError =>
      'You must agree to the Terms of Use and Privacy Policy to continue';

  @override
  String signInFailedError(String error) {
    return 'Sign in failed: $error';
  }

  @override
  String signInWithAppleFailedError(String error) {
    return 'Apple sign in failed: $error';
  }

  @override
  String get nameLabel => 'Name';

  @override
  String get requiredFieldError => 'This field is required';

  @override
  String get markAllAsReadButton => 'Mark all as read';

  @override
  String get mustSignInToViewNotifications => 'Sign in to view notifications';

  @override
  String get errorLoadingNotifications => 'Failed to load notifications';

  @override
  String get noNotificationsYet => 'No notifications yet';

  @override
  String get justNowLabel => 'Just now';

  @override
  String minutesAgoLabel(int minutes) {
    return '$minutes min ago';
  }

  @override
  String hoursAgoLabel(int hours) {
    return '${hours}h ago';
  }

  @override
  String daysAgoLabel(int days) {
    return '${days}d ago';
  }

  @override
  String get defaultCustomerName => 'User';

  @override
  String get setYourFareTitle => 'Set Your Fare';

  @override
  String get routeFromLabel => 'From';

  @override
  String get routeToLabel => 'To';

  @override
  String get distanceLabel => 'Distance';

  @override
  String get estimatedTimeLabel => 'Estimated Time';

  @override
  String get suggestedFareForDriversLabel => 'Suggested fare for drivers';

  @override
  String autoSuggestedFareLabel(String amount) {
    return 'Auto-suggested fare: EGP $amount';
  }

  @override
  String get autoAcceptCheckboxLabel =>
      'Auto-accept the first offer at the suggested price';

  @override
  String get searchForDriversButton => 'Search for Drivers';

  @override
  String get phoneNumberFormatError => 'Please enter a valid phone number';

  @override
  String get mobileNumberMatchHint =>
      'If an admin already added you, enter the exact same mobile number they used — your account will be linked manually from the dashboard';

  @override
  String get credentialAlreadyInUseError =>
      'This mobile number is already linked to another account. Please use a different number';

  @override
  String get otpSendFailedGenericError =>
      'An error occurred while sending the verification code. Please try again later';

  @override
  String get tryAgainLabel => 'Try Again';

  @override
  String errorOccurredWithMessage(String message) {
    return 'An error occurred: $message';
  }

  @override
  String get otpSendNoticeLabel =>
      'We\'ll send a verification code to this number';

  @override
  String get sendCodeButton => 'Send Code';

  @override
  String get invalidOtpError => 'Incorrect code, please try again';

  @override
  String get confirmPhoneNumberTitle => 'Confirm Number';

  @override
  String otpSentToNumberLabel(String phone) {
    return 'We\'ve sent a verification code to $phone';
  }

  @override
  String get resendCodeButton => 'Resend code';

  @override
  String resendCodeCountdown(int seconds) {
    return 'You can resend the code in ${seconds}s';
  }

  @override
  String get didntReceiveCodeLabel => 'Didn\'t receive the code?';

  @override
  String get codeResentMessage => 'Code resent';

  @override
  String get determiningAddressLabel => 'Determining address...';

  @override
  String get customLocationLabel => 'Custom Location';

  @override
  String get doneButton => 'Done';

  @override
  String get rateTripArrivedSafelyTitle => 'You\'ve arrived safely!';

  @override
  String get rateTripSubtitle => 'Rate your trip with the driver';

  @override
  String get rateRiderTripFinishedTitle => 'Trip finished';

  @override
  String get rateRiderSubtitle => 'Rate the rider for this trip';

  @override
  String get pleaseSelectStarsFirst => 'Please select a star rating first';

  @override
  String get failedToSaveRatingError => 'Couldn\'t save rating, try again';

  @override
  String get thankYouForRatingLabel => 'Thank you for your rating!';

  @override
  String get ratingVeryBadLabel => 'Very Bad';

  @override
  String get ratingFairLabel => 'Fair';

  @override
  String get ratingGoodLabel => 'Good';

  @override
  String get ratingVeryGoodLabel => 'Very Good';

  @override
  String get ratingExcellentLabel => 'Excellent';

  @override
  String get chooseYourRatingLabel => 'Choose your rating';

  @override
  String get commentHintOptional => 'Write a comment (optional)';

  @override
  String get submitRatingButton => 'Submit Rating';

  @override
  String get skipButton => 'Skip';

  @override
  String get failedToAcceptOfferError => 'Couldn\'t accept offer, try again';

  @override
  String get offerAcceptedTitle => 'Offer Accepted!';

  @override
  String driverOnWayWithFareLabel(String driverName, String price) {
    return 'Driver $driverName is on the way to you for EGP $price';
  }

  @override
  String get cancelSearchTitle => 'Cancel search?';

  @override
  String get cancelSearchBody =>
      'This will cancel your request and stop searching for drivers';

  @override
  String get goBackButton => 'Go Back';

  @override
  String get cancelOrderButton => 'Cancel Order';

  @override
  String get cancelTripButton => 'Cancel Trip';

  @override
  String get cancelReasonSheetTitle => 'Why are you cancelling?';

  @override
  String get cancelReasonChangedMind => 'I changed my mind';

  @override
  String get cancelReasonDriverTooSlow => 'Driver is taking too long';

  @override
  String get cancelReasonWrongAddress => 'I entered the wrong address';

  @override
  String get cancelReasonFoundOtherWay => 'Found another way to go';

  @override
  String get cancelReasonOther => 'Other reason';

  @override
  String get cancelReasonPassengerNoResponse => 'Passenger isn\'t responding';

  @override
  String get cancelReasonPassengerNotAtLocation =>
      'Passenger isn\'t at the pickup location';

  @override
  String get cancelReasonVehicleIssue => 'Vehicle issue';

  @override
  String cancellationFeeWarning(String amount) {
    return 'EGP $amount will be deducted from your wallet as a cancellation fee since the driver was already on the way';
  }

  @override
  String cancellationFeeChargedSnackbar(String amount) {
    return 'Trip cancelled, EGP $amount cancellation fee deducted from your wallet';
  }

  @override
  String get tripCancelledSuccessSnackbar => 'Trip cancelled';

  @override
  String get increaseFareButton => 'Increase Fare';

  @override
  String autoAcceptNearestDriverLabel(String amount) {
    return 'Automatically accept the nearest driver for EGP $amount';
  }

  @override
  String cashAmountLabel(String amount) {
    return 'EGP $amount in cash';
  }

  @override
  String get oneDriverViewingOrderLabel => 'One driver is viewing your request';

  @override
  String multipleDriversViewingOrderLabel(int count) {
    return '$count drivers are viewing your request';
  }

  @override
  String get tryRaisingFareTitle => 'Try raising the fare';

  @override
  String get raiseFareHintBody => 'Improves your chances of a faster ride';

  @override
  String searchWithFareLabel(String amount) {
    return 'Search with fare EGP $amount';
  }

  @override
  String newOfferFromDriverLabel(String driverName) {
    return 'New offer from $driverName';
  }

  @override
  String get rejectButton => 'Reject';

  @override
  String get acceptButton => 'Accept';

  @override
  String get setPinTitle => 'Set a 4-digit PIN';

  @override
  String get unknownProviderLabel => 'Unknown';

  @override
  String get googleAccountLabel => 'Google Account';

  @override
  String get appleAccountLabel => 'Apple Account';

  @override
  String phoneNumberProviderLabel(String phone) {
    return 'Phone Number ($phone)';
  }

  @override
  String get emailPasswordProviderLabel => 'Email & Password';

  @override
  String get deleteAccountPermanentlyTitle => 'Delete Account Permanently';

  @override
  String get deleteAccountConfirmBody =>
      'Your account and data will be permanently deleted and can\'t be recovered. Are you sure?';

  @override
  String get deletePermanentlyButton => 'Delete Permanently';

  @override
  String get reauthRequiredForDeleteError =>
      'Please sign out and back in before deleting your account';

  @override
  String get signInMethodLabel => 'Sign-in Method';

  @override
  String get appLockTitle => 'Lock app with a PIN';

  @override
  String get appLockSubtitle =>
      'You\'ll need the PIN each time you open the app';

  @override
  String get noMatchingResultsError => 'No matching results';

  @override
  String get searchFailedTryAgainError => 'Search failed, please try again';

  @override
  String get unknownPlaceLabel => 'Unknown place';

  @override
  String get whereDoYouWantToGoTitle => 'Where do you want to go?';

  @override
  String get editPickupLocationTitle => 'Change pickup location';

  @override
  String get editDestinationTitle => 'Change destination';

  @override
  String get searchPlaceHint => 'Type a street or place name...';

  @override
  String get pickFromMapLabel => 'Pick from map';

  @override
  String get startTypingToSearchLabel => 'Start typing to search for a place';

  @override
  String get recentSearchesLabel => 'Recent Searches';

  @override
  String get failedToOpenAppError => 'Couldn\'t open the required app';

  @override
  String get whatsappSupportMessage => 'Hello, I need help with the Tayar app';

  @override
  String get supportEmailSubject => 'Tayar App Support';

  @override
  String get supportMessageSentConfirmation =>
      'Message sent, our team will reach out soon';

  @override
  String get genericErrorTryAgain => 'An error occurred, please try again';

  @override
  String get contactUsDirectlyLabel => 'Contact us directly';

  @override
  String get whatsappLabel => 'WhatsApp';

  @override
  String get callLabel => 'Call';

  @override
  String get emailLabel => 'Email';

  @override
  String get orSendMessageHereLabel => 'Or send us your message here';

  @override
  String get supportMessageHint => 'Write your issue or inquiry here...';

  @override
  String get sendButton => 'Send';

  @override
  String get tripCancelledTitle => 'Trip Cancelled';

  @override
  String get tripCancelledByDriverOrSystemLabel =>
      'The trip was cancelled by the driver or the system';

  @override
  String get driverOnWayToYouLabel => 'The driver is on the way to you';

  @override
  String get driverArrivedAtPickupLabel => 'Driver has arrived';

  @override
  String get arrivedAtYourDestinationStatusLabel =>
      'You\'ve arrived at your destination';

  @override
  String get tripStartedOnWayToDestinationLabel =>
      'Trip started - on the way to the destination';

  @override
  String get updatingLabel => 'Updating...';

  @override
  String get arrivedWaitingDriverToEndTripLabel =>
      'You\'ve arrived! Ask the driver to end the trip';

  @override
  String get waitingDriverShareLocationLabel =>
      'Waiting for driver\'s location...';

  @override
  String get noOrdersYetTitle => 'No orders yet';

  @override
  String get noOrdersYetSubtitle => 'Your orders will show up here';

  @override
  String get orderStatusSearchingLabel => 'Searching for a driver';

  @override
  String get orderStatusAcceptedLabel => 'Accepted';

  @override
  String get orderStatusInProgressLabel => 'In progress';

  @override
  String get orderStatusCompletedLabel => 'Completed';

  @override
  String get orderStatusCancelledLabel => 'Cancelled';

  @override
  String get rideOrderTypeLabel => 'Ride';

  @override
  String get deliveryOrderTypeLabel => 'Delivery';

  @override
  String fareAmountEgpLabel(String amount) {
    return '$amount EGP';
  }

  @override
  String get chatWithDriverLabel => 'Chat';

  @override
  String get callDriverLabel => 'Call';

  @override
  String get chatWithPassengerLabel => 'Chat';

  @override
  String get callPassengerLabel => 'Call';

  @override
  String originalProposedFareLabel(String amount) {
    return 'Proposed price: $amount EGP';
  }

  @override
  String get chatErrorLoadingMessages => 'Failed to load messages';

  @override
  String get chatNoMessagesYet => 'No messages yet, start the conversation';

  @override
  String get chatTypeMessageHint => 'Type a message...';

  @override
  String get chatTypingIndicator => 'Typing...';

  @override
  String get chatQuickReplyOnMyWay => 'I\'m on my way';

  @override
  String get chatQuickReplyArrived => 'I\'ve arrived';

  @override
  String get chatQuickReplyWaitPlease => 'Please wait a moment';

  @override
  String get chatQuickReplyOk => 'OK';

  @override
  String get chooseAccountTypeTitle => 'Choose your account type';

  @override
  String get chooseAccountTypeSubtitle =>
      'You can start as a passenger or a driver';

  @override
  String get passengerRoleTitle => 'Passenger';

  @override
  String get passengerRoleDescription => 'Order your ride easily and quickly';

  @override
  String get driverRoleTitle => 'Driver';

  @override
  String get driverRoleDescription => 'Work and earn money with your Bike';

  @override
  String driverCommissionBadge(String percent) {
    return 'Only $percent% commission';
  }

  @override
  String driverCommissionHighlightDetail(String percent) {
    return 'Our commission is only $percent% per trip — far less than other apps';
  }

  @override
  String get completeProfileTitle => 'Complete your profile';

  @override
  String get completeProfileSubtitle =>
      'We\'ll use your name so people can recognize you';

  @override
  String get topUpWalletButton => 'Top up wallet';

  @override
  String get topUpWalletTitle => 'Top up wallet balance';

  @override
  String get topUpWalletSubtitle =>
      'Transfer the amount via InstaPay and upload the receipt screenshot, we\'ll review your request and add it to your balance shortly';

  @override
  String get topUpAmountLabel => 'Amount (EGP)';

  @override
  String topUpAmountRangeHint(String min, String max) {
    return 'Between $min and $max EGP';
  }

  @override
  String get topUpProofLabel => 'Transfer proof screenshot';

  @override
  String get topUpProofRequiredError =>
      'You need to upload a transfer proof screenshot';

  @override
  String get invalidAmountError => 'Enter a valid amount';

  @override
  String get topUpSubmitButton => 'Submit request';

  @override
  String get topUpSubmittedTitle => 'Request submitted';

  @override
  String get topUpSubmittedBody =>
      'We\'ll review your top-up request and add it to your balance soon';

  @override
  String get walletTransactionsTitle => 'Transaction history';

  @override
  String get noWalletTransactionsLabel => 'No transactions yet';

  @override
  String get walletCommissionTransactionLabel => 'Trip commission';

  @override
  String get walletTopupPendingLabel => 'Top-up request - pending review';

  @override
  String get walletTopupApprovedLabel => 'Top-up request - approved';

  @override
  String get walletTopupRejectedLabel => 'Top-up request - rejected';

  @override
  String get negativeWalletBalanceNote =>
      'Your balance is negative, top up your wallet to keep receiving new orders';

  @override
  String get myWalletLabel => 'My Wallet';

  @override
  String get walletSummaryPassengerLabel => 'My ride wallet';

  @override
  String get walletSummaryDriverLabel => 'Driver dues';

  @override
  String get walletTripPaymentLabel => 'Trip paid with wallet';

  @override
  String get walletAdminCreditLabel => 'Credit added by admin';

  @override
  String walletAvailableBalanceLabel(String amount) {
    return 'Available balance: EGP $amount';
  }

  @override
  String get walletInsufficientBalanceLabel =>
      'Insufficient balance for this fare';

  @override
  String walletMaxFareCapLabel(String amount) {
    return 'Max fare you can offer based on your wallet balance: EGP $amount';
  }

  @override
  String get homePromoBannerText => 'Get your first delivery for free';

  @override
  String get homeSearchHint => 'Where would you like to go?';

  @override
  String get savedPlacesLabel => 'Saved places';

  @override
  String get savedPlaceHome => 'Home';

  @override
  String get savedPlaceWork => 'Work';

  @override
  String get savedPlaceAdd => 'Add';

  @override
  String get recentDestinationsLabel => 'Recent destinations';

  @override
  String nearbyDriversCountLabel(int count) {
    return '$count drivers nearby';
  }

  @override
  String get rateLastTripReminderText => 'Rate your last trip';

  @override
  String get selectHomeAddressTitle => 'Choose your home address';

  @override
  String get selectWorkAddressTitle => 'Choose your work address';

  @override
  String get savedAddressSavedConfirmation => 'Address saved';

  @override
  String get savedAddressSaveError =>
      'Something went wrong while saving the address, please try again';

  @override
  String get selectCustomPlaceTitle => 'Choose the place\'s location';

  @override
  String get nameSavedPlaceTitle => 'Name this place';

  @override
  String get nameSavedPlaceHint => 'e.g. Gym, Office';

  @override
  String get nameSavedPlaceRequiredError => 'Please enter a name';

  @override
  String get removeSavedPlaceTitle => 'Remove saved place?';

  @override
  String get removeSavedPlaceMessage =>
      'This place will be removed from your saved places';

  @override
  String get removeSavedPlaceButton => 'Remove';

  @override
  String get savedPlaceRemovedConfirmation => 'Saved place removed';

  @override
  String get becomeVendorTitle => 'Become a business partner';

  @override
  String get becomeVendorIntro =>
      'Fill in your store details and we\'ll reach out after reviewing.';

  @override
  String get vendorStoreNameLabel => 'Store name';

  @override
  String get vendorStoreNameHint => 'e.g. Al Noor Supermarket';

  @override
  String get vendorBusinessTypeLabel => 'Business type';

  @override
  String get vendorTypeRestaurant => 'Restaurant';

  @override
  String get vendorTypeSupermarket => 'Supermarket';

  @override
  String get vendorTypePharmacy => 'Pharmacy';

  @override
  String get vendorTypeOther => 'Other';

  @override
  String get vendorPhoneLabel => 'Mobile/WhatsApp number';

  @override
  String get vendorLocationLabel => 'Store location';

  @override
  String get vendorLocationPickTitle => 'Pick the store location';

  @override
  String get vendorNoteLabel => 'Note (optional)';

  @override
  String get vendorNoteHint => 'Any extra details you\'d like to add';

  @override
  String get vendorSubmitButton => 'Submit request';

  @override
  String get vendorFillRequiredFieldsError =>
      'Please fill in the store name, phone number, and location';

  @override
  String get vendorSubmitFailedError =>
      'Couldn\'t submit the request, please try again';

  @override
  String get vendorApplicationSentTitle => 'Request sent';

  @override
  String get vendorApplicationSentMessage =>
      'Your request is under review, we\'ll be in touch soon.';

  @override
  String get okButton => 'OK';

  @override
  String get registerStoreDrawerLabel => 'Want to become a business partner?';

  @override
  String get becomeVendorDrawerLabel => 'Business partner';

  @override
  String get vendorPartnersDrawerLabel => 'Our business partners';

  @override
  String get vendorPartnersScreenTitle => 'Our business partners';

  @override
  String get noVendorPartnersYetMessage => 'No business partners near you yet';

  @override
  String vendorDistanceAwayLabel(String type, String distance) {
    return '$type - $distance km away';
  }

  @override
  String get orderFromVendorButton => 'Order delivery';

  @override
  String get sosSheetTitle => 'Emergency (SOS)';

  @override
  String get sosAlertSentToAdminNotice =>
      'An instant alert with your current location was sent to the Tayar team';

  @override
  String get sosCallPoliceLabel => 'Call the police';

  @override
  String get sosCallSupportLabel => 'Call Tayar support';

  @override
  String get sosNotifyEmergencyContactLabel => 'Notify emergency contact';

  @override
  String get sosNoEmergencyContactSetHint =>
      'No contact saved - tap to add one';

  @override
  String get sosWhatsappMessage =>
      'I need help right now, I\'m on a trip on the Tayar app. Please message or call me if you can.';

  @override
  String get shareTripIntro =>
      'I\'m currently on a trip using the Tayar app, here are the details:';

  @override
  String get shareTripDriverLabel => 'Driver';

  @override
  String get shareTripPassengerLabel => 'Passenger';

  @override
  String get shareTripFromLabel => 'From';

  @override
  String get shareTripToLabel => 'To';

  @override
  String get shareTripLiveLocationLabel => 'Current location';

  @override
  String get emergencyContactTitle => 'Emergency contact';

  @override
  String get emergencyContactSubtitle =>
      'This number will get a WhatsApp alert with your location if you tap the SOS button during a trip';

  @override
  String get emergencyContactHint => 'Emergency contact\'s phone number';

  @override
  String get savedSuccessfully => 'Saved successfully';

  @override
  String get redeemCodeSectionTitle => 'Have a promo or referral code?';

  @override
  String get redeemCodeButtonLabel => 'Redeem code';

  @override
  String get enterCodeHint => 'Enter the code here';

  @override
  String get redeemCodeSubmitButton => 'Confirm';

  @override
  String codeRedeemedSuccessMessage(String amount) {
    return 'Nice! $amount EGP was added to your wallet';
  }

  @override
  String get invalidCodeGenericError => 'That code isn\'t valid';

  @override
  String get myReferralCodeTitle => 'Your referral code';

  @override
  String get myReferralCodeSubtitle =>
      'Share this code with friends — you\'ll get wallet credit every time someone uses it';

  @override
  String get copyReferralCodeButton => 'Copy code';

  @override
  String get shareReferralCodeButton => 'Share';

  @override
  String get referralCodeCopiedMessage => 'Code copied';

  @override
  String get referralShareMessageIntro =>
      'Try Tayar and get a welcome credit when you sign up! Use this referral code:';

  @override
  String get referralOptionalFieldLabel => 'Referral code (optional)';

  @override
  String get referralOptionalFieldHint =>
      'If someone invited you, enter their code here';

  @override
  String get walletPromoCreditLabel => 'Promo code';

  @override
  String get walletReferralCreditLabel => 'Referral bonus';

  @override
  String get rideTimingSectionTitle => 'Ride timing';

  @override
  String get rideTimingNowOption => 'Now';

  @override
  String get rideTimingScheduledOption => 'Schedule for later';

  @override
  String get chooseScheduleDateTimeButton => 'Choose date & time';

  @override
  String scheduledForLabel(String dateTime) {
    return 'Scheduled for $dateTime';
  }

  @override
  String get scheduleMinLeadError => 'Pick a time at least 10 minutes from now';

  @override
  String scheduleMaxAdvanceError(int days) {
    return 'You can\'t schedule a ride more than $days days ahead';
  }

  @override
  String scheduledRideSearchingBanner(String dateTime) {
    return 'Your ride is scheduled for $dateTime - we\'ll start finding a rider now so they can confirm with you';
  }

  @override
  String get addToFavoriteDriversButton => 'Add to favorites';

  @override
  String get removeFromFavoriteDriversButton => 'Remove from favorites';

  @override
  String get blockDriverButton => 'Block driver';

  @override
  String get unblockDriverButton => 'Unblock';

  @override
  String get blockDriverConfirmTitle => 'Block this driver?';

  @override
  String blockDriverConfirmBody(String driverName) {
    return '$driverName won\'t be able to see or accept your ride requests once blocked. You can unblock them anytime from your profile.';
  }

  @override
  String get blockButton => 'Block';

  @override
  String get driverAddedToFavoritesMessage => 'Driver added to favorites';

  @override
  String get driverRemovedFromFavoritesMessage =>
      'Driver removed from favorites';

  @override
  String get driverBlockedMessage => 'Driver blocked';

  @override
  String get driverUnblockedMessage => 'Driver unblocked';

  @override
  String get myDriversDrawerLabel => 'My drivers';

  @override
  String get myDriversScreenTitle => 'My drivers';

  @override
  String get favoriteDriversTabLabel => 'Favorites';

  @override
  String get blockedDriversTabLabel => 'Blocked';

  @override
  String get noFavoriteDriversYetMessage =>
      'No favorite drivers yet - add one from the rating screen after any trip';

  @override
  String get noBlockedDriversYetMessage => 'You haven\'t blocked any drivers';
}
