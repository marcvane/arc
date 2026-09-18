import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // =================================
  // SUPABASE
  // =================================

  try {
    await Supabase.initialize(
      url:
          'https://fervsgtratqvwcxljdqd.supabase.co',
      publishableKey:
          'sb_publishable_Q84yZ-nOd4IqBBsetrJOMw_vtI0yG_B',
    );
  } catch (error, stackTrace) {
    debugPrint(
      'Erreur initialisation Supabase : $error',
    );

    debugPrint(
      '$stackTrace',
    );
  }

  // =================================
  // FIREBASE
  //
  // Android / iOS uniquement.
  //
  // Firebase ne doit jamais empêcher
  // ARC de démarrer.
  // =================================

  if (!kIsWeb) {
    try {
      await Firebase.initializeApp(
        options:
            DefaultFirebaseOptions.currentPlatform,
      );

      debugPrint(
        'Firebase initialisé correctement.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Firebase non initialisé : $error',
      );

      debugPrint(
        '$stackTrace',
      );
    }
  }

  // =================================
  // LANCEMENT DE L'APPLICATION
  // =================================

  runApp(
    const ArcApp(),
  );
}

// =================================
// APPLICATION ARC
// =================================

class ArcApp extends StatefulWidget {
  const ArcApp({
    super.key,
  });

  @override
  State<ArcApp> createState() =>
      _ArcAppState();
}

class _ArcAppState extends State<ArcApp> {
  StreamSubscription<AuthState>?
      authSubscription;

  @override
  void initState() {
    super.initState();

    try {
      authSubscription =
          Supabase.instance.client.auth
              .onAuthStateChange
              .listen(
        (data) {
          if (!mounted) {
            return;
          }

          setState(
            () {},
          );
        },
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Erreur écoute Auth Supabase : $error',
      );

      debugPrint(
        '$stackTrace',
      );
    }
  }

  @override
  void dispose() {
    authSubscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'ARC',

      theme: ThemeData(
        brightness:
            Brightness.dark,

        scaffoldBackgroundColor:
            Colors.black,

        colorScheme:
            const ColorScheme.dark(
          primary:
              Colors.white,
        ),
      ),

      home:
          const AuthGate(),
    );
  }
}

// =================================
// AUTH GATE
// =================================

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
  });

  @override
  State<AuthGate> createState() =>
      _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool isLoading = true;

  bool hasProfile = false;

  bool notificationsInitialized =
      false;

  @override
  void initState() {
    super.initState();

    checkAccount();
  }

  // ==============================
  // VÉRIFICATION DU COMPTE
  // ==============================

  Future<void> checkAccount() async {
    try {
      final user =
          Supabase.instance.client.auth
              .currentUser;

      // ==============================
      // PAS CONNECTÉ
      // ==============================

      if (user == null) {
        if (!mounted) {
          return;
        }

        setState(
          () {
            isLoading = false;

            hasProfile = false;

            notificationsInitialized =
                false;
          },
        );

        return;
      }

      // ==============================
      // VÉRIFICATION DU PROFIL
      // ==============================

      final profile =
          await Supabase.instance.client
              .from(
                'profiles',
              )
              .select(
                'id, username, birth_date, photo_1_url',
              )
              .eq(
                'id',
                user.id,
              )
              .maybeSingle();

      final username =
          profile?['username']
              as String?;

      final birthDate =
          profile?['birth_date'];

      final photo1Url =
          profile?['photo_1_url']
              as String?;

      final profileComplete =
          profile != null &&
          username != null &&
          username
              .trim()
              .isNotEmpty &&
          birthDate != null &&
          birthDate
              .toString()
              .trim()
              .isNotEmpty &&
          photo1Url != null &&
          photo1Url
              .trim()
              .isNotEmpty;

      if (!mounted) {
        return;
      }

      setState(
        () {
          hasProfile =
              profileComplete;

          isLoading =
              false;
        },
      );

      // ==============================
      // NOTIFICATIONS
      // ==============================

      if (!kIsWeb &&
          profileComplete &&
          !notificationsInitialized) {
        notificationsInitialized =
            true;

        try {
          await NotificationService
              .initialize();
        } catch (error, stackTrace) {
          debugPrint(
            'Impossible d’initialiser '
            'les notifications : $error',
          );

          debugPrint(
            '$stackTrace',
          );

          notificationsInitialized =
              false;
        }
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Impossible de vérifier '
        'le compte : $error',
      );

      debugPrint(
        '$stackTrace',
      );

      if (!mounted) {
        return;
      }

      setState(
        () {
          hasProfile =
              false;

          isLoading =
              false;

          notificationsInitialized =
              false;
        },
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    User? user;

    try {
      user =
          Supabase.instance.client.auth
              .currentUser;
    } catch (error) {
      debugPrint(
        'Impossible de lire '
        'l’utilisateur Supabase : $error',
      );

      user = null;
    }

    // ==============================
    // CHARGEMENT
    // ==============================

    if (isLoading) {
      return const Scaffold(
        backgroundColor:
            Colors.black,

        body:
            Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    // ==============================
    // UTILISATEUR NON CONNECTÉ
    // ==============================

    if (user == null) {
      return const WelcomePage();
    }

    // ==============================
    // PROFIL À COMPLÉTER
    // ==============================

    if (!hasProfile) {
      return const ProfileSetupScreen();
    }

    // ==============================
    // APPLICATION
    // ==============================

    return const HomeScreen();
  }
}

// =================================
// PAGE D'ACCUEIL
// =================================

class WelcomePage extends StatelessWidget {
  const WelcomePage({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          Colors.black,

      body:
          SafeArea(
        child:
            Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal:
                28,
          ),

          child:
              Column(
            children: [
              const Spacer(),

              // ==========================
              // LOGO ARC
              // ==========================

              Image.asset(
                'assets/arc_logo.png',
                height:
                    100,
                fit:
                    BoxFit.contain,
              ),

              const SizedBox(
                height:
                    20,
              ),

              const Text(
                "L'audace a un nom.",

                textAlign:
                    TextAlign.center,

                style:
                    TextStyle(
                  fontSize:
                      16,

                  color:
                      Colors.white70,

                  letterSpacing:
                      1,
                ),
              ),

              const Spacer(),

              // ==========================
              // ENTRÉE UNIQUE ARC
              // ==========================

              SizedBox(
                width:
                    double.infinity,

                height:
                    56,

                child:
                    ElevatedButton(
                  onPressed:
                      () {
                    Navigator.push(
                      context,

                      MaterialPageRoute(
                        builder:
                            (
                              context,
                            ) =>
                                const LoginScreen(),
                      ),
                    );
                  },

                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        Colors.white,

                    foregroundColor:
                        Colors.black,

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                    ),
                  ),

                  child:
                      const Text(
                    'Commencer',

                    style:
                        TextStyle(
                      fontSize:
                          17,

                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height:
                    24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}