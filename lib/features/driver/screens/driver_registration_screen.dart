import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/config/legal_config.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/features/shared/widgets/photo_upload_tile.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:hilla_ride/core/utils/legal_url_launcher.dart';

class DriverRegistrationScreen extends StatefulWidget {
  const DriverRegistrationScreen({
    super.key,
    required this.phone,
  });

  final String phone;

  @override
  State<DriverRegistrationScreen> createState() =>
      _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  final _nameController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _plateController = TextEditingController();
  final _licenseController = TextEditingController();
  PickedImage? _idPhoto;
  PickedImage? _profilePhoto;
  var _acceptedTerms = false;
  var _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _vehicleTypeController.dispose();
    _plateController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) => openLegalDocumentUrl(url);

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
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = l10n.photoPickFailed);
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AppState>().authService;
    final user = auth.currentUser;
    if (user == null) return;

    final name = _nameController.text.trim();
    if (name.isEmpty || _vehicleTypeController.text.trim().isEmpty) {
      setState(() => _errorMessage = l10n.registrationFieldsRequired);
      return;
    }
    if (_idPhoto == null || _profilePhoto == null) {
      setState(() => _errorMessage = l10n.registrationPhotosRequired);
      return;
    }
    if (!_acceptedTerms) {
      setState(() => _errorMessage = l10n.registrationTermsRequired);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final storage = context.read<AppState>().storageService;
      final idPhotoUrl = await storage.uploadDriverDocument(
        uid: user.uid,
        bytes: _idPhoto!.bytes,
        fileName: 'id_photo.jpg',
      );
      final profilePhotoUrl = await storage.uploadDriverDocument(
        uid: user.uid,
        bytes: _profilePhoto!.bytes,
        fileName: 'profile_photo.jpg',
      );

      await auth.saveUserProfile(
        role: UserRole.driver,
        name: name,
        age: 18,
        phone: widget.phone,
      );
      if (!mounted) return;

      await context.read<AppState>().driverService.submitRegistration(
            uid: user.uid,
            phone: widget.phone,
            name: name,
            vehicleType: _vehicleTypeController.text.trim(),
            vehiclePlate: _plateController.text.trim(),
            licenseNumber: _licenseController.text.trim(),
            idPhotoUrl: idPhotoUrl,
            profilePhotoUrl: profilePhotoUrl,
          );
    } on FirebaseException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.code == 'unauthorized'
              ? l10n.registrationStorageRulesHint
              : l10n.registrationSubmitFailed;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = l10n.registrationSubmitFailed);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.driverRegistration)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.fullName),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _vehicleTypeController,
              decoration: InputDecoration(labelText: l10n.vehicleType),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _plateController,
              decoration: InputDecoration(labelText: l10n.vehiclePlateOptional),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _licenseController,
              decoration: InputDecoration(labelText: l10n.licenseNumberOptional),
            ),
            const SizedBox(height: 20),
            PhotoUploadTile(
              label: l10n.idPhotoLabel,
              image: _idPhoto,
              onPickGallery: () => _pickPhoto(isIdPhoto: true, source: ImageSource.gallery),
              onPickCamera: () => _pickPhoto(isIdPhoto: true, source: ImageSource.camera),
            ),
            const SizedBox(height: 12),
            PhotoUploadTile(
              label: l10n.profilePhotoLabel,
              image: _profilePhoto,
              onPickGallery: () => _pickPhoto(isIdPhoto: false, source: ImageSource.gallery),
              onPickCamera: () => _pickPhoto(isIdPhoto: false, source: ImageSource.camera),
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
                      onChanged: _isSaving
                          ? null
                          : (value) => setState(() => _acceptedTerms = value ?? false),
                      title: Text(l10n.acceptDriverTerms),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : _submit,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.submitForApproval),
            ),
          ],
        ),
      ),
    );
  }
}

class DriverPendingScreen extends StatelessWidget {
  const DriverPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_top, size: 72, color: Color(0xFF0F766E)),
              const SizedBox(height: 24),
              Text(
                l10n.pendingApprovalTitle,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.pendingApprovalBody,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DriverRejectedScreen extends StatelessWidget {
  const DriverRejectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.rejectedTitle,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class DriverBlockedScreen extends StatelessWidget {
  const DriverBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, size: 72, color: Colors.redAccent),
              const SizedBox(height: 24),
              Text(
                l10n.accountBlockedTitle,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.driverBlockedBody,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomerBlockedScreen extends StatelessWidget {
  const CustomerBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, size: 72, color: Colors.redAccent),
              const SizedBox(height: 24),
              Text(
                l10n.accountBlockedTitle,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.customerBlockedBody,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
