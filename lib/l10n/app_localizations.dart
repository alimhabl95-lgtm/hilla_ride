import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Hello Tuk-Tuk'**
  String get appTitle;

  /// No description provided for @welcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get welcomeMessage;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @selectRole.
  ///
  /// In en, this message translates to:
  /// **'How will you use Hello Tuk-Tuk?'**
  String get selectRole;

  /// No description provided for @roleCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get roleCustomer;

  /// No description provided for @roleCustomerDesc.
  ///
  /// In en, this message translates to:
  /// **'Request rides around Hilla'**
  String get roleCustomerDesc;

  /// No description provided for @roleDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get roleDriver;

  /// No description provided for @roleDriverDesc.
  ///
  /// In en, this message translates to:
  /// **'Accept rides and earn money'**
  String get roleDriverDesc;

  /// No description provided for @roleManager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get roleManager;

  /// No description provided for @roleManagerDesc.
  ///
  /// In en, this message translates to:
  /// **'Approve drivers and manage the fleet'**
  String get roleManagerDesc;

  /// No description provided for @phoneLogin.
  ///
  /// In en, this message translates to:
  /// **'Phone login'**
  String get phoneLogin;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneHint;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send verification code'**
  String get sendCode;

  /// No description provided for @verifyCode.
  ///
  /// In en, this message translates to:
  /// **'Verify code'**
  String get verifyCode;

  /// No description provided for @otpHint.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get otpHint;

  /// No description provided for @customerProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get customerProfileTitle;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender (optional)'**
  String get gender;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @pickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get pickup;

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destination;

  /// No description provided for @searchPlaces.
  ///
  /// In en, this message translates to:
  /// **'Search places in Hilla'**
  String get searchPlaces;

  /// No description provided for @noPlacesFound.
  ///
  /// In en, this message translates to:
  /// **'No places found. Try a shorter name or use Pin on map.'**
  String get noPlacesFound;

  /// No description provided for @searchAction.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchAction;

  /// No description provided for @searchPlacesHint.
  ///
  /// In en, this message translates to:
  /// **'Type in Arabic or English, then tap Search'**
  String get searchPlacesHint;

  /// No description provided for @searchFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Search or type English (hospital, market)'**
  String get searchFieldHint;

  /// No description provided for @searchTapPlaceHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a place in the list, or pick a category below'**
  String get searchTapPlaceHint;

  /// No description provided for @placesInHillaCount.
  ///
  /// In en, this message translates to:
  /// **'{count} places in Hilla'**
  String placesInHillaCount(int count);

  /// No description provided for @pinOnMap.
  ///
  /// In en, this message translates to:
  /// **'Pin on map'**
  String get pinOnMap;

  /// No description provided for @requestRide.
  ///
  /// In en, this message translates to:
  /// **'Request ride'**
  String get requestRide;

  /// No description provided for @searchingDriver.
  ///
  /// In en, this message translates to:
  /// **'Searching for a driver...'**
  String get searchingDriver;

  /// No description provided for @driverFound.
  ///
  /// In en, this message translates to:
  /// **'Driver on the way'**
  String get driverFound;

  /// No description provided for @noDriversAvailable.
  ///
  /// In en, this message translates to:
  /// **'No drivers available right now. Try again later.'**
  String get noDriversAvailable;

  /// No description provided for @liveDriverLocation.
  ///
  /// In en, this message translates to:
  /// **'Live driver location'**
  String get liveDriverLocation;

  /// No description provided for @driverRegistration.
  ///
  /// In en, this message translates to:
  /// **'Driver registration'**
  String get driverRegistration;

  /// No description provided for @vehicleType.
  ///
  /// In en, this message translates to:
  /// **'Vehicle type'**
  String get vehicleType;

  /// No description provided for @vehiclePlate.
  ///
  /// In en, this message translates to:
  /// **'Plate number'**
  String get vehiclePlate;

  /// No description provided for @licenseNumber.
  ///
  /// In en, this message translates to:
  /// **'License number'**
  String get licenseNumber;

  /// No description provided for @submitForApproval.
  ///
  /// In en, this message translates to:
  /// **'Submit for approval'**
  String get submitForApproval;

  /// No description provided for @pendingApprovalTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for manager approval'**
  String get pendingApprovalTitle;

  /// No description provided for @pendingApprovalBody.
  ///
  /// In en, this message translates to:
  /// **'Your account will be activated after a manager reviews your information.'**
  String get pendingApprovalBody;

  /// No description provided for @rejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Registration rejected'**
  String get rejectedTitle;

  /// No description provided for @goOnline.
  ///
  /// In en, this message translates to:
  /// **'Go online'**
  String get goOnline;

  /// No description provided for @goOffline.
  ///
  /// In en, this message translates to:
  /// **'Go offline'**
  String get goOffline;

  /// No description provided for @newRideRequest.
  ///
  /// In en, this message translates to:
  /// **'New ride request'**
  String get newRideRequest;

  /// No description provided for @acceptRide.
  ///
  /// In en, this message translates to:
  /// **'Accept ride'**
  String get acceptRide;

  /// No description provided for @rejectRide.
  ///
  /// In en, this message translates to:
  /// **'Reject ride'**
  String get rejectRide;

  /// No description provided for @activeRideExists.
  ///
  /// In en, this message translates to:
  /// **'You already have an active ride. Finish or cancel it before booking another.'**
  String get activeRideExists;

  /// No description provided for @managerTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver approvals'**
  String get managerTitle;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @noPendingDrivers.
  ///
  /// In en, this message translates to:
  /// **'No pending driver applications'**
  String get noPendingDrivers;

  /// No description provided for @noDriversYet.
  ///
  /// In en, this message translates to:
  /// **'No drivers registered yet.'**
  String get noDriversYet;

  /// No description provided for @pendingDriversLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load drivers. Publish Firestore rules from firestore.rules in Firebase Console → Firestore → Rules, then click Publish. Also confirm you are logged in as manager.'**
  String get pendingDriversLoadError;

  /// No description provided for @checkAllDriversTab.
  ///
  /// In en, this message translates to:
  /// **'Tip: open the All Drivers tab to see every registered driver.'**
  String get checkAllDriversTab;

  /// No description provided for @unnamedDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver (name not saved)'**
  String get unnamedDriver;

  /// No description provided for @routeToPickup.
  ///
  /// In en, this message translates to:
  /// **'To customer pickup'**
  String get routeToPickup;

  /// No description provided for @routeToDestination.
  ///
  /// In en, this message translates to:
  /// **'Pickup to destination'**
  String get routeToDestination;

  /// No description provided for @firebaseSetupRequired.
  ///
  /// In en, this message translates to:
  /// **'Firebase is not configured yet. Run: flutterfire configure'**
  String get firebaseSetupRequired;

  /// No description provided for @currentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get currentLocation;

  /// No description provided for @confirmLocation.
  ///
  /// In en, this message translates to:
  /// **'Confirm location'**
  String get confirmLocation;

  /// No description provided for @tapMapToPin.
  ///
  /// In en, this message translates to:
  /// **'Tap the map to choose a location'**
  String get tapMapToPin;

  /// No description provided for @rideFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get rideFrom;

  /// No description provided for @rideTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get rideTo;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @wrongRoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Wrong app for this account'**
  String get wrongRoleTitle;

  /// No description provided for @wrongRoleBody.
  ///
  /// In en, this message translates to:
  /// **'This app is for {expectedRole} accounts. You signed in as {actualRole}.'**
  String wrongRoleBody(String expectedRole, String actualRole);

  /// No description provided for @adminPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Hello Tuk-Tuk Admin'**
  String get adminPanelTitle;

  /// No description provided for @pendingDriversTab.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingDriversTab;

  /// No description provided for @activeRidesTab.
  ///
  /// In en, this message translates to:
  /// **'Active rides'**
  String get activeRidesTab;

  /// No description provided for @allDriversTab.
  ///
  /// In en, this message translates to:
  /// **'All drivers'**
  String get allDriversTab;

  /// No description provided for @rideHistoryTab.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get rideHistoryTab;

  /// No description provided for @noActiveRides.
  ///
  /// In en, this message translates to:
  /// **'No active rides'**
  String get noActiveRides;

  /// No description provided for @cashFare.
  ///
  /// In en, this message translates to:
  /// **'Cash fare'**
  String get cashFare;

  /// No description provided for @paymentMethodCash.
  ///
  /// In en, this message translates to:
  /// **'Payment: cash only'**
  String get paymentMethodCash;

  /// No description provided for @startRide.
  ///
  /// In en, this message translates to:
  /// **'Start ride'**
  String get startRide;

  /// No description provided for @endRide.
  ///
  /// In en, this message translates to:
  /// **'End ride'**
  String get endRide;

  /// No description provided for @cashCollected.
  ///
  /// In en, this message translates to:
  /// **'Cash collected'**
  String get cashCollected;

  /// No description provided for @waitingCustomerCashConfirm.
  ///
  /// In en, this message translates to:
  /// **'Waiting for customer cash confirmation'**
  String get waitingCustomerCashConfirm;

  /// No description provided for @payCash.
  ///
  /// In en, this message translates to:
  /// **'I paid cash'**
  String get payCash;

  /// No description provided for @cashPaymentConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Cash payment confirmed'**
  String get cashPaymentConfirmed;

  /// No description provided for @waitingForRides.
  ///
  /// In en, this message translates to:
  /// **'Waiting for ride requests'**
  String get waitingForRides;

  /// No description provided for @rideCompleted.
  ///
  /// In en, this message translates to:
  /// **'Ride completed'**
  String get rideCompleted;

  /// No description provided for @modeChooserSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how you want to use Hello Tuk-Tuk today'**
  String get modeChooserSubtitle;

  /// No description provided for @takeRide.
  ///
  /// In en, this message translates to:
  /// **'Take a ride'**
  String get takeRide;

  /// No description provided for @takeRideDesc.
  ///
  /// In en, this message translates to:
  /// **'Book a trip around Hilla city'**
  String get takeRideDesc;

  /// No description provided for @driveAndEarn.
  ///
  /// In en, this message translates to:
  /// **'Enter or register as driver'**
  String get driveAndEarn;

  /// No description provided for @driveAndEarnDesc.
  ///
  /// In en, this message translates to:
  /// **'Create your driver account and start accepting rides'**
  String get driveAndEarnDesc;

  /// No description provided for @accountAlreadyOpenElsewhere.
  ///
  /// In en, this message translates to:
  /// **'This account is already open on another phone. Log out there first, then try again.'**
  String get accountAlreadyOpenElsewhere;

  /// No description provided for @accountLoggedInElsewhere.
  ///
  /// In en, this message translates to:
  /// **'You were signed out because this account opened on another phone.'**
  String get accountLoggedInElsewhere;

  /// No description provided for @switchMode.
  ///
  /// In en, this message translates to:
  /// **'Switch mode'**
  String get switchMode;

  /// No description provided for @phoneLoginModeHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your phone to continue registration'**
  String get phoneLoginModeHint;

  /// No description provided for @managerAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'This admin panel is only for manager accounts.'**
  String get managerAccessDenied;

  /// No description provided for @phoneNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Iraqi phone number (9 digits after +964).'**
  String get phoneNumberInvalid;

  /// No description provided for @phoneHintExample.
  ///
  /// In en, this message translates to:
  /// **'7901234567'**
  String get phoneHintExample;

  /// No description provided for @phoneVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Phone verification failed. Check Firebase setup and try again.'**
  String get phoneVerificationFailed;

  /// No description provided for @webPhoneLoginHint.
  ///
  /// In en, this message translates to:
  /// **'On web, phone login needs Firebase configured and reCAPTCHA. For testing, use an Android phone or emulator.'**
  String get webPhoneLoginHint;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginTitle;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberMe;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginButton;

  /// No description provided for @createAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccountButton;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Check your phone and password.'**
  String get loginFailed;

  /// No description provided for @signupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signupTitle;

  /// No description provided for @emailOptional.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get emailOptional;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get passwordMinLength;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name.'**
  String get nameRequired;

  /// No description provided for @signupFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign up failed. Try a different phone number.'**
  String get signupFailed;

  /// No description provided for @resetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset link sent.'**
  String get resetEmailSent;

  /// No description provided for @resetFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send reset link.'**
  String get resetFailed;

  /// No description provided for @forgotPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone or email to reset your password.'**
  String get forgotPasswordHint;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// No description provided for @bookRideTitle.
  ///
  /// In en, this message translates to:
  /// **'Book ride'**
  String get bookRideTitle;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minutes;

  /// No description provided for @bookNowButton.
  ///
  /// In en, this message translates to:
  /// **'Book now'**
  String get bookNowButton;

  /// No description provided for @bookRideFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not complete booking. Check your connection and try again.'**
  String get bookRideFailed;

  /// No description provided for @currentRideTitle.
  ///
  /// In en, this message translates to:
  /// **'Current ride'**
  String get currentRideTitle;

  /// No description provided for @pickupDestinationRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose pickup and destination first.'**
  String get pickupDestinationRequired;

  /// No description provided for @pickupDestinationMustDiffer.
  ///
  /// In en, this message translates to:
  /// **'Pickup and destination must be different places (at least 100 m apart).'**
  String get pickupDestinationMustDiffer;

  /// No description provided for @districtLabel.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get districtLabel;

  /// No description provided for @subDistrictLabel.
  ///
  /// In en, this message translates to:
  /// **'Sub-district'**
  String get subDistrictLabel;

  /// No description provided for @selectSubDistrictHint.
  ///
  /// In en, this message translates to:
  /// **'Select sub-district'**
  String get selectSubDistrictHint;

  /// No description provided for @selectSubDistrictRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select your sub-district first.'**
  String get selectSubDistrictRequired;

  /// No description provided for @fixedCustomerDistrictLabel.
  ///
  /// In en, this message translates to:
  /// **'Al-Hashimiya District'**
  String get fixedCustomerDistrictLabel;

  /// No description provided for @whereTo.
  ///
  /// In en, this message translates to:
  /// **'Where to?'**
  String get whereTo;

  /// No description provided for @bookRideButton.
  ///
  /// In en, this message translates to:
  /// **'Book ride'**
  String get bookRideButton;

  /// No description provided for @findingDriverTitle.
  ///
  /// In en, this message translates to:
  /// **'Finding driver'**
  String get findingDriverTitle;

  /// No description provided for @findingDriverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notifying online drivers in your city. First to accept gets the ride.'**
  String get findingDriverSubtitle;

  /// No description provided for @driverAssignedTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver assigned'**
  String get driverAssignedTitle;

  /// No description provided for @waitingDriverAccept.
  ///
  /// In en, this message translates to:
  /// **'Waiting for driver to accept…'**
  String get waitingDriverAccept;

  /// No description provided for @trackDriverTitle.
  ///
  /// In en, this message translates to:
  /// **'Track driver'**
  String get trackDriverTitle;

  /// No description provided for @tripInProgress.
  ///
  /// In en, this message translates to:
  /// **'Trip in progress'**
  String get tripInProgress;

  /// No description provided for @tripCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip completed'**
  String get tripCompletedTitle;

  /// No description provided for @doneButton.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneButton;

  /// No description provided for @searchRegionHint.
  ///
  /// In en, this message translates to:
  /// **'Search is limited to {region}'**
  String searchRegionHint(String region);

  /// No description provided for @placesInRegionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} places in {region}'**
  String placesInRegionCount(int count, String region);

  /// No description provided for @searchOutsideRegion.
  ///
  /// In en, this message translates to:
  /// **'This location is outside the selected area.'**
  String get searchOutsideRegion;

  /// No description provided for @googleMapsKeyRequired.
  ///
  /// In en, this message translates to:
  /// **'Add your Google Maps API key to enable online search.'**
  String get googleMapsKeyRequired;

  /// No description provided for @placesApiDenied.
  ///
  /// In en, this message translates to:
  /// **'Online place search is limited. Results below use OpenStreetMap for this area.'**
  String get placesApiDenied;

  /// No description provided for @locatingCurrentPosition.
  ///
  /// In en, this message translates to:
  /// **'Getting your location…'**
  String get locatingCurrentPosition;

  /// No description provided for @searchUsingOpenStreetMap.
  ///
  /// In en, this message translates to:
  /// **'Showing places from OpenStreetMap in this area.'**
  String get searchUsingOpenStreetMap;

  /// No description provided for @locationServiceDisabled.
  ///
  /// In en, this message translates to:
  /// **'Turn on location (GPS) in your phone settings.'**
  String get locationServiceDisabled;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required. Allow it in app settings.'**
  String get locationPermissionDenied;

  /// No description provided for @locationFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not get GPS location. Tap the location icon to try again.'**
  String get locationFetchFailed;

  /// No description provided for @authEmailPasswordDisabled.
  ///
  /// In en, this message translates to:
  /// **'Enable Email/Password in Firebase Console: Authentication → Sign-in method → Email/Password → Enable.'**
  String get authEmailPasswordDisabled;

  /// No description provided for @authEmailAlreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'This phone number is already registered. Try logging in instead.'**
  String get authEmailAlreadyInUse;

  /// No description provided for @restoreProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore your account'**
  String get restoreProfileTitle;

  /// No description provided for @restoreProfileMessage.
  ///
  /// In en, this message translates to:
  /// **'Your login is still active but your profile data was removed from the server. Enter your name below to restore access.'**
  String get restoreProfileMessage;

  /// No description provided for @restoreProfileRoleHint.
  ///
  /// In en, this message translates to:
  /// **'Account type: {role}'**
  String restoreProfileRoleHint(String role);

  /// No description provided for @restoreProfileAction.
  ///
  /// In en, this message translates to:
  /// **'Restore account'**
  String get restoreProfileAction;

  /// No description provided for @useDifferentAccount.
  ///
  /// In en, this message translates to:
  /// **'Use a different account'**
  String get useDifferentAccount;

  /// No description provided for @assistantProfileMissingHint.
  ///
  /// In en, this message translates to:
  /// **'Assistant accounts must be recreated by the manager from the admin panel.'**
  String get assistantProfileMissingHint;

  /// No description provided for @authTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a few minutes and try again.'**
  String get authTooManyRequests;

  /// No description provided for @authNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your internet connection and try again.'**
  String get authNetworkError;

  /// No description provided for @dragMapToSelectPin.
  ///
  /// In en, this message translates to:
  /// **'Drag the map to move the pin to your location.'**
  String get dragMapToSelectPin;

  /// No description provided for @pinStreetNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Could not read the street name. Move the pin slightly and try again.'**
  String get pinStreetNameRequired;

  /// No description provided for @outOfServiceZone.
  ///
  /// In en, this message translates to:
  /// **'Out of Service Zone'**
  String get outOfServiceZone;

  /// No description provided for @calculatingFare.
  ///
  /// In en, this message translates to:
  /// **'Calculating fare…'**
  String get calculatingFare;

  /// No description provided for @fareCalculationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not calculate the fare. Check your connection and try again.'**
  String get fareCalculationFailed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @drivingDistance.
  ///
  /// In en, this message translates to:
  /// **'Driving distance'**
  String get drivingDistance;

  /// No description provided for @maxDistanceLimit.
  ///
  /// In en, this message translates to:
  /// **'Maximum ride distance is {km} km.'**
  String maxDistanceLimit(String km);

  /// No description provided for @pricingTab.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get pricingTab;

  /// No description provided for @pricingRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Pricing rules'**
  String get pricingRulesTitle;

  /// No description provided for @pricingRulesHint.
  ///
  /// In en, this message translates to:
  /// **'Fares use Google Maps driving distance. Rides above the maximum distance are blocked.'**
  String get pricingRulesHint;

  /// No description provided for @maxDistanceKmLabel.
  ///
  /// In en, this message translates to:
  /// **'Maximum distance'**
  String get maxDistanceKmLabel;

  /// No description provided for @priceBracketsTitle.
  ///
  /// In en, this message translates to:
  /// **'Distance brackets'**
  String get priceBracketsTitle;

  /// No description provided for @fromKm.
  ///
  /// In en, this message translates to:
  /// **'From (km)'**
  String get fromKm;

  /// No description provided for @toKm.
  ///
  /// In en, this message translates to:
  /// **'To (km)'**
  String get toKm;

  /// No description provided for @priceIqd.
  ///
  /// In en, this message translates to:
  /// **'Price (IQD)'**
  String get priceIqd;

  /// No description provided for @savePricingRules.
  ///
  /// In en, this message translates to:
  /// **'Save pricing rules'**
  String get savePricingRules;

  /// No description provided for @pricingSaved.
  ///
  /// In en, this message translates to:
  /// **'Pricing rules saved.'**
  String get pricingSaved;

  /// No description provided for @pricingSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save pricing rules. Check the values and try again.'**
  String get pricingSaveFailed;

  /// No description provided for @pricingSavePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Save blocked by Firebase. Deploy the latest firestore.rules and Cloud Functions (savePricingConfig), then confirm your account role in the users collection is manager or assistant with pricing permission.'**
  String get pricingSavePermissionDenied;

  /// No description provided for @pricingInvalidValues.
  ///
  /// In en, this message translates to:
  /// **'Check all distance and price fields use valid numbers.'**
  String get pricingInvalidValues;

  /// No description provided for @estimatedDistanceNote.
  ///
  /// In en, this message translates to:
  /// **'Approximate distance — exact route could not be loaded.'**
  String get estimatedDistanceNote;

  /// No description provided for @noRideHistory.
  ///
  /// In en, this message translates to:
  /// **'No ride history yet.'**
  String get noRideHistory;

  /// No description provided for @chatWithDriver.
  ///
  /// In en, this message translates to:
  /// **'Chat with driver'**
  String get chatWithDriver;

  /// No description provided for @chatWithCustomer.
  ///
  /// In en, this message translates to:
  /// **'Chat with customer'**
  String get chatWithCustomer;

  /// No description provided for @noChatMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Say hello!'**
  String get noChatMessages;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message…'**
  String get typeMessage;

  /// No description provided for @holdToRecordVoice.
  ///
  /// In en, this message translates to:
  /// **'Tap mic to record voice'**
  String get holdToRecordVoice;

  /// No description provided for @tapToRecordVoice.
  ///
  /// In en, this message translates to:
  /// **'Tap to record'**
  String get tapToRecordVoice;

  /// No description provided for @stopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop & send'**
  String get stopRecording;

  /// No description provided for @voiceMessageTooShort.
  ///
  /// In en, this message translates to:
  /// **'Hold the mic a little longer, then tap stop.'**
  String get voiceMessageTooShort;

  /// No description provided for @recordingVoice.
  ///
  /// In en, this message translates to:
  /// **'Recording…'**
  String get recordingVoice;

  /// No description provided for @voiceMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get voiceMessageLabel;

  /// No description provided for @microphonePermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required for voice messages.'**
  String get microphonePermissionRequired;

  /// No description provided for @voiceMessageSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send voice message. Try again.'**
  String get voiceMessageSendFailed;

  /// No description provided for @voiceMessagePlaybackFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not play voice message.'**
  String get voiceMessagePlaybackFailed;

  /// No description provided for @messageSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send message. Check your connection and try again.'**
  String get messageSendFailed;

  /// No description provided for @chatLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load chat messages.'**
  String get chatLoadFailed;

  /// No description provided for @microphonePermissionWebHint.
  ///
  /// In en, this message translates to:
  /// **'Allow microphone access in your browser settings, then try again.'**
  String get microphonePermissionWebHint;

  /// No description provided for @driverWorkDistrictLabel.
  ///
  /// In en, this message translates to:
  /// **'Work city'**
  String get driverWorkDistrictLabel;

  /// No description provided for @driverWorkDistrictHint.
  ///
  /// In en, this message translates to:
  /// **'Assign this driver to a city. They receive ride requests only in that city. First driver to accept gets the ride.'**
  String get driverWorkDistrictHint;

  /// No description provided for @driverWorkDistrictRequired.
  ///
  /// In en, this message translates to:
  /// **'Manager must assign a work city before this driver can receive rides.'**
  String get driverWorkDistrictRequired;

  /// No description provided for @driverWorkDistrictSaved.
  ///
  /// In en, this message translates to:
  /// **'Driver work city updated.'**
  String get driverWorkDistrictSaved;

  /// No description provided for @saveDriverWorkDistrict.
  ///
  /// In en, this message translates to:
  /// **'Save work city'**
  String get saveDriverWorkDistrict;

  /// No description provided for @noDriversInDistrict.
  ///
  /// In en, this message translates to:
  /// **'No drivers are online in this city right now. Ask the manager to assign drivers to this area.'**
  String get noDriversInDistrict;

  /// No description provided for @openChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get openChat;

  /// No description provided for @supportTitle.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get supportTitle;

  /// No description provided for @contactManagement.
  ///
  /// In en, this message translates to:
  /// **'Contact management'**
  String get contactManagement;

  /// No description provided for @supportMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Describe your issue or question…'**
  String get supportMessageHint;

  /// No description provided for @supportSent.
  ///
  /// In en, this message translates to:
  /// **'Message sent to management.'**
  String get supportSent;

  /// No description provided for @callSupport.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get callSupport;

  /// No description provided for @whatsappSupport.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp support'**
  String get whatsappSupport;

  /// No description provided for @emailSupport.
  ///
  /// In en, this message translates to:
  /// **'Email support'**
  String get emailSupport;

  /// No description provided for @legalDocuments.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legalDocuments;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @managementReply.
  ///
  /// In en, this message translates to:
  /// **'Management'**
  String get managementReply;

  /// No description provided for @supportInboxTab.
  ///
  /// In en, this message translates to:
  /// **'Support inbox'**
  String get supportInboxTab;

  /// No description provided for @noSupportMessages.
  ///
  /// In en, this message translates to:
  /// **'No support messages yet.'**
  String get noSupportMessages;

  /// No description provided for @replyToUser.
  ///
  /// In en, this message translates to:
  /// **'Reply to user…'**
  String get replyToUser;

  /// No description provided for @closeThread.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeThread;

  /// No description provided for @driverHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver history'**
  String get driverHistoryTitle;

  /// No description provided for @viewDriverHistory.
  ///
  /// In en, this message translates to:
  /// **'View ride history'**
  String get viewDriverHistory;

  /// No description provided for @earningsTab.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earningsTab;

  /// No description provided for @commissionSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform commission'**
  String get commissionSettingsTitle;

  /// No description provided for @commissionSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Set the percentage the platform keeps from each completed ride fare. This applies to all drivers.'**
  String get commissionSettingsHint;

  /// No description provided for @platformPercentLabel.
  ///
  /// In en, this message translates to:
  /// **'Commission percentage'**
  String get platformPercentLabel;

  /// No description provided for @saveCommissionSettings.
  ///
  /// In en, this message translates to:
  /// **'Save commission'**
  String get saveCommissionSettings;

  /// No description provided for @commissionSaved.
  ///
  /// In en, this message translates to:
  /// **'Commission settings saved.'**
  String get commissionSaved;

  /// No description provided for @commissionSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save commission. Enter a value between 0 and 100.'**
  String get commissionSaveFailed;

  /// No description provided for @totalPlatformProfit.
  ///
  /// In en, this message translates to:
  /// **'Total platform profit'**
  String get totalPlatformProfit;

  /// No description provided for @managerProfitByDriver.
  ///
  /// In en, this message translates to:
  /// **'Profit by driver'**
  String get managerProfitByDriver;

  /// No description provided for @managerProfitFromDriver.
  ///
  /// In en, this message translates to:
  /// **'Your profit'**
  String get managerProfitFromDriver;

  /// No description provided for @driverNetEarnings.
  ///
  /// In en, this message translates to:
  /// **'Driver earnings'**
  String get driverNetEarnings;

  /// No description provided for @platformCommission.
  ///
  /// In en, this message translates to:
  /// **'Platform commission'**
  String get platformCommission;

  /// No description provided for @outstandingProfitLabel.
  ///
  /// In en, this message translates to:
  /// **'Outstanding profit'**
  String get outstandingProfitLabel;

  /// No description provided for @outstandingProfitTotal.
  ///
  /// In en, this message translates to:
  /// **'Total outstanding profit'**
  String get outstandingProfitTotal;

  /// No description provided for @lifetimeProfitLabel.
  ///
  /// In en, this message translates to:
  /// **'Lifetime profit'**
  String get lifetimeProfitLabel;

  /// No description provided for @lifetimeProfitTotal.
  ///
  /// In en, this message translates to:
  /// **'Total lifetime profit'**
  String get lifetimeProfitTotal;

  /// No description provided for @owedToPlatformLabel.
  ///
  /// In en, this message translates to:
  /// **'Owed to platform'**
  String get owedToPlatformLabel;

  /// No description provided for @lastProfitReceivedLabel.
  ///
  /// In en, this message translates to:
  /// **'Last profit received'**
  String get lastProfitReceivedLabel;

  /// No description provided for @receivedProfitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm profit received'**
  String get receivedProfitsTitle;

  /// No description provided for @receivedProfitsAction.
  ///
  /// In en, this message translates to:
  /// **'Profits received'**
  String get receivedProfitsAction;

  /// No description provided for @receivedProfitsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm you received {amount} from this driver. Their outstanding balance will reset to zero for the next rides.'**
  String receivedProfitsConfirm(String amount);

  /// No description provided for @receivedProfitsSuccess.
  ///
  /// In en, this message translates to:
  /// **'Profit received. Outstanding balance reset.'**
  String get receivedProfitsSuccess;

  /// No description provided for @driverBonusesTab.
  ///
  /// In en, this message translates to:
  /// **'Bonuses'**
  String get driverBonusesTab;

  /// No description provided for @driverBonusesHint.
  ///
  /// In en, this message translates to:
  /// **'Grant bonuses to drivers and mark them as paid when you pay out.'**
  String get driverBonusesHint;

  /// No description provided for @grantBonusQuickTitle.
  ///
  /// In en, this message translates to:
  /// **'Grant bonus to driver'**
  String get grantBonusQuickTitle;

  /// No description provided for @grantBonusTitle.
  ///
  /// In en, this message translates to:
  /// **'Grant bonus'**
  String get grantBonusTitle;

  /// No description provided for @grantBonusHint.
  ///
  /// In en, this message translates to:
  /// **'Add a bonus for {driverName}.'**
  String grantBonusHint(String driverName);

  /// No description provided for @grantBonusAction.
  ///
  /// In en, this message translates to:
  /// **'Grant bonus'**
  String get grantBonusAction;

  /// No description provided for @bonusAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Bonus amount'**
  String get bonusAmountLabel;

  /// No description provided for @bonusReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get bonusReasonLabel;

  /// No description provided for @bonusAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid bonus amount.'**
  String get bonusAmountInvalid;

  /// No description provided for @bonusGranted.
  ///
  /// In en, this message translates to:
  /// **'Bonus granted.'**
  String get bonusGranted;

  /// No description provided for @pendingBonusLabel.
  ///
  /// In en, this message translates to:
  /// **'Pending bonus'**
  String get pendingBonusLabel;

  /// No description provided for @pendingBonusesTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending bonuses'**
  String get pendingBonusesTitle;

  /// No description provided for @noPendingBonuses.
  ///
  /// In en, this message translates to:
  /// **'No pending bonuses.'**
  String get noPendingBonuses;

  /// No description provided for @markBonusPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark paid'**
  String get markBonusPaid;

  /// No description provided for @bonusMarkedPaid.
  ///
  /// In en, this message translates to:
  /// **'Bonus marked as paid.'**
  String get bonusMarkedPaid;

  /// No description provided for @completedRidesCount.
  ///
  /// In en, this message translates to:
  /// **'Completed rides'**
  String get completedRidesCount;

  /// No description provided for @yourEarningsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your earnings'**
  String get yourEarningsTitle;

  /// No description provided for @rideEarningsManager.
  ///
  /// In en, this message translates to:
  /// **'Fare {fare} • Your profit {profit} ({percent}%)'**
  String rideEarningsManager(String fare, String profit, String percent);

  /// No description provided for @rideEarningsDriver.
  ///
  /// In en, this message translates to:
  /// **'You keep {net} • Platform fee {fee} ({percent}%)'**
  String rideEarningsDriver(String net, String fee, String percent);

  /// No description provided for @idPhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'ID photo'**
  String get idPhotoLabel;

  /// No description provided for @profilePhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'Profile photo'**
  String get profilePhotoLabel;

  /// No description provided for @pickFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get pickFromGallery;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get takePhoto;

  /// No description provided for @driverTermsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms to work with Hello Tuk-Tuk'**
  String get driverTermsTitle;

  /// No description provided for @driverTermsBody.
  ///
  /// In en, this message translates to:
  /// **'You agree to follow app rules, provide safe rides, collect cash fares honestly, and accept that the manager may review your documents and block your account for repeated cancellations or violations.'**
  String get driverTermsBody;

  /// No description provided for @acceptDriverTerms.
  ///
  /// In en, this message translates to:
  /// **'I accept the terms to work with this app'**
  String get acceptDriverTerms;

  /// No description provided for @registrationFieldsRequired.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all required fields.'**
  String get registrationFieldsRequired;

  /// No description provided for @vehiclePlateOptional.
  ///
  /// In en, this message translates to:
  /// **'Plate number (optional)'**
  String get vehiclePlateOptional;

  /// No description provided for @licenseNumberOptional.
  ///
  /// In en, this message translates to:
  /// **'License number (optional)'**
  String get licenseNumberOptional;

  /// No description provided for @registrationPhotosRequired.
  ///
  /// In en, this message translates to:
  /// **'Please upload your ID photo and your personal photo.'**
  String get registrationPhotosRequired;

  /// No description provided for @registrationTermsRequired.
  ///
  /// In en, this message translates to:
  /// **'You must accept the terms before submitting.'**
  String get registrationTermsRequired;

  /// No description provided for @registrationSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not submit registration. Check your connection and try again.'**
  String get registrationSubmitFailed;

  /// No description provided for @photoPickFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the photo. Allow camera or gallery permission and try again.'**
  String get photoPickFailed;

  /// No description provided for @registrationStorageRulesHint.
  ///
  /// In en, this message translates to:
  /// **'Photo upload blocked by Firebase. Open Firebase Console → Storage → Rules, paste storage.rules from the project, then Publish.'**
  String get registrationStorageRulesHint;

  /// No description provided for @customersTab.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customersTab;

  /// No description provided for @noCustomers.
  ///
  /// In en, this message translates to:
  /// **'No customers yet.'**
  String get noCustomers;

  /// No description provided for @blockUser.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get blockUser;

  /// No description provided for @unblockUser.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblockUser;

  /// No description provided for @removeDriver.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get removeDriver;

  /// No description provided for @removeDriverConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this driver account?'**
  String get removeDriverConfirmTitle;

  /// No description provided for @removeDriverConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes their profile from the app. They can use Forgot Password, then log in with the same phone to set up again.'**
  String get removeDriverConfirmMessage;

  /// No description provided for @driverRemoved.
  ///
  /// In en, this message translates to:
  /// **'Driver account deleted.'**
  String get driverRemoved;

  /// No description provided for @removeDriverFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete driver account. Try again.'**
  String get removeDriverFailed;

  /// No description provided for @deleteCustomer.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteCustomer;

  /// No description provided for @removeCustomerConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this customer account?'**
  String get removeCustomerConfirmTitle;

  /// No description provided for @removeCustomerConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes their profile from the app. They can use Forgot Password, then log in with the same phone to set up again.'**
  String get removeCustomerConfirmMessage;

  /// No description provided for @customerRemoved.
  ///
  /// In en, this message translates to:
  /// **'Customer account deleted.'**
  String get customerRemoved;

  /// No description provided for @removeCustomerFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete customer account. Try again.'**
  String get removeCustomerFailed;

  /// No description provided for @accountReleasedSignupHint.
  ///
  /// In en, this message translates to:
  /// **'This phone was reset by the manager. Use Forgot Password to set a new password, then log in to create your profile again.'**
  String get accountReleasedSignupHint;

  /// No description provided for @blockedLabel.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get blockedLabel;

  /// No description provided for @accountBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Account blocked'**
  String get accountBlockedTitle;

  /// No description provided for @driverBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'Your driver account has been blocked by management. Contact support if you think this is a mistake.'**
  String get driverBlockedBody;

  /// No description provided for @customerBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'Your account has been blocked by management because of repeated ride cancellations or other violations. Contact support for help.'**
  String get customerBlockedBody;

  /// No description provided for @cancelledRidesCount.
  ///
  /// In en, this message translates to:
  /// **'Cancelled rides'**
  String get cancelledRidesCount;

  /// No description provided for @noDriverPhotos.
  ///
  /// In en, this message translates to:
  /// **'No photos uploaded.'**
  String get noDriverPhotos;

  /// No description provided for @addBracket.
  ///
  /// In en, this message translates to:
  /// **'Add bracket'**
  String get addBracket;

  /// No description provided for @removeBracket.
  ///
  /// In en, this message translates to:
  /// **'Remove bracket'**
  String get removeBracket;

  /// No description provided for @liveMapTab.
  ///
  /// In en, this message translates to:
  /// **'Live map'**
  String get liveMapTab;

  /// No description provided for @tripDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip details'**
  String get tripDetailsTitle;

  /// No description provided for @customerDetails.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customerDetails;

  /// No description provided for @driverDetails.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get driverDetails;

  /// No description provided for @noDriverAssigned.
  ///
  /// In en, this message translates to:
  /// **'No driver assigned yet.'**
  String get noDriverAssigned;

  /// No description provided for @managerProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Manager profile'**
  String get managerProfileTitle;

  /// No description provided for @noLocationYet.
  ///
  /// In en, this message translates to:
  /// **'Location not available'**
  String get noLocationYet;

  /// No description provided for @noOnlineDrivers.
  ///
  /// In en, this message translates to:
  /// **'No drivers online right now.'**
  String get noOnlineDrivers;

  /// No description provided for @tripMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip map'**
  String get tripMapTitle;

  /// No description provided for @tripStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Trip status'**
  String get tripStatusLabel;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @myProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'My profile'**
  String get myProfileTitle;

  /// No description provided for @myTripsTitle.
  ///
  /// In en, this message translates to:
  /// **'My trips'**
  String get myTripsTitle;

  /// No description provided for @accountInformation.
  ///
  /// In en, this message translates to:
  /// **'Account information'**
  String get accountInformation;

  /// No description provided for @accountTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Account type'**
  String get accountTypeLabel;

  /// No description provided for @registeredAt.
  ///
  /// In en, this message translates to:
  /// **'Registered'**
  String get registeredAt;

  /// No description provided for @tripDateTime.
  ///
  /// In en, this message translates to:
  /// **'Date & time'**
  String get tripDateTime;

  /// No description provided for @tripHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'Your completed and cancelled trips with date and time.'**
  String get tripHistoryHint;

  /// No description provided for @totalTripsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} completed trips'**
  String totalTripsCount(int count);

  /// No description provided for @rateDriverTitle.
  ///
  /// In en, this message translates to:
  /// **'Rate your driver'**
  String get rateDriverTitle;

  /// No description provided for @rateDriverHint.
  ///
  /// In en, this message translates to:
  /// **'How was your trip?'**
  String get rateDriverHint;

  /// No description provided for @driverFeedbackLabel.
  ///
  /// In en, this message translates to:
  /// **'Feedback (optional)'**
  String get driverFeedbackLabel;

  /// No description provided for @driverFeedbackHint.
  ///
  /// In en, this message translates to:
  /// **'Share your experience with the driver'**
  String get driverFeedbackHint;

  /// No description provided for @submitRating.
  ///
  /// In en, this message translates to:
  /// **'Submit rating'**
  String get submitRating;

  /// No description provided for @ratingSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your feedback!'**
  String get ratingSubmitted;

  /// No description provided for @driverReviewsTab.
  ///
  /// In en, this message translates to:
  /// **'Driver reviews'**
  String get driverReviewsTab;

  /// No description provided for @noDriverReviews.
  ///
  /// In en, this message translates to:
  /// **'No driver reviews yet'**
  String get noDriverReviews;

  /// No description provided for @driverLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get driverLabel;

  /// No description provided for @customerLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customerLabel;

  /// No description provided for @unknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownUser;

  /// No description provided for @feedbackLabel.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedbackLabel;

  /// No description provided for @awaitingPayment.
  ///
  /// In en, this message translates to:
  /// **'Awaiting payment confirmation'**
  String get awaitingPayment;

  /// No description provided for @cityPricingLabel.
  ///
  /// In en, this message translates to:
  /// **'City / district'**
  String get cityPricingLabel;

  /// No description provided for @roleAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get roleAssistant;

  /// No description provided for @assistantsTab.
  ///
  /// In en, this message translates to:
  /// **'Assistants'**
  String get assistantsTab;

  /// No description provided for @assistantsTabHint.
  ///
  /// In en, this message translates to:
  /// **'Create dashboard accounts for your team with limited permissions.'**
  String get assistantsTabHint;

  /// No description provided for @createAssistantTitle.
  ///
  /// In en, this message translates to:
  /// **'New assistant account'**
  String get createAssistantTitle;

  /// No description provided for @createAssistantButton.
  ///
  /// In en, this message translates to:
  /// **'Create assistant'**
  String get createAssistantButton;

  /// No description provided for @assistantPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Allowed activities'**
  String get assistantPermissionsTitle;

  /// No description provided for @assistantFormInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter name, valid email, and password (6+ characters).'**
  String get assistantFormInvalid;

  /// No description provided for @assistantCreated.
  ///
  /// In en, this message translates to:
  /// **'Assistant account created.'**
  String get assistantCreated;

  /// No description provided for @assistantCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create assistant.'**
  String get assistantCreateFailed;

  /// No description provided for @existingAssistantsTitle.
  ///
  /// In en, this message translates to:
  /// **'Team members'**
  String get existingAssistantsTitle;

  /// No description provided for @noAssistantsYet.
  ///
  /// In en, this message translates to:
  /// **'No assistants yet.'**
  String get noAssistantsYet;

  /// No description provided for @editAssistantPermissions.
  ///
  /// In en, this message translates to:
  /// **'Edit permissions'**
  String get editAssistantPermissions;

  /// No description provided for @assistantLoginHint.
  ///
  /// In en, this message translates to:
  /// **'Use the email and password your manager gave you.'**
  String get assistantLoginHint;

  /// No description provided for @assistantNoPermissions.
  ///
  /// In en, this message translates to:
  /// **'Your account has no dashboard permissions. Contact the manager.'**
  String get assistantNoPermissions;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @permPendingDrivers.
  ///
  /// In en, this message translates to:
  /// **'Approve pending drivers'**
  String get permPendingDrivers;

  /// No description provided for @permActiveRides.
  ///
  /// In en, this message translates to:
  /// **'View active rides'**
  String get permActiveRides;

  /// No description provided for @permLiveMap.
  ///
  /// In en, this message translates to:
  /// **'View live map'**
  String get permLiveMap;

  /// No description provided for @permAllDrivers.
  ///
  /// In en, this message translates to:
  /// **'View all drivers'**
  String get permAllDrivers;

  /// No description provided for @permCustomers.
  ///
  /// In en, this message translates to:
  /// **'Manage customers'**
  String get permCustomers;

  /// No description provided for @permRideHistory.
  ///
  /// In en, this message translates to:
  /// **'View ride history'**
  String get permRideHistory;

  /// No description provided for @permPricing.
  ///
  /// In en, this message translates to:
  /// **'Edit city pricing'**
  String get permPricing;

  /// No description provided for @permEarnings.
  ///
  /// In en, this message translates to:
  /// **'View earnings & commission'**
  String get permEarnings;

  /// No description provided for @permDriverReviews.
  ///
  /// In en, this message translates to:
  /// **'View driver reviews'**
  String get permDriverReviews;

  /// No description provided for @permSupportInbox.
  ///
  /// In en, this message translates to:
  /// **'Support inbox'**
  String get permSupportInbox;

  /// No description provided for @permManageAssistants.
  ///
  /// In en, this message translates to:
  /// **'Manage assistants'**
  String get permManageAssistants;

  /// No description provided for @filterByCity.
  ///
  /// In en, this message translates to:
  /// **'Filter by city'**
  String get filterByCity;

  /// No description provided for @allCities.
  ///
  /// In en, this message translates to:
  /// **'All cities'**
  String get allCities;

  /// No description provided for @filterBySubDistrict.
  ///
  /// In en, this message translates to:
  /// **'Filter by sub-district'**
  String get filterBySubDistrict;

  /// No description provided for @allSubDistricts.
  ///
  /// In en, this message translates to:
  /// **'All sub-districts'**
  String get allSubDistricts;

  /// No description provided for @filterByMonth.
  ///
  /// In en, this message translates to:
  /// **'Filter by month'**
  String get filterByMonth;

  /// No description provided for @allMonths.
  ///
  /// In en, this message translates to:
  /// **'All months'**
  String get allMonths;

  /// No description provided for @tripsInMonth.
  ///
  /// In en, this message translates to:
  /// **'{count} trips'**
  String tripsInMonth(int count);

  /// No description provided for @supportContactSettings.
  ///
  /// In en, this message translates to:
  /// **'Support contact'**
  String get supportContactSettings;

  /// No description provided for @supportPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Support phone number'**
  String get supportPhoneLabel;

  /// No description provided for @supportWhatsappLabel.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp number'**
  String get supportWhatsappLabel;

  /// No description provided for @supportEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Support email'**
  String get supportEmailLabel;

  /// No description provided for @saveSupportContact.
  ///
  /// In en, this message translates to:
  /// **'Save contact'**
  String get saveSupportContact;

  /// No description provided for @supportContactSaved.
  ///
  /// In en, this message translates to:
  /// **'Support contact saved.'**
  String get supportContactSaved;

  /// No description provided for @pricingUsingDefaultsHint.
  ///
  /// In en, this message translates to:
  /// **'Showing default prices for this city. Edit the values below and click Save to store them in Firebase.'**
  String get pricingUsingDefaultsHint;

  /// No description provided for @pricingForCity.
  ///
  /// In en, this message translates to:
  /// **'Prices for {city}'**
  String pricingForCity(String city);

  /// No description provided for @pricingDistrictDefault.
  ///
  /// In en, this message translates to:
  /// **'District default (all sub-districts)'**
  String get pricingDistrictDefault;

  /// No description provided for @pricingForArea.
  ///
  /// In en, this message translates to:
  /// **'Prices for {district} — {subDistrict}'**
  String pricingForArea(String district, String subDistrict);

  /// No description provided for @pricingSubDistrictFallbackHint.
  ///
  /// In en, this message translates to:
  /// **'If no sub-district prices are saved, the district default prices are used for rides.'**
  String get pricingSubDistrictFallbackHint;

  /// No description provided for @promoCodesTab.
  ///
  /// In en, this message translates to:
  /// **'Promo codes'**
  String get promoCodesTab;

  /// No description provided for @promoCodesHint.
  ///
  /// In en, this message translates to:
  /// **'New customers automatically receive the FREE3 code when auto-assign is enabled.'**
  String get promoCodesHint;

  /// No description provided for @promoCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Promo code'**
  String get promoCodeLabel;

  /// No description provided for @promoCodeActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get promoCodeActive;

  /// No description provided for @promoEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Promo enabled'**
  String get promoEnabledLabel;

  /// No description provided for @promoEnabledHint.
  ///
  /// In en, this message translates to:
  /// **'Turn off to stop discounts without deleting the code.'**
  String get promoEnabledHint;

  /// No description provided for @promoAutoAssignLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto-assign on signup'**
  String get promoAutoAssignLabel;

  /// No description provided for @promoAutoAssignHint.
  ///
  /// In en, this message translates to:
  /// **'Give this code to every new customer account.'**
  String get promoAutoAssignHint;

  /// No description provided for @promoDiscountPercentLabel.
  ///
  /// In en, this message translates to:
  /// **'Discount percent'**
  String get promoDiscountPercentLabel;

  /// No description provided for @promoMaxDiscountLabel.
  ///
  /// In en, this message translates to:
  /// **'Max discount per ride'**
  String get promoMaxDiscountLabel;

  /// No description provided for @promoMaxRidesLabel.
  ///
  /// In en, this message translates to:
  /// **'Discounted rides per customer'**
  String get promoMaxRidesLabel;

  /// No description provided for @promoDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get promoDescriptionLabel;

  /// No description provided for @savePromoCode.
  ///
  /// In en, this message translates to:
  /// **'Save promo code'**
  String get savePromoCode;

  /// No description provided for @promoCodeSaved.
  ///
  /// In en, this message translates to:
  /// **'Promo code saved.'**
  String get promoCodeSaved;

  /// No description provided for @promoDiscountApplied.
  ///
  /// In en, this message translates to:
  /// **'{code}: you save {amount}'**
  String promoDiscountApplied(String code, String amount);

  /// No description provided for @monthlyLeaderboardTab.
  ///
  /// In en, this message translates to:
  /// **'Monthly prize leaderboard'**
  String get monthlyLeaderboardTab;

  /// No description provided for @monthlyLeaderboardMonth.
  ///
  /// In en, this message translates to:
  /// **'Month: {monthKey}'**
  String monthlyLeaderboardMonth(String monthKey);

  /// No description provided for @monthlyPrizeAmount.
  ///
  /// In en, this message translates to:
  /// **'Prize: {amount}'**
  String monthlyPrizeAmount(String amount);

  /// No description provided for @leaderboardRideCount.
  ///
  /// In en, this message translates to:
  /// **'{count} rides this month'**
  String leaderboardRideCount(int count);

  /// No description provided for @leaderboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'No completed rides this month yet.'**
  String get leaderboardEmpty;

  /// No description provided for @markAsWinner.
  ///
  /// In en, this message translates to:
  /// **'Mark as winner'**
  String get markAsWinner;

  /// No description provided for @markAsPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark as paid'**
  String get markAsPaid;

  /// No description provided for @resetMonthlyCounter.
  ///
  /// In en, this message translates to:
  /// **'Reset monthly counter'**
  String get resetMonthlyCounter;

  /// No description provided for @resetMonthlyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reset all driver ride counts for the new month? This clears the current winner.'**
  String get resetMonthlyConfirm;

  /// No description provided for @leaderboardWinnerMarked.
  ///
  /// In en, this message translates to:
  /// **'Winner marked.'**
  String get leaderboardWinnerMarked;

  /// No description provided for @leaderboardPaidMarked.
  ///
  /// In en, this message translates to:
  /// **'Prize marked as paid.'**
  String get leaderboardPaidMarked;

  /// No description provided for @leaderboardResetDone.
  ///
  /// In en, this message translates to:
  /// **'Monthly counters reset.'**
  String get leaderboardResetDone;

  /// No description provided for @leaderboardWinnerBadge.
  ///
  /// In en, this message translates to:
  /// **'Winner'**
  String get leaderboardWinnerBadge;

  /// No description provided for @leaderboardPaidBadge.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get leaderboardPaidBadge;

  /// No description provided for @leaderboardCurrentWinner.
  ///
  /// In en, this message translates to:
  /// **'Current winner: {name}'**
  String leaderboardCurrentWinner(String name);

  /// No description provided for @permPromoCodes.
  ///
  /// In en, this message translates to:
  /// **'Manage promo codes'**
  String get permPromoCodes;

  /// No description provided for @permMonthlyLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Monthly prize leaderboard'**
  String get permMonthlyLeaderboard;

  /// No description provided for @driverMonthlyPrizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly prize challenge'**
  String get driverMonthlyPrizeTitle;

  /// No description provided for @driverMonthlyRideCount.
  ///
  /// In en, this message translates to:
  /// **'{count} rides this month'**
  String driverMonthlyRideCount(int count);

  /// No description provided for @driverMonthlyRank.
  ///
  /// In en, this message translates to:
  /// **'You are #{rank} this month — {count} rides'**
  String driverMonthlyRank(int rank, int count);

  /// No description provided for @driverMonthlyPrizeAmount.
  ///
  /// In en, this message translates to:
  /// **'Top driver this month wins {amount}!'**
  String driverMonthlyPrizeAmount(String amount);

  /// No description provided for @ridePromoSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Promo code used'**
  String get ridePromoSectionTitle;

  /// No description provided for @ridePromoCodeUsed.
  ///
  /// In en, this message translates to:
  /// **'Code: {code}'**
  String ridePromoCodeUsed(String code);

  /// No description provided for @ridePromoOriginalFare.
  ///
  /// In en, this message translates to:
  /// **'Full fare: {amount}'**
  String ridePromoOriginalFare(String amount);

  /// No description provided for @ridePromoCustomerPaid.
  ///
  /// In en, this message translates to:
  /// **'Customer paid: {amount}'**
  String ridePromoCustomerPaid(String amount);

  /// No description provided for @ridePromoDiscountAmount.
  ///
  /// In en, this message translates to:
  /// **'Promo discount: {amount}'**
  String ridePromoDiscountAmount(String amount);

  /// No description provided for @rideDriverCompensationOwed.
  ///
  /// In en, this message translates to:
  /// **'Pay driver: {amount}'**
  String rideDriverCompensationOwed(String amount);

  /// No description provided for @rideDriverCompensationHint.
  ///
  /// In en, this message translates to:
  /// **'The customer paid less because of the promo. Pay the driver this amount so they are not shortchanged.'**
  String get rideDriverCompensationHint;

  /// No description provided for @ridePromoUsedCompact.
  ///
  /// In en, this message translates to:
  /// **'{code} −{amount}'**
  String ridePromoUsedCompact(String code, String amount);

  /// No description provided for @rideDriverCompensationCompact.
  ///
  /// In en, this message translates to:
  /// **'Pay driver {amount}'**
  String rideDriverCompensationCompact(String amount);

  /// No description provided for @fakeDriversTitle.
  ///
  /// In en, this message translates to:
  /// **'Test drivers'**
  String get fakeDriversTitle;

  /// No description provided for @fakeDriversHint.
  ///
  /// In en, this message translates to:
  /// **'Create a fake driver for testing. When you activate them, they go online in Hilla and automatically accept matched rides.'**
  String get fakeDriversHint;

  /// No description provided for @createFakeDriver.
  ///
  /// In en, this message translates to:
  /// **'Create test driver'**
  String get createFakeDriver;

  /// No description provided for @fakeDriverCreated.
  ///
  /// In en, this message translates to:
  /// **'Test driver created. Tap Activate to go online.'**
  String get fakeDriverCreated;

  /// No description provided for @fakeDriverBadge.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get fakeDriverBadge;

  /// No description provided for @activateFakeDriver.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get activateFakeDriver;

  /// No description provided for @deactivateFakeDriver.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get deactivateFakeDriver;

  /// No description provided for @fakeDriverActivated.
  ///
  /// In en, this message translates to:
  /// **'Test driver is online and will auto-accept rides.'**
  String get fakeDriverActivated;

  /// No description provided for @fakeDriverDeactivated.
  ///
  /// In en, this message translates to:
  /// **'Test driver is offline.'**
  String get fakeDriverDeactivated;

  /// No description provided for @driverNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver name'**
  String get driverNameLabel;

  /// No description provided for @savedPlacesTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved places'**
  String get savedPlacesTitle;

  /// No description provided for @placeSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save place'**
  String get placeSaveAction;

  /// No description provided for @placeRemoveFromSaved.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved'**
  String get placeRemoveFromSaved;

  /// No description provided for @placeSaved.
  ///
  /// In en, this message translates to:
  /// **'Place saved.'**
  String get placeSaved;

  /// No description provided for @placeRemovedFromSaved.
  ///
  /// In en, this message translates to:
  /// **'Removed from saved places.'**
  String get placeRemovedFromSaved;

  /// No description provided for @savedPlacesEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Search for a place and tap Save to keep it here.'**
  String get savedPlacesEmptyHint;

  /// No description provided for @savePlaceShort.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get savePlaceShort;

  /// No description provided for @savedPlaceShort.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedPlaceShort;

  /// No description provided for @savePlaceHint.
  ///
  /// In en, this message translates to:
  /// **'Tap Save on any result to add it to your saved places.'**
  String get savePlaceHint;

  /// No description provided for @broadcastToDrivers.
  ///
  /// In en, this message translates to:
  /// **'Message all drivers'**
  String get broadcastToDrivers;

  /// No description provided for @broadcastToCustomers.
  ///
  /// In en, this message translates to:
  /// **'Message all customers'**
  String get broadcastToCustomers;

  /// No description provided for @broadcastDriversHint.
  ///
  /// In en, this message translates to:
  /// **'Send a push notification to every approved online-capable driver.'**
  String get broadcastDriversHint;

  /// No description provided for @broadcastCustomersHint.
  ///
  /// In en, this message translates to:
  /// **'Send a push notification to every customer.'**
  String get broadcastCustomersHint;

  /// No description provided for @announcementTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get announcementTitleLabel;

  /// No description provided for @announcementMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get announcementMessageLabel;

  /// No description provided for @announcementDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Announcement'**
  String get announcementDefaultTitle;

  /// No description provided for @announcementFieldsRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a title and message.'**
  String get announcementFieldsRequired;

  /// No description provided for @sendAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendAnnouncement;

  /// No description provided for @broadcastSentSummary.
  ///
  /// In en, this message translates to:
  /// **'Sent to {sent} of {total} devices.'**
  String broadcastSentSummary(int sent, int total);

  /// No description provided for @broadcastPublishedSummary.
  ///
  /// In en, this message translates to:
  /// **'Announcement published to {total} users. They will receive it in the app.'**
  String broadcastPublishedSummary(int total);

  /// No description provided for @broadcastSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send announcement. Check your connection and try again.'**
  String get broadcastSendFailed;

  /// No description provided for @editProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfileTitle;

  /// No description provided for @editProfileButton.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfileButton;

  /// No description provided for @saveProfile.
  ///
  /// In en, this message translates to:
  /// **'Save profile'**
  String get saveProfile;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get profileUpdated;

  /// No description provided for @changePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordTitle;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPassword;

  /// No description provided for @changePasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get changePasswordButton;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password updated.'**
  String get passwordChanged;

  /// No description provided for @passwordFieldsRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your current and new password.'**
  String get passwordFieldsRequired;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'New passwords do not match.'**
  String get passwordsDoNotMatch;

  /// No description provided for @fullNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required.'**
  String get fullNameRequired;

  /// No description provided for @phoneChangeHint.
  ///
  /// In en, this message translates to:
  /// **'To change your phone, enter the new number and your current password below.'**
  String get phoneChangeHint;

  /// No description provided for @currentPasswordForPhoneChange.
  ///
  /// In en, this message translates to:
  /// **'Current password (required to change phone)'**
  String get currentPasswordForPhoneChange;

  /// No description provided for @phoneChangePasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password to change phone number.'**
  String get phoneChangePasswordRequired;

  /// No description provided for @recoveryEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Recovery email (optional)'**
  String get recoveryEmailLabel;

  /// No description provided for @recoveryEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Optional email for account recovery.'**
  String get recoveryEmailHint;

  /// No description provided for @forgotPasswordStepsHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number and new password.'**
  String get forgotPasswordStepsHint;

  /// No description provided for @whatsappOtpTitle.
  ///
  /// In en, this message translates to:
  /// **'SMS verification'**
  String get whatsappOtpTitle;

  /// No description provided for @whatsappOtpInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code we sent to your phone by SMS.'**
  String get whatsappOtpInstructions;

  /// No description provided for @whatsappOtpSent.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent to {phone}.'**
  String whatsappOtpSent(String phone);

  /// No description provided for @whatsappOtpResend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get whatsappOtpResend;

  /// No description provided for @whatsappOtpResendWait.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String whatsappOtpResendWait(int seconds);

  /// No description provided for @whatsappOtpSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send SMS verification code. Try again.'**
  String get whatsappOtpSendFailed;

  /// No description provided for @whatsappOtpIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect verification code.'**
  String get whatsappOtpIncorrect;

  /// No description provided for @whatsappOtpExpired.
  ///
  /// In en, this message translates to:
  /// **'Verification code expired. Tap Resend code and try again.'**
  String get whatsappOtpExpired;

  /// No description provided for @whatsappOtpTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Request a new code.'**
  String get whatsappOtpTooManyAttempts;

  /// No description provided for @whatsappOtpSignupHint.
  ///
  /// In en, this message translates to:
  /// **'We will send an SMS verification code before creating your account.'**
  String get whatsappOtpSignupHint;

  /// No description provided for @openPasswordResetPage.
  ///
  /// In en, this message translates to:
  /// **'Open reset page'**
  String get openPasswordResetPage;

  /// No description provided for @resetLinkOpened.
  ///
  /// In en, this message translates to:
  /// **'Password reset page opened. Set your new password there.'**
  String get resetLinkOpened;

  /// No description provided for @resetWhileLoggedInHint.
  ///
  /// In en, this message translates to:
  /// **'If you are signed in, open Profile → Edit profile → Change password.'**
  String get resetWhileLoggedInHint;

  /// No description provided for @announcementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get announcementsTitle;

  /// No description provided for @announcementsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No announcements from the manager yet.'**
  String get announcementsEmpty;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
