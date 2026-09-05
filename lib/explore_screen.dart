import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'public_profile_screen.dart';
import 'screens/campus_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() =>
      _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final SupabaseClient supabase =
      Supabase.instance.client;

  final TextEditingController searchController =
      TextEditingController();

  bool isLoading = true;
  bool isSearching = false;

  String? errorMessage;

  int myElo = 0;

  List<Map<String, dynamic>> exploreProfiles = [];
  List<Map<String, dynamic>> searchResults = [];

  @override
  void initState() {
    super.initState();
    loadExploreProfiles();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ============================================
  // CHARGER EXPLORER
  // ============================================

  Future<void> loadExploreProfiles() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Utilisateur non connecté.';
      });

      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      // ========================================
      // MON ELO
      // ========================================

      final myProfile = await supabase
          .from('profiles')
          .select('elo')
          .eq(
            'id',
            user.id,
          )
          .single();

      final elo =
          (myProfile['elo'] as num?)?.toInt() ?? 0;

      // ========================================
      // EXPLORER
      //
      // Seulement les profils ayant :
      // Elo <= mon Elo
      // ========================================

      final response = await supabase
          .from('profiles')
          .select(
            'id, username, age, bio, elo, league, photo_1_url',
          )
          .lte(
            'elo',
            elo,
          )
          .neq(
            'id',
            user.id,
          )
          .order(
            'elo',
            ascending: false,
          );

      if (!mounted) return;

      setState(() {
        myElo = elo;

        exploreProfiles =
            List<Map<String, dynamic>>.from(
          response,
        );

        isLoading = false;
        errorMessage = null;
      });
    } catch (error) {
      debugPrint(
        'Erreur Explorer : $error',
      );

      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
            'Impossible de charger les profils.';
      });
    }
  }

  // ============================================
  // RECHERCHER UN UTILISATEUR
  // ============================================

  Future<void> searchUsers(
    String query,
  ) async {
    final cleanQuery = query.trim();

    if (cleanQuery.isEmpty) {
      if (!mounted) return;

      setState(() {
        searchResults = [];
        isSearching = false;
        errorMessage = null;
      });

      return;
    }

    final currentUser =
        supabase.auth.currentUser;

    if (currentUser == null) {
      return;
    }

    setState(() {
      isSearching = true;
      errorMessage = null;
    });

    try {
      // ========================================
      // RECHERCHE GLOBALE
      //
      // Aucune restriction Elo.
      // ========================================

      final response = await supabase
          .from('profiles')
          .select(
            'id, username, age, bio, elo, league, photo_1_url',
          )
          .ilike(
            'username',
            '%$cleanQuery%',
          )
          .neq(
            'id',
            currentUser.id,
          )
          .order(
            'elo',
            ascending: false,
          )
          .limit(30);

      if (!mounted) return;

      // Évite qu'une ancienne recherche
      // remplace une recherche plus récente.
      if (searchController.text.trim() !=
          cleanQuery) {
        return;
      }

      setState(() {
        searchResults =
            List<Map<String, dynamic>>.from(
          response,
        );

        isSearching = false;
      });
    } catch (error) {
      debugPrint(
        'Erreur recherche Explorer : $error',
      );

      if (!mounted) return;

      setState(() {
        isSearching = false;
        errorMessage =
            'Impossible d’effectuer la recherche.';
      });
    }
  }

  // ============================================
  // OUVRIR CAMPUS
  // ============================================

  void openCampus() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const CampusScreen(),
      ),
    );
  }

  // ============================================
  // OUVRIR UN PROFIL PUBLIC
  // ============================================

  void openProfile(
    Map<String, dynamic> profile,
  ) {
    final userId =
        profile['id'] as String?;

    if (userId == null) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PublicProfileScreen(
          userId: userId,
        ),
      ),
    );
  }

  // ============================================
  // CARTE CAMPUS
  // ============================================

  Widget buildCampusCard() {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 18,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFF151515,
        ),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: openCampus,
          borderRadius:
              BorderRadius.circular(20),
          child: Padding(
            padding:
                const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),
                  child: const Icon(
                    Icons.school_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),

                const SizedBox(
                  width: 16,
                ),

                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Campus',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      SizedBox(
                        height: 4,
                      ),

                      Text(
                        'Découvre les classements de ton campus',
                        style: TextStyle(
                          color:
                              Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.chevron_right,
                  color: Colors.white54,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // CARTE PROFIL
  // ============================================

  Widget buildProfileTile(
    Map<String, dynamic> profile,
  ) {
    final username =
        profile['username']?.toString() ??
            'Utilisateur';

    final age =
        (profile['age'] as num?)?.toInt();

    final elo =
        (profile['elo'] as num?)?.toInt() ??
            1500;

    final league =
        profile['league']?.toString() ??
            'Non classé';

    final photoUrl =
        profile['photo_1_url']?.toString();

    return Card(
      color: const Color(
        0xFF151515,
      ),
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      child: ListTile(
        onTap: () {
          openProfile(
            profile,
          );
        },

        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),

        leading: CircleAvatar(
          radius: 28,
          backgroundColor:
              Colors.white12,
          backgroundImage:
              photoUrl != null &&
                      photoUrl.isNotEmpty
                  ? NetworkImage(
                      photoUrl,
                    )
                  : null,
          child: photoUrl == null ||
                  photoUrl.isEmpty
              ? const Icon(
                  Icons.person,
                  color: Colors.white38,
                )
              : null,
        ),

        title: Text(
          '@$username',
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.bold,
            fontSize: 16,
          ),
        ),

        subtitle: Padding(
          padding:
              const EdgeInsets.only(
            top: 4,
          ),
          child: Text(
            age != null
                ? '$league • $age ans'
                : league,
            style: const TextStyle(
              color: Colors.white54,
            ),
          ),
        ),

        trailing: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          crossAxisAlignment:
              CrossAxisAlignment.end,
          children: [
            Text(
              '$elo',
              style: const TextStyle(
                color: Colors.white,
                fontWeight:
                    FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Text(
              'Elo',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
              ),
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
    final query =
        searchController.text.trim();

    final searchMode =
        query.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,

      // ========================================
      // APPBAR
      // Reste parfaitement noire au scroll
      // ========================================

      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,

        elevation: 0,
        scrolledUnderElevation: 0,

        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,

        title: Image.asset(
          'assets/arc_logo.png',
          height: 42,
          fit: BoxFit.contain,
        ),

        actions: [
          if (!searchMode)
            IconButton(
              onPressed:
                  loadExploreProfiles,
              tooltip: 'Actualiser',
              icon: const Icon(
                Icons.refresh,
              ),
            ),
        ],
      ),

      body: Column(
        children: [
          // ====================================
          // TITRE
          // ====================================

          const Padding(
            padding:
                EdgeInsets.fromLTRB(
              16,
              16,
              16,
              6,
            ),
            child: Align(
              alignment:
                  Alignment.centerLeft,
              child: Text(
                'EXPLORER',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight:
                      FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),

          // ====================================
          // RECHERCHE
          // ====================================

          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              10,
              16,
              12,
            ),
            child: TextField(
              controller:
                  searchController,
              onChanged:
                  searchUsers,
              style: const TextStyle(
                color: Colors.white,
              ),
              decoration:
                  InputDecoration(
                hintText:
                    'Rechercher un pseudo...',
                hintStyle:
                    const TextStyle(
                  color: Colors.white38,
                ),
                prefixIcon:
                    const Icon(
                  Icons.search,
                  color: Colors.white54,
                ),
                suffixIcon:
                    searchMode
                        ? IconButton(
                            onPressed: () {
                              searchController
                                  .clear();

                              setState(() {
                                searchResults =
                                    [];
                                isSearching =
                                    false;
                                errorMessage =
                                    null;
                              });
                            },
                            icon:
                                const Icon(
                              Icons.close,
                              color:
                                  Colors.white54,
                            ),
                          )
                        : null,
                filled: true,
                fillColor:
                    Colors.white10,
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                  borderSide:
                      BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: _buildContent(
              searchMode,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // CONTENU EXPLORER / RECHERCHE
  // ============================================

  Widget _buildContent(
    bool searchMode,
  ) {
    // ==========================================
    // MODE RECHERCHE
    // ==========================================

    if (searchMode) {
      if (isSearching) {
        return const Center(
          child:
              CircularProgressIndicator(),
        );
      }

      if (errorMessage != null) {
        return Center(
          child: Text(
            errorMessage!,
            style: const TextStyle(
              color: Colors.redAccent,
            ),
          ),
        );
      }

      if (searchResults.isEmpty) {
        return const Center(
          child: Text(
            'Aucun utilisateur trouvé.',
            style: TextStyle(
              color: Colors.white38,
            ),
          ),
        );
      }

      return ListView.builder(
        padding:
            const EdgeInsets.fromLTRB(
          16,
          4,
          16,
          24,
        ),
        itemCount:
            searchResults.length,
        itemBuilder:
            (
          context,
          index,
        ) {
          return buildProfileTile(
            searchResults[index],
          );
        },
      );
    }

    // ==========================================
    // MODE EXPLORER
    // ==========================================

    if (isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(
            24,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Text(
                errorMessage!,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color:
                      Colors.white70,
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              OutlinedButton(
                onPressed:
                    loadExploreProfiles,
                child:
                    const Text(
                  'Réessayer',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh:
          loadExploreProfiles,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          16,
          4,
          16,
          24,
        ),
        children: [
          // ====================================
          // CAMPUS
          // ====================================

          buildCampusCard(),

          // ====================================
          // RÈGLE EXPLORER
          // ====================================

          Padding(
            padding:
                const EdgeInsets.only(
              bottom: 16,
            ),
            child: Text(
              'Profils accessibles jusqu’à $myElo Elo',
              style:
                  const TextStyle(
                color:
                    Colors.white54,
                fontSize: 14,
              ),
            ),
          ),

          // ====================================
          // AUCUN PROFIL
          // ====================================

          if (exploreProfiles.isEmpty)
            const Padding(
              padding:
                  EdgeInsets.only(
                top: 100,
              ),
              child: Center(
                child: Text(
                  'Aucun profil à explorer pour le moment.',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color:
                        Colors.white38,
                  ),
                ),
              ),
            ),

          // ====================================
          // PROFILS
          // ====================================

          ...exploreProfiles.map(
            buildProfileTile,
          ),
        ],
      ),
    );
  }
}