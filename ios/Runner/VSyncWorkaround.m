#import <Flutter/Flutter.h>
#import <objc/runtime.h>

static BOOL HillaRideIsIOS26OrLater(void) {
  NSOperatingSystemVersion version = [NSProcessInfo processInfo].operatingSystemVersion;
  return version.majorVersion >= 26;
}

static void HillaRideSkipTouchRateCorrectionVSync(id self, SEL _cmd) {
  // No-op: avoids null task runner crash on iOS 26 ProMotion devices.
}

static void HillaRideSkipKeyboardAnimationVsync(id self, SEL _cmd) {
  // No-op: same engine timing issue as touch-rate correction on iOS 26.
}

static void HillaRideInstallVSyncWorkaround(void) {
  Class flutterViewControllerClass = [FlutterViewController class];
  if (flutterViewControllerClass == Nil) {
    return;
  }

  SEL touchRateSelector = NSSelectorFromString(@"createTouchRateCorrectionVSyncClientIfNeeded");
  Method touchRateMethod = class_getInstanceMethod(flutterViewControllerClass, touchRateSelector);
  if (touchRateMethod != NULL) {
    method_setImplementation(touchRateMethod, (IMP)HillaRideSkipTouchRateCorrectionVSync);
  }

  SEL keyboardSelector = NSSelectorFromString(@"setUpKeyboardAnimationVsyncClient:");
  Method keyboardMethod = class_getInstanceMethod(flutterViewControllerClass, keyboardSelector);
  if (keyboardMethod != NULL) {
    method_setImplementation(keyboardMethod, (IMP)HillaRideSkipKeyboardAnimationVsync);
  }
}

__attribute__((constructor)) static void HillaRideVSyncWorkaroundInit(void) {
  if (!HillaRideIsIOS26OrLater()) {
    return;
  }
  HillaRideInstallVSyncWorkaround();
}
