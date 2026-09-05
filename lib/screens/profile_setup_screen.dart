import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../home_screen.dart';


class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() =>
      _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final usernameController = TextEditingController();
  final bioController = TextEditingController();

  final ImagePicker picker = ImagePicker();

  DateTime? birthDate;

  XFile? photo1;
  XFile? photo2;
  XFile? photo3;

  String? existingPhoto1Url;
  String? existingPhoto2Url;
  String? existingPhoto3Url;

  bool removePhoto2 = false;
  bool removePhoto3 = false;

  bool isLoading = true;
  bool isSaving = false;
  bool isExistingProfile = false;

  // Empêche le navigateur Web de réutiliser une ancienne
  // version mise en cache d'une photo Supabase ayant la même URL.
  int photoCacheVersion =
      DateTime.now().millisecondsSinceEpoch;

  // Étape utilisée uniquement lors de la création initiale.
  // 0 = pseudo
  // 1 = date de naissance
  // 2 = photo principale
  int setupStep = 0;

  @override
  void initState() {
    super.initState();
    loadExistingProfile();
  }

  @override
  void dispose() {
    usernameController.dispose();
    bioController.dispose();
    super.dispose();
  }

  // ============================================
  // CALCULER L'ÂGE
  // ============================================

  int calculateAge(DateTime date) {
    final today = DateTime.now();

    int age = today.year - date.year;

    if (today.month < date.month ||
        (today.month == date.month &&
            today.day < date.day)) {
      age--;
    }

    return age;
  }

  // ============================================
  // FORMATER DATE
  // ============================================

  String formatBirthDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  // ============================================
  // CHOISIR DATE DE NAISSANCE
  // ============================================

  Future<void> selectBirthDate() async {
    if (isSaving) return;

    final now = DateTime.now();

    final maximumDate = DateTime(
      now.year - 13,
      now.month,
      now.day,
    );

    final minimumDate = DateTime(
      now.year - 120,
      now.month,
      now.day,
    );

    final initialDate =
        birthDate ?? DateTime(now.year - 18);

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(maximumDate)
          ? maximumDate
          : initialDate,
      firstDate: minimumDate,
      lastDate: maximumDate,
      helpText: 'Date de naissance',
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      birthDate = selectedDate;
    });
  }

  // ============================================
  // CHARGER LE PROFIL EXISTANT
  // ============================================

  Future<void> loadExistingProfile() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select(
            'username, birth_date, bio, '
            'photo_1_url, photo_2_url, photo_3_url',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (response != null) {
        final username = response['username'] as String?;
        final birthDateValue = response['birth_date'];
        final bio = response['bio'] as String?;

        existingPhoto1Url =
            response['photo_1_url'] as String?;

        existingPhoto2Url =
            response['photo_2_url'] as String?;

        existingPhoto3Url =
            response['photo_3_url'] as String?;

        if (username != null && username.isNotEmpty) {
          usernameController.text = username;

          final hasBirthDate = birthDateValue != null;

          final hasMainPhoto =
              existingPhoto1Url != null &&
              existingPhoto1Url!.isNotEmpty;

          isExistingProfile =
              hasBirthDate && hasMainPhoto;
        }

        if (birthDateValue != null) {
          birthDate = DateTime.tryParse(
            birthDateValue.toString(),
          );
        }

        if (bio != null) {
          bioController.text = bio;
        }
      }

      if (!mounted) return;

      setState(() {
        photoCacheVersion =
            DateTime.now().millisecondsSinceEpoch;
        isLoading = false;
      });
    } catch (error) {
      debugPrint(
        'Erreur chargement profil : $error',
      );

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  // ============================================
  // CHOISIR + CADRER UNE PHOTO
  // ============================================

  Future<XFile?> pickPhoto() async {
    final selectedPhoto = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (selectedPhoto == null) {
      return null;
    }

    if (!mounted) {
      return null;
    }

    final screenWidth =
        MediaQuery.of(context).size.width;

    final isSmallScreen =
        screenWidth < 600;

    final croppedPhoto = await ImageCropper().cropImage(
      sourcePath: selectedPhoto.path,

      aspectRatio: const CropAspectRatio(
        ratioX: 3,
        ratioY: 4,
      ),

      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,

      uiSettings: [
        // ========================================
        // ANDROID
        // ========================================

        AndroidUiSettings(
          toolbarTitle: 'Cadrer la photo',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          backgroundColor: Colors.black,
          activeControlsWidgetColor: Colors.white,
          lockAspectRatio: true,
          hideBottomControls: false,
          showCropGrid: true,
        ),

        // ========================================
        // IOS
        // ========================================

        IOSUiSettings(
          title: 'Cadrer la photo',
          doneButtonTitle: 'Valider',
          cancelButtonTitle: 'Annuler',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          showCancelConfirmationDialog: true,
        ),

        // ========================================
        // WEB
        // ========================================

        WebUiSettings(
          context: context,

          size: CropperSize(
            width: isSmallScreen
                ? (screenWidth * 0.82).round()
                : 500,
            height: isSmallScreen
                ? 360
                : 500,
          ),

          minContainerWidth: 200,
          minContainerHeight: 200,

          movable: true,
          zoomable: true,
          zoomOnTouch: true,
          zoomOnWheel: true,
          cropBoxMovable: true,
          cropBoxResizable: true,

          barrierColor: Colors.black87,

          translations: const WebTranslations(
            title: 'Cadrer la photo',
            rotateLeftTooltip: 'Tourner à gauche',
            rotateRightTooltip: 'Tourner à droite',
            cancelButton: 'Annuler',
            cropButton: 'Valider',
          ),
        ),
      ],
    );

    if (croppedPhoto == null) {
      return null;
    }

    return XFile(
      croppedPhoto.path,
    );
  }

  Future<void> selectPhoto(int number) async {
    if (isSaving) return;

    final selectedPhoto = await pickPhoto();

    if (selectedPhoto == null || !mounted) {
      return;
    }

    setState(() {
      if (number == 1) {
        photo1 = selectedPhoto;
      } else if (number == 2) {
        photo2 = selectedPhoto;
        removePhoto2 = false;
      } else if (number == 3) {
        photo3 = selectedPhoto;
        removePhoto3 = false;
      }
    });
  }

  // ============================================
  // SUPPRIMER UNE PHOTO OPTIONNELLE
  // ============================================

  void deletePhoto(int number) {
    if (isSaving) return;

    if (number == 1) {
      showMessage(
        'La photo principale est obligatoire. '
        'Tu peux la remplacer, mais pas la supprimer.',
      );

      return;
    }

    setState(() {
      if (number == 2) {
        photo2 = null;
        existingPhoto2Url = null;
        removePhoto2 = true;
      } else if (number == 3) {
        photo3 = null;
        existingPhoto3Url = null;
        removePhoto3 = true;
      }
    });
  }

  // ============================================
  // UPLOAD PHOTO
  // ============================================

  Future<String?> uploadPhoto(
    XFile? photo,
    int index,
  ) async {
    if (photo == null) {
      return null;
    }

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Utilisateur non connecté.',
      );
    }

    final Uint8List bytes = await photo.readAsBytes();

    final path = '${user.id}/photo_$index.jpg';

    await Supabase.instance.client.storage
        .from('profile-photos')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    return Supabase.instance.client.storage
        .from('profile-photos')
        .getPublicUrl(path);
  }

  // ============================================
  // SUPPRESSION STORAGE
  // ============================================

  Future<void> deletePhotoFromStorage(
    int index,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return;
    }

    final path = '${user.id}/photo_$index.jpg';

    try {
      await Supabase.instance.client.storage
          .from('profile-photos')
          .remove([
        path,
      ]);
    } catch (error) {
      debugPrint(
        'Erreur suppression photo $index : $error',
      );
    }
  }

  // ============================================
  // PSEUDO UNIQUE
  // ============================================

  Future<bool> usernameAlreadyExists(
    String username,
    String currentUserId,
  ) async {
    final response =
        await Supabase.instance.client
            .from('profiles')
            .select('id')
            .ilike(
              'username',
              username,
            )
            .neq(
              'id',
              currentUserId,
            )
            .limit(1);

    return response.isNotEmpty;
  }

  // ============================================
  // VALIDATION PSEUDO ONBOARDING
  // ============================================

  Future<void> continueFromUsername() async {
    if (isSaving) return;

    final username = usernameController.text.trim();

    if (username.isEmpty) {
      showMessage('Choisis un pseudo.');
      return;
    }

    if (username.length < 3) {
      showMessage(
        'Le pseudo doit contenir au moins 3 caractères.',
      );
      return;
    }

    if (username.length > 20) {
      showMessage(
        'Le pseudo est limité à 20 caractères.',
      );
      return;
    }

    final usernameRegex = RegExp(
      r'^[a-zA-Z0-9._]+$',
    );

    if (!usernameRegex.hasMatch(username)) {
      showMessage(
        'Utilise uniquement des lettres, chiffres, '
        'points ou underscores.',
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      showMessage('Utilisateur non connecté.');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final pseudoPris = await usernameAlreadyExists(
        username,
        user.id,
      );

      if (!mounted) return;

      if (pseudoPris) {
        setState(() {
          isSaving = false;
        });

        showMessage(
          'Ce pseudo est déjà utilisé.',
        );

        return;
      }

      setState(() {
        isSaving = false;
        setupStep = 1;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      showMessage(
        'Impossible de vérifier le pseudo.',
      );
    }
  }

  // ============================================
  // VALIDATION DATE ONBOARDING
  // ============================================

  void continueFromBirthDate() {
    if (birthDate == null) {
      showMessage(
        'Indique ta date de naissance pour continuer.',
      );
      return;
    }

    final age = calculateAge(birthDate!);

    if (age < 13) {
      showMessage(
        'Tu dois avoir au moins 13 ans pour utiliser ARC.',
      );
      return;
    }

    if (age > 120) {
      showMessage(
        'Entre une date de naissance valide.',
      );
      return;
    }

    setState(() {
      setupStep = 2;
    });
  }

  // ============================================
  // RETOUR ONBOARDING
  // ============================================

  void previousSetupStep() {
    if (isSaving) return;

    if (setupStep > 0) {
      setState(() {
        setupStep--;
      });
    }
  }

  // ============================================
  // SAUVEGARDER
  // ============================================

  Future<void> saveProfile() async {
    if (isSaving) {
      return;
    }

    final username = usernameController.text.trim();
    final bio = bioController.text.trim();

    if (username.isEmpty) {
      showMessage(
        'Choisis un pseudo.',
      );

      return;
    }

    if (username.length < 3) {
      showMessage(
        'Le pseudo doit contenir au moins 3 caractères.',
      );

      return;
    }

    if (username.length > 20) {
      showMessage(
        'Le pseudo est limité à 20 caractères.',
      );

      return;
    }

    final usernameRegex = RegExp(
      r'^[a-zA-Z0-9._]+$',
    );

    if (!usernameRegex.hasMatch(username)) {
      showMessage(
        'Utilise uniquement des lettres, chiffres, '
        'points ou underscores.',
      );

      return;
    }

    if (birthDate == null) {
      showMessage(
        'Indique ta date de naissance pour continuer.',
      );

      return;
    }

    final age = calculateAge(birthDate!);

    if (age < 13) {
      showMessage(
        'Tu dois avoir au moins 13 ans pour utiliser ARC.',
      );

      return;
    }

    if (age > 120) {
      showMessage(
        'Entre une date de naissance valide.',
      );

      return;
    }

    if (bio.length > 165) {
      showMessage(
        'La description est limitée à 165 caractères.',
      );

      return;
    }

    final hasMainPhoto =
        photo1 != null ||
        (existingPhoto1Url != null &&
            existingPhoto1Url!.isNotEmpty);

    if (!hasMainPhoto) {
      showMessage(
        'Ajoute une photo principale pour continuer.',
      );

      return;
    }

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      showMessage(
        'Utilisateur non connecté.',
      );

      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final pseudoPris =
          await usernameAlreadyExists(
        username,
        user.id,
      );

      if (pseudoPris) {
        if (!mounted) return;

        setState(() {
          isSaving = false;
        });

        showMessage(
          'Ce pseudo est déjà utilisé.',
        );

        return;
      }

      if (removePhoto2) {
        await deletePhotoFromStorage(2);
      }

      if (removePhoto3) {
        await deletePhotoFromStorage(3);
      }

      final newPhoto1Url =
          await uploadPhoto(
        photo1,
        1,
      );

      final newPhoto2Url =
          await uploadPhoto(
        photo2,
        2,
      );

      final newPhoto3Url =
          await uploadPhoto(
        photo3,
        3,
      );

      final finalPhoto1Url =
          newPhoto1Url ?? existingPhoto1Url;

      final finalPhoto2Url =
          removePhoto2
              ? null
              : newPhoto2Url ??
                  existingPhoto2Url;

      final finalPhoto3Url =
          removePhoto3
              ? null
              : newPhoto3Url ??
                  existingPhoto3Url;

      if (finalPhoto1Url == null ||
          finalPhoto1Url.isEmpty) {
        if (!mounted) return;

        setState(() {
          isSaving = false;
        });

        showMessage(
          'Une photo principale est obligatoire.',
        );

        return;
      }

      await Supabase.instance.client
          .from('profiles')
          .upsert({
        'id': user.id,
        'username': username,
        'age': age,
        'birth_date':
            '${birthDate!.year.toString().padLeft(4, '0')}-'
            '${birthDate!.month.toString().padLeft(2, '0')}-'
            '${birthDate!.day.toString().padLeft(2, '0')}',
        'bio': bio,
        'photo_1_url': finalPhoto1Url,
        'photo_2_url': finalPhoto2Url,
        'photo_3_url': finalPhoto3Url,
      });

      if (!mounted) return;

      if (isExistingProfile) {
        Navigator.pop(context);
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const HomeScreen(),
          ),
          (route) => false,
        );
      }
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      if (error.code == '23505') {
        showMessage(
          'Ce pseudo est déjà utilisé.',
        );
      } else {
        showMessage(
          'Erreur Supabase : ${error.message}',
        );
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      showMessage(
        'Erreur : $error',
      );
    }
  }

  // ============================================
  // MESSAGE
  // ============================================

  void showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================
  // BUILD
  // ============================================

  @override
  Widget build(
    BuildContext context,
  ) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!isExistingProfile) {
      return _buildInitialSetup();
    }

    return _buildEditProfile();
  }

  // ============================================
  // CRÉATION INITIALE — RESPONSIVE
  // ============================================

  Widget _buildInitialSetup() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: setupStep > 0
            ? IconButton(
                onPressed:
                    isSaving ? null : previousSetupStep,
                icon: const Icon(
                  Icons.arrow_back,
                ),
              )
            : null,
        title: const Text(
          'Créer ton profil',
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWideScreen =
                constraints.maxWidth >= 700;

            final horizontalPadding =
                isWideScreen ? 32.0 : 28.0;

            final setupContent = ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 520,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                ),
                child: Column(
                  children: [
                    const SizedBox(
                      height: 8,
                    ),

                    _buildSetupProgress(),

                    SizedBox(
                      height:
                          isWideScreen ? 34 : 42,
                    ),

                    Expanded(
                      child: AnimatedSwitcher(
                        duration:
                            const Duration(
                          milliseconds: 220,
                        ),
                        child: setupStep == 0
                            ? _buildUsernameStep()
                            : setupStep == 1
                                ? _buildBirthDateStep()
                                : _buildPhotoStep(
                                    isWideScreen:
                                        isWideScreen,
                                  ),
                      ),
                    ),
                  ],
                ),
              ),
            );

            if (isWideScreen) {
              return Center(
                child: SizedBox(
                  height: constraints.maxHeight > 720
                      ? 720
                      : constraints.maxHeight,
                  child: setupContent,
                ),
              );
            }

            return Center(
              child: SizedBox(
                height: constraints.maxHeight,
                child: setupContent,
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================
  // PROGRESSION ONBOARDING
  // ============================================

  Widget _buildSetupProgress() {
    return Column(
      children: [
        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${setupStep + 1} sur 3',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Text(
              'ARC',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 12,
        ),

        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: (setupStep + 1) / 3,
            minHeight: 3,
            backgroundColor: Colors.white12,
            valueColor:
                const AlwaysStoppedAnimation<Color>(
              Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================
  // ÉTAPE 1 — PSEUDO
  // ============================================

  Widget _buildUsernameStep() {
    return Column(
      key: const ValueKey('username_step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choisis ton pseudo',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 10,
        ),

        const Text(
          'C’est le nom que les autres utilisateurs '
          'verront sur ARC.',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 15,
            height: 1.4,
          ),
        ),

        const SizedBox(
          height: 38,
        ),

        TextField(
          controller: usernameController,
          enabled: !isSaving,
          autofocus: true,
          autocorrect: false,
          maxLength: 20,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!isSaving) {
              continueFromUsername();
            }
          },
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
          ),
          decoration: const InputDecoration(
            labelText: 'Pseudo',
            hintText: 'ex : marc.vane',
            prefixText: '@',
            labelStyle: TextStyle(
              color: Colors.white60,
            ),
            hintStyle: TextStyle(
              color: Colors.white30,
            ),
          ),
        ),

        const Spacer(),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed:
                isSaving ? null : continueFromUsername,
            child: isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Continuer',
                  ),
          ),
        ),

        const SizedBox(
          height: 22,
        ),
      ],
    );
  }

  // ============================================
  // ÉTAPE 2 — DATE DE NAISSANCE
  // ============================================

  Widget _buildBirthDateStep() {
    return Column(
      key: const ValueKey('birth_date_step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quelle est ta date de naissance ?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 10,
        ),

        const Text(
          'Tu dois avoir au moins 13 ans '
          'pour utiliser ARC.',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 15,
            height: 1.4,
          ),
        ),

        const SizedBox(
          height: 42,
        ),

        InkWell(
          onTap:
              isSaving ? null : selectBirthDate,
          borderRadius: BorderRadius.circular(4),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Date de naissance',
              labelStyle: TextStyle(
                color: Colors.white60,
              ),
              suffixIcon: Icon(
                Icons.calendar_month_outlined,
                color: Colors.white60,
              ),
            ),
            child: Text(
              birthDate == null
                  ? 'Choisir une date'
                  : formatBirthDate(
                      birthDate!,
                    ),
              style: TextStyle(
                color: birthDate == null
                    ? Colors.white38
                    : Colors.white,
                fontSize: 17,
              ),
            ),
          ),
        ),

        if (birthDate != null) ...[
          const SizedBox(
            height: 10,
          ),
          Text(
            '${calculateAge(birthDate!)} ans',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],

        const Spacer(),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed:
                isSaving ? null : continueFromBirthDate,
            child: const Text(
              'Continuer',
            ),
          ),
        ),

        const SizedBox(
          height: 22,
        ),
      ],
    );
  }

  // ============================================
  // ÉTAPE 3 — PHOTO PRINCIPALE
  // ============================================

  Widget _buildPhotoStep({
    required bool isWideScreen,
  }) {
    final hasMainPhoto =
        photo1 != null ||
        (existingPhoto1Url != null &&
            existingPhoto1Url!.isNotEmpty);

    final photoWidth =
        isWideScreen ? 190.0 : 210.0;

    final photoHeight =
        isWideScreen ? 253.0 : 280.0;

    return Column(
      key: const ValueKey('photo_step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ajoute ton premier look',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 10,
        ),

        const Text(
          'Cette photo sera ta photo principale '
          'et sera utilisée pour les affrontements.',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 15,
            height: 1.4,
          ),
        ),

        SizedBox(
          height: isWideScreen ? 22 : 34,
        ),

        Expanded(
          child: Center(
            child: GestureDetector(
              onTap:
                  isSaving ? null : () => selectPhoto(1),
              child: Container(
                width: photoWidth,
                height: photoHeight,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  border: Border.all(
                    color: hasMainPhoto
                        ? Colors.white
                        : Colors.white38,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: hasMainPhoto
                    ? _photoContent(
                        newPhoto: photo1,
                        existingUrl:
                            existingPhoto1Url,
                      )
                    : const Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            color: Colors.white,
                            size: 42,
                          ),
                          SizedBox(
                            height: 14,
                          ),
                          Text(
                            'Ajouter une photo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),

        if (hasMainPhoto)
          Center(
            child: TextButton(
              onPressed:
                  isSaving ? null : () => selectPhoto(1),
              child: const Text(
                'Changer la photo',
              ),
            ),
          ),

        const SizedBox(
          height: 12,
        ),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed:
                isSaving ? null : saveProfile,
            child: isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Rejoindre ARC',
                  ),
          ),
        ),

        const SizedBox(
          height: 22,
        ),
      ],
    );
  }

  // ============================================
  // MODIFIER LE PROFIL — RESPONSIVE
  // ============================================

  Widget _buildEditProfile() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Modifier le profil',
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWideScreen =
                constraints.maxWidth >= 700;

            final horizontalPadding =
                isWideScreen ? 32.0 : 28.0;

            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 520,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(
                          height: 20,
                        ),

                        TextField(
                          controller: usernameController,
                          autocorrect: false,
                          maxLength: 20,
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Pseudo',
                            hintText: 'ex : marc.vane',
                            prefixText: '@',
                            labelStyle: TextStyle(
                              color: Colors.white60,
                            ),
                            hintStyle: TextStyle(
                              color: Colors.white30,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        InkWell(
                          onTap: isSaving
                              ? null
                              : selectBirthDate,
                          borderRadius:
                              BorderRadius.circular(4),
                          child: InputDecorator(
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'Date de naissance *',
                              labelStyle: TextStyle(
                                color: Colors.white60,
                              ),
                              suffixIcon: Icon(
                                Icons
                                    .calendar_month_outlined,
                                color: Colors.white60,
                              ),
                            ),
                            child: Text(
                              birthDate == null
                                  ? 'Choisir une date'
                                  : formatBirthDate(
                                      birthDate!,
                                    ),
                              style: TextStyle(
                                color: birthDate == null
                                    ? Colors.white38
                                    : Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),

                        if (birthDate != null) ...[
                          const SizedBox(
                            height: 7,
                          ),
                          Align(
                            alignment:
                                Alignment.centerLeft,
                            child: Text(
                              '${calculateAge(birthDate!)} ans',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(
                          height: 24,
                        ),

                        TextField(
                          controller: bioController,
                          maxLength: 165,
                          maxLines: 4,
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Description (facultatif)',
                            alignLabelWithHint: true,
                            labelStyle: TextStyle(
                              color: Colors.white60,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        const Align(
                          alignment:
                              Alignment.centerLeft,
                          child: Text(
                            'Photos',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 6,
                        ),

                        const Align(
                          alignment:
                              Alignment.centerLeft,
                          child: Text(
                            'La photo principale est obligatoire et sera '
                            'utilisée pour les affrontements.',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            _buildPhotoSlot(
                              number: 1,
                              label: 'Principale *',
                              newPhoto: photo1,
                              existingUrl:
                                  existingPhoto1Url,
                              canDelete: false,
                            ),
                            _buildPhotoSlot(
                              number: 2,
                              label: 'Photo 2',
                              newPhoto: photo2,
                              existingUrl:
                                  existingPhoto2Url,
                              canDelete: true,
                            ),
                            _buildPhotoSlot(
                              number: 3,
                              label: 'Photo 3',
                              newPhoto: photo3,
                              existingUrl:
                                  existingPhoto3Url,
                              canDelete: true,
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 45,
                        ),

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : saveProfile,
                            child: isSaving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Enregistrer',
                                  ),
                          ),
                        ),

                        const SizedBox(
                          height: 30,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================
  // SLOT PHOTO
  // ============================================

  Widget _buildPhotoSlot({
    required int number,
    required String label,
    required XFile? newPhoto,
    required String? existingUrl,
    required bool canDelete,
  }) {
    final hasPhoto =
        newPhoto != null ||
        (existingUrl != null &&
            existingUrl.isNotEmpty);

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: isSaving
                  ? null
                  : () => selectPhoto(number),
              child: Container(
                width: 95,
                height: 120,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  border: Border.all(
                    color: hasPhoto
                        ? Colors.white
                        : number == 1
                            ? Colors.white54
                            : Colors.white30,
                  ),
                  borderRadius: BorderRadius.circular(
                    14,
                  ),
                ),
                child: _photoContent(
                  newPhoto: newPhoto,
                  existingUrl: existingUrl,
                ),
              ),
            ),

            if (hasPhoto && canDelete)
              Positioned(
                top: -8,
                right: -8,
                child: GestureDetector(
                  onTap: isSaving
                      ? null
                      : () => deletePhoto(
                            number,
                          ),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration:
                        const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(
          height: 8,
        ),

        Text(
          label,
          style: TextStyle(
            color: number == 1
                ? Colors.white
                : Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ============================================
  // CONTENU PHOTO
  // ============================================

  Widget _photoContent({
    required XFile? newPhoto,
    required String? existingUrl,
  }) {
    if (newPhoto != null) {
      return FutureBuilder<Uint8List>(
        future: newPhoto.readAsBytes(),
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.hasData) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white38,
              ),
            );
          }

          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );
    }

    if (existingUrl != null &&
        existingUrl.isNotEmpty) {
      final separator =
          existingUrl.contains('?') ? '&' : '?';

      final cacheBustedUrl =
          '$existingUrl${separator}v=$photoCacheVersion';

      return Image.network(
        cacheBustedUrl,
        fit: BoxFit.cover,
        errorBuilder: (
          context,
          error,
          stackTrace,
        ) {
          return const Center(
            child: Icon(
              Icons.person,
              color: Colors.white38,
            ),
          );
        },
      );
    }

    return const Center(
      child: Icon(
        Icons.add_a_photo_outlined,
        color: Colors.white54,
        size: 30,
      ),
    );
  }
}