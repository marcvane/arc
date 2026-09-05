import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/campus_service.dart';
import 'campus_chat_screen.dart';

class CampusScreen extends StatefulWidget {
  const CampusScreen({super.key});

  @override
  State<CampusScreen> createState() =>
      _CampusScreenState();
}

class _CampusScreenState extends State<CampusScreen> {
  bool isLoading = true;
  bool isSaving = false;

  String? errorMessage;

  // ============================================
  // INSCRIPTION CAMPUS
  // ============================================

  List<Map<String, dynamic>> campuses = [];

  String? selectedCampusId;

  // ============================================
  // CAMPUS ACTUEL
  // ============================================

  Map<String, dynamic>? myCampusData;

  // ============================================
  // CLASSEMENTS
  // ============================================

  List<Map<String, dynamic>> campusRanking = [];
  List<Map<String, dynamic>> universityRanking = [];

  int campusScore = 0;

  int selectedRankingIndex = 0;

  // ============================================
  // CARTE
  // ============================================

  final MapController mapController =
      MapController();

  List<Map<String, dynamic>> mapCampuses = [];

  Map<String, dynamic>? selectedMapCampus;

  @override
  void initState() {
    super.initState();

    loadEverything();
  }

  // ============================================
  // CHARGEMENT GLOBAL
  // ============================================

  Future<void> loadEverything() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final campusData =
          await CampusService.getMyCampus();

      // ========================================
      // UTILISATEUR SANS CAMPUS
      // ========================================

      if (campusData == null ||
          campusData['campus_id'] == null) {
        final results = await Future.wait([
          CampusService.getCampuses(),
          CampusService.getCampusesForMap(),
        ]);

        final campusList = results[0];

        final loadedMapCampuses = results[1];

        if (!mounted) return;

        setState(() {
          myCampusData = null;

          campuses = campusList;

          selectedCampusId = null;

          campusRanking = [];
          universityRanking = [];

          campusScore = 0;

          mapCampuses =
              loadedMapCampuses;

          selectedMapCampus = null;

          selectedRankingIndex = 0;

          isLoading = false;
          errorMessage = null;
        });

        return;
      }

      // ========================================
      // UTILISATEUR DÉJÀ INSCRIT
      // ========================================

      final campusId =
          campusData['campus_id'].toString();

      final results = await Future.wait([
        CampusService.getCampusRanking(
          campusId,
        ),
        CampusService.getUniversityRanking(),
        CampusService.getCampusScore(
          campusId,
        ),
        CampusService.getCampusesForMap(),
      ]);

      final loadedCampusRanking =
          results[0]
              as List<Map<String, dynamic>>;

      final loadedUniversityRanking =
          results[1]
              as List<Map<String, dynamic>>;

      final loadedCampusScore =
          results[2] as int;

      final loadedMapCampuses =
          results[3]
              as List<Map<String, dynamic>>;

      // ========================================
      // TROUVER MON CAMPUS SUR LA CARTE
      // ========================================

      Map<String, dynamic>? myMapCampus;

      for (final campus
          in loadedMapCampuses) {
        if (campus['id']?.toString() ==
            campusId) {
          myMapCampus = campus;
          break;
        }
      }

      final initialMapCampus =
          myMapCampus ??
              (loadedMapCampuses.isNotEmpty
                  ? loadedMapCampuses.first
                  : null);

      if (!mounted) return;

