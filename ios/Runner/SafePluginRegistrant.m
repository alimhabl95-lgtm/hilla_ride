#import "SafePluginRegistrant.h"

#if __has_include(<cloud_firestore/FLTFirebaseFirestorePlugin.h>)
#import <cloud_firestore/FLTFirebaseFirestorePlugin.h>
#else
@import cloud_firestore;
#endif

#if __has_include(<cloud_functions/FirebaseFunctionsPlugin.h>)
#import <cloud_functions/FirebaseFunctionsPlugin.h>
#else
@import cloud_functions;
#endif

#if __has_include(<firebase_auth/FLTFirebaseAuthPlugin.h>)
#import <firebase_auth/FLTFirebaseAuthPlugin.h>
#else
@import firebase_auth;
#endif

#if __has_include(<firebase_core/FLTFirebaseCorePlugin.h>)
#import <firebase_core/FLTFirebaseCorePlugin.h>
#else
@import firebase_core;
#endif

#if __has_include(<firebase_messaging/FLTFirebaseMessagingPlugin.h>)
#import <firebase_messaging/FLTFirebaseMessagingPlugin.h>
#else
@import firebase_messaging;
#endif

#if __has_include(<firebase_storage/FLTFirebaseStoragePlugin.h>)
#import <firebase_storage/FLTFirebaseStoragePlugin.h>
#else
@import firebase_storage;
#endif

#if __has_include(<flutter_local_notifications/FlutterLocalNotificationsPlugin.h>)
#import <flutter_local_notifications/FlutterLocalNotificationsPlugin.h>
#else
@import flutter_local_notifications;
#endif

#if __has_include(<geolocator_apple/GeolocatorPlugin.h>)
#import <geolocator_apple/GeolocatorPlugin.h>
#else
@import geolocator_apple;
#endif

#if __has_include(<google_maps_flutter_ios/FGMGoogleMapsPlugin.h>)
#import <google_maps_flutter_ios/FGMGoogleMapsPlugin.h>
#else
@import google_maps_flutter_ios;
#endif

#if __has_include(<google_places_sdk_plus_ios/SwiftFlutterGooglePlacesSdkIosPlugin.h>)
#import <google_places_sdk_plus_ios/SwiftFlutterGooglePlacesSdkIosPlugin.h>
#else
@import google_places_sdk_plus_ios;
#endif

#if __has_include(<image_picker_ios/FLTImagePickerPlugin.h>)
#import <image_picker_ios/FLTImagePickerPlugin.h>
#else
@import image_picker_ios;
#endif

#if __has_include(<package_info_plus/FPPPackageInfoPlusPlugin.h>)
#import <package_info_plus/FPPPackageInfoPlusPlugin.h>
#else
@import package_info_plus;
#endif

#if __has_include(<permission_handler_apple/PermissionHandlerPlugin.h>)
#import <permission_handler_apple/PermissionHandlerPlugin.h>
#else
@import permission_handler_apple;
#endif

#if __has_include(<record_ios/RecordIosPlugin.h>)
#import <record_ios/RecordIosPlugin.h>
#else
@import record_ios;
#endif

#if __has_include(<shared_preferences_foundation/SharedPreferencesPlugin.h>)
#import <shared_preferences_foundation/SharedPreferencesPlugin.h>
#else
@import shared_preferences_foundation;
#endif

#if __has_include(<url_launcher_ios/URLLauncherPlugin.h>)
#import <url_launcher_ios/URLLauncherPlugin.h>
#else
@import url_launcher_ios;
#endif

static void RegisterPlugin(id registry, NSString* pluginKey, void (^registerBlock)(NSObject<FlutterPluginRegistrar>*)) {
  NSObject<FlutterPluginRegistrar>* registrar = [registry registrarForPlugin:pluginKey];
  if (registrar == nil) {
    NSLog(@"SafePluginRegistrant: skipping %@ (registrar is nil)", pluginKey);
    return;
  }
  registerBlock(registrar);
}

@implementation SafePluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  RegisterPlugin(registry, @"FLTFirebaseFirestorePlugin", ^(NSObject<FlutterPluginRegistrar>* registrar) {
    [FLTFirebaseFirestorePlugin registerWithRegistrar:registrar];
  });
  RegisterPlugin(registry, @"FirebaseFunctionsPlugin", ^(NSObject<FlutterPluginRegistrar>* registrar) {
    [FirebaseFunctionsPlugin registerWithRegistrar:registrar];
  });
  RegisterPlugin(registry, @"FLTFirebaseAuthPlugin", ^(NSObject<FlutterPluginRegistrar>* registrar) {
    [FLTFirebaseAuthPlugin registerWithRegistrar:registrar];
  });
  RegisterPlugin(registry, @"FLTFirebaseCorePlugin", ^(NSObject<FlutterPluginRegistrar>* registrar) {
    [FLTFirebaseCorePlugin registerWithRegistrar:registrar];
  });
  RegisterPlugin(registry, @"FLTFirebaseMessagingPlugin", ^(NSObject<FlutterPluginRegistrar>* registrar) {
    [FLTFirebaseMessagingPlugin registerWithRegistrar:registrar];
  });
  RegisterPlugin(registry, @"FLTFirebaseStoragePlugin", ^(NSObject<FlutterPluginRegistrar>* registrar) {
    [FLTFirebaseStoragePlugin registerWithRegistrar:registrar];
  });
  RegisterPlugin(registry, @"FlutterLocalNotificationsPlugin", ^(NSObject<FlutterPluginRegistrar>* registrar) {
    [FlutterLocalNotificationsPlugin registerWithRegistrar:registrar];
  });
  RegisterPlugin(registry, @"GeolocatorPlugin", ^(NSObject<FlutterPluginRegistrar>* registrar) {
    [GeolocatorPlugin registerWithRegistrar:registrar];
  });
  RegisterPlugin(registry, @"FGMGoogleMapsPlugin", ^(NSObject<FlutterPluginRegistrar>* registrar) {
    [FGMGoogleMapsPlugin registerWithRegistrar:registrar];
  });
  RegisterPlugin(registry, @"SwiftFlutterGooglePlacesSdkIosPlugin", ^(NSObject<FlutterPluginRegistrar>* registrar) {
    [SwiftFlutterGooglePlacesSdkIosPlugin registerWithRegistrar:registrar];
  });
  RegisterPlugin(registry, @"FLTImagePickerPlugin", ^(NSObject<FlutterPluginRegistrar>* registrar) {
    [FLTImagePickerPlugin registerWithRegistrar:registrar];
  });
  RegisterPlugin(registry, @"FPPPackageInfoPlusPlugin", ^(NSObject<FlutterPluginRegistrar>* registrar) {
    [FPPPackageInfoPlusPlugin registerWithRegistrar:registrar];
  });
  RegisterPlugin(registry, @"PermissionHandlerPlugin", ^(NSObject<FlutterPluginRegistrar>* registrar) {
    [PermissionHandlerPlugin registerWithRegistrar:registrar];
  });
  RegisterPlugin(registry, @"RecordIosPlugin", ^(NSObject<FlutterPluginRegistrar>* registrar) {
    [RecordIosPlugin registerWithRegistrar:registrar];
  });
  RegisterPlugin(registry, @"SharedPreferencesPlugin", ^(NSObject<FlutterPluginRegistrar>* registrar) {
    [SharedPreferencesPlugin registerWithRegistrar:registrar];
  });
  RegisterPlugin(registry, @"URLLauncherPlugin", ^(NSObject<FlutterPluginRegistrar>* registrar) {
    [URLLauncherPlugin registerWithRegistrar:registrar];
  });
}

@end
