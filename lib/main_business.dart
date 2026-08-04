import 'package:hilla_ride/bootstrap.dart';
import 'package:hilla_ride/core/config/app_variant.dart';

/// Hello Tuk-Tuk Business client.
///
/// Phase 1: hosted as the Web Portal (`hello-tiktok-57dc5-business`).
/// Phase 2: package the same entry + [BusinessService] as the mobile app —
/// same Firebase Auth logins, no data migration.
Future<void> main() => bootstrapApp(AppVariant.business);
