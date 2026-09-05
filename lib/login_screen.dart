import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/about_arc_screen.dart';
import 'screens/contact_arc_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/terms_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ============================================
  // CONTROLLERS
  // ============================================

  final emailController = TextEditingController();
  final codeController = TextEditingController();

  // ============================================
  // ÉTAT AUTH
  // ============================================

  bool isLoading = false;
  bool codeSent = false;

  String pendingEmail = '';

  // ============================================
  // ACCEPTATION LÉGALE
  // ============================================

  bool acceptedLegal = false;

  static const String termsVersion = '1.0';
  static const String privacyVersion = '1.0';

  // ============================================
  // RENVOI DU CODE
  // ============================================

  int resendSeconds = 0;

  Timer? resendTimer;

  // ============================================
  // NOTIFICATION ARC
  // ============================================

  String? arcNotificationMessage;

  ArcNotificationType arcNotificationType =
      ArcNotificationType.info;

  Timer? notificationTimer;

  // ============================================
  // AFFICHER NOTIFICATION ARC
  // ============================================

  void showArcNotification(
    String message, {
    ArcNotificationType type = ArcNotificationType.info,
    Duration duration = const Duration(seconds: 5),
  }) {
    notificationTimer?.cancel();

    if (!mounted) return;

    setState(() {
      arcNotificationMessage = message;
      arcNotificationType = type;
    });

    notificationTimer = Timer(
      duration,
      () {
        if (!mounted) return;

        setState(() {
          arcNotificationMessage = null;
        });
      },
    );
  }

  // ============================================
  // MASQUER NOTIFICATION ARC
  // ============================================

  void hideArcNotification() {
    notificationTimer?.cancel();

    if (!mounted) return;

    setState(() {
      arcNotificationMessage = null;
    });
  }

  // ============================================
  // VALIDATION EMAIL
  // ============================================

  bool _isValidEmail(String email) {
    final value = email.trim();

    if (value.isEmpty) {
      return false;
    }

    final regex = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    return regex.hasMatch(value);
  }

  // ============================================
  // TIMER RENVOI
  // ============================================

  void _startResendTimer() {
    resendTimer?.cancel();

    if (!mounted) return;

    setState(() {
      resendSeconds = 60;
    });

    resendTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (resendSeconds <= 1) {
          timer.cancel();

          setState(() {
            resendSeconds = 0;
          });

          return;
        }

        setState(() {
          resendSeconds--;
        });
      },
    );
  }

  // ============================================
  // ENVOYER LE CODE OTP
  // ============================================

  Future<void> sendCode({
    bool isResend = false,
  }) async {
    FocusScope.of(context).unfocus();

    hideArcNotification();

    final email = isResend
        ? pendingEmail
        : emailController.text.trim().toLowerCase();

    if (!_isValidEmail(email)) {
      showArcNotification(
        'Entre une adresse e-mail valide.',
        type: ArcNotificationType.error,
      );

      return;
    }

    if (!isResend && !acceptedLegal) {
      showArcNotification(
        'Accepte les Conditions d’utilisation '
        'et la Politique de confidentialité '
        'pour continuer.',
        type: ArcNotificationType.error,
        duration: const Duration(seconds: 6),
      );

      return;
    }

    if (isResend && resendSeconds > 0) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
        data: isResend
            ? null
            : {
                'terms_version': termsVersion,
                'privacy_version': privacyVersion,
                'legal_accepted_at':
                    DateTime.now().toUtc().toIso8601String(),
              },
      );

      if (!mounted) return;

      setState(() {
        pendingEmail = email;
        codeSent = true;
        codeController.clear();
        isLoading = false;
      });

      _startResendTimer();

      if (isResend) {
        showArcNotification(
          'Un nouveau code vient de t’être envoyé.',
          type: ArcNotificationType.success,
          duration: const Duration(seconds: 4),
        );
      }
    } on AuthException catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      debugPrint(
        'Erreur OTP ARC : ${error.message}',
      );

      showArcNotification(
        _friendlyOtpSendError(
          error.message,
        ),
        type: ArcNotificationType.error,
        duration: const Duration(seconds: 6),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      debugPrint(
        'Erreur envoi code ARC : $error',
      );

      showArcNotification(
        'Impossible d’envoyer le code. '
        'Réessaie dans quelques instants.',
        type: ArcNotificationType.error,
      );
    }
  }

  // ============================================
  // VÉRIFIER LE CODE OTP
  // ============================================

  Future<void> verifyCode() async {
    FocusScope.of(context).unfocus();

    hideArcNotification();

    final code = codeController.text
        .replaceAll(
          ' ',
          '',
        )
        .trim();

    if (code.length != 8 ||
        int.tryParse(code) == null) {
      showArcNotification(
        'Entre le code à 8 chiffres '
        'reçu par e-mail.',
        type: ArcNotificationType.error,
      );

      return;
    }

    if (pendingEmail.isEmpty) {
      showArcNotification(
        'Ton adresse e-mail est '
        'introuvable. Recommence.',
        type: ArcNotificationType.error,
      );

      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response =
          await Supabase.instance.client.auth.verifyOTP(
        email: pendingEmail,
        token: code,
        type: OtpType.email,
      );

      final user =
          response.user ??
          Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw Exception(
          'Impossible de récupérer '
          'le compte ARC.',
        );
      }

      final profile = await Supabase.instance.client
          .from('profiles')
          .select(
            'id, username, birth_date, photo_1_url',
          )
          .eq(
            'id',
            user.id,
          )
          .maybeSingle();

      final username =
          profile?['username'] as String?;

      final birthDate =
          profile?['birth_date'];

      final photo1Url =
          profile?['photo_1_url'] as String?;

      final profileComplete =
          profile != null &&
          username != null &&
          username.trim().isNotEmpty &&
          birthDate != null &&
          birthDate.toString().trim().isNotEmpty &&
          photo1Url != null &&
          photo1Url.trim().isNotEmpty;

      if (!mounted) return;

      resendTimer?.cancel();

      if (!profileComplete) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const ProfileSetupScreen(),
          ),
          (route) => false,
        );

        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const HomeScreen(),
        ),
        (route) => false,
      );
    } on AuthException catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      debugPrint(
        'Erreur vérification OTP ARC : '
        '${error.message}',
      );

      showArcNotification(
        _friendlyOtpVerifyError(
          error.message,
        ),
        type: ArcNotificationType.error,
        duration: const Duration(seconds: 6),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      debugPrint(
        'Erreur connexion OTP ARC : '
        '$error',
      );

      showArcNotification(
        'Impossible de vérifier le code. '
        'Réessaie.',
        type: ArcNotificationType.error,
      );
    }
  }

  // ============================================
  // ERREUR ENVOI OTP LISIBLE
  // ============================================

  String _friendlyOtpSendError(
    String rawMessage,
  ) {
    final message =
        rawMessage.toLowerCase();

    if (message.contains('rate limit') ||
        message.contains('too many requests') ||
        message.contains('security purposes') ||
        message.contains('seconds')) {
      return 'Patiente quelques instants '
          'avant de demander un nouveau code.';
    }

    if (message.contains(
      'invalid email',
    )) {
      return 'Cette adresse e-mail '
          'n’est pas valide.';
    }

    return 'Impossible d’envoyer le code. '
        'Réessaie dans quelques instants.';
  }

  // ============================================
  // ERREUR OTP LISIBLE
  // ============================================

  String _friendlyOtpVerifyError(
    String rawMessage,
  ) {
    final message =
        rawMessage.toLowerCase();

    if (message.contains('expired') ||
        message.contains('otp_expired')) {
      return 'Ce code a expiré. '
          'Demande un nouveau code.';
    }

    if (message.contains('invalid') ||
        message.contains('token')) {
      return 'Ce code est incorrect '
          'ou a expiré.';
    }

    if (message.contains('rate limit') ||
        message.contains('too many requests')) {
      return 'Trop de tentatives. '
          'Réessaie dans quelques instants.';
    }

    return 'Code incorrect ou expiré. '
        'Vérifie les 8 chiffres.';
  }

  // ============================================
  // MODIFIER L'ADRESSE E-MAIL
  // ============================================

  void changeEmail() {
    FocusScope.of(context).unfocus();

    resendTimer?.cancel();

    hideArcNotification();

    setState(() {
      codeSent = false;
      codeController.clear();
      pendingEmail = '';
      resendSeconds = 0;
      isLoading = false;
    });
  }

  // ============================================
  // OUVRIR UN ÉCRAN
  // ============================================

  void _openScreen(
    Widget screen,
  ) {
    FocusScope.of(context).unfocus();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            screen,
      ),
    );
  }

  // ============================================
  // LIEN FOOTER
  // ============================================

  Widget _footerLink(
    String text,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(8),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 5,
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11.5,
            fontWeight:
                FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ============================================
  // FOOTER ARC
  // ============================================

  Widget _buildFooter() {
    return Column(
      children: [
        Wrap(
          alignment:
              WrapAlignment.center,
          crossAxisAlignment:
              WrapCrossAlignment.center,
          spacing: 2,
          runSpacing: 0,
          children: [
            _footerLink(
              'À propos d’ARC',
              () {
                _openScreen(
                  const AboutArcScreen(),
                );
              },
            ),
            const Text(
              '•',
              style: TextStyle(
                color: Colors.white24,
                fontSize: 10,
              ),
            ),
            _footerLink(
              'Nous contacter',
              () {
                _openScreen(
                  const ContactArcScreen(),
                );
              },
            ),
          ],
        ),
        Wrap(
          alignment:
              WrapAlignment.center,
          crossAxisAlignment:
              WrapCrossAlignment.center,
          spacing: 2,
          runSpacing: 0,
          children: [
            _footerLink(
              'Confidentialité',
              () {
                _openScreen(
                  const PrivacyPolicyScreen(),
                );
              },
            ),
            const Text(
              '•',
              style: TextStyle(
                color: Colors.white24,
                fontSize: 10,
              ),
            ),
            _footerLink(
              'Conditions',
              () {
                _openScreen(
                  const TermsScreen(),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  // ============================================
  // NOTIFICATION ARC
  // ============================================

  Widget _buildArcNotification() {
    final message =
        arcNotificationMessage;

    if (message == null) {
      return const SizedBox.shrink();
    }

    IconData icon;
    String title;

    switch (arcNotificationType) {
      case ArcNotificationType.success:
        icon = Icons.check_rounded;
        title = 'ARC';
        break;

      case ArcNotificationType.error:
        icon =
            Icons.error_outline_rounded;
        title =
            'Un problème est survenu';
        break;

      case ArcNotificationType.info:
        icon =
            Icons.info_outline_rounded;
        title = 'ARC';
        break;
    }

    return AnimatedSwitcher(
      duration:
          const Duration(
        milliseconds: 250,
      ),
      child: Container(
        key: ValueKey(message),
        width: double.infinity,
        margin:
            const EdgeInsets.only(
          bottom: 24,
        ),
        padding:
            const EdgeInsets.all(
          16,
        ),
        decoration: BoxDecoration(
          color: const Color(
            0xFF151515,
          ),
          borderRadius:
              BorderRadius.circular(
            18,
          ),
          border: Border.all(
            color: Colors.white12,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 18,
              offset: Offset(
                0,
                8,
              ),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              padding:
                  const EdgeInsets.all(
                7,
              ),
              decoration:
                  BoxDecoration(
                color: Colors.black,
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),
                border: Border.all(
                  color:
                      Colors.white12,
                ),
              ),
              child: Image.asset(
                'assets/arc_logo.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(
              width: 14,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        icon,
                        color:
                            Colors.white,
                        size: 16,
                      ),
                      const SizedBox(
                        width: 6,
                      ),
                      Expanded(
                        child: Text(
                          title,
                          style:
                              const TextStyle(
                            color:
                                Colors.white,
                            fontSize:
                                14,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  Text(
                    message,
                    style:
                        const TextStyle(
                      color:
                          Colors.white60,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              width: 8,
            ),
            GestureDetector(
              onTap:
                  hideArcNotification,
              child:
                  const Padding(
                padding:
                    EdgeInsets.all(
                  4,
                ),
                child: Icon(
                  Icons.close_rounded,
                  color:
                      Colors.white38,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // ACCEPTATION LÉGALE
  // ============================================

  Widget _buildLegalAcceptance() {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: acceptedLegal,
          onChanged:
              isLoading
                  ? null
                  : (value) {
                      setState(() {
                        acceptedLegal =
                            value ??
                                false;
                      });
                    },
        ),
        Expanded(
          child: Padding(
            padding:
                const EdgeInsets.only(
              top: 11,
            ),
            child: Wrap(
              children: [
                const Text(
                  'J’accepte les ',
                  style: TextStyle(
                    color:
                        Colors.white70,
                    fontSize: 13,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _openScreen(
                      const TermsScreen(),
                    );
                  },
                  child:
                      const Text(
                    'Conditions d’utilisation',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize: 13,
                      fontWeight:
                          FontWeight.bold,
                      decoration:
                          TextDecoration
                              .underline,
                    ),
                  ),
                ),
                const Text(
                  ' et la ',
                  style: TextStyle(
                    color:
                        Colors.white70,
                    fontSize: 13,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _openScreen(
                      const PrivacyPolicyScreen(),
                    );
                  },
                  child:
                      const Text(
                    'Politique de confidentialité',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize: 13,
                      fontWeight:
                          FontWeight.bold,
                      decoration:
                          TextDecoration
                              .underline,
                    ),
                  ),
                ),
                const Text(
                  '.',
                  style: TextStyle(
                    color:
                        Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================
  // ÉTAPE E-MAIL
  // ============================================

  Widget _buildEmailStep() {
    return Column(
      children: [
        const Text(
          'Entre ton adresse e-mail',
          textAlign:
              TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight:
                FontWeight.w700,
          ),
        ),
        const SizedBox(
          height: 8,
        ),
        const Text(
          'On t’enverra un code à 8 chiffres.',
          textAlign:
              TextAlign.center,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 14,
          ),
        ),
        const SizedBox(
          height: 30,
        ),
        TextField(
          controller:
              emailController,
          keyboardType:
              TextInputType.emailAddress,
          autocorrect: false,
          textCapitalization:
              TextCapitalization.none,
          textInputAction:
              TextInputAction.done,
          enabled: !isLoading,
          style:
              const TextStyle(
            color: Colors.white,
          ),
          decoration:
              const InputDecoration(
            labelText: 'E-mail',
          ),
          onSubmitted: (_) {
            if (!isLoading) {
              sendCode();
            }
          },
        ),
        const SizedBox(
          height: 18,
        ),
        _buildLegalAcceptance(),
        const SizedBox(
          height: 22,
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                isLoading
                    ? null
                    : sendCode,
            child:
                isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Continuer',
                      ),
          ),
        ),
      ],
    );
  }

  // ============================================
  // ÉTAPE CODE
  // ============================================

  Widget _buildCodeStep() {
    return Column(
      children: [
        const Text(
          'Entre ton code',
          textAlign:
              TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight:
                FontWeight.w700,
          ),
        ),
        const SizedBox(
          height: 8,
        ),
        const Text(
          'Un code à 8 chiffres a été envoyé à',
          textAlign:
              TextAlign.center,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 14,
          ),
        ),
        const SizedBox(
          height: 4,
        ),
        Text(
          pendingEmail,
          textAlign:
              TextAlign.center,
          style:
              const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight:
                FontWeight.w600,
          ),
        ),
        const SizedBox(
          height: 30,
        ),
        TextField(
          controller:
              codeController,
          keyboardType:
              TextInputType.number,
          maxLength: 8,
          textAlign:
              TextAlign.center,
          autofocus: true,
          enabled: !isLoading,
          textInputAction:
              TextInputAction.done,
          style:
              const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight:
                FontWeight.w700,
            letterSpacing: 8,
          ),
          decoration:
              const InputDecoration(
            hintText: '00000000',
            counterText: '',
          ),
          onChanged: (value) {
            final cleaned =
                value
                    .replaceAll(
                      ' ',
                      '',
                    )
                    .trim();

            if (cleaned.length == 8 &&
                int.tryParse(cleaned) !=
                    null &&
                !isLoading) {
              verifyCode();
            }
          },
          onSubmitted: (_) {
            if (!isLoading) {
              verifyCode();
            }
          },
        ),
        const SizedBox(
          height: 22,
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                isLoading
                    ? null
                    : verifyCode,
            child:
                isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Continuer',
                      ),
          ),
        ),
        const SizedBox(
          height: 12,
        ),
        TextButton(
          onPressed:
              isLoading ||
                      resendSeconds > 0
                  ? null
                  : () {
                      sendCode(
                        isResend: true,
                      );
                    },
          child: Text(
            resendSeconds > 0
                ? 'Renvoyer le code dans ${resendSeconds}s'
                : 'Renvoyer le code',
          ),
        ),
        TextButton(
          onPressed:
              isLoading
                  ? null
                  : changeEmail,
          child:
              const Text(
            'Modifier l’adresse e-mail',
          ),
        ),
      ],
    );
  }

  // ============================================
  // DISPOSE
  // ============================================

  @override
  void dispose() {
    notificationTimer?.cancel();
    resendTimer?.cancel();

    emailController.dispose();
    codeController.dispose();

    super.dispose();
  }

  // ============================================
  // BUILD
  // ============================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              // ==================================
              // RESPONSIVE ARC
              //
              // Mobile :
              // conserve le comportement actuel.
              //
              // Grand écran :
              // largeur max 520 px
              // hauteur max 720 px
              // bloc entièrement centré.
              // ==================================

              final isWideScreen =
                  constraints.maxWidth >= 700;

              final horizontalPadding =
                  isWideScreen ? 32.0 : 24.0;

              final logoWidth =
                  isWideScreen ? 190.0 : 230.0;

              // ================================
              // CONTENU INTERNE ARC
              // ================================

              final content = ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 520,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    24,
                    horizontalPadding,
                    16,
                  ),
                  child: Column(
                    children: [
                      const Spacer(),

                      // ==================
                      // LOGO ARC
                      // ==================

                      Image.asset(
                        'assets/arc_logo.png',
                        width: logoWidth,
                        fit: BoxFit.contain,
                      ),

                      SizedBox(
                        height:
                            isWideScreen
                                ? 28
                                : 35,
                      ),

                      // ==================
                      // NOTIFICATION ARC
                      // ==================

                      _buildArcNotification(),

                      // ==================
                      // AUTH UNIQUE ARC
                      // ==================

                      AnimatedSwitcher(
                        duration:
                            const Duration(
                          milliseconds: 250,
                        ),
                        child: codeSent
                            ? Container(
                                key:
                                    const ValueKey(
                                  'code',
                                ),
                                child:
                                    _buildCodeStep(),
                              )
                            : Container(
                                key:
                                    const ValueKey(
                                  'email',
                                ),
                                child:
                                    _buildEmailStep(),
                              ),
                      ),

                      const Spacer(),

                      // ==================
                      // FOOTER ARC
                      // ==================

                      _buildFooter(),
                    ],
                  ),
                ),
              );

              // ==================================
              // GRAND ÉCRAN
              //
              // La colonne ARC ne peut jamais
              // s'étirer sur toute la hauteur PC.
              // Elle est limitée à 720 px et
              // centrée verticalement.
              // ==================================

              if (isWideScreen) {
                return SingleChildScrollView(
                  physics:
                      const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          constraints.maxHeight,
                    ),
                    child: Center(
                      child: SizedBox(
                        height: constraints.maxHeight >
                                720
                            ? 720
                            : constraints.maxHeight,
                        child: content,
                      ),
                    ),
                  ),
                );
              }

              // ==================================
              // MOBILE
              //
              // Même logique que précédemment :
              // le contenu utilise au minimum
              // toute la hauteur disponible.
              // ==================================

              return SingleChildScrollView(
                physics:
                    const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Center(
                      child: content,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ==============================================
// TYPE DE NOTIFICATION ARC
// ==============================================

enum ArcNotificationType {
  info,
  success,
  error,
}