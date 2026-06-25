// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Hello Tuk-Tuk';

  @override
  String get welcomeMessage => 'Welcome!';

  @override
  String get continueLabel => 'Continue';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get logout => 'Log out';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get arabic => 'Arabic';

  @override
  String get selectRole => 'How will you use Hello Tuk-Tuk?';

  @override
  String get roleCustomer => 'Customer';

  @override
  String get roleCustomerDesc => 'Request rides around Hilla';

  @override
  String get roleDriver => 'Driver';

  @override
  String get roleDriverDesc => 'Accept rides and earn money';

  @override
  String get roleManager => 'Manager';

  @override
  String get roleManagerDesc => 'Approve drivers and manage the fleet';

  @override
  String get phoneLogin => 'Phone login';

  @override
  String get phoneHint => 'Phone number';

  @override
  String get sendCode => 'Send verification code';

  @override
  String get verifyCode => 'Verify code';

  @override
  String get otpHint => '6-digit code';

  @override
  String get customerProfileTitle => 'Your profile';

  @override
  String get fullName => 'Full name';

  @override
  String get age => 'Age';

  @override
  String get gender => 'Gender (optional)';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get pickup => 'Pickup';

  @override
  String get destination => 'Destination';

  @override
  String get searchPlaces => 'Search places in Hilla';

  @override
  String get noPlacesFound =>
      'No places found. Try a shorter name or use Pin on map.';

  @override
  String get searchAction => 'Search';

  @override
  String get searchPlacesHint => 'Type in Arabic or English, then tap Search';

  @override
  String get searchFieldHint => 'Search or type English (hospital, market)';

  @override
  String get searchTapPlaceHint =>
      'Tap a place in the list, or pick a category below';

  @override
  String placesInHillaCount(int count) {
    return '$count places in Hilla';
  }

  @override
  String get pinOnMap => 'Pin on map';

  @override
  String get requestRide => 'Request ride';

  @override
  String get searchingDriver => 'Searching for a driver...';

  @override
  String get driverFound => 'Driver on the way';

  @override
  String get noDriversAvailable =>
      'No drivers available right now. Try again later.';

  @override
  String get liveDriverLocation => 'Live driver location';

  @override
  String get driverRegistration => 'Driver registration';

  @override
  String get vehicleType => 'Vehicle type';

  @override
  String get vehiclePlate => 'Plate number';

  @override
  String get licenseNumber => 'License number';

  @override
  String get submitForApproval => 'Submit for approval';

  @override
  String get pendingApprovalTitle => 'Waiting for manager approval';

  @override
  String get pendingApprovalBody =>
      'Your account will be activated after a manager reviews your information.';

  @override
  String get rejectedTitle => 'Registration rejected';

  @override
  String get goOnline => 'Go online';

  @override
  String get goOffline => 'Go offline';

  @override
  String get newRideRequest => 'New ride request';

  @override
  String get acceptRide => 'Accept ride';

  @override
  String get rejectRide => 'Reject ride';

  @override
  String get activeRideExists =>
      'You already have an active ride. Finish or cancel it before booking another.';

  @override
  String get managerTitle => 'Driver approvals';

  @override
  String get approve => 'Approve';

  @override
  String get reject => 'Reject';

  @override
  String get noPendingDrivers => 'No pending driver applications';

  @override
  String get noDriversYet => 'No drivers registered yet.';

  @override
  String get pendingDriversLoadError =>
      'Could not load drivers. Publish Firestore rules from firestore.rules in Firebase Console → Firestore → Rules, then click Publish. Also confirm you are logged in as manager.';

  @override
  String get checkAllDriversTab =>
      'Tip: open the All Drivers tab to see every registered driver.';

  @override
  String get unnamedDriver => 'Driver (name not saved)';

  @override
  String get routeToPickup => 'To customer pickup';

  @override
  String get routeToDestination => 'Pickup to destination';

  @override
  String get firebaseSetupRequired =>
      'Firebase is not configured yet. Run: flutterfire configure';

  @override
  String get currentLocation => 'Current location';

  @override
  String get confirmLocation => 'Confirm location';

  @override
  String get tapMapToPin => 'Tap the map to choose a location';

  @override
  String get rideFrom => 'From';

  @override
  String get rideTo => 'To';

  @override
  String get profile => 'Profile';

  @override
  String get wrongRoleTitle => 'Wrong app for this account';

  @override
  String wrongRoleBody(String expectedRole, String actualRole) {
    return 'This app is for $expectedRole accounts. You signed in as $actualRole.';
  }

  @override
  String get adminPanelTitle => 'Hello Tuk-Tuk Admin';

  @override
  String get pendingDriversTab => 'Pending';

  @override
  String get activeRidesTab => 'Active rides';

  @override
  String get allDriversTab => 'All drivers';

  @override
  String get rideHistoryTab => 'History';

  @override
  String get noActiveRides => 'No active rides';

  @override
  String get cashFare => 'Cash fare';

  @override
  String get paymentMethodCash => 'Payment: cash only';

  @override
  String get startRide => 'Start ride';

  @override
  String get endRide => 'End ride';

  @override
  String get cashCollected => 'Cash collected';

  @override
  String get waitingCustomerCashConfirm =>
      'Waiting for customer cash confirmation';

  @override
  String get payCash => 'I paid cash';

  @override
  String get cashPaymentConfirmed => 'Cash payment confirmed';

  @override
  String get waitingForRides => 'Waiting for ride requests';

  @override
  String get rideCompleted => 'Ride completed';

  @override
  String get modeChooserSubtitle =>
      'Choose how you want to use Hello Tuk-Tuk today';

  @override
  String get takeRide => 'Take a ride';

  @override
  String get takeRideDesc => 'Book a trip around Hilla city';

  @override
  String get driveAndEarn => 'Enter or register as driver';

  @override
  String get driveAndEarnDesc =>
      'Create your driver account and start accepting rides';

  @override
  String get accountAlreadyOpenElsewhere =>
      'This account is already open on another phone. Log out there first, then try again.';

  @override
  String get accountLoggedInElsewhere =>
      'You were signed out because this account opened on another phone.';

  @override
  String get switchMode => 'Switch mode';

  @override
  String get phoneLoginModeHint =>
      'Sign in with your phone to continue registration';

  @override
  String get managerAccessDenied =>
      'This admin panel is only for manager accounts.';

  @override
  String get phoneNumberInvalid =>
      'Enter a valid Iraqi phone number (9 digits after +964).';

  @override
  String get phoneHintExample => '7901234567';

  @override
  String get phoneVerificationFailed =>
      'Phone verification failed. Check Firebase setup and try again.';

  @override
  String get webPhoneLoginHint =>
      'On web, phone login needs Firebase configured and reCAPTCHA. For testing, use an Android phone or emulator.';

  @override
  String get loginTitle => 'Log in';

  @override
  String get passwordLabel => 'Password';

  @override
  String get rememberMe => 'Remember me';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get loginButton => 'Log in';

  @override
  String get createAccountButton => 'Create account';

  @override
  String get loginFailed => 'Login failed. Check your phone and password.';

  @override
  String get signupTitle => 'Create account';

  @override
  String get emailOptional => 'Email (optional)';

  @override
  String get passwordMinLength => 'Password must be at least 6 characters.';

  @override
  String get nameRequired => 'Please enter your full name.';

  @override
  String get signupFailed => 'Sign up failed. Try a different phone number.';

  @override
  String get resetEmailSent => 'Password reset link sent.';

  @override
  String get resetFailed => 'Could not send reset link.';

  @override
  String get forgotPasswordHint =>
      'Enter your phone or email to reset your password.';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get bookRideTitle => 'Book ride';

  @override
  String get minutes => 'min';

  @override
  String get bookNowButton => 'Book now';

  @override
  String get bookRideFailed =>
      'Could not complete booking. Check your connection and try again.';

  @override
  String get currentRideTitle => 'Current ride';

  @override
  String get pickupDestinationRequired =>
      'Choose pickup and destination first.';

  @override
  String get pickupDestinationMustDiffer =>
      'Pickup and destination must be different places (at least 100 m apart).';

  @override
  String get districtLabel => 'District';

  @override
  String get subDistrictLabel => 'Sub-district';

  @override
  String get selectSubDistrictHint => 'Select sub-district';

  @override
  String get selectSubDistrictRequired =>
      'Please select your sub-district first.';

  @override
  String get fixedCustomerDistrictLabel => 'Al-Hashimiya District';

  @override
  String get whereTo => 'Where to?';

  @override
  String get bookRideButton => 'Book ride';

  @override
  String get findingDriverTitle => 'Finding driver';

  @override
  String get findingDriverSubtitle =>
      'Notifying online drivers in your city. First to accept gets the ride.';

  @override
  String get driverAssignedTitle => 'Driver assigned';

  @override
  String get waitingDriverAccept => 'Waiting for driver to accept…';

  @override
  String get trackDriverTitle => 'Track driver';

  @override
  String get tripInProgress => 'Trip in progress';

  @override
  String get tripCompletedTitle => 'Trip completed';

  @override
  String get doneButton => 'Done';

  @override
  String searchRegionHint(String region) {
    return 'Search is limited to $region';
  }

  @override
  String placesInRegionCount(int count, String region) {
    return '$count places in $region';
  }

  @override
  String get searchOutsideRegion =>
      'This location is outside the selected area.';

  @override
  String get googleMapsKeyRequired =>
      'Add your Google Maps API key to enable online search.';

  @override
  String get placesApiDenied =>
      'Online place search is limited. Results below use OpenStreetMap for this area.';

  @override
  String get locatingCurrentPosition => 'Getting your location…';

  @override
  String get searchUsingOpenStreetMap =>
      'Showing places from OpenStreetMap in this area.';

  @override
  String get locationServiceDisabled =>
      'Turn on location (GPS) in your phone settings.';

  @override
  String get locationPermissionDenied =>
      'Location permission is required. Allow it in app settings.';

  @override
  String get locationFetchFailed =>
      'Could not get GPS location. Tap the location icon to try again.';

  @override
  String get authEmailPasswordDisabled =>
      'Enable Email/Password in Firebase Console: Authentication → Sign-in method → Email/Password → Enable.';

  @override
  String get authEmailAlreadyInUse =>
      'This phone number is already registered. Try logging in instead.';

  @override
  String get restoreProfileTitle => 'Restore your account';

  @override
  String get restoreProfileMessage =>
      'Your login is still active but your profile data was removed from the server. Enter your name below to restore access.';

  @override
  String restoreProfileRoleHint(String role) {
    return 'Account type: $role';
  }

  @override
  String get restoreProfileAction => 'Restore account';

  @override
  String get useDifferentAccount => 'Use a different account';

  @override
  String get assistantProfileMissingHint =>
      'Assistant accounts must be recreated by the manager from the admin panel.';

  @override
  String get authTooManyRequests =>
      'Too many attempts. Wait a few minutes and try again.';

  @override
  String get authNetworkError =>
      'Network error. Check your internet connection and try again.';

  @override
  String get dragMapToSelectPin =>
      'Drag the map to move the pin to your location.';

  @override
  String get pinStreetNameRequired =>
      'Could not read the street name. Move the pin slightly and try again.';

  @override
  String get outOfServiceZone => 'Out of Service Zone';

  @override
  String get calculatingFare => 'Calculating fare…';

  @override
  String get fareCalculationFailed =>
      'Could not calculate the fare. Check your connection and try again.';

  @override
  String get retry => 'Retry';

  @override
  String get drivingDistance => 'Driving distance';

  @override
  String maxDistanceLimit(String km) {
    return 'Maximum ride distance is $km km.';
  }

  @override
  String get pricingTab => 'Pricing';

  @override
  String get pricingRulesTitle => 'Pricing rules';

  @override
  String get pricingRulesHint =>
      'Fares use Google Maps driving distance. Rides above the maximum distance are blocked.';

  @override
  String get maxDistanceKmLabel => 'Maximum distance';

  @override
  String get priceBracketsTitle => 'Distance brackets';

  @override
  String get fromKm => 'From (km)';

  @override
  String get toKm => 'To (km)';

  @override
  String get priceIqd => 'Price (IQD)';

  @override
  String get savePricingRules => 'Save pricing rules';

  @override
  String get pricingSaved => 'Pricing rules saved.';

  @override
  String get pricingSaveFailed =>
      'Could not save pricing rules. Check the values and try again.';

  @override
  String get pricingSavePermissionDenied =>
      'Save blocked by Firebase. Deploy the latest firestore.rules and Cloud Functions (savePricingConfig), then confirm your account role in the users collection is manager or assistant with pricing permission.';

  @override
  String get pricingInvalidValues =>
      'Check all distance and price fields use valid numbers.';

  @override
  String get estimatedDistanceNote =>
      'Approximate distance — exact route could not be loaded.';

  @override
  String get noRideHistory => 'No ride history yet.';

  @override
  String get chatWithDriver => 'Chat with driver';

  @override
  String get chatWithCustomer => 'Chat with customer';

  @override
  String get noChatMessages => 'No messages yet. Say hello!';

  @override
  String get typeMessage => 'Type a message…';

  @override
  String get holdToRecordVoice => 'Tap mic to record voice';

  @override
  String get tapToRecordVoice => 'Tap to record';

  @override
  String get stopRecording => 'Stop & send';

  @override
  String get voiceMessageTooShort =>
      'Hold the mic a little longer, then tap stop.';

  @override
  String get recordingVoice => 'Recording…';

  @override
  String get voiceMessageLabel => 'Voice message';

  @override
  String get microphonePermissionRequired =>
      'Microphone permission is required for voice messages.';

  @override
  String get voiceMessageSendFailed =>
      'Could not send voice message. Try again.';

  @override
  String get voiceMessagePlaybackFailed => 'Could not play voice message.';

  @override
  String get messageSendFailed =>
      'Could not send message. Check your connection and try again.';

  @override
  String get chatLoadFailed => 'Could not load chat messages.';

  @override
  String get microphonePermissionWebHint =>
      'Allow microphone access in your browser settings, then try again.';

  @override
  String get driverWorkDistrictLabel => 'Work city';

  @override
  String get driverWorkDistrictHint =>
      'Assign this driver to a city. They receive ride requests only in that city. First driver to accept gets the ride.';

  @override
  String get driverWorkDistrictRequired =>
      'Manager must assign a work city before this driver can receive rides.';

  @override
  String get driverWorkDistrictSaved => 'Driver work city updated.';

  @override
  String get saveDriverWorkDistrict => 'Save work city';

  @override
  String get noDriversInDistrict =>
      'No drivers are online in this city right now. Ask the manager to assign drivers to this area.';

  @override
  String get openChat => 'Chat';

  @override
  String get supportTitle => 'Support';

  @override
  String get contactManagement => 'Contact management';

  @override
  String get supportMessageHint => 'Describe your issue or question…';

  @override
  String get supportSent => 'Message sent to management.';

  @override
  String get callSupport => 'Call';

  @override
  String get whatsappSupport => 'WhatsApp support';

  @override
  String get emailSupport => 'Email support';

  @override
  String get legalDocuments => 'Legal';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get managementReply => 'Management';

  @override
  String get supportInboxTab => 'Support inbox';

  @override
  String get noSupportMessages => 'No support messages yet.';

  @override
  String get replyToUser => 'Reply to user…';

  @override
  String get closeThread => 'Close';

  @override
  String get driverHistoryTitle => 'Driver history';

  @override
  String get viewDriverHistory => 'View ride history';

  @override
  String get earningsTab => 'Earnings';

  @override
  String get commissionSettingsTitle => 'Platform commission';

  @override
  String get commissionSettingsHint =>
      'Set the percentage the platform keeps from each completed ride fare. This applies to all drivers.';

  @override
  String get platformPercentLabel => 'Commission percentage';

  @override
  String get saveCommissionSettings => 'Save commission';

  @override
  String get commissionSaved => 'Commission settings saved.';

  @override
  String get commissionSaveFailed =>
      'Could not save commission. Enter a value between 0 and 100.';

  @override
  String get totalPlatformProfit => 'Total platform profit';

  @override
  String get managerProfitByDriver => 'Profit by driver';

  @override
  String get managerProfitFromDriver => 'Your profit';

  @override
  String get driverNetEarnings => 'Driver earnings';

  @override
  String get platformCommission => 'Platform commission';

  @override
  String get outstandingProfitLabel => 'Outstanding profit';

  @override
  String get outstandingProfitTotal => 'Total outstanding profit';

  @override
  String get lifetimeProfitLabel => 'Lifetime profit';

  @override
  String get lifetimeProfitTotal => 'Total lifetime profit';

  @override
  String get owedToPlatformLabel => 'Owed to platform';

  @override
  String get lastProfitReceivedLabel => 'Last profit received';

  @override
  String get receivedProfitsTitle => 'Confirm profit received';

  @override
  String get receivedProfitsAction => 'Profits received';

  @override
  String receivedProfitsConfirm(String amount) {
    return 'Confirm you received $amount from this driver. Their outstanding balance will reset to zero for the next rides.';
  }

  @override
  String get receivedProfitsSuccess =>
      'Profit received. Outstanding balance reset.';

  @override
  String get driverBonusesTab => 'Bonuses';

  @override
  String get driverBonusesHint =>
      'Grant bonuses to drivers and mark them as paid when you pay out.';

  @override
  String get grantBonusQuickTitle => 'Grant bonus to driver';

  @override
  String get grantBonusTitle => 'Grant bonus';

  @override
  String grantBonusHint(String driverName) {
    return 'Add a bonus for $driverName.';
  }

  @override
  String get grantBonusAction => 'Grant bonus';

  @override
  String get bonusAmountLabel => 'Bonus amount';

  @override
  String get bonusReasonLabel => 'Reason (optional)';

  @override
  String get bonusAmountInvalid => 'Enter a valid bonus amount.';

  @override
  String get bonusGranted => 'Bonus granted.';

  @override
  String get pendingBonusLabel => 'Pending bonus';

  @override
  String get pendingBonusesTitle => 'Pending bonuses';

  @override
  String get noPendingBonuses => 'No pending bonuses.';

  @override
  String get markBonusPaid => 'Mark paid';

  @override
  String get bonusMarkedPaid => 'Bonus marked as paid.';

  @override
  String get completedRidesCount => 'Completed rides';

  @override
  String get yourEarningsTitle => 'Your earnings';

  @override
  String rideEarningsManager(String fare, String profit, String percent) {
    return 'Fare $fare • Your profit $profit ($percent%)';
  }

  @override
  String rideEarningsDriver(String net, String fee, String percent) {
    return 'You keep $net • Platform fee $fee ($percent%)';
  }

  @override
  String get idPhotoLabel => 'ID photo';

  @override
  String get profilePhotoLabel => 'Profile photo';

  @override
  String get pickFromGallery => 'Gallery';

  @override
  String get takePhoto => 'Camera';

  @override
  String get driverTermsTitle => 'Terms to work with Hello Tuk-Tuk';

  @override
  String get driverTermsBody =>
      'You agree to follow app rules, provide safe rides, collect cash fares honestly, and accept that the manager may review your documents and block your account for repeated cancellations or violations.';

  @override
  String get acceptDriverTerms => 'I accept the terms to work with this app';

  @override
  String get registrationFieldsRequired =>
      'Please fill in all required fields.';

  @override
  String get vehiclePlateOptional => 'Plate number (optional)';

  @override
  String get licenseNumberOptional => 'License number (optional)';

  @override
  String get registrationPhotosRequired =>
      'Please upload your ID photo and your personal photo.';

  @override
  String get registrationTermsRequired =>
      'You must accept the terms before submitting.';

  @override
  String get registrationSubmitFailed =>
      'Could not submit registration. Check your connection and try again.';

  @override
  String get photoPickFailed =>
      'Could not load the photo. Allow camera or gallery permission and try again.';

  @override
  String get registrationStorageRulesHint =>
      'Photo upload blocked by Firebase. Open Firebase Console → Storage → Rules, paste storage.rules from the project, then Publish.';

  @override
  String get customersTab => 'Customers';

  @override
  String get noCustomers => 'No customers yet.';

  @override
  String get blockUser => 'Block';

  @override
  String get unblockUser => 'Unblock';

  @override
  String get removeDriver => 'Delete account';

  @override
  String get removeDriverConfirmTitle => 'Delete this driver account?';

  @override
  String get removeDriverConfirmMessage =>
      'This removes their profile from the app. They can use Forgot Password, then log in with the same phone to set up again.';

  @override
  String get driverRemoved => 'Driver account deleted.';

  @override
  String get removeDriverFailed =>
      'Could not delete driver account. Try again.';

  @override
  String get deleteCustomer => 'Delete account';

  @override
  String get removeCustomerConfirmTitle => 'Delete this customer account?';

  @override
  String get removeCustomerConfirmMessage =>
      'This removes their profile from the app. They can use Forgot Password, then log in with the same phone to set up again.';

  @override
  String get customerRemoved => 'Customer account deleted.';

  @override
  String get removeCustomerFailed =>
      'Could not delete customer account. Try again.';

  @override
  String get accountReleasedSignupHint =>
      'This phone was reset by the manager. Use Forgot Password to set a new password, then log in to create your profile again.';

  @override
  String get blockedLabel => 'Blocked';

  @override
  String get accountBlockedTitle => 'Account blocked';

  @override
  String get driverBlockedBody =>
      'Your driver account has been blocked by management. Contact support if you think this is a mistake.';

  @override
  String get customerBlockedBody =>
      'Your account has been blocked by management because of repeated ride cancellations or other violations. Contact support for help.';

  @override
  String get cancelledRidesCount => 'Cancelled rides';

  @override
  String get noDriverPhotos => 'No photos uploaded.';

  @override
  String get addBracket => 'Add bracket';

  @override
  String get removeBracket => 'Remove bracket';

  @override
  String get liveMapTab => 'Live map';

  @override
  String get tripDetailsTitle => 'Trip details';

  @override
  String get customerDetails => 'Customer';

  @override
  String get driverDetails => 'Driver';

  @override
  String get noDriverAssigned => 'No driver assigned yet.';

  @override
  String get managerProfileTitle => 'Manager profile';

  @override
  String get noLocationYet => 'Location not available';

  @override
  String get noOnlineDrivers => 'No drivers online right now.';

  @override
  String get tripMapTitle => 'Trip map';

  @override
  String get tripStatusLabel => 'Trip status';

  @override
  String get statusLabel => 'Status';

  @override
  String get myProfileTitle => 'My profile';

  @override
  String get myTripsTitle => 'My trips';

  @override
  String get accountInformation => 'Account information';

  @override
  String get accountTypeLabel => 'Account type';

  @override
  String get registeredAt => 'Registered';

  @override
  String get tripDateTime => 'Date & time';

  @override
  String get tripHistoryHint =>
      'Your completed and cancelled trips with date and time.';

  @override
  String totalTripsCount(int count) {
    return '$count completed trips';
  }

  @override
  String get rateDriverTitle => 'Rate your driver';

  @override
  String get rateDriverHint => 'How was your trip?';

  @override
  String get driverFeedbackLabel => 'Feedback (optional)';

  @override
  String get driverFeedbackHint => 'Share your experience with the driver';

  @override
  String get submitRating => 'Submit rating';

  @override
  String get ratingSubmitted => 'Thank you for your feedback!';

  @override
  String get driverReviewsTab => 'Driver reviews';

  @override
  String get noDriverReviews => 'No driver reviews yet';

  @override
  String get driverLabel => 'Driver';

  @override
  String get customerLabel => 'Customer';

  @override
  String get unknownUser => 'Unknown';

  @override
  String get feedbackLabel => 'Feedback';

  @override
  String get awaitingPayment => 'Awaiting payment confirmation';

  @override
  String get cityPricingLabel => 'City / district';

  @override
  String get roleAssistant => 'Assistant';

  @override
  String get assistantsTab => 'Assistants';

  @override
  String get assistantsTabHint =>
      'Create dashboard accounts for your team with limited permissions.';

  @override
  String get createAssistantTitle => 'New assistant account';

  @override
  String get createAssistantButton => 'Create assistant';

  @override
  String get assistantPermissionsTitle => 'Allowed activities';

  @override
  String get assistantFormInvalid =>
      'Enter name, valid email, and password (6+ characters).';

  @override
  String get assistantCreated => 'Assistant account created.';

  @override
  String get assistantCreateFailed => 'Could not create assistant.';

  @override
  String get existingAssistantsTitle => 'Team members';

  @override
  String get noAssistantsYet => 'No assistants yet.';

  @override
  String get editAssistantPermissions => 'Edit permissions';

  @override
  String get assistantLoginHint =>
      'Use the email and password your manager gave you.';

  @override
  String get assistantNoPermissions =>
      'Your account has no dashboard permissions. Contact the manager.';

  @override
  String get emailLabel => 'Email';

  @override
  String get permPendingDrivers => 'Approve pending drivers';

  @override
  String get permActiveRides => 'View active rides';

  @override
  String get permLiveMap => 'View live map';

  @override
  String get permAllDrivers => 'View all drivers';

  @override
  String get permCustomers => 'Manage customers';

  @override
  String get permRideHistory => 'View ride history';

  @override
  String get permPricing => 'Edit city pricing';

  @override
  String get permEarnings => 'View earnings & commission';

  @override
  String get permDriverReviews => 'View driver reviews';

  @override
  String get permSupportInbox => 'Support inbox';

  @override
  String get permManageAssistants => 'Manage assistants';

  @override
  String get filterByCity => 'Filter by city';

  @override
  String get allCities => 'All cities';

  @override
  String get filterBySubDistrict => 'Filter by sub-district';

  @override
  String get allSubDistricts => 'All sub-districts';

  @override
  String get filterByMonth => 'Filter by month';

  @override
  String get allMonths => 'All months';

  @override
  String tripsInMonth(int count) {
    return '$count trips';
  }

  @override
  String get supportContactSettings => 'Support contact';

  @override
  String get supportPhoneLabel => 'Support phone number';

  @override
  String get supportWhatsappLabel => 'WhatsApp number';

  @override
  String get supportEmailLabel => 'Support email';

  @override
  String get saveSupportContact => 'Save contact';

  @override
  String get supportContactSaved => 'Support contact saved.';

  @override
  String get pricingUsingDefaultsHint =>
      'Showing default prices for this city. Edit the values below and click Save to store them in Firebase.';

  @override
  String pricingForCity(String city) {
    return 'Prices for $city';
  }

  @override
  String get pricingDistrictDefault => 'District default (all sub-districts)';

  @override
  String pricingForArea(String district, String subDistrict) {
    return 'Prices for $district — $subDistrict';
  }

  @override
  String get pricingSubDistrictFallbackHint =>
      'If no sub-district prices are saved, the district default prices are used for rides.';

  @override
  String get promoCodesTab => 'Promo codes';

  @override
  String get promoCodesHint =>
      'New customers automatically receive the FREE3 code when auto-assign is enabled.';

  @override
  String get promoCodeLabel => 'Promo code';

  @override
  String get promoCodeActive => 'Active';

  @override
  String get promoEnabledLabel => 'Promo enabled';

  @override
  String get promoEnabledHint =>
      'Turn off to stop discounts without deleting the code.';

  @override
  String get promoAutoAssignLabel => 'Auto-assign on signup';

  @override
  String get promoAutoAssignHint =>
      'Give this code to every new customer account.';

  @override
  String get promoDiscountPercentLabel => 'Discount percent';

  @override
  String get promoMaxDiscountLabel => 'Max discount per ride';

  @override
  String get promoMaxRidesLabel => 'Discounted rides per customer';

  @override
  String get promoDescriptionLabel => 'Description';

  @override
  String get savePromoCode => 'Save promo code';

  @override
  String get promoCodeSaved => 'Promo code saved.';

  @override
  String promoDiscountApplied(String code, String amount) {
    return '$code: you save $amount';
  }

  @override
  String get monthlyLeaderboardTab => 'Monthly prize leaderboard';

  @override
  String monthlyLeaderboardMonth(String monthKey) {
    return 'Month: $monthKey';
  }

  @override
  String monthlyPrizeAmount(String amount) {
    return 'Prize: $amount';
  }

  @override
  String leaderboardRideCount(int count) {
    return '$count rides this month';
  }

  @override
  String get leaderboardEmpty => 'No completed rides this month yet.';

  @override
  String get markAsWinner => 'Mark as winner';

  @override
  String get markAsPaid => 'Mark as paid';

  @override
  String get resetMonthlyCounter => 'Reset monthly counter';

  @override
  String get resetMonthlyConfirm =>
      'Reset all driver ride counts for the new month? This clears the current winner.';

  @override
  String get leaderboardWinnerMarked => 'Winner marked.';

  @override
  String get leaderboardPaidMarked => 'Prize marked as paid.';

  @override
  String get leaderboardResetDone => 'Monthly counters reset.';

  @override
  String get leaderboardWinnerBadge => 'Winner';

  @override
  String get leaderboardPaidBadge => 'Paid';

  @override
  String leaderboardCurrentWinner(String name) {
    return 'Current winner: $name';
  }

  @override
  String get permPromoCodes => 'Manage promo codes';

  @override
  String get permMonthlyLeaderboard => 'Monthly prize leaderboard';

  @override
  String get driverMonthlyPrizeTitle => 'Monthly prize challenge';

  @override
  String driverMonthlyRideCount(int count) {
    return '$count rides this month';
  }

  @override
  String driverMonthlyRank(int rank, int count) {
    return 'You are #$rank this month — $count rides';
  }

  @override
  String driverMonthlyPrizeAmount(String amount) {
    return 'Top driver this month wins $amount!';
  }

  @override
  String get ridePromoSectionTitle => 'Promo code used';

  @override
  String ridePromoCodeUsed(String code) {
    return 'Code: $code';
  }

  @override
  String ridePromoOriginalFare(String amount) {
    return 'Full fare: $amount';
  }

  @override
  String ridePromoCustomerPaid(String amount) {
    return 'Customer paid: $amount';
  }

  @override
  String ridePromoDiscountAmount(String amount) {
    return 'Promo discount: $amount';
  }

  @override
  String rideDriverCompensationOwed(String amount) {
    return 'Pay driver: $amount';
  }

  @override
  String get rideDriverCompensationHint =>
      'The customer paid less because of the promo. Pay the driver this amount so they are not shortchanged.';

  @override
  String ridePromoUsedCompact(String code, String amount) {
    return '$code −$amount';
  }

  @override
  String rideDriverCompensationCompact(String amount) {
    return 'Pay driver $amount';
  }

  @override
  String get fakeDriversTitle => 'Test drivers';

  @override
  String get fakeDriversHint =>
      'Create a fake driver for testing. When you activate them, they go online in Hilla and automatically accept matched rides.';

  @override
  String get createFakeDriver => 'Create test driver';

  @override
  String get fakeDriverCreated =>
      'Test driver created. Tap Activate to go online.';

  @override
  String get fakeDriverBadge => 'Test';

  @override
  String get activateFakeDriver => 'Activate';

  @override
  String get deactivateFakeDriver => 'Deactivate';

  @override
  String get fakeDriverActivated =>
      'Test driver is online and will auto-accept rides.';

  @override
  String get fakeDriverDeactivated => 'Test driver is offline.';

  @override
  String get driverNameLabel => 'Driver name';

  @override
  String get savedPlacesTitle => 'Saved places';

  @override
  String get placeSaveAction => 'Save place';

  @override
  String get placeRemoveFromSaved => 'Remove from saved';

  @override
  String get placeSaved => 'Place saved.';

  @override
  String get placeRemovedFromSaved => 'Removed from saved places.';

  @override
  String get savedPlacesEmptyHint =>
      'Search for a place and tap Save to keep it here.';

  @override
  String get savePlaceShort => 'Save';

  @override
  String get savedPlaceShort => 'Saved';

  @override
  String get savePlaceHint =>
      'Tap Save on any result to add it to your saved places.';

  @override
  String get broadcastToDrivers => 'Message all drivers';

  @override
  String get broadcastToCustomers => 'Message all customers';

  @override
  String get broadcastDriversHint =>
      'Send a push notification to every approved online-capable driver.';

  @override
  String get broadcastCustomersHint =>
      'Send a push notification to every customer.';

  @override
  String get announcementTitleLabel => 'Title';

  @override
  String get announcementMessageLabel => 'Message';

  @override
  String get announcementDefaultTitle => 'Announcement';

  @override
  String get announcementFieldsRequired => 'Enter a title and message.';

  @override
  String get sendAnnouncement => 'Send';

  @override
  String broadcastSentSummary(int sent, int total) {
    return 'Sent to $sent of $total devices.';
  }

  @override
  String broadcastPublishedSummary(int total) {
    return 'Announcement published to $total users. They will receive it in the app.';
  }

  @override
  String get broadcastSendFailed =>
      'Could not send announcement. Check your connection and try again.';

  @override
  String get editProfileTitle => 'Edit profile';

  @override
  String get editProfileButton => 'Edit profile';

  @override
  String get saveProfile => 'Save profile';

  @override
  String get profileUpdated => 'Profile updated.';

  @override
  String get changePasswordTitle => 'Change password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmNewPassword => 'Confirm new password';

  @override
  String get changePasswordButton => 'Update password';

  @override
  String get passwordChanged => 'Password updated.';

  @override
  String get passwordFieldsRequired => 'Enter your current and new password.';

  @override
  String get passwordsDoNotMatch => 'New passwords do not match.';

  @override
  String get fullNameRequired => 'Name is required.';

  @override
  String get phoneChangeHint =>
      'To change your phone, enter the new number and your current password below.';

  @override
  String get currentPasswordForPhoneChange =>
      'Current password (required to change phone)';

  @override
  String get phoneChangePasswordRequired =>
      'Enter your current password to change phone number.';

  @override
  String get recoveryEmailLabel => 'Recovery email (optional)';

  @override
  String get recoveryEmailHint => 'Optional email for account recovery.';

  @override
  String get forgotPasswordStepsHint =>
      'Enter your phone number and new password.';

  @override
  String get whatsappOtpTitle => 'SMS verification';

  @override
  String get whatsappOtpInstructions =>
      'Enter the 6-digit code we sent to your phone by SMS.';

  @override
  String whatsappOtpSent(String phone) {
    return 'Verification code sent to $phone.';
  }

  @override
  String get whatsappOtpResend => 'Resend code';

  @override
  String whatsappOtpResendWait(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get whatsappOtpSendFailed =>
      'Could not send SMS verification code. Try again.';

  @override
  String get whatsappOtpIncorrect => 'Incorrect verification code.';

  @override
  String get whatsappOtpExpired =>
      'Verification code expired. Tap Resend code and try again.';

  @override
  String get whatsappOtpTooManyAttempts =>
      'Too many attempts. Request a new code.';

  @override
  String get whatsappOtpSignupHint =>
      'We will send an SMS verification code before creating your account.';

  @override
  String get openPasswordResetPage => 'Open reset page';

  @override
  String get resetLinkOpened =>
      'Password reset page opened. Set your new password there.';

  @override
  String get resetWhileLoggedInHint =>
      'If you are signed in, open Profile → Edit profile → Change password.';

  @override
  String get announcementsTitle => 'Announcements';

  @override
  String get announcementsEmpty => 'No announcements from the manager yet.';
}
