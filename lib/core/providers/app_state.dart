import 'package:flutter/material.dart';
import 'package:hilla_ride/core/services/announcement_service.dart';
import 'package:hilla_ride/core/services/broadcast_service.dart';
import 'package:hilla_ride/core/services/assistant_service.dart';
import 'package:hilla_ride/core/services/admin_service.dart';
import 'package:hilla_ride/core/services/app_services.dart';
import 'package:hilla_ride/core/services/chat_service.dart';
import 'package:hilla_ride/core/services/commission_service.dart';
import 'package:hilla_ride/core/services/geocoding_service.dart';
import 'package:hilla_ride/core/services/monthly_prize_service.dart';
import 'package:hilla_ride/core/services/pricing_service.dart';
import 'package:hilla_ride/core/services/promo_service.dart';
import 'package:hilla_ride/core/services/saved_places_service.dart';
import 'package:hilla_ride/core/services/support_service.dart';
import 'package:hilla_ride/core/services/storage_service.dart';
import 'package:hilla_ride/core/services/session_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    AuthService? authService,
    DriverService? driverService,
    RideService? rideService,
    GeocodingService? geocodingService,
    AdminService? adminService,
    PricingService? pricingService,
    ChatService? chatService,
    SupportService? supportService,
    CommissionService? commissionService,
    StorageService? storageService,
    AssistantService? assistantService,
    PromoService? promoService,
    MonthlyPrizeService? monthlyPrizeService,
    SavedPlacesService? savedPlacesService,
    BroadcastService? broadcastService,
    SessionService? sessionService,
    AnnouncementService? announcementService,
  })  : sessionService = sessionService ?? SessionService(),
        authService = authService ??
            AuthService(sessionService: sessionService ?? SessionService()),
        savedPlacesService = savedPlacesService ?? SavedPlacesService(),
        broadcastService = broadcastService ?? BroadcastService(),
        announcementService = announcementService ?? AnnouncementService(),
        driverService = driverService ?? DriverService(),
        geocodingService = geocodingService ?? GeocodingService(),
        adminService = adminService ?? AdminService(),
        pricingService = pricingService ?? PricingService(),
        promoService = promoService ?? PromoService(),
        monthlyPrizeService = monthlyPrizeService ?? MonthlyPrizeService(),
        assistantService = assistantService ?? AssistantService(),
        chatService = chatService ?? ChatService(),
        supportService = supportService ?? SupportService(),
        commissionService = commissionService ?? CommissionService(),
        storageService = storageService ?? StorageService(),
        rideService = rideService ??
            RideService(
              driverService: driverService ?? DriverService(),
              commissionService: commissionService ?? CommissionService(),
              monthlyPrizeService: monthlyPrizeService ?? MonthlyPrizeService(),
            );

  final AuthService authService;
  final SessionService sessionService;
  final DriverService driverService;
  final RideService rideService;
  final GeocodingService geocodingService;
  final AdminService adminService;
  final PricingService pricingService;
  final PromoService promoService;
  final MonthlyPrizeService monthlyPrizeService;
  final AssistantService assistantService;
  final ChatService chatService;
  final SupportService supportService;
  final CommissionService commissionService;
  final StorageService storageService;
  final SavedPlacesService savedPlacesService;
  final BroadcastService broadcastService;
  final AnnouncementService announcementService;

  factory AppState.create() {
    final sessionService = SessionService();
    final driverService = DriverService();
    final commissionService = CommissionService();
    final promoService = PromoService();
    final monthlyPrizeService = MonthlyPrizeService();
    return AppState(
      sessionService: sessionService,
      authService: AuthService(sessionService: sessionService),
      driverService: driverService,
      commissionService: commissionService,
      promoService: promoService,
      monthlyPrizeService: monthlyPrizeService,
      rideService: RideService(
        driverService: driverService,
        commissionService: commissionService,
        monthlyPrizeService: monthlyPrizeService,
      ),
    );
  }

  @override
  void dispose() {
    driverService.dispose();
    super.dispose();
  }
}

class LocaleProvider extends ChangeNotifier {
  Locale? _locale = const Locale('ar');

  Locale? get locale => _locale;

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }
}
