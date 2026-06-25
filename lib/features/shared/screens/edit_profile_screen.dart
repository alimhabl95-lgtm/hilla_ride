import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/auth/auth_error_messages.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/widgets/arabic_text_field.dart';
import 'package:hilla_ride/features/auth/widgets/password_text_field.dart';
import 'package:hilla_ride/features/shared/widgets/photo_upload_tile.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.role,
    required this.user,
    this.driver,
  });

  final UserRole role;
  final AppUser user;
  final DriverProfile? driver;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _ageController;
  late final TextEditingController _vehicleTypeController;
  late final TextEditingController _vehiclePlateController;
  late final TextEditingController _licenseController;
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;
  late final TextEditingController _phoneChangePasswordController;

  String? _gender;
  PickedImage? _profilePhoto;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    final driver = widget.driver;
    _nameController = TextEditingController(text: user.name);
    _phoneController = TextEditingController(text: user.phone);
    _emailController = TextEditingController(text: user.email ?? '');
    _ageController = TextEditingController(
      text: user.age > 0 ? '${user.age}' : '',
    );
    _vehicleTypeController = TextEditingController(text: driver?.vehicleType ?? '');
    _vehiclePlateController = TextEditingController(text: driver?.vehiclePlate ?? '');
    _licenseController = TextEditingController(text: driver?.licenseNumber ?? '');
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _phoneChangePasswordController = TextEditingController();
    _gender = user.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _vehicleTypeController.dispose();
    _vehiclePlateController.dispose();
    _licenseController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _phoneChangePasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final storage = context.read<AppState>().storageService;
    final file = await storage.pickImage(source);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _profilePhoto = PickedImage(bytes: bytes, fileName: 'profile_photo.jpg');
    });
  }

  Future<void> _saveProfile() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.fullNameRequired)),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final appState = context.read<AppState>();
      final auth = appState.authService;
      final uid = auth.currentUser?.uid ?? widget.user.uid;
      var profilePhotoUrl = widget.role == UserRole.driver
          ? widget.driver?.profilePhotoUrl ?? ''
          : widget.user.profilePhotoUrl;

      if (_profilePhoto != null) {
        if (widget.role == UserRole.driver) {
          profilePhotoUrl = await appState.storageService.uploadDriverDocument(
            uid: uid,
            bytes: _profilePhoto!.bytes,
            fileName: 'profile_photo.jpg',
          );
        } else {
          profilePhotoUrl = await appState.storageService.uploadUserProfilePhoto(
            uid: uid,
            bytes: _profilePhoto!.bytes,
          );
        }
      }

      if (widget.role == UserRole.customer) {
        final age = int.tryParse(_ageController.text.trim()) ?? widget.user.age;
        await auth.updateUserProfileFields(
          name: name,
          age: age,
          gender: _gender,
          email: _emailController.text.trim(),
          profilePhotoUrl: profilePhotoUrl,
        );
      } else {
        await auth.updateUserProfileFields(
          name: name,
          email: _emailController.text.trim(),
        );
        if (widget.driver != null) {
          await appState.driverService.updateProfile(
            uid: uid,
            name: name,
            vehicleType: _vehicleTypeController.text.trim(),
            vehiclePlate: _vehiclePlateController.text.trim(),
            licenseNumber: _licenseController.text.trim(),
            profilePhotoUrl: profilePhotoUrl,
          );
        }
      }

      final newPhone = _phoneController.text.trim();
      if (newPhone.isNotEmpty && newPhone != widget.user.phone) {
        final password = _phoneChangePasswordController.text;
        if (password.isEmpty) {
          throw FirebaseAuthException(
            code: 'requires-recent-login',
            message: l10n.phoneChangePasswordRequired,
          );
        }
        await auth.updateAccountPhone(
          currentPassword: password,
          newPhoneRaw: newPhone,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileUpdated)),
      );
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      showAuthErrorSnackBar(context, error);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'unauthorized'
                ? l10n.registrationStorageRulesHint
                : (error.message?.isNotEmpty == true
                    ? error.message!
                    : l10n.photoPickFailed),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final l10n = AppLocalizations.of(context)!;
    final current = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (current.isEmpty || newPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordFieldsRequired)),
      );
      return;
    }
    if (newPassword != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordsDoNotMatch)),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<AppState>().authService.changePassword(
            currentPassword: current,
            newPassword: newPassword,
          );
      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordChanged)),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      showAuthErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isCustomer = widget.role == UserRole.customer;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editProfileTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          PhotoUploadTile(
            label: l10n.profilePhotoLabel,
            image: _profilePhoto,
            onPickGallery: () => _pickPhoto(ImageSource.gallery),
            onPickCamera: () => _pickPhoto(ImageSource.camera),
          ),
          const SizedBox(height: 16),
          ArabicTextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: l10n.fullName),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: l10n.phoneHint,
              helperText: l10n.phoneChangeHint,
            ),
          ),
          const SizedBox(height: 12),
          PasswordTextField(
            controller: _phoneChangePasswordController,
            label: l10n.currentPasswordForPhoneChange,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: l10n.recoveryEmailLabel,
              helperText: l10n.recoveryEmailHint,
            ),
          ),
          if (isCustomer) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.age),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: InputDecoration(labelText: l10n.gender),
              items: [
                DropdownMenuItem(value: 'male', child: Text(l10n.male)),
                DropdownMenuItem(value: 'female', child: Text(l10n.female)),
              ],
              onChanged: (value) => setState(() => _gender = value),
            ),
          ],
          if (widget.role == UserRole.driver && widget.driver != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _vehicleTypeController,
              decoration: InputDecoration(labelText: l10n.vehicleType),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _vehiclePlateController,
              decoration: InputDecoration(labelText: l10n.vehiclePlate),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _licenseController,
              decoration: InputDecoration(labelText: l10n.licenseNumber),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _saveProfile,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.saveProfile),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.changePasswordTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          PasswordTextField(
            controller: _currentPasswordController,
            label: l10n.currentPassword,
          ),
          const SizedBox(height: 12),
          PasswordTextField(
            controller: _newPasswordController,
            label: l10n.newPassword,
          ),
          const SizedBox(height: 12),
          PasswordTextField(
            controller: _confirmPasswordController,
            label: l10n.confirmNewPassword,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _saving ? null : _changePassword,
            child: Text(l10n.changePasswordButton),
          ),
        ],
      ),
    );
  }
}
