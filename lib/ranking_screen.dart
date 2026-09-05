import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'public_profile_screen.dart';

class RankingScreen extends StatefulWidget {
  final int refreshTrigger;

  const RankingScreen({
    super.key,
    this.refreshTrigger = 0,
  });

  @override
  State<RankingScreen> createState() =>
      _RankingScreenState();
}

class _RankingScreenState
    extends State<RankingScreen> {
  List<Map<String, dynamic>> users = [];

  bool isLoading = true;
  bool isRefreshing = false;

  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadRanking();
  }

  @override
  void didUpdateWidget(
    covariant RankingScreen oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.refreshTrigger !=
        widget.refreshTrigger) {
      loadRanking(
        showLoading: false,
      );
    }
  }

  // ============================================
  // CHARGER LE CLASSEMENT
  // ============================================

  Future<void> loadRanking({
    bool showLoading = false,
  }) async {
    if (showLoading && mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    if (isRefreshing) {
      return;
    }

    isRefreshing = true;

    try {
      final response =
          await Supabase.instance.client
              .from('profiles')
              .select(
                'id, username, elo, league, photo_1_url',
              )
              .order(
                'elo',
                ascending: false,
              )
              .limit(100);

      if (!mounted) return;

      setState(() {
        users =
            List<Map<String, dynamic>>.from(
          response,
        );

        isLoading = false;
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage =
            'Impossible de charger le classement.';
        isLoading = false;
      });
    } finally {
      isRefreshing = false;
    }
  }

  // ============================================
  // BUILD
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      // ========================================
      // APP BAR
      // ========================================

      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,

        // Garde la barre parfaitement noire
        // même pendant le scroll.
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,

        title: Image.asset(
          'assets/arc_logo.png',
          height: 42,
          fit: BoxFit.contain,
        ),
      ),

      // ========================================
      // BODY
      // ========================================

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Text(
                        errorMessage!,
                        style:
                            const TextStyle(
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(
                        height: 18,
                      ),

                      ElevatedButton(
                        onPressed: () {
                          loadRanking(
                            showLoading: true,
                          );
                        },
                        child: const Text(
                          'Réessayer',
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      loadRanking(),

                  child:
                      ListView.separated(
                    physics:
                        const AlwaysScrollableScrollPhysics(),

                    itemCount:
                        users.length + 1,

                    separatorBuilder:
                        (context, index) {
                      if (index == 0) {
                        return const SizedBox
                            .shrink();
                      }

                      return const Divider(
                        color:
                            Colors.white12,
                        height: 1,
                      );
                    },

                    itemBuilder:
                        (context, index) {
                      // =========================
                      // TITRE
                      // =========================

                      if (index == 0) {
                        return const Padding(
                          padding:
                              EdgeInsets
                                  .fromLTRB(
                            20,
                            16,
                            20,
                            22,
                          ),
                          child: Text(
                            'CLASSEMENT',
                            style: TextStyle(
                              color:
                                  Colors.white,
                              fontSize: 24,
                              fontWeight:
                                  FontWeight
                                      .bold,
                              letterSpacing: 2,
                            ),
                          ),
                        );
                      }

                      // =========================
                      // UTILISATEUR
                      // =========================

                      final rankingIndex =
                          index - 1;

                      final user =
                          users[
                              rankingIndex];

                      final username =
                          user['username']
                                  as String? ??
                              'Utilisateur';

                      final elo =
                          (user['elo']
                                      as num?)
                                  ?.toInt() ??
                              1500;

                      final league =
                          user['league']
                                  as String? ??
                              'Argent';

                      final photoUrl =
                          user['photo_1_url']
                              as String?;

                      return ListTile(
                        // =======================
                        // OUVRIR PROFIL
                        // =======================

                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      PublicProfileScreen(
                                userId:
                                    user['id']
                                        as String,
                              ),
                            ),
                          );

                          // Recharge également
                          // après consultation.
                          await loadRanking();
                        },

                        contentPadding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),

                        // =======================
                        // POSITION + PHOTO
                        // =======================

                        leading: SizedBox(
                          width: 75,

                          child: Row(
                            children: [
                              SizedBox(
                                width: 28,

                                child: Text(
                                  '${rankingIndex + 1}',
                                  style:
                                      TextStyle(
                                    color:
                                        rankingIndex <
                                                3
                                            ? Colors
                                                .white
                                            : Colors
                                                .white60,
                                    fontSize:
                                        17,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                              ),

                              CircleAvatar(
                                backgroundColor:
                                    Colors
                                        .white12,

                                backgroundImage:
                                    photoUrl !=
                                                null &&
                                            photoUrl
                                                .isNotEmpty
                                        ? NetworkImage(
                                            photoUrl,
                                          )
                                        : null,

                                child:
                                    photoUrl ==
                                                null ||
                                            photoUrl
                                                .isEmpty
                                        ? const Icon(
                                            Icons
                                                .person,
                                            color:
                                                Colors
                                                    .white54,
                                          )
                                        : null,
                              ),
                            ],
                          ),
                        ),

                        // =======================
                        // PSEUDO
                        // =======================

                        title: Text(
                          '@$username',
                          style:
                              const TextStyle(
                            color:
                                Colors.white,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),

                        // =======================
                        // LIGUE
                        // =======================

                        subtitle: Text(
                          league,
                          style:
                              const TextStyle(
                            color:
                                Colors.white54,
                          ),
                        ),

                        // =======================
                        // ELO
                        // =======================

                        trailing: Text(
                          '$elo',
                          style:
                              const TextStyle(
                            color:
                                Colors.white,
                            fontSize: 17,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}