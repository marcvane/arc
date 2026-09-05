import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/user_model.dart';
import '../services/matchmaking_service.dart';
import '../profile_service.dart';
import '../vote_limit_service.dart';
import '../vote_service.dart';

class VoteScreen extends StatefulWidget {
  const VoteScreen({super.key});

  @override
  State<VoteScreen> createState() => _VoteScreenState();
}

class _VoteScreenState extends State<VoteScreen> {
  List<ArcUser> profiles = [];

  ArcUser? profileA;
  ArcUser? profileB;

  int votesLeft = 0;

  bool isLoading = true;
  bool isVoting = false;

  String? errorMessage;

  // ============================================
  // FEEDBACK DU VOTE
  // ============================================

  String? selectedWinnerId;

  bool showVoteResult = false;

  String voteResultTitle = '';

  int lastWinnerChange = 0;

  // ============================================
  // TRANSITION ENTRE LES DUELS
  // ============================================

  int duelVersion = 0;

  // ============================================
  // INITIALISATION
  // ============================================

  @override
  void initState() {
    super.initState();
    initializeScreen();
  }

  // ============================================
  // CHARGEMENT INITIAL
  // ============================================

  Future<void> initializeScreen() async {
    try {
      final results = await Future.wait([
        ProfileService.getProfiles(),
        VoteLimitService.getRemainingVotes(),
      ]);

      profiles = results[0] as List<ArcUser>;
      votesLeft = results[1] as int;

      if (!mounted) return;

      if (votesLeft <= 0) {
        setState(() {
          isLoading = false;
          errorMessage =
              'Tu as utilisé tes 20 votes aujourd’hui.';
        });

        return;
      }

      createNewDuel();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
            'Impossible de charger ARC : $error';
      });
    }
  }

  // ============================================
  // RAFRAÎCHIR LES PROFILS
  // ============================================

  Future<void> refreshProfiles() async {
    try {
      profiles =
          await ProfileService.getProfiles();

      if (!mounted) return;

      createNewDuel();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isVoting = false;
        errorMessage =
            'Impossible de charger un nouveau duel.';
      });
    }
  }

  // ============================================
  // CRÉER UN NOUVEAU DUEL
  // ============================================

  void createNewDuel() {
    final duel =
        MatchmakingService.createDuel(
      users: profiles,
    );

    if (!mounted) return;

    setState(() {
      selectedWinnerId = null;

      showVoteResult = false;

      voteResultTitle = '';

      lastWinnerChange = 0;

      duelVersion++;

      if (duel == null) {
        profileA = null;
        profileB = null;

        errorMessage =
            'Pas assez de profils disponibles.';
      } else {
        profileA = duel[0];
        profileB = duel[1];

        errorMessage = null;
      }

      isLoading = false;
    });
  }

  // ============================================
  // VOTER
  // ============================================

  Future<void> voteFor(
    ArcUser winner,
  ) async {
    if (profileA == null ||
        profileB == null ||
        votesLeft <= 0 ||
        isVoting) {
      return;
    }

    final currentProfileA =
        profileA!;

    final currentProfileB =
        profileB!;

    // ========================================
    // 1. FEEDBACK IMMÉDIAT
    // ========================================

    HapticFeedback.mediumImpact();

    setState(() {
      isVoting = true;

      selectedWinnerId =
          winner.id;
    });

    await Future.delayed(
      const Duration(
        milliseconds: 140,
      ),
    );

    try {
      final result =
          await VoteService.castVote(
        profileAId:
            currentProfileA.id,

        profileBId:
            currentProfileB.id,

        winnerId:
            winner.id,
      );

      if (!mounted) return;

      // ======================================
      // 2. VOTE VALIDÉ
      // ======================================

      HapticFeedback.lightImpact();

      SystemSound.play(
        SystemSoundType.click,
      );

      setState(() {
        votesLeft =
            result.votesRemaining;

        voteResultTitle =
            '@${winner.username}';

        lastWinnerChange =
            result.winnerChange;

        showVoteResult =
            true;
      });

      await Future.delayed(
        const Duration(
          milliseconds: 450,
        ),
      );

      if (!mounted) return;

      // ======================================
      // 3. PLUS DE VOTES
      // ======================================

      if (result.votesRemaining <= 0) {
        setState(() {
          profileA = null;
          profileB = null;

          selectedWinnerId =
              null;

          showVoteResult =
              false;

          isVoting =
              false;

          errorMessage =
              'Tu as utilisé tes 20 votes aujourd’hui.';
        });

        return;
      }

      // ======================================
      // 4. PRÉPARER LE DUEL SUIVANT
      // ======================================

      setState(() {
        showVoteResult =
            false;

        selectedWinnerId =
            null;
      });

      await refreshProfiles();

      if (!mounted) return;

      setState(() {
        isVoting = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isVoting = false;

        selectedWinnerId =
            null;

        showVoteResult =
            false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Vote impossible : $error',
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
    // ==========================================
    // CHARGEMENT
    // ==========================================

    if (isLoading) {
      return const Scaffold(
        backgroundColor:
            Colors.black,

        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    // ==========================================
    // ERREUR / FIN DES VOTES
    // ==========================================

    if (errorMessage != null ||
        profileA == null ||
        profileB == null) {
      return Scaffold(
        backgroundColor:
            Colors.black,

        appBar: AppBar(
          backgroundColor:
              Colors.black,

          title: Image.asset(
            'assets/arc_logo.png',

            height:
                42,

            fit:
                BoxFit.contain,
          ),
        ),

        body: Center(
          child: Padding(
            padding:
                const EdgeInsets.all(
              30,
            ),

            child: Column(
              mainAxisSize:
                  MainAxisSize.min,

              children: [
                const Icon(
                  Icons.bolt,

                  color:
                      Colors.white24,

                  size:
                      50,
                ),

                const SizedBox(
                  height:
                      18,
                ),

                Text(
                  errorMessage ??
                      'Aucun duel disponible.',

                  textAlign:
                      TextAlign.center,

                  style:
                      const TextStyle(
                    color:
                        Colors.white,

                    fontSize:
                        18,

                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ==========================================
    // ÉCRAN DE VOTE
    // ==========================================

    return Scaffold(
      backgroundColor:
          Colors.black,

      appBar: AppBar(
        backgroundColor:
            Colors.black,

        title: Image.asset(
          'assets/arc_logo.png',

          height:
              42,

          fit:
              BoxFit.contain,
        ),

        actions: [
          Padding(
            padding:
                const EdgeInsets.only(
              right:
                  18,
            ),

            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal:
                      11,

                  vertical:
                      6,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      Colors.white10,

                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),

                child: Row(
                  mainAxisSize:
                      MainAxisSize.min,

                  children: [
                    const Icon(
                      Icons.bolt,

                      color:
                          Colors.white70,

                      size:
                          15,
                    ),

                    const SizedBox(
                      width:
                          5,
                    ),

                    Text(
                      '$votesLeft / 20',

                      style:
                          const TextStyle(
                        color:
                            Colors.white,

                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: Stack(
          children: [
            // ==================================
            // CONTENU PRINCIPAL
            // ==================================

            Padding(
              padding:
                  const EdgeInsets.all(
                16,
              ),

              child: Column(
                children: [
                  const SizedBox(
                    height:
                        4,
                  ),

                  // ============================
                  // TITRE
                  // ============================

                  const Text(
                    'Qui a le plus de style ?',

                    textAlign:
                        TextAlign.center,

                    style:
                        TextStyle(
                      color:
                          Colors.white,

                      fontSize:
                          24,

                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height:
                        7,
                  ),

                  const Text(
                    'Choisis ton favori',

                    style:
                        TextStyle(
                      color:
                          Colors.white38,

                      fontSize:
                          13,
                    ),
                  ),

                  const SizedBox(
                    height:
                        20,
                  ),

                  // ============================
                  // DUEL
                  // ============================

                  Expanded(
                    child:
                        AnimatedSwitcher(
                      duration:
                          const Duration(
                        milliseconds:
                            260,
                      ),

                      switchInCurve:
                          Curves.easeOutCubic,

                      switchOutCurve:
                          Curves.easeInCubic,

                      transitionBuilder:
                          (
                        child,
                        animation,
                      ) {
                        final slide =
                            Tween<Offset>(
                          begin:
                              const Offset(
                            0.08,
                            0,
                          ),

                          end:
                              Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent:
                                animation,

                            curve:
                                Curves.easeOutCubic,
                          ),
                        );

                        return FadeTransition(
                          opacity:
                              animation,

                          child:
                              SlideTransition(
                            position:
                                slide,

                            child:
                                child,
                          ),
                        );
                      },

                      child: LayoutBuilder(
                        key:
                            ValueKey(
                          'duel_$duelVersion',
                        ),

                        builder: (
                          context,
                          constraints,
                        ) {
                          final isWideScreen =
                              constraints.maxWidth >=
                                  700;

                          // ====================
                          // MOBILE
                          // ====================

                          if (!isWideScreen) {
                            return Row(
                              children: [
                                Expanded(
                                  child:
                                      profileCard(
                                    profileA!,
                                  ),
                                ),

                                const SizedBox(
                                  width:
                                      12,
                                ),

                                Expanded(
                                  child:
                                      profileCard(
                                    profileB!,
                                  ),
                                ),
                              ],
                            );
                          }

                          // ====================
                          // DESKTOP / TABLETTE
                          // ====================
                          //
                          // Les cartes ne
                          // s'étirent plus sur
                          // toute la largeur.
                          // Leur largeur dépend
                          // de la hauteur
                          // disponible afin de
                          // conserver un rendu
                          // vertical proche du
                          // ratio 3:4.

                          final availableImageHeight =
                              (constraints.maxHeight -
                                      58)
                                  .clamp(
                                    0.0,
                                    double.infinity,
                                  )
                                  .toDouble();

                          final desiredCardWidth =
                              availableImageHeight *
                                  3 /
                                  4;

                          final desiredDuelWidth =
                              (desiredCardWidth *
                                      2) +
                                  12;

                          final duelWidth =
                              desiredDuelWidth <
                                      constraints
                                          .maxWidth
                                  ? desiredDuelWidth
                                  : constraints
                                      .maxWidth;

                          return Center(
                            child: SizedBox(
                              width:
                                  duelWidth,

                              child: Row(
                                children: [
                                  Expanded(
                                    child:
                                        profileCard(
                                      profileA!,
                                    ),
                                  ),

                                  const SizedBox(
                                    width:
                                        12,
                                  ),

                                  Expanded(
                                    child:
                                        profileCard(
                                      profileB!,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(
                    height:
                        16,
                  ),

                  // ============================
                  // CHARGEMENT DU VOTE
                  // ============================

                  AnimatedSwitcher(
                    duration:
                        const Duration(
                      milliseconds:
                          150,
                    ),

                    child:
                        isVoting &&
                                !showVoteResult
                            ? const SizedBox(
                                key:
                                    ValueKey(
                                  'loader',
                                ),

                                width:
                                    22,

                                height:
                                    22,

                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                ),
                              )
                            : const SizedBox(
                                key:
                                    ValueKey(
                                  'empty-loader',
                                ),

                                height:
                                    22,
                              ),
                  ),

                  const SizedBox(
                    height:
                        8,
                  ),

                  Text(
                    '$votesLeft votes restants aujourd’hui',

                    style:
                        const TextStyle(
                      color:
                          Colors.white60,
                    ),
                  ),

                  const SizedBox(
                    height:
                        16,
                  ),
                ],
              ),
            ),

            // ==================================
            // FEEDBACK DU VOTE
            // ==================================

            IgnorePointer(
              child:
                  AnimatedSwitcher(
                duration:
                    const Duration(
                  milliseconds:
                      180,
                ),

                transitionBuilder:
                    (
                  child,
                  animation,
                ) {
                  return FadeTransition(
                    opacity:
                        animation,

                    child:
                        ScaleTransition(
                      scale:
                          Tween<double>(
                        begin:
                            0.82,

                        end:
                            1,
                      ).animate(
                        CurvedAnimation(
                          parent:
                              animation,

                          curve:
                              Curves.easeOutBack,
                        ),
                      ),

                      child:
                          child,
                    ),
                  );
                },

                child:
                    showVoteResult
                        ? Center(
                            key:
                                const ValueKey(
                              'vote-result',
                            ),

                            child:
                                Container(
                              margin:
                                  const EdgeInsets.symmetric(
                                horizontal:
                                    40,
                              ),

                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal:
                                    24,

                                vertical:
                                    18,
                              ),

                              decoration:
                                  BoxDecoration(
                                color:
                                    Colors.black
                                        .withValues(
                                  alpha:
                                      0.92,
                                ),

                                borderRadius:
                                    BorderRadius.circular(
                                  24,
                                ),

                                border:
                                    Border.all(
                                  color:
                                      Colors.white24,
                                ),

                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.white
                                            .withValues(
                                      alpha:
                                          0.08,
                                    ),

                                    blurRadius:
                                        30,

                                    spreadRadius:
                                        3,
                                  ),
                                ],
                              ),

                              child:
                                  Column(
                                mainAxisSize:
                                    MainAxisSize.min,

                                children: [
                                  Container(
                                    width:
                                        52,

                                    height:
                                        52,

                                    decoration:
                                        const BoxDecoration(
                                      color:
                                          Colors.white,

                                      shape:
                                          BoxShape.circle,
                                    ),

                                    child:
                                        const Icon(
                                      Icons.check,

                                      color:
                                          Colors.black,

                                      size:
                                          30,
                                    ),
                                  ),

                                  const SizedBox(
                                    height:
                                        12,
                                  ),

                                  Text(
                                    voteResultTitle,

                                    textAlign:
                                        TextAlign.center,

                                    style:
                                        const TextStyle(
                                      color:
                                          Colors.white,

                                      fontSize:
                                          17,

                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(
                                    height:
                                        5,
                                  ),

                                  // ======================
                                  // ELO ANIMÉ
                                  // ======================

                                  TweenAnimationBuilder<
                                      double>(
                                    tween:
                                        Tween<double>(
                                      begin:
                                          0,

                                      end:
                                          lastWinnerChange
                                              .toDouble(),
                                    ),

                                    duration:
                                        const Duration(
                                      milliseconds:
                                          340,
                                    ),

                                    curve:
                                        Curves.easeOutCubic,

                                    builder:
                                        (
                                      context,
                                      value,
                                      child,
                                    ) {
                                      final amount =
                                          value.round();

                                      return Text(
                                        '+$amount Elo',

                                        style:
                                            const TextStyle(
                                          color:
                                              Colors.white,

                                          fontSize:
                                              18,

                                          fontWeight:
                                              FontWeight.w900,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(
                            key:
                                ValueKey(
                              'no-vote-result',
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // CARTE D'UN PROFIL
  // ============================================

  Widget profileCard(
    ArcUser user,
  ) {
    final hasPhoto =
        user.photoUrls.isNotEmpty &&
        user.photoUrls.first.isNotEmpty;

    final isWinner =
        selectedWinnerId ==
            user.id;

    final hasSelection =
        selectedWinnerId != null;

    final isLoser =
        hasSelection &&
        !isWinner;

    // ==========================================
    // RÉACTION VISUELLE
    // ==========================================

    final scale =
        isWinner
            ? 1.035
            : isLoser
                ? 0.955
                : 1.0;

    final opacity =
        isWinner
            ? 1.0
            : isLoser
                ? 0.32
                : 1.0;

    final borderColor =
        isWinner
            ? Colors.white
            : Colors.white24;

    final borderWidth =
        isWinner
            ? 2.2
            : 1.0;

    return GestureDetector(
      behavior:
          HitTestBehavior.opaque,

      onTap:
          isVoting
              ? null
              : () {
                  voteFor(
                    user,
                  );
                },

      child: AnimatedScale(
        scale:
            scale,

        duration:
            const Duration(
          milliseconds:
              160,
        ),

        curve:
            Curves.easeOutBack,

        child: AnimatedOpacity(
          duration:
              const Duration(
            milliseconds:
                160,
          ),

          opacity:
              opacity,

          child:
              AnimatedContainer(
            duration:
                const Duration(
              milliseconds:
                  160,
            ),

            curve:
                Curves.easeOut,

            clipBehavior:
                Clip.antiAlias,

            decoration:
                BoxDecoration(
              color:
                  Colors.black,

              borderRadius:
                  BorderRadius.circular(
                22,
              ),

              border:
                  Border.all(
                color:
                    borderColor,

                width:
                    borderWidth,
              ),

              boxShadow:
                  isWinner
                      ? [
                          BoxShadow(
                            color:
                                Colors.white
                                    .withValues(
                              alpha:
                                  0.20,
                            ),

                            blurRadius:
                                28,

                            spreadRadius:
                                3,
                          ),
                        ]
                      : null,
            ),

            child: Stack(
              children: [
                // ============================
                // CONTENU CARTE
                // ============================

                Column(
                  children: [
                    Expanded(
                      child:
                          SizedBox(
                        width:
                            double.infinity,

                        child:
                            hasPhoto
                                ? Image.network(
                                    user.photoUrls.first,

                                    fit:
                                        BoxFit.cover,

                                    errorBuilder:
                                        (
                                      context,
                                      error,
                                      stackTrace,
                                    ) {
                                      return const Center(
                                        child:
                                            Icon(
                                          Icons.person,

                                          size:
                                              90,

                                          color:
                                              Colors.white38,
                                        ),
                                      );
                                    },
                                  )
                                : const Center(
                                    child:
                                        Icon(
                                      Icons.person,

                                      size:
                                          90,

                                      color:
                                          Colors.white38,
                                    ),
                                  ),
                      ),
                    ),

                    Container(
                      width:
                          double.infinity,

                      padding:
                          const EdgeInsets.all(
                        14,
                      ),

                      color:
                          Colors.black,

                      child:
                          Text(
                        '@${user.username}',

                        textAlign:
                            TextAlign.center,

                        overflow:
                            TextOverflow.ellipsis,

                        style:
                            const TextStyle(
                          color:
                              Colors.white,

                          fontSize:
                              18,

                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                // ============================
                // FLASH GAGNANT
                // ============================

                AnimatedOpacity(
                  duration:
                      const Duration(
                    milliseconds:
                        120,
                  ),

                  opacity:
                      isWinner
                          ? 1
                          : 0,

                  child:
                      Container(
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.white
                              .withValues(
                        alpha:
                            0.09,
                      ),

                      borderRadius:
                          BorderRadius.circular(
                        22,
                      ),
                    ),

                    child:
                        const Center(
                      child:
                          Icon(
                        Icons.check_circle,

                        color:
                            Colors.white,

                        size:
                            54,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}