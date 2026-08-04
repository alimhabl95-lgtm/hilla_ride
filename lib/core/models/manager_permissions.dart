class AdminPermissions {
  AdminPermissions._();

  static const overview = 'overview';
  static const pendingDrivers = 'pendingDrivers';
  static const activeRides = 'activeRides';
  static const liveMap = 'liveMap';
  static const allDrivers = 'allDrivers';
  static const customers = 'customers';
  static const rideHistory = 'rideHistory';
  static const pricing = 'pricing';
  static const earnings = 'earnings';
  static const driverReviews = 'driverReviews';
  static const supportInbox = 'supportInbox';
  static const manageAssistants = 'manageAssistants';
  static const promoCodes = 'promoCodes';
  static const monthlyLeaderboard = 'monthlyLeaderboard';
  static const wallet = 'wallet';
  static const serviceAreas = 'serviceAreas';
  static const rewards = 'rewards';
  static const businessPartners = 'businessPartners';

  static const defaultAssistant = [
    overview,
    pendingDrivers,
    activeRides,
    liveMap,
    allDrivers,
    rideHistory,
    supportInbox,
  ];

  static const all = [
    overview,
    pendingDrivers,
    activeRides,
    liveMap,
    allDrivers,
    customers,
    rideHistory,
    pricing,
    earnings,
    driverReviews,
    supportInbox,
    manageAssistants,
    promoCodes,
    monthlyLeaderboard,
    wallet,
    serviceAreas,
    rewards,
    businessPartners,
  ];
}

extension AdminPermissionLabels on String {
  String labelKey() => switch (this) {
        AdminPermissions.overview => 'permOverview',
        AdminPermissions.pendingDrivers => 'permPendingDrivers',
        AdminPermissions.activeRides => 'permActiveRides',
        AdminPermissions.liveMap => 'permLiveMap',
        AdminPermissions.allDrivers => 'permAllDrivers',
        AdminPermissions.customers => 'permCustomers',
        AdminPermissions.rideHistory => 'permRideHistory',
        AdminPermissions.pricing => 'permPricing',
        AdminPermissions.earnings => 'permEarnings',
        AdminPermissions.driverReviews => 'permDriverReviews',
        AdminPermissions.supportInbox => 'permSupportInbox',
        AdminPermissions.manageAssistants => 'permManageAssistants',
        AdminPermissions.promoCodes => 'permPromoCodes',
        AdminPermissions.monthlyLeaderboard => 'permMonthlyLeaderboard',
        AdminPermissions.wallet => 'permWallet',
        AdminPermissions.serviceAreas => 'permServiceAreas',
        AdminPermissions.rewards => 'permRewards',
        AdminPermissions.businessPartners => 'permBusinessPartners',
        _ => 'permUnknown',
      };
}
