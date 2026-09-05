import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

import 'services/league_services.dart';
import 'services/progress_services.dart';
import 'services/elo_history_services.dart';

import 'screens/profile_setup_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'login_screen.dart';
import 'screens/battle_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseClient supabase =
      Supabase.instance.client;

  Map<String, dynamic>? profile;

  bool isLoading = true;
  String? errorMessage;

  List<EloHistoryPoint> eloHistory = [];

  // ============================================
  // CACHE PHOTOS
  //
  // Permet de forcer le rechargement des images
  // quand une photo est remplacée dans Storage
  // mais conserve exactement la même URL.
  // ============================================

  int photoCacheVersion =
      DateTime.now().millisecondsSinceEpoch;

  // ============================================
  // ANIMATION PROGRESSION
  // ============================================

  double animatedProgress = 0.0;
  int displayedElo = 1500;
  bool progressionReady = false;

  // ============================================
  // INITIALISATION
  // ============================================

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  // ============================================
  // CALCULER L'ÂGE
  // ============================================

  int? calculateAgeFromBirthDate(
    dynamic birthDateValue,
  ) {
    if (birthDateValue == null) {
      return null;
    }

    final birthDate = DateTime.tryParse(
      birthDateValue.toString(),
    );

    if (birthDate == null) {
      return null;
    }

    final today = DateTime.now();

    int age = today.year - birthDate.year;

    if (today.month < birthDate.month ||
        (today.month == birthDate.month &&
            today.day < birthDate.day)) {
      age--;
    }

    return age;
  }

  // ============================================
  // CHARGER LE PROFIL
  // ============================================

  Future<void> loadProfile() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception(
          'Utilisateur non connecté',
        );
      }

      // ========================================
      // PROFIL + CAMPUS + CLAN
      // ========================================

      final response = await supabase
          .from('profiles')
          .select(
            '''
            *,
            campuses(
              id,
              name,
              slug,
              city,
              country,
              latitude,
              longitude
            ),
            clans(
              id,
              name,
              slug
            )
            ''',
          )
          .eq(
            'id',
            user.id,
          )
          .single();

      // ========================================
      // HISTORIQUE ELO
      // ========================================

      final history =
          await EloHistoryService.getMyHistory();

      if (!mounted) return;

      final newProfile =
          Map<String, dynamic>.from(
        response,
      );

      final newElo =
          (newProfile['elo'] as num?)
                  ?.toInt() ??
              1500;

      final newProgress =
          ProgressService.progressToNextLeague(
        newElo,
      );

      setState(() {
        profile = newProfile;
        eloHistory = history;

        // ======================================
        // FORCE LE RECHARGEMENT DES PHOTOS
        // ======================================

        photoCacheVersion =
            DateTime.now().millisecondsSinceEpoch;

        displayedElo = newElo;
        animatedProgress = 0.0;
        progressionReady = false;

        isLoading = false;
        errorMessage = null;
      });

      // ========================================
      // DÉCLENCHER L'ANIMATION APRÈS LE BUILD
      // ========================================

      await Future.delayed(
        const Duration(
          milliseconds: 180,
        ),
      );

      if (!mounted) return;

      setState(() {
        animatedProgress =
            newProgress.clamp(
          0.0,
          1.0,
        );

        progressionReady = true;
      });
    } catch (error) {
      debugPrint(
        'Erreur chargement profil : $error',
      );

      if (!mounted) return;

      setState(() {
        errorMessage =
            'Impossible de charger ton profil.';

        isLoading = false;
      });
    }
  }

  // ============================================
  // MODIFIER LE PROFIL
  // ============================================

  Future<void> editProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const ProfileSetupScreen(),
      ),
    );

    if (!mounted) return;

    await loadProfile();
  }

  // ============================================
  // OUVRIR L'HISTORIQUE DES AFFRONTEMENTS
  // ============================================

  Future<void> openBattleHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const BattleHistoryScreen(),
      ),
    );

    if (!mounted) return;

    await loadProfile();
  }

  // ============================================
  // OUVRIR LES CGU
  // ============================================

  void openTerms() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const TermsScreen(),
      ),
    );
  }

  // ============================================
  // OUVRIR LA POLITIQUE DE CONFIDENTIALITÉ
  // ============================================

  void openPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const PrivacyPolicyScreen(),
      ),
    );
  }

  // ============================================
  // DÉCONNEXION
  // ============================================

  Future<void> logout() async {
    try {
      await supabase.auth.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const LoginScreen(),
        ),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible de se déconnecter.',
          ),
        ),
      );
    }
  }

  // ============================================
  // SUPPRIMER LE COMPTE
  // ============================================

  Future<void> deleteAccount() async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor:
              const Color(0xFF171717),
          title: const Text(
            'Supprimer mon compte ?',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          content: const Text(
            'Cette action est définitive. Ton profil, ton classement '
            'et les données associées à ton compte seront supprimés.',
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
                'Supprimer définitivement',
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
      final response =
          await supabase.functions.invoke(
        'delete-account',
      );

      if (response.status != 200) {
        throw Exception(
          'Erreur suppression : ${response.data}',
        );
      }

      await supabase.auth.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const LoginScreen(),
        ),
        (route) => false,
      );
    } catch (error) {
      debugPrint(
        'Erreur suppression compte : $error',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible de supprimer le compte.',
          ),
        ),
      );
    }
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

    if (errorMessage != null ||
        profile == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            errorMessage ??
                'Profil introuvable.',
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    // ==========================================
    // DONNÉES PROFIL
    // ==========================================

    final username =
        profile!['username']
                as String? ??
            'Utilisateur';

    final calculatedAge =
        calculateAgeFromBirthDate(
      profile!['birth_date'],
    );

    final oldAge =
        (profile!['age'] as num?)
            ?.toInt();

    final age =
        calculatedAge ?? oldAge;

    final bio =
        profile!['bio']
                as String? ??
            '';

    final elo =
        (profile!['elo'] as num?)
                ?.toInt() ??
            1500;

    final league =
        LeagueService.getLeagueFromElo(
      elo,
    );

    final leagueName =
        LeagueService.getLeagueName(
      league,
    );

    final eloRemaining =
        ProgressService.eloToNextLeague(
      elo,
    );

    // ==========================================
    // ÉCHELLE GRAPHIQUE ELO
    // ==========================================

    double? chartMinY;
    double? chartMaxY;

    if (eloHistory.isNotEmpty) {
      final eloValues = eloHistory
          .map(
            (point) =>
                point.elo.toDouble(),
          )
          .toList();

      final minElo =
          eloValues.reduce(
        (a, b) => a < b ? a : b,
      );

      final maxElo =
          eloValues.reduce(
        (a, b) => a > b ? a : b,
      );

      chartMinY =
          ((minElo - 10) / 10)
                  .floor() *
              10.0;

      chartMaxY =
          ((maxElo + 10) / 10)
                  .ceil() *
              10.0;

      if (chartMinY == chartMaxY) {
        chartMinY -= 10;
        chartMaxY += 10;
      }
    }

    // ==========================================
    // CAMPUS + CLAN
    // ==========================================

    final campusData =
        profile!['campuses'];

    final clanData =
        profile!['clans'];

    String? campusName;
    String? campusCity;
    String? clanName;

    if (campusData is Map) {
      campusName =
          campusData['name']
              ?.toString();

      campusCity =
          campusData['city']
              ?.toString();
    }

    if (clanData is Map) {
      clanName =
          clanData['name']
              ?.toString();
    }

    final hasCampus =
        campusName != null &&
        campusName.isNotEmpty;

    // ==========================================
    // PHOTOS
    // ==========================================

    final photoUrls = <String>[
      if (profile!['photo_1_url']
              is String &&
          (profile!['photo_1_url']
                  as String)
              .isNotEmpty)
        profile!['photo_1_url']
            as String,

      if (profile!['photo_2_url']
              is String &&
          (profile!['photo_2_url']
                  as String)
              .isNotEmpty)
        profile!['photo_2_url']
            as String,

      if (profile!['photo_3_url']
              is String &&
          (profile!['photo_3_url']
                  as String)
              .isNotEmpty)
        profile!['photo_3_url']
            as String,
    ];

    return Scaffold(
      backgroundColor: Colors.black,

      // ========================================
      // APP BAR
      // ========================================

      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor:
            Colors.transparent,
        shadowColor:
            Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,

        title: Image.asset(
          'assets/arc_logo.png',
          height: 42,
          fit: BoxFit.contain,
        ),

        actions: [
          IconButton(
            onPressed: editProfile,
            icon: const Icon(
              Icons.edit,
            ),
            tooltip:
                'Modifier le profil',
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: loadProfile,

        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),

          padding:
              const EdgeInsets.all(24),

          children: [
            // ==================================
            // PHOTOS
            // ==================================

            Center(
              child: SizedBox(
                height: 420,

                child: photoUrls.isEmpty
                    ? Container(
                        width:
                            double.infinity,

                        decoration:
                            BoxDecoration(
                          color:
                              Colors.white10,

                          borderRadius:
                              BorderRadius.circular(
                            24,
                          ),
                        ),

                        child:
                            const Center(
                          child: Icon(
                            Icons.person,
                            size: 90,
                            color:
                                Colors.white38,
                          ),
                        ),
                      )
                    : PageView.builder(
                        itemCount:
                            photoUrls.length,

                        itemBuilder:
                            (
                          context,
                          index,
                        ) {
                          final originalUrl =
                              photoUrls[index];

                          final separator =
                              originalUrl.contains('?')
                                  ? '&'
                                  : '?';

                          final refreshedUrl =
                              '$originalUrl'
                              '${separator}v='
                              '$photoCacheVersion';

                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),

                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(
                                24,
                              ),

                              child:
                                  Image.network(
                                refreshedUrl,

                                width:
                                    double.infinity,

                                fit:
                                    BoxFit.cover,

                                errorBuilder:
                                    (
                                  context,
                                  error,
                                  stackTrace,
                                ) {
                                  return Container(
                                    color:
                                        Colors.white10,

                                    child:
                                        const Center(
                                      child: Icon(
                                        Icons.person,
                                        size: 90,
                                        color:
                                            Colors.white38,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            // ==================================
            // PSEUDO
            // ==================================

            Center(
              child: Text(
                '@$username',
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),

            // ==================================
            // AGE
            // ==================================

            if (age != null) ...[
              const SizedBox(
                height: 6,
              ),

              Center(
                child: Text(
                  '$age ans',
                  style:
                      const TextStyle(
                    color:
                        Colors.white54,
                    fontSize: 15,
                  ),
                ),
              ),
            ],

            // ==================================
            // CAMPUS + CLAN
            // ==================================

            if (hasCampus) ...[
              const SizedBox(
                height: 16,
              ),

              Container(
                width:
                    double.infinity,

                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      Colors.white10,

                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),

                  border:
                      Border.all(
                    color:
                        Colors.white12,
                  ),
                ),

                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,

                      children: [
                        const Icon(
                          Icons
                              .school_outlined,
                          color:
                              Colors.white70,
                          size: 19,
                        ),

                        const SizedBox(
                          width: 8,
                        ),

                        Flexible(
                          child: Text(
                            campusName,
                            textAlign:
                                TextAlign.center,
                            style:
                                const TextStyle(
                              color:
                                  Colors.white,
                              fontSize: 15,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (campusCity !=
                            null &&
                        campusCity
                            .isNotEmpty) ...[
                      const SizedBox(
                        height: 4,
                      ),

                      Text(
                        campusCity,
                        style:
                            const TextStyle(
                          color:
                              Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],

                    if (clanName !=
                            null &&
                        clanName
                            .isNotEmpty) ...[
                      const SizedBox(
                        height: 10,
                      ),

                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),

                        decoration:
                            BoxDecoration(
                          color:
                              Colors.white12,

                          borderRadius:
                              BorderRadius.circular(
                            100,
                          ),
                        ),

                        child: Row(
                          mainAxisSize:
                              MainAxisSize.min,

                          children: [
                            const Icon(
                              Icons
                                  .groups_2_outlined,
                              size: 15,
                              color:
                                  Colors.white54,
                            ),

                            const SizedBox(
                              width: 6,
                            ),

                            Flexible(
                              child: Text(
                                clanName,
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.white70,
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // ==================================
            // BIO
            // ==================================

            if (bio.isNotEmpty) ...[
              const SizedBox(
                height: 20,
              ),

              Text(
                bio,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color:
                      Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],

            const SizedBox(
              height: 20,
            ),

            // ==================================
            // MODIFIER PROFIL
            // ==================================

            SizedBox(
              width:
                  double.infinity,

              child:
                  OutlinedButton.icon(
                onPressed:
                    editProfile,
                icon:
                    const Icon(
                  Icons.edit,
                ),
                label:
                    const Text(
                  'Modifier le profil',
                ),
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            // ==================================
            // DÉCONNEXION
            // ==================================

            SizedBox(
              width:
                  double.infinity,

              child:
                  TextButton.icon(
                onPressed: logout,
                icon:
                    const Icon(
                  Icons.logout,
                  color:
                      Colors.redAccent,
                ),
                label:
                    const Text(
                  'Se déconnecter',
                  style:
                      TextStyle(
                    color:
                        Colors.redAccent,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 36,
            ),

            // ==================================
            // PROGRESSION ARC
            // ==================================

            Container(
              padding:
                  const EdgeInsets.all(
                22,
              ),

              decoration:
                  BoxDecoration(
                color:
                    Colors.white10,

                borderRadius:
                    BorderRadius.circular(
                  24,
                ),

                border:
                    Border.all(
                  color:
                      Colors.white12,
                ),
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.bolt,
                        color:
                            Colors.white54,
                        size: 17,
                      ),

                      SizedBox(
                        width: 6,
                      ),

                      Text(
                        'PROGRESSION ARC',
                        style:
                            TextStyle(
                          color:
                              Colors.white38,
                          fontSize: 11,
                          letterSpacing:
                              1.8,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.end,

                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                          children: [
                            const Text(
                              'LIGUE ACTUELLE',
                              style:
                                  TextStyle(
                                color:
                                    Colors.white38,
                                fontSize: 10,
                                letterSpacing:
                                    1.3,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),

                            const SizedBox(
                              height: 5,
                            ),

                            Text(
                              leagueName,
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white,
                                fontSize: 27,
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),

                      TweenAnimationBuilder<int>(
                        tween: IntTween(
                          begin:
                              progressionReady
                                  ? displayedElo
                                  : 0,
                          end: elo,
                        ),

                        duration:
                            const Duration(
                          milliseconds: 800,
                        ),

                        curve:
                            Curves.easeOutCubic,

                        builder:
                            (
                          context,
                          value,
                          child,
                        ) {
                          return Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.end,

                            children: [
                              Text(
                                '$value',
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.white,
                                  fontSize: 24,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),

                              const Text(
                                'ELO',
                                style:
                                    TextStyle(
                                  color:
                                      Colors.white38,
                                  fontSize: 10,
                                  letterSpacing:
                                      1.3,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(
                      100,
                    ),

                    child:
                        TweenAnimationBuilder<
                            double>(
                      tween:
                          Tween<double>(
                        begin: 0,
                        end:
                            animatedProgress,
                      ),

                      duration:
                          const Duration(
                        milliseconds: 900,
                      ),

                      curve:
                          Curves.easeOutCubic,

                      builder:
                          (
                        context,
                        value,
                        child,
                      ) {
                        return LinearProgressIndicator(
                          value:
                              value.clamp(
                            0.0,
                            1.0,
                          ),
                          minHeight: 10,
                          backgroundColor:
                              Colors.white12,
                          valueColor:
                              const AlwaysStoppedAnimation<
                                  Color>(
                            Colors.white,
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(
                    height: 13,
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          eloRemaining <= 0
                              ? 'Ligue maximale atteinte'
                              : 'Encore $eloRemaining Elo',
                          style:
                              const TextStyle(
                            color:
                                Colors.white70,
                            fontSize: 14,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),

                      if (eloRemaining > 0)
                        const Row(
                          children: [
                            Text(
                              'PROCHAINE LIGUE',
                              style:
                                  TextStyle(
                                color:
                                    Colors.white30,
                                fontSize: 9,
                                letterSpacing: 1,
                              ),
                            ),

                            SizedBox(
                              width: 5,
                            ),

                            Icon(
                              Icons
                                  .arrow_forward_rounded,
                              color:
                                  Colors.white38,
                              size: 15,
                            ),
                          ],
                        ),
                    ],
                  ),

                  if (eloRemaining > 0) ...[
                    const SizedBox(
                      height: 18,
                    ),

                    Container(
                      width:
                          double.infinity,

                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),

                      decoration:
                          BoxDecoration(
                        color:
                            Colors.white
                                .withValues(
                          alpha: 0.05,
                        ),

                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),

                      child: Row(
                        children: [
                          const Icon(
                            Icons
                                .trending_up_rounded,
                            color:
                                Colors.white54,
                            size: 18,
                          ),

                          const SizedBox(
                            width: 10,
                          ),

                          Expanded(
                            child: Text(
                              'Plus que $eloRemaining Elo avant ta prochaine ligue.',
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white60,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(
              height: 30,
            ),

            // ==================================
            // ÉVOLUTION ELO
            // ==================================

            const Text(
              'Évolution Elo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            SizedBox(
              height: 220,

              child:
                  eloHistory.length < 2
                      ? const Center(
                          child: Text(
                            'Pas encore assez de données.',
                            style:
                                TextStyle(
                              color:
                                  Colors.white38,
                            ),
                          ),
                        )
                      : LineChart(
                          LineChartData(
                            minY: chartMinY,
                            maxY: chartMaxY,

                            gridData:
                                FlGridData(
                              show: true,
                              horizontalInterval:
                                  10,
                              drawVerticalLine:
                                  false,

                              getDrawingHorizontalLine:
                                  (value) {
                                return const FlLine(
                                  color:
                                      Colors.white10,
                                  strokeWidth:
                                      1,
                                );
                              },
                            ),

                            titlesData:
                                FlTitlesData(
                              topTitles:
                                  const AxisTitles(
                                sideTitles:
                                    SideTitles(
                                  showTitles:
                                      false,
                                ),
                              ),

                              rightTitles:
                                  const AxisTitles(
                                sideTitles:
                                    SideTitles(
                                  showTitles:
                                      false,
                                ),
                              ),

                              bottomTitles:
                                  const AxisTitles(
                                sideTitles:
                                    SideTitles(
                                  showTitles:
                                      false,
                                ),
                              ),

                              leftTitles:
                                  AxisTitles(
                                sideTitles:
                                    SideTitles(
                                  showTitles:
                                      true,

                                  interval:
                                      10,

                                  reservedSize:
                                      48,

                                  getTitlesWidget:
                                      (
                                    value,
                                    meta,
                                  ) {
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(
                                        right:
                                            8,
                                      ),

                                      child:
                                          Text(
                                        value
                                            .toInt()
                                            .toString(),

                                        textAlign:
                                            TextAlign.right,

                                        style:
                                            const TextStyle(
                                          color:
                                              Colors.white54,
                                          fontSize:
                                              11,
                                          fontWeight:
                                              FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                            borderData:
                                FlBorderData(
                              show: false,
                            ),

                            lineBarsData: [
                              LineChartBarData(
                                spots:
                                    List.generate(
                                  eloHistory
                                      .length,
                                  (index) =>
                                      FlSpot(
                                    index
                                        .toDouble(),
                                    eloHistory[
                                            index]
                                        .elo
                                        .toDouble(),
                                  ),
                                ),

                                isCurved: true,
                                barWidth: 3,

                                dotData:
                                    const FlDotData(
                                  show: false,
                                ),

                                belowBarData:
                                    BarAreaData(
                                  show: false,
                                ),
                              ),
                            ],
                          ),
                        ),
            ),

            const SizedBox(
              height: 38,
            ),

            // ==================================
            // AFFRONTEMENTS
            // ==================================

            const Text(
              'Affrontements',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            SizedBox(
              width:
                  double.infinity,
              height: 54,

              child:
                  OutlinedButton.icon(
                onPressed:
                    openBattleHistory,
                icon:
                    const Icon(
                  Icons.history,
                ),
                label:
                    const Text(
                  'Historique des affrontements',
                ),
              ),
            ),

            const SizedBox(
              height: 38,
            ),

            // ==================================
            // LÉGAL
            // ==================================

            const Divider(
              color:
                  Colors.white12,
            ),

            const SizedBox(
              height: 24,
            ),

            const Text(
              'À propos et légal',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            ListTile(
              contentPadding:
                  EdgeInsets.zero,

              leading:
                  const Icon(
                Icons
                    .description_outlined,
                color:
                    Colors.white70,
              ),

              title:
                  const Text(
                'Conditions d’utilisation',
                style:
                    TextStyle(
                  color:
                      Colors.white,
                ),
              ),

              subtitle:
                  const Text(
                'Version 1.0',
                style:
                    TextStyle(
                  color:
                      Colors.white38,
                  fontSize: 12,
                ),
              ),

              trailing:
                  const Icon(
                Icons.chevron_right,
                color:
                    Colors.white38,
              ),

              onTap: openTerms,
            ),

            ListTile(
              contentPadding:
                  EdgeInsets.zero,

              leading:
                  const Icon(
                Icons
                    .privacy_tip_outlined,
                color:
                    Colors.white70,
              ),

              title:
                  const Text(
                'Politique de confidentialité',
                style:
                    TextStyle(
                  color:
                      Colors.white,
                ),
              ),

              subtitle:
                  const Text(
                'Version 1.0',
                style:
                    TextStyle(
                  color:
                      Colors.white38,
                  fontSize: 12,
                ),
              ),

              trailing:
                  const Icon(
                Icons.chevron_right,
                color:
                    Colors.white38,
              ),

              onTap:
                  openPrivacyPolicy,
            ),

            const SizedBox(
              height: 8,
            ),

            const Center(
              child: Text(
                'ARC • Version 1.0',
                style: TextStyle(
                  color:
                      Colors.white30,
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(
              height: 30,
            ),

            // ==================================
            // SUPPRESSION DU COMPTE
            // ==================================

            const Divider(
              color:
                  Colors.white12,
            ),

            const SizedBox(
              height: 20,
            ),

            SizedBox(
              width:
                  double.infinity,

              child:
                  TextButton.icon(
                onPressed:
                    deleteAccount,

                icon:
                    const Icon(
                  Icons
                      .delete_forever_outlined,
                  color:
                      Colors.redAccent,
                ),

                label:
                    const Text(
                  'Supprimer mon compte',
                  style:
                      TextStyle(
                    color:
                        Colors.redAccent,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 20,
            ),
          ],
        ),
      ),
    );
  }
}