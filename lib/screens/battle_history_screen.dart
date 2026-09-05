import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../public_profile_screen.dart';

class BattleHistoryScreen extends StatefulWidget {
  const BattleHistoryScreen({
    super.key,
  });

  @override
  State<BattleHistoryScreen> createState() =>
      _BattleHistoryScreenState();
}

class _BattleHistoryScreenState
    extends State<BattleHistoryScreen> {
  final SupabaseClient supabase =
      Supabase.instance.client;

  bool isLoading = true;

  String? errorMessage;

  List<Map<String, dynamic>> battles = [];

  @override
  void initState() {
    super.initState();

    loadBattles();
  }

  // ============================================
  // CHARGER L'HISTORIQUE
  // ============================================

  Future<void> loadBattles() async {
    final currentUser =
        supabase.auth.currentUser;

    if (currentUser == null) {
      if (!mounted) return;

      setState(() {
        isLoading = false;

        errorMessage =
            'Utilisateur non connecté.';
      });

      return;
    }

    try {
      // Tous les affrontements dans lesquels
      // notre profil était présent.

      final response = await supabase
          .from('votes')
          .select(
            '''
            id,
            voter_id,
            profile_a_id,
            profile_b_id,
            winner_id,
            loser_id,
            winner_elo_before,
            winner_elo_after,
            loser_elo_before,
            loser_elo_after,
            created_at
            ''',
          )
          .or(
            'profile_a_id.eq.${currentUser.id},'
            'profile_b_id.eq.${currentUser.id}',
          )
          .order(
            'created_at',
            ascending: false,
          )
          .limit(100);

      final voteRows =
          List<Map<String, dynamic>>.from(
        response,
      );

      // ========================================
      // RÉCUPÉRER LES IDS DES ADVERSAIRES
      // ========================================

      final opponentIds = <String>{};

      for (final vote in voteRows) {
        final profileAId =
            vote['profile_a_id'] as String?;

        final profileBId =
            vote['profile_b_id'] as String?;

        if (profileAId == currentUser.id &&
            profileBId != null) {
          opponentIds.add(
            profileBId,
          );
        } else if (
            profileBId == currentUser.id &&
            profileAId != null) {
          opponentIds.add(
            profileAId,
          );
        }
      }

      // ========================================
      // RÉCUPÉRER LES PROFILS ADVERSAIRES
      // ========================================

      final Map<String, Map<String, dynamic>>
          profilesById = {};

      if (opponentIds.isNotEmpty) {
        final profileRows = await supabase
            .from('profiles')
            .select(
              'id, username, photo_1_url, elo, league',
            )
            .inFilter(
              'id',
              opponentIds.toList(),
            );

        for (final row in profileRows) {
          final profile =
              Map<String, dynamic>.from(
            row,
          );

          final id =
              profile['id'] as String?;

          if (id != null) {
            profilesById[id] =
                profile;
          }
        }
      }

      // ========================================
      // CONSTRUIRE L'HISTORIQUE
      // ========================================

      final loadedBattles =
          <Map<String, dynamic>>[];

      for (final vote in voteRows) {
        final profileAId =
            vote['profile_a_id'] as String?;

        final profileBId =
            vote['profile_b_id'] as String?;

        String? opponentId;

        if (profileAId ==
            currentUser.id) {
          opponentId =
              profileBId;
        } else if (
            profileBId ==
            currentUser.id) {
          opponentId =
              profileAId;
        }

        if (opponentId == null) {
          continue;
        }

        final opponent =
            profilesById[opponentId];

        if (opponent == null) {
          continue;
        }

        final winnerId =
            vote['winner_id'] as String?;

        final isVictory =
            winnerId == currentUser.id;

        // ======================================
        // CALCUL DE LA VARIATION ELO
        // ======================================

        int eloBefore;
        int eloAfter;

        if (isVictory) {
          eloBefore =
              (vote['winner_elo_before']
                          as num?)
                      ?.toInt() ??
                  1500;

          eloAfter =
              (vote['winner_elo_after']
                          as num?)
                      ?.toInt() ??
                  eloBefore;
        } else {
          eloBefore =
              (vote['loser_elo_before']
                          as num?)
                      ?.toInt() ??
                  1500;

          eloAfter =
              (vote['loser_elo_after']
                          as num?)
                      ?.toInt() ??
                  eloBefore;
        }

        final eloChange =
            eloAfter - eloBefore;

        loadedBattles.add({
          'vote': vote,
          'opponent': opponent,
          'isVictory': isVictory,
          'eloChange': eloChange,
          'eloBefore': eloBefore,
          'eloAfter': eloAfter,
        });
      }

      if (!mounted) return;

      setState(() {
        battles =
            loadedBattles;

        isLoading = false;

        errorMessage = null;
      });
    } catch (error) {
      debugPrint(
        'Erreur historique affrontements : $error',
      );

      if (!mounted) return;

      setState(() {
        isLoading = false;

        errorMessage =
            'Impossible de charger l’historique des affrontements.';
      });
    }
  }

  // ============================================
  // OUVRIR LE PROFIL DE L'ADVERSAIRE
  // ============================================

  void openProfile(
    String userId,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PublicProfileScreen(
          userId: userId,
        ),
      ),
    );
  }

  // ============================================
  // FORMATTER LA DATE
  // ============================================

  String formatDate(
    dynamic value,
  ) {
    if (value == null) {
      return '';
    }

    try {
      final date =
          DateTime.parse(
        value.toString(),
      ).toLocal();

      final now =
          DateTime.now();

      final today =
          DateTime(
        now.year,
        now.month,
        now.day,
      );

      final battleDay =
          DateTime(
        date.year,
        date.month,
        date.day,
      );

      final difference =
          today
              .difference(
                battleDay,
              )
              .inDays;

      final hour =
          date.hour
              .toString()
              .padLeft(
                2,
                '0',
              );

      final minute =
          date.minute
              .toString()
              .padLeft(
                2,
                '0',
              );

      if (difference == 0) {
        return 'Aujourd’hui · $hour:$minute';
      }

      if (difference == 1) {
        return 'Hier · $hour:$minute';
      }

      final day =
          date.day
              .toString()
              .padLeft(
                2,
                '0',
              );

      final month =
          date.month
              .toString()
              .padLeft(
                2,
                '0',
              );

      return '$day/$month/${date.year} · $hour:$minute';
    } catch (_) {
      return '';
    }
  }

  // ============================================
  // AVATAR
  // ============================================

  Widget buildAvatar(
    Map<String, dynamic> profile,
  ) {
    final photoUrl =
        profile['photo_1_url']
            as String?;

    if (photoUrl == null ||
        photoUrl.isEmpty) {
      return const CircleAvatar(
        radius: 27,
        backgroundColor:
            Colors.white10,
        child: Icon(
          Icons.person,
          color:
              Colors.white54,
        ),
      );
    }

    return CircleAvatar(
      radius: 27,
      backgroundColor:
          Colors.white10,
      backgroundImage:
          NetworkImage(
        photoUrl,
      ),
    );
  }

  // ============================================
  // CARTE D'UN AFFRONTEMENT
  // ============================================

  Widget buildBattleCard(
    Map<String, dynamic> battle,
  ) {
    final opponent =
        battle['opponent']
            as Map<String, dynamic>;

    final vote =
        battle['vote']
            as Map<String, dynamic>;

    final isVictory =
        battle['isVictory']
            as bool;

    final eloChange =
        battle['eloChange']
            as int;

    final eloBefore =
        battle['eloBefore']
            as int;

    final eloAfter =
        battle['eloAfter']
            as int;

    final opponentId =
        opponent['id']
            as String;

    final username =
        opponent['username']
                as String? ??
            'Utilisateur';

    final createdAt =
        vote['created_at'];

    return InkWell(
      borderRadius:
          BorderRadius.circular(
        18,
      ),

      onTap: () {
        openProfile(
          opponentId,
        );
      },

      child: Container(
        padding:
            const EdgeInsets.all(
          16,
        ),

        decoration:
            BoxDecoration(
          color:
              Colors.white10,

          borderRadius:
              BorderRadius.circular(
            18,
          ),
        ),

        child: Row(
          children: [
            buildAvatar(
              opponent,
            ),

            const SizedBox(
              width: 14,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                children: [
                  Text(
                    isVictory
                        ? 'VICTOIRE'
                        : 'DÉFAITE',

                    style:
                        TextStyle(
                      color:
                          isVictory
                              ? Colors
                                  .greenAccent
                              : Colors
                                  .redAccent,

                      fontSize:
                          12,

                      fontWeight:
                          FontWeight
                              .bold,

                      letterSpacing:
                          1.2,
                    ),
                  ),

                  const SizedBox(
                    height: 5,
                  ),

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

                      fontSize:
                          17,

                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  Text(
                    formatDate(
                      createdAt,
                    ),

                    style:
                        const TextStyle(
                      color:
                          Colors.white54,

                      fontSize:
                          13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              width: 10,
            ),

            Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .end,

              children: [
                Text(
                  eloChange > 0
                      ? '+$eloChange'
                      : '$eloChange',

                  style:
                      TextStyle(
                    color:
                        eloChange >= 0
                            ? Colors
                                .greenAccent
                            : Colors
                                .redAccent,

                    fontSize:
                        19,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                const Text(
                  'Elo',

                  style:
                      TextStyle(
                    color:
                        Colors.white54,

                    fontSize:
                        12,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  '$eloBefore → $eloAfter',

                  style:
                      const TextStyle(
                    color:
                        Colors.white38,

                    fontSize:
                        11,
                  ),
                ),
              ],
            ),
          ],
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
      backgroundColor:
          Colors.black,

      appBar: AppBar(
        backgroundColor:
            Colors.black,

        foregroundColor:
            Colors.white,

        title:
            const Text(
          'Historique',

          style:
              TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),

      body:
          isLoading
              ? const Center(
                  child:
                      CircularProgressIndicator(),
                )
              : errorMessage != null
                  ? Center(
                      child:
                          Padding(
                        padding:
                            const EdgeInsets
                                .all(
                          24,
                        ),

                        child:
                            Column(
                          mainAxisSize:
                              MainAxisSize
                                  .min,

                          children: [
                            Text(
                              errorMessage!,

                              textAlign:
                                  TextAlign
                                      .center,

                              style:
                                  const TextStyle(
                                color:
                                    Colors
                                        .white70,
                              ),
                            ),

                            const SizedBox(
                              height:
                                  20,
                            ),

                            ElevatedButton(
                              onPressed:
                                  loadBattles,

                              child:
                                  const Text(
                                'Réessayer',
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : battles.isEmpty
                      ? RefreshIndicator(
                          onRefresh:
                              loadBattles,

                          child:
                              ListView(
                            physics:
                                const AlwaysScrollableScrollPhysics(),

                            children:
                                const [
                              SizedBox(
                                height:
                                    180,
                              ),

                              Icon(
                                Icons
                                    .history,
                                size:
                                    46,
                                color:
                                    Colors
                                        .white24,
                              ),

                              SizedBox(
                                height:
                                    16,
                              ),

                              Center(
                                child:
                                    Text(
                                  'Aucun affrontement pour le moment.',

                                  style:
                                      TextStyle(
                                    color:
                                        Colors
                                            .white54,

                                    fontSize:
                                        16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh:
                              loadBattles,

                          child:
                              ListView
                                  .separated(
                            physics:
                                const AlwaysScrollableScrollPhysics(),

                            padding:
                                const EdgeInsets
                                    .fromLTRB(
                              18,
                              18,
                              18,
                              30,
                            ),

                            itemCount:
                                battles
                                    .length,

                            separatorBuilder:
                                (
                              _,
                              _,
                            ) =>
                                    const SizedBox(
                              height:
                                  12,
                            ),

                            itemBuilder:
                                (
                              context,
                              index,
                            ) {
                              return buildBattleCard(
                                battles[
                                    index],
                              );
                            },
                          ),
                        ),
    );
  }
}