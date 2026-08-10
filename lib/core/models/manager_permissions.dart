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
  static const complaints = 'complaints';
  static const notifications = 'notifications';
  static const driverPerformance = 'driverPerformance';
  static const reports = 'reports';
  static const auditLog = 'auditLog';
  static const appSettings = 'appSettings';

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
    complaints,
    notifications,
    driverPerformance,
    reports,
    auditLog,
    appSettings,
  ];
}

class AdminRoleTemplates {
  AdminRoleTemplates._();

  static const superAdmin = AdminPermissions.all;

  static const operationsManager = [
    AdminPermissions.overview,
    AdminPermissions.pendingDrivers,
    AdminPermissions.activeRides,
    AdminPermissions.liveMap,
    AdminPermissions.allDrivers,
    AdminPermissions.rideHistory,
    AdminPermissions.serviceAreas,
    AdminPermissions.complaints,
    AdminPermissions.notifications,
    AdminPermissions.driverPerformance,
    AdminPermissions.businessPartners,
  ];

  static const financeManager = [
    AdminPermissions.overview,
    AdminPermissions.earnings,
    AdminPermissions.wallet,
    AdminPermissions.rewards,
    AdminPermissions.reports,
    AdminPermissions.pricing,
    AdminPermissions.promoCodes,
    AdminPermissions.auditLog,
  ];

  static const customerSupport = [
    AdminPermissions.overview,
    AdminPermissions.customers,
    AdminPermissions.supportInbox,
    AdminPermissions.complaints,
    AdminPermissions.rideHistory,
    AdminPermissions.notifications,
    AdminPermissions.driverReviews,
  ];

  static const templateKeys = {
    'superAdmin': superAdmin,
    'operationsManager': operationsManager,
    'financeManager': financeManager,
    'customerSupport': customerSupport,
  };

  static String labelForKey(String key, {required bool isAr}) {
    return switch (key) {
      'superAdmin' => isAr ? 'مدير عام' : 'Super Admin',
      'operationsManager' => isAr ? 'عمليات' : 'Operations',
      'financeManager' => isAr ? 'مالية' : 'Finance',
      'customerSupport' => isAr ? 'دعم العملاء' : 'Support',
      _ => key,
    };
  }
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
        AdminPermissions.complaints => 'permComplaints',
        AdminPermissions.notifications => 'permNotifications',
        AdminPermissions.driverPerformance => 'permDriverPerformance',
        AdminPermissions.reports => 'permReports',
        AdminPermissions.auditLog => 'permAuditLog',
        AdminPermissions.appSettings => 'permAppSettings',
        _ => 'permUnknown',
      };
}
