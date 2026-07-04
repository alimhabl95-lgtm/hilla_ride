#import <Flutter/Flutter.h>

@interface SafePluginRegistrant : NSObject
+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry;
@end
