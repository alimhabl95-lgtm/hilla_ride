#import "VSyncWorkaround.h"

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

static IMP gOriginalLoadViewIMP = NULL;

static void HillaRideLoadView(id self, SEL _cmd) {
  ((void (*)(id, SEL))gOriginalLoadViewIMP)(self, _cmd);

  if (!HillaRideIsIOS26OrLater()) {
    return;
  }

  UIView* view = [self view];
  for (UIView* subview in view.subviews) {
    if (![subview isKindOfClass:[UILabel class]]) {
      continue;
    }

    UILabel* label = (UILabel*)subview;
    if (![label.text containsString:@"debug mode Flutter apps"]) {
      continue;
    }

    NSString* version =
        [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?";
    NSString* build =
        [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"?";
    label.text =
        [NSString stringWithFormat:
                      @"TestFlight build %@ (%@) was packaged as DEBUG.\n\n"
                      @"iOS 26 cannot run debug builds from the home screen.\n\n"
                      @"Delete this app and wait for the next Codemagic release "
                      @"(Hello Tuk-Tuk %@ on TestFlight).",
                      version, build, version];
    label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    break;
  }
}

void HillaRideInstallVSyncWorkaround(void) {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    if (!HillaRideIsIOS26OrLater()) {
      return;
    }

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

    SEL loadViewSelector = @selector(loadView);
    Method loadViewMethod = class_getInstanceMethod(flutterViewControllerClass, loadViewSelector);
    if (loadViewMethod != NULL) {
      gOriginalLoadViewIMP = method_getImplementation(loadViewMethod);
      method_setImplementation(loadViewMethod, (IMP)HillaRideLoadView);
    }
  });
}
