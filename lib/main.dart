import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'home_screen.dart';
import 'login_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==============================
  // FIREBASE
  //
  // Android / iOS uniquement pour
  // le moment.
  //
  // La version Web ARC utilise
  // Supabase normalement, mais ne
  // démarre pas Firebase tant que
  // Firebase Web n'est pas configuré.
  // ==============================

  if (!kIsWeb) {
    await Firebase.initializeApp();
  }

  // ==============================
  // SUPABASE
  // ==============================

  await Supabase.initialize(
    url:
        'https://fervsgtratqvwcxljdqd.supabase.co',
    publishableKey:
        'sb_publishable_Q84yZ-nOd4IqBBsetrJOMw_vtI0yG_B',
  );

  runApp(const ArcApp());
}

// =================================
// APPLICATION ARC
// =================================

class ArcApp extends StatefulWidget {
  const ArcApp({super.key});

  @override
  State<ArcApp> createState() => _ArcAppState();
}

class _ArcAppState extends State<ArcApp> {
  StreamSubscription<AuthState>? authSubscription;

  @override
  void initState() {
    super.initState();

    authSubscription = Supabase
        .instance.client.auth.onAuthStateChange
        .listen((data) {
      if (!mounted) return;

      setState(() {});
    });
  }

  @override
  void dispose() {
    authSubscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ARC',

      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,

        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
        ),
      ),

      home: const AuthGate(),
    );
  }
}

// =================================
// AUTH GATE
// =================================

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() =>
      _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool isLoading = true;

  // "hasProfile" signifie :
  // le profil ARC est réellement terminé,
  // avec pseudo + date de naissance
  // + photo principale.
  bool hasProfile = false;

  bool notificationsInitialized = false;

  @override
  void initState() {
    super.initState();

    checkAccount();
  }

  // ==============================
  // VÉRIFICATION DU COMPTE
  // ==============================

  Future<void> checkAccount() async {
    final user =
        Supabase.instance.client.auth.currentUser;

    // ==============================
    // PAS CONNECTÉ
    // ==============================

    if (user == null) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        hasProfile = false;
        notificationsInitialized = false;
      });

      return;
    }

    // ==============================
    // VÉRIFICATION DU PROFIL
    // ==============================

    try {
      final profile = await Supabase
          .instance.client
          .from('profiles')
          .select(
            'id, username, birth_date, photo_1_url',
          )
          .eq('id', user.id)
          .maybeSingle();

      // ==============================
      // PROFIL COMPLET ?
      // ==============================

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

      setState(() {
        hasProfile = profileComplete;
        isLoading = false;
      });

      // ==============================
      // NOTIFICATIONS
      //
      // Pas sur Web pour le moment.
      // ==============================

      if (!kIsWeb &&
          profileComplete &&
          !notificationsInitialized) {
        notificationsInitialized = true;

        try {
          await NotificationService.initialize();
        } catch (error) {
          debugPrint(
            'Impossible d’initialiser '
            'les notifications : $error',
          );

          notificationsInitialized = false;
        }
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        hasProfile = false;
        isLoading = false;
      });

      debugPrint(
        'Impossible de vérifier le profil : $error',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user =
        Supabase.instance.client.auth.currentUser;

    // ==============================
    // CHARGEMENT
    // ==============================

    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,

        body: Center(
          child: CircularProgressIndicator(),
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
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 28,
          ),

          child: Column(
            children: [
              const Spacer(),

              // ==========================
              // LOGO ARC
              // ==========================

              Image.asset(
                'assets/arc_logo.png',
                height: 100,
                fit: BoxFit.contain,
              ),

              const SizedBox(
                height: 20,
              ),

              const Text(
                "L'audace a un nom.",
                textAlign: TextAlign.center,

                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  letterSpacing: 1,
                ),
              ),

              const Spacer(),

              // ==========================
              // ENTRÉE UNIQUE ARC
              // ==========================

              SizedBox(
                width: double.infinity,
                height: 56,

                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const LoginScreen(),
                      ),
                    );
                  },

                  style:
                      ElevatedButton.styleFrom(
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

                  child: const Text(
                    'Commencer',

                    style: TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}