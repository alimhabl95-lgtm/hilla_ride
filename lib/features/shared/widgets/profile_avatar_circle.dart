import 'package:flutter/material.dart';
import 'package:hilla_ride/features/shared/widgets/firebase_driver_photo_image.dart';

class ProfileAvatarCircle extends StatelessWidget {
  const ProfileAvatarCircle.driver({
    super.key,
    required this.driverId,
    required this.name,
    this.profilePhotoUrl = '',
    this.radius = 48,
  })  : userId = null,
        isDriver = true;

  const ProfileAvatarCircle.customer({
    super.key,
    required this.userId,
    required this.name,
    this.profilePhotoUrl = '',
    this.radius = 48,
  })  : driverId = null,
        isDriver = false;

  final bool isDriver;
  final String? driverId;
  final String? userId;
  final String name;
  final String profilePhotoUrl;
  final double radius;

  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  Widget _initialAvatar(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      child: Text(
        _initial,
        style: TextStyle(fontSize: radius * 0.66),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;

    if (isDriver && driverId != null && profilePhotoUrl.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: FirebaseDriverPhotoImage(
            driverId: driverId!,
            fileName: 'profile_photo.jpg',
            imageUrl: profilePhotoUrl,
          ),
        ),
      );
    }

    if (!isDriver &&
        userId != null &&
        userId!.isNotEmpty &&
        profilePhotoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          profilePhotoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialAvatar(context),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: size,
              height: size,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        ),
      );
    }

    return _initialAvatar(context);
  }
}
