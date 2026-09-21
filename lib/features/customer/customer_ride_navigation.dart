/// Lets the app bar "Current ride" control reopen the active-ride UI from home.
class CustomerRideNavigation {
  CustomerRideNavigation._();

  static void Function(String rideId)? openActiveRideSession;
  static void Function()? minimizeActiveRideSession;

  static void openSession(String rideId) {
    openActiveRideSession?.call(rideId);
  }

  static void minimizeSession() {
    minimizeActiveRideSession?.call();
  }
}