      setState(() {
        myCampusData = campusData;

        selectedCampusId = campusId;

        campusRanking =
            loadedCampusRanking;

        universityRanking =
            loadedUniversityRanking;

        campusScore =
            loadedCampusScore;

        mapCampuses =
            loadedMapCampuses;

        selectedMapCampus =
            initialMapCampus;

        selectedRankingIndex = 0;

        isLoading = false;
        errorMessage = null;
      });
    } catch (error) {
      debugPrint(
        'Erreur chargement Campus : $error',
      );

      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
            'Impossible de charger Campus.';
      });
    }
  }

  // ============================================
  // SÉLECTION CAMPUS
  // ============================================

  void selectCampus(
    String campusId,
  ) {
    setState(() {
      selectedCampusId = campusId;
    });
  }

  // ============================================
  // REJOINDRE CAMPUS
  // ============================================

  Future<void> saveSelection() async {
    final campusId = selectedCampusId;

    if (campusId == null) {
      showMessage('Choisis ton campus.');
      return;
    }

    final selectedCampus =
        campuses.cast<Map<String, dynamic>>().firstWhere(
      (campus) => campus['id']?.toString() == campusId,
      orElse: () => <String, dynamic>{},
    );

    final campusName =
        selectedCampus['name']?.toString() ?? 'ce campus';

    // ========================================
    // PILOTE LYCÉES DE BUSSY-SAINT-GEORGES
    // ========================================
    // Ces trois établissements peuvent être rejoints
    // directement, sans vérification d'e-mail.
    // Tous les autres campus conservent la
    // vérification étudiante actuelle.

    final isOpenPilotCampus =
        campusName == 'Lycée Martin Luther King' ||
            campusName == 'Lycée Maurice Rondeau' ||
            campusName == 'Collège Jacques-Yves Cousteau';

    if (isOpenPilotCampus) {
      if (isSaving) return;

      setState(() {
        isSaving = true;
      });

      try {
        await CampusService.joinCampus(
          campusId: campusId,
        );

        if (!mounted) return;

        setState(() {
          isSaving = false;
        });

        await loadEverything();
      } catch (error) {
        debugPrint(
          'Erreur inscription lycée pilote : $error',
        );

        if (!mounted) return;

        setState(() {
          isSaving = false;
        });

        showMessage(
          'Impossible de rejoindre cet établissement.',
        );
      }

      return;
    }

    await _openStudentVerification(
      campusId: campusId,
      campusName: campusName,
    );
  }

  // ============================================
  // VÉRIFICATION ÉTUDIANTE
  // ============================================

  Future<void> _openStudentVerification({
    required String campusId,
    required String campusName,
  }) async {
    final emailController = TextEditingController();

    final email = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool sending = false;
        String? localError;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              final value =
                  emailController.text.trim().toLowerCase();

              if (value.isEmpty || !value.contains('@')) {
                setDialogState(() {
                  localError =
                      'Entre ton adresse e-mail universitaire.';
                });
                return;
              }

              setDialogState(() {
                sending = true;
                localError = null;
              });

              try {
                final response = await Supabase.instance.client.functions.invoke(
                  'request-campus-verification',
                  body: {
                    'campus_id': campusId,
                    'university_email': value,
                  },
                );

                final data = response.data;

                if (data is Map &&
                    data['success'] == true) {
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext, value);
                  return;
                }

                final message = data is Map
                    ? data['error']?.toString()
                    : null;

                setDialogState(() {
                  sending = false;
                  localError =
                      message ?? 'Impossible d’envoyer le code.';
                });
              } on FunctionException catch (error) {
                String message =
                    'Impossible d’envoyer le code.';

                final details = error.details;
                if (details is Map &&
                    details['error'] != null) {
                  message = details['error'].toString();
                }

                setDialogState(() {
                  sending = false;
                  localError = message;
                });
              } catch (error) {
                debugPrint(
                  'Erreur demande vérification Campus : $error',
                );

                setDialogState(() {
                  sending = false;
                  localError =
                      'Impossible d’envoyer le code.';
                });
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF111111),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(
                  color: Colors.white12,
                ),
              ),
              title: const Text(
                'Vérifie ton statut étudiant',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pour rejoindre $campusName, utilise '
                      'l’adresse e-mail fournie par ton établissement.',
                      style: const TextStyle(
                        color: Colors.white60,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: emailController,
                      enabled: !sending,
                      keyboardType:
                          TextInputType.emailAddress,
                      textInputAction:
                          TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'prenom.nom@etu.univ-grenoble-alpes.fr',
                        hintStyle: const TextStyle(
                          color: Colors.white30,
                        ),
                        prefixIcon: const Icon(
                          Icons.school_outlined,
                          color: Colors.white54,
                        ),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Colors.white12,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      onSubmitted: (_) {
                        if (!sending) {
                          submit();
                        }
                      },
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        localError!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: sending
                      ? null
                      : () => Navigator.pop(
                            dialogContext,
                          ),
                  child: const Text(
                    'Annuler',
                    style: TextStyle(
                      color: Colors.white54,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: sending ? null : submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Envoyer le code',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();

    if (!mounted || email == null) {
      return;
    }

    await _openCodeVerification(
      campusId: campusId,
      campusName: campusName,
      universityEmail: email,
    );
  }

  Future<void> _openCodeVerification({
    required String campusId,
    required String campusName,
    required String universityEmail,
  }) async {
    final codeController = TextEditingController();

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool verifying = false;
        bool resending = false;
        String? localError;
        String? localInfo;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> verify() async {
              final code =
                  codeController.text.trim();

              if (!RegExp(r'^\d{6}$').hasMatch(code)) {
                setDialogState(() {
                  localError =
                      'Entre les 6 chiffres reçus par e-mail.';
                  localInfo = null;
                });
                return;
              }

              setDialogState(() {
                verifying = true;
                localError = null;
                localInfo = null;
              });

              try {
                final response =
                    await Supabase.instance.client.functions.invoke(
                  'verify-campus-code',
                  body: {
                    'code': code,
                  },
                );

                final data = response.data;

                if (data is Map &&
                    data['success'] == true) {
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext, true);
                  return;
                }

                final message = data is Map
                    ? data['error']?.toString()
                    : null;

                setDialogState(() {
                  verifying = false;
                  localError =
                      message ?? 'Code incorrect.';
                });
              } on FunctionException catch (error) {
                String message =
                    'Impossible de vérifier le code.';

                final details = error.details;
                if (details is Map &&
                    details['error'] != null) {
                  message = details['error'].toString();
                }

                setDialogState(() {
                  verifying = false;
                  localError = message;
                });
              } catch (error) {
                debugPrint(
                  'Erreur validation code Campus : $error',
                );

                setDialogState(() {
                  verifying = false;
                  localError =
                      'Impossible de vérifier le code.';
                });
              }
            }

            Future<void> resend() async {
              setDialogState(() {
                resending = true;
                localError = null;
                localInfo = null;
              });

              try {
                final response =
                    await Supabase.instance.client.functions.invoke(
                  'request-campus-verification',
                  body: {
                    'campus_id': campusId,
                    'university_email':
                        universityEmail,
                  },
                );

                final data = response.data;

                if (data is Map &&
                    data['success'] == true) {
                  setDialogState(() {
                    resending = false;
                    localInfo =
                        'Un nouveau code a été envoyé.';
                  });
                  return;
                }

                final message = data is Map
                    ? data['error']?.toString()
                    : null;

                setDialogState(() {
                  resending = false;
                  localError =
                      message ?? 'Impossible de renvoyer le code.';
                });
              } on FunctionException catch (error) {
                String message =
                    'Impossible de renvoyer le code.';

                final details = error.details;
                if (details is Map &&
                    details['error'] != null) {
                  message = details['error'].toString();
                }

                setDialogState(() {
                  resending = false;
                  localError = message;
                });
              } catch (error) {
                debugPrint(
                  'Erreur renvoi code Campus : $error',
                );

                setDialogState(() {
                  resending = false;
                  localError =
                      'Impossible de renvoyer le code.';
                });
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF111111),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(
                  color: Colors.white12,
                ),
              ),
              title: const Text(
                'Entre ton code',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.mark_email_read_outlined,
                      color: Colors.white,
                      size: 42,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Nous avons envoyé un code à 6 chiffres à\n'
                      '$universityEmail',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white60,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: codeController,
                      enabled: !verifying,
                      autofocus: true,
                      keyboardType:
                          TextInputType.number,
                      textInputAction:
                          TextInputAction.done,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '000000',
                        hintStyle: const TextStyle(
                          color: Colors.white24,
                          letterSpacing: 8,
                        ),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Colors.white12,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      onSubmitted: (_) {
                        if (!verifying) {
                          verify();
                        }
                      },
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        localError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (localInfo != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        localInfo!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed:
                          resending || verifying
                              ? null
                              : resend,
                      child: resending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Renvoyer le code',
                              style: TextStyle(
                                color: Colors.white54,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: verifying
                      ? null
                      : () => Navigator.pop(
                            dialogContext,
                            false,
                          ),
                  child: const Text(
                    'Annuler',
                    style: TextStyle(
                      color: Colors.white54,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed:
                      verifying ? null : verify,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  child: verifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Vérifier',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    codeController.dispose();

    if (!mounted || verified != true) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await CampusService.joinCampus(
        campusId: campusId,
      );

      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      await loadEverything();
    } catch (error) {
      debugPrint(
        'Erreur inscription Campus après vérification : $error',
      );

      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      showMessage(
        'Adresse vérifiée, mais impossible de rejoindre le campus.',
      );
    }
  }

  // ============================================
  // OUVRIR LE CHAT DU CAMPUS

  // ============================================

  void openCampusChat() {
    final campusId =
        myCampusData?['campus_id']
            ?.toString();

    final campus =
        myCampusData?['campuses'];

    final campusName =
        campus is Map
            ? campus['name']?.toString() ??
                'Campus'
            : 'Campus';

    if (campusId == null ||
        campusId.isEmpty) {
      showMessage(
        'Impossible d’ouvrir le chat du campus.',
      );

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CampusChatScreen(
          campusId: campusId,
          campusName: campusName,
        ),
      ),
    );
  }

  // ============================================
  // QUITTER CAMPUS
  // ============================================

  Future<void> confirmLeaveCampus() async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor:
              const Color(0xFF181818),

          title: const Text(
            'Quitter ton campus ?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),

          content: const Text(
            'Tu ne feras plus partie du classement '
            'de ce campus.',
            style: TextStyle(
              color: Colors.white70,
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'Annuler',
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text(
                'Quitter',
                style: TextStyle(
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await CampusService.leaveCampus();

      if (!mounted) return;

      await loadEverything();
    } catch (error) {
      debugPrint(
        'Erreur sortie Campus : $error',
      );

      showMessage(
        'Impossible de quitter le campus.',
      );
    }
  }

  // ============================================
  // MESSAGE
  // ============================================

  void showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          message,
        ),
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
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,

        // Empêche l'AppBar de devenir grise
        // lorsqu'on fait défiler la page.
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,

        title: Image.asset(
          'assets/arc_logo.png',
          height: 42,
          fit: BoxFit.contain,
        ),

        actions: [
          // ====================================
          // CHAT DU CAMPUS
          // ====================================

          if (myCampusData != null)
            IconButton(
              tooltip: 'Chat du campus',
              onPressed: openCampusChat,
              icon: const Icon(
                Icons.forum_outlined,
                color: Colors.white,
              ),
            ),

          // ====================================
          // OPTIONS CAMPUS
          // ====================================

          if (myCampusData != null)
            PopupMenuButton<String>(
              color:
                  const Color(0xFF181818),

              onSelected: (value) {
                if (value == 'leave') {
                  confirmLeaveCampus();
                }
              },

              itemBuilder: (_) => [
                const PopupMenuItem<String>(
                  value: 'leave',
                  child: Text(
                    'Quitter le campus',
                    style: TextStyle(
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),

      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  // ============================================
  // BODY
  // ============================================

  Widget _buildBody() {
    if (isLoading &&
        myCampusData == null &&
        campuses.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (errorMessage != null &&
        myCampusData == null &&
        campuses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                ),
              ),

              const SizedBox(height: 20),

              OutlinedButton(
                onPressed: loadEverything,
                child: const Text(
                  'Réessayer',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (myCampusData != null) {
      return _buildCampusHub();
    }

    return _buildJoinCampus();
  }

  // ============================================
  // REJOINDRE UN CAMPUS
  // ============================================

  Widget _buildJoinCampus() {
    return RefreshIndicator(
      onRefresh: loadEverything,

      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),

        padding: const EdgeInsets.all(24),

        children: [
          const Text(
            'CAMPUS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              letterSpacing: 3,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Rejoins ton campus',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            'Retrouve les membres de ton établissement, '
            'grimpe dans le classement et représente '
            'ton établissement.',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 16,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 32),

          if (errorMessage != null) ...[
            _buildErrorBox(
              errorMessage!,
            ),
            const SizedBox(height: 24),
          ],

          const Text(
            'Ton campus',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          ...campuses.map(
            _buildCampusChoice,
          ),

          if (selectedCampusId != null) ...[
            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              height: 56,

              child: ElevatedButton(
                onPressed:
                    isSaving
                        ? null
                        : saveSelection,

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
                        'Rejoindre mon campus',
                      ),
              ),
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ============================================
  // CHOIX CAMPUS
  // ============================================

  Widget _buildCampusChoice(
    Map<String, dynamic> campus,
  ) {
    final id =
        campus['id'].toString();

    final name =
        campus['name']?.toString() ??
            'Campus';

    final city =
        campus['city']?.toString() ??
            '';

    final selected =
        selectedCampusId == id;

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 10,
      ),

      child: InkWell(
        borderRadius:
            BorderRadius.circular(16),

        onTap: () {
          selectCampus(id);
        },

        child: Container(
          padding:
              const EdgeInsets.all(18),

          decoration: BoxDecoration(
            color: selected
                ? Colors.white
                : Colors.white10,

            borderRadius:
                BorderRadius.circular(16),
          ),

          child: Row(
            children: [
              Icon(
                Icons.school_outlined,
                color: selected
                    ? Colors.black
                    : Colors.white,
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: selected
                            ? Colors.black
                            : Colors.white,
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    if (city.isNotEmpty) ...[
                      const SizedBox(height: 3),

                      Text(
                        city,
                        style: TextStyle(
                          color: selected
                              ? Colors.black54
                              : Colors.white54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if (selected)
                const Icon(
                  Icons.check,
                  color: Colors.black,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // HUB CAMPUS
  // ============================================

  Widget _buildCampusHub() {
    final campus =
        myCampusData?['campuses'];

    final campusName =
        campus is Map
            ? campus['name']?.toString() ??
                'Campus'
            : 'Campus';

    final city =
        campus is Map
            ? campus['city']?.toString() ??
                ''
            : '';

    return RefreshIndicator(
      onRefresh: loadEverything,

      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),

        padding:
            const EdgeInsets.fromLTRB(
          20,
          12,
          20,
          40,
        ),

        children: [
          const Text(
            'CAMPUS',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              letterSpacing: 3,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            campusName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),

          if (city.isNotEmpty) ...[
            const SizedBox(height: 5),

            Text(
              city,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 15,
              ),
            ),
          ],

          const SizedBox(height: 22),

          _buildScoreCard(),

          const SizedBox(height: 32),

          const Text(
            'Carte des campus',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Explore les campus ARC de Grenoble '
            'et découvre leur puissance.',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 16),

          _buildCampusMap(),

          const SizedBox(height: 34),

          Container(
            padding: const EdgeInsets.all(4),

            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius:
                  BorderRadius.circular(16),
            ),

            child: Row(
              children: [
                _buildRankingTab(
                  index: 0,
                  label: 'Mon campus',
                ),
                _buildRankingTab(
                  index: 1,
                  label: 'Grenoble',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            selectedRankingIndex == 0
                ? 'Classement $campusName'
                : 'Classement Grenoble',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          if (selectedRankingIndex == 0)
            _buildUserRanking(
              campusRanking,
            ),

          if (selectedRankingIndex == 1)
            _buildUniversityRanking(),
        ],
      ),
    );
  }

  // ============================================
  // SCORE CAMPUS
  // ============================================

  Widget _buildScoreCard() {
    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius:
            BorderRadius.circular(22),
      ),

      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,

            decoration:
                const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),

            child: const Icon(
              Icons.bolt,
              color: Colors.black,
              size: 28,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                const Text(
                  'Score collectif',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  '$campusScore',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // CARTE INTERACTIVE
  // ============================================

  Widget _buildCampusMap() {
    if (mapCampuses.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,

        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius:
              BorderRadius.circular(22),
        ),

        child: const Text(
          'Aucun campus disponible sur la carte.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white38,
          ),
        ),
      );
    }

    final currentCampus =
        selectedMapCampus ??
            mapCampuses.first;

    final latitude =
        (currentCampus['latitude']
                    as num?)
                ?.toDouble() ??
            45.1885;

    final longitude =
        (currentCampus['longitude']
                    as num?)
                ?.toDouble() ??
            5.7245;

    int maxScore = 0;

    for (final campus in mapCampuses) {
      final score =
          (campus['score'] as num?)
                  ?.toInt() ??
              0;

      if (score > maxScore) {
        maxScore = score;
      }
    }

    Color campusColor({
      required int score,
      required bool isMine,
    }) {
      if (isMine) {
        return const Color(
          0xFFFFD166,
        );
      }

      if (maxScore <= 0) {
        return Colors.white54;
      }

      final ratio =
          (score / maxScore).clamp(
        0.0,
        1.0,
      );

      if (ratio >= 0.80) {
        return const Color(
          0xFFFFC857,
        );
      }

      if (ratio >= 0.55) {
        return const Color(
          0xFFFFE29A,
        );
      }

      if (ratio >= 0.30) {
        return Colors.white;
      }

      if (ratio >= 0.10) {
        return Colors.white70;
      }

      return Colors.white38;
    }

    double campusSize({
      required int score,
      required bool isMine,
    }) {
      if (maxScore <= 0) {
        return isMine ? 58 : 46;
      }

      final ratio =
          (score / maxScore).clamp(
        0.0,
        1.0,
      );

      double size =
          42 + (20 * ratio);

      if (isMine && size < 56) {
        size = 56;
      }

      return size;
    }

    final markers = <Marker>[];

    for (final campus in mapCampuses) {
      final lat =
          (campus['latitude'] as num?)
              ?.toDouble();

      final lng =
          (campus['longitude'] as num?)
              ?.toDouble();

      if (lat == null || lng == null) {
        continue;
      }

      final campusId =
          campus['id'].toString();

      final score =
          (campus['score'] as num?)
                  ?.toInt() ??
              0;

      final memberCount =
          (campus['member_count']
                      as num?)
                  ?.toInt() ??
              0;

      final isMine =
          campusId ==
              selectedCampusId;

      final isSelected =
          selectedMapCampus?['id']
                  ?.toString() ==
              campusId;

      final color =
          campusColor(
        score: score,
        isMine: isMine,
      );

      final baseSize =
          campusSize(
        score: score,
        isMine: isMine,
      );

      final displayedSize =
          isSelected
              ? baseSize + 8
              : baseSize;

      markers.add(
        Marker(
          point: LatLng(
            lat,
            lng,
          ),

          width: displayedSize + 28,
          height: displayedSize + 28,

          alignment: Alignment.center,

          child: GestureDetector(
            behavior:
                HitTestBehavior.opaque,

            onTap: () {
              setState(() {
                selectedMapCampus =
                    campus;
              });

              mapController.move(
                LatLng(
                  lat,
                  lng,
                ),
                14,
              );
            },

            child: Center(
              child: AnimatedContainer(
                duration:
                    const Duration(
                  milliseconds: 220,
                ),

                curve: Curves.easeOut,

                width: displayedSize,
                height: displayedSize,

                decoration:
                    BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,

                  border: Border.all(
                    color: isSelected
                        ? Colors.white
                        : Colors.black,
                    width:
                        isSelected
                            ? 4
                            : 2,
                  ),

                  boxShadow: [
                    BoxShadow(
                      color:
                          color.withValues(
                        alpha:
                            isSelected
                                ? 0.65
                                : 0.30,
                      ),
                      blurRadius:
                          isSelected
                              ? 20
                              : 10,
                      spreadRadius:
                          isSelected
                              ? 3
                              : 1,
                    ),
                    const BoxShadow(
                      color: Colors.black54,
                      blurRadius: 8,
                      offset: Offset(
                        0,
                        3,
                      ),
                    ),
                  ],
                ),

                child: Stack(
                  clipBehavior: Clip.none,
                  alignment:
                      Alignment.center,

                  children: [
                    Icon(
                      Icons.school,
                      color: Colors.black,
                      size:
                          displayedSize *
                              0.44,
                    ),

                    if (isMine)
                      Positioned(
                        top: -9,

                        child: Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),

                          decoration:
                              BoxDecoration(
                            color:
                                Colors.black,

                            borderRadius:
                                BorderRadius
                                    .circular(
                              20,
                            ),

                            border:
                                Border.all(
                              color:
                                  const Color(
                                0xFFFFD166,
                              ),
                            ),
                          ),

                          child:
                              const Text(
                            'ARC',
                            style:
                                TextStyle(
                              color: Color(
                                0xFFFFD166,
                              ),
                              fontSize: 8,
                              fontWeight:
                                  FontWeight
                                      .bold,
                              letterSpacing:
                                  1,
                            ),
                          ),
                        ),
                      ),

                    if (memberCount > 1)
                      Positioned(
                        right: -4,
                        bottom: -4,

                        child: Container(
                          constraints:
                              const BoxConstraints(
                            minWidth: 21,
                            minHeight: 21,
                          ),

                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 5,
                          ),

                          alignment:
                              Alignment.center,

                          decoration:
                              BoxDecoration(
                            color:
                                Colors.black,

                            borderRadius:
                                BorderRadius
                                    .circular(
                              20,
                            ),

                            border:
                                Border.all(
                              color:
                                  Colors.white,
                              width: 1.5,
                            ),
                          ),

                          child: Text(
                            memberCount > 99
                                ? '99+'
                                : '$memberCount',

                            style:
                                const TextStyle(
                              color:
                                  Colors.white,
                              fontSize: 9,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        ClipRRect(
          borderRadius:
              BorderRadius.circular(22),

          child: SizedBox(
            height: 300,

            child: FlutterMap(
              mapController:
                  mapController,

              options: MapOptions(
                initialCenter:
                    LatLng(
                  latitude,
                  longitude,
                ),

                initialZoom: 12,
                minZoom: 3,
                maxZoom: 18,

                interactionOptions:
                    const InteractionOptions(
                  flags:
                      InteractiveFlag.all,
                ),
              ),

              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName:
                      'com.arc.app',
                ),

                MarkerLayer(
                  markers: markers,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        Container(
          width: double.infinity,

          padding:
              const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 11,
          ),

          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius:
                BorderRadius.circular(14),
          ),

          child: const Row(
            children: [
              Icon(
                Icons.touch_app_outlined,
                color: Colors.white54,
                size: 17,
              ),

              SizedBox(width: 8),

              Expanded(
                child: Text(
                  'Déplace et zoome sur la carte. '
                  'La taille et la couleur indiquent '
                  'la puissance des campus.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (selectedMapCampus != null) ...[
          const SizedBox(height: 12),

          _buildSelectedCampusCard(
            selectedMapCampus!,
          ),
        ],
      ],
    );
  }

  // ============================================
  // CAMPUS SÉLECTIONNÉ SUR LA CARTE
  // ============================================

  Widget _buildSelectedCampusCard(
    Map<String, dynamic> campus,
  ) {
    final name =
        campus['name']?.toString() ??
            'Campus';

    final city =
        campus['city']?.toString() ??
            '';

    final score =
        (campus['score'] as num?)
                ?.toInt() ??
            0;

    final memberCount =
        (campus['member_count'] as num?)
                ?.toInt() ??
            0;

    final campusId =
        campus['id']?.toString();

    final isMine =
        campusId != null &&
            campusId ==
                selectedCampusId;

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white10,

        borderRadius:
            BorderRadius.circular(18),

        border: isMine
            ? Border.all(
                color:
                    const Color(
                  0xFFFFD166,
                ),
              )
            : null,
      ),

      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,

            decoration: BoxDecoration(
              color: isMine
                  ? const Color(
                      0xFFFFD166,
                    )
                  : Colors.white,

              borderRadius:
                  BorderRadius.circular(14),
            ),

            child: const Icon(
              Icons.school,
              color: Colors.black,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,

                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontWeight:
                              FontWeight
                                  .bold,
                          fontSize: 15,
                        ),
                      ),
                    ),

                    if (isMine) ...[
                      const SizedBox(
                        width: 7,
                      ),

                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),

                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFFFFD166,
                          ),

                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),
                        ),

                        child:
                            const Text(
                          'TON CAMPUS',
                          style:
                              TextStyle(
                            color:
                                Colors.black,
                            fontSize: 8,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 4),

                Text(
                  city.isNotEmpty
                      ? '$city • $memberCount membres'
                      : '$memberCount membres',

                  style:
                      const TextStyle(
                    color:
                        Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,

            children: [
              Text(
                '$score',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const Text(
                'pts',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================
  // ONGLET CLASSEMENT
  // ============================================

  Widget _buildRankingTab({
    required int index,
    required String label,
  }) {
    final selected =
        selectedRankingIndex == index;

    return Expanded(
      child: InkWell(
        borderRadius:
            BorderRadius.circular(12),

        onTap: () {
          setState(() {
            selectedRankingIndex =
                index;
          });
        },

        child: AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 180,
          ),

          padding:
              const EdgeInsets.symmetric(
            vertical: 12,
          ),

          decoration: BoxDecoration(
            color: selected
                ? Colors.white
                : Colors.transparent,

            borderRadius:
                BorderRadius.circular(12),
          ),

          child: Text(
            label,
            textAlign: TextAlign.center,

            style: TextStyle(
              color: selected
                  ? Colors.black
                  : Colors.white54,

              fontSize: 13,

              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // CLASSEMENT UTILISATEURS
  // ============================================

  Widget _buildUserRanking(
    List<Map<String, dynamic>> ranking,
  ) {
    if (ranking.isEmpty) {
      return const Padding(
        padding:
            EdgeInsets.symmetric(
          vertical: 40,
        ),

        child: Center(
          child: Text(
            'Aucun membre pour le moment.',
            style: TextStyle(
              color: Colors.white38,
            ),
          ),
        ),
      );
    }

    return Column(
      children: List.generate(
        ranking.length,
        (index) {
          final user =
              ranking[index];

          final username =
              user['username']
                      ?.toString() ??
                  'Utilisateur';

          final elo =
              (user['elo'] as num?)
                      ?.toInt() ??
                  1500;

          final league =
              user['league']
                      ?.toString() ??
                  '';

          final photo =
              user['photo_1_url']
                  ?.toString();

          return Container(
            margin:
                const EdgeInsets.only(
              bottom: 8,
            ),

            padding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),

            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius:
                  BorderRadius.circular(16),
            ),

            child: Row(
              children: [
                SizedBox(
                  width: 32,

                  child: Text(
                    '${index + 1}',

                    style: TextStyle(
                      color: index < 3
                          ? Colors.white
                          : Colors.white38,

                      fontSize: 17,

                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                CircleAvatar(
                  radius: 22,

                  backgroundColor:
                      Colors.white12,

                  backgroundImage:
                      photo != null &&
                              photo.isNotEmpty
                          ? NetworkImage(
                              photo,
                            )
                          : null,

                  child:
                      photo == null ||
                              photo.isEmpty
                          ? const Icon(
                              Icons.person,
                              color:
                                  Colors.white38,
                            )
                          : null,
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [
                      Text(
                        '@$username',
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,

                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),

                      if (league.isNotEmpty)
                        Text(
                          league,
                          style:
                              const TextStyle(
                            color:
                                Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),

                Text(
                  '$elo',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(width: 3),

                const Text(
                  'Elo',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================
  // CLASSEMENT GRENOBLE
  // ============================================

  Widget _buildUniversityRanking() {
    if (universityRanking.isEmpty) {
      return const Padding(
        padding:
            EdgeInsets.symmetric(
          vertical: 40,
        ),

        child: Center(
          child: Text(
            'Aucun campus classé.',
            style: TextStyle(
              color: Colors.white38,
            ),
          ),
        ),
      );
    }

    return Column(
      children: List.generate(
        universityRanking.length,
        (index) {
          final university =
              universityRanking[index];

          final name =
              university['name']
                      ?.toString() ??
                  'Campus';

          final city =
              university['city']
                      ?.toString() ??
                  '';

          final score =
              (university['score']
                          as num?)
                      ?.toInt() ??
                  0;

          final memberCount =
              (university['member_count']
                          as num?)
                      ?.toInt() ??
                  0;

          return Container(
            margin:
                const EdgeInsets.only(
              bottom: 8,
            ),

            padding:
                const EdgeInsets.all(15),

            decoration: BoxDecoration(
              color: Colors.white10,

              borderRadius:
                  BorderRadius.circular(16),
            ),

            child: Row(
              children: [
                SizedBox(
                  width: 34,

                  child: Text(
                    '${index + 1}',

                    style: TextStyle(
                      color: index < 3
                          ? Colors.white
                          : Colors.white38,

                      fontSize: 18,

                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                Container(
                  width: 44,
                  height: 44,

                  decoration:
                      BoxDecoration(
                    color: Colors.white12,

                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),

                  child: const Icon(
                    Icons.school,
                    color: Colors.white70,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,

                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        city.isNotEmpty
                            ? '$city • $memberCount membres'
                            : '$memberCount membres',

                        style:
                            const TextStyle(
                          color:
                              Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.end,

                  children: [
                    Text(
                      '$score',
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const Text(
                      'pts',
                      style: TextStyle(
                        color:
                            Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================
  // ERREUR
  // ============================================

  Widget _buildErrorBox(
    String message,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color:
            Colors.redAccent.withValues(
          alpha: 0.12,
        ),

        borderRadius:
            BorderRadius.circular(16),
      ),

      child: Text(
        message,
        style: const TextStyle(
          color: Colors.redAccent,
        ),
      ),
    );
  }
}