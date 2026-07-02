import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/auth/auth_error_messages.dart';
import 'package:hilla_ride/core/auth/phone_auth_credentials.dart';
import 'package:hilla_ride/core/config/legal_config.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/utils/legal_url_launcher.dart';
import 'package:hilla_ride/features/auth/widgets/password_text_field.dart';
import 'package:hilla_ride/features/shared/widgets/photo_upload_tile.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, required this.selectedMode});

  final UserRole selectedMode;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();
  final _plateController = TextEditingController();
  final _colorController = TextEditingController();
  PickedImage? _idPhoto;
  PickedImage? _profilePhoto;
  var _acceptedTerms = false;
  var _isLoading = false;

  bool get _isDriver => widget.selectedMode == UserRole.driver;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _plateController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto({required bool isIdPhoto, required ImageSource source}) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final image = await pickImageFile(context, source);
      if (image == null || !mounted) return;
      setState(() {
        if (isIdPhoto) {
          _idPhoto = image;
        } else {
          _profilePhoto = image;
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.photoPickFailed)),
      );
    }
  }

  Future<void> _launchUrl(String url) => openLegalDocumentUrl(url);

  bool _validateCommonFields(AppLocalizations l10n) {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.nameRequired)),
      );
      return false;
    }
    if (!PhoneAuthCredentials.isValidIraqiPhone(_phoneController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.phoneNumberInvalid)),
      );
      return false;
    }
    if (!PhoneAuthCredentials.isValidPassword(_passwordController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordMinLength)),
      );
      return false;
    }
    return true;
  }

  bool _validateDriverFields(AppLocalizations l10n) {
    final age = int.tryParse(_ageController.text.trim()) ?? 0;
    if (age <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.ageRequired)),
      );
      return false;
    }
    if (age < 18) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.driverMinAge)),
      );
      return false;
    }
    if (_plateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.vehiclePlateRequired)),
      );
      return false;
    }
    if (_colorController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.vehicleColorRequired)),
      );
      return false;
    }
    if (_idPhoto == null || _profilePhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.registrationPhotosRequired)),
      );
      return false;
    }
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.registrationTermsRequired)),
      );
      return false;
    }
    return true;
  }

  Future<void> _showSuccessDialog({
    required String title,
    required String message,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.goToLogin),
          ),
        ],
      ),
    );
  }

  Future<void> _signupCustomer() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_validateCommonFields(l10n)) return;

    setState(() => _isLoading = true);
    try {
      final authService = context.read<AppState>().authService;
      await authService.signUpWithPhonePassword(
        phoneRaw: _phoneController.text,
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        role: UserRole.customer,
        email: _emailController.text.trim(),
      );
      await authService.signOut();
      if (!mounted) return;

      await _showSuccessDialog(
        title: l10n.signupSuccessTitle,
        message: l10n.signupSuccessMessage,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      showAuthErrorSnackBar(context, error);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      showFunctionsErrorSnackBar(context, error);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signupDriver() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_validateCommonFields(l10n) || !_validateDriverFields(l10n)) return;

    final age = int.parse(_ageController.text.trim());
    final appState = context.read<AppState>();
    final authService = appState.authService;
    User? createdUser;
    var applicationSaved = false;

    setState(() => _isLoading = true);
    try {
      final credential = await authService.signUpWithPhonePassword(
        phoneRaw: _phoneController.text,
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        role: UserRole.driver,
        age: age,
      );
      createdUser = credential.user;
      final uid = createdUser?.uid;
      if (uid == null) {
        throw FirebaseAuthException(
          code: 'internal',
          message: 'Registration failed. Try again.',
        );
      }

      await createdUser!.reload();
      await createdUser.getIdToken(true);

      final phone = PhoneAuthCredentials.normalizePhone(_phoneController.text);
      final storage = appState.storageService;
      final idPhotoUrl = await storage.uploadDriverDocument(
        uid: uid,
        bytes: _idPhoto!.bytes,
        fileName: 'id_photo.jpg',
      );
      final profilePhotoUrl = await storage.uploadDriverDocument(
        uid: uid,
        bytes: _profilePhoto!.bytes,
        fileName: 'profile_photo.jpg',
      );

      await appState.driverService.submitRegistration(
        uid: uid,
        phone: phone,
        name: _nameController.text.trim(),
        vehicleType: 'Tuk-Tuk',
        vehiclePlate: _plateController.text.trim(),
        vehicleColor: _colorController.text.trim(),
        idPhotoUrl: idPhotoUrl,
        profilePhotoUrl: profilePhotoUrl,
      );
      applicationSaved = true;

      await authService.signOut();
      if (!mounted) return;

      await _showSuccessDialog(
        title: l10n.driverSignupSuccessTitle,
        message: l10n.driverSignupSuccessMessage,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      showAuthErrorSnackBar(context, error);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message?.isNotEmpty == true
                ? error.message!
                : l10n.registrationSubmitFailed,
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'unauthorized' || error.code == 'permission-denied'
                ? l10n.registrationStorageRulesHint
                : (error.message?.isNotEmpty == true
                    ? error.message!
                    : l10n.registrationSubmitFailed),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.registrationSubmitFailed)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signup() {
    if (_isDriver) {
      return _signupDriver();
    }
    return _signupCustomer();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isDriver ? l10n.driverRegistration : l10n.signupTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.fullName,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.phoneHint,
                  prefixIcon: const Icon(Icons.phone),
                  hintText: '7701234567',
                ),
              ),
              const SizedBox(height: 12),
              if (!_isDriver) ...[
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.emailOptional,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              PasswordTextField(
                controller: _passwordController,
                label: l10n.passwordLabel,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.passwordMinLength,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_isDriver) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.age,
                    prefixIcon: const Icon(Icons.cake_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _plateController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: l10n.vehiclePlateOptional,
                    prefixIcon: const Icon(Icons.directions_car_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _colorController,
                  decoration: InputDecoration(
                    labelText: l10n.vehicleColor,
                    prefixIcon: const Icon(Icons.palette_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                PhotoUploadTile(
                  label: l10n.idPhotoLabel,
                  image: _idPhoto,
                  onPickGallery: () =>
                      _pickPhoto(isIdPhoto: true, source: ImageSource.gallery),
                  onPickCamera: () =>
                      _pickPhoto(isIdPhoto: true, source: ImageSource.camera),
                ),
                const SizedBox(height: 12),
                PhotoUploadTile(
                  label: l10n.profilePhotoLabel,
                  image: _profilePhoto,
                  onPickGallery: () =>
                      _pickPhoto(isIdPhoto: false, source: ImageSource.gallery),
                  onPickCamera: () =>
                      _pickPhoto(isIdPhoto: false, source: ImageSource.camera),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.driverTermsTitle,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(l10n.driverTermsBody),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => _launchUrl(
                                LegalConfig.termsOfServiceUrl(
                                  languageCode: l10n.localeName.startsWith('ar')
                                      ? 'ar'
                                      : 'en',
                                ),
                              ),
                              child: Text(l10n.termsOfService),
                            ),
                            TextButton(
                              onPressed: () => _launchUrl(
                                LegalConfig.privacyPolicyUrl(
                                  languageCode: l10n.localeName.startsWith('ar')
                                      ? 'ar'
                                      : 'en',
                                ),
                              ),
                              child: Text(l10n.privacyPolicy),
                            ),
                          ],
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _acceptedTerms,
                          onChanged: _isLoading
                              ? null
                              : (value) =>
                                  setState(() => _acceptedTerms = value ?? false),
                          title: Text(l10n.acceptDriverTerms),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _signup,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _isDriver ? l10n.submitForApproval : l10n.createAccountButton,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
