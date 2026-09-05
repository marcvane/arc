import 'package:flutter/material.dart';

import 'screens/vote_screen.dart';
import 'ranking_screen.dart';
import 'explore_screen.dart';
import 'social_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;

  late final PageController pageController;

  // Ce compteur permet de demander au classement
  // de se recharger lorsqu'on ouvre l'onglet.
  int rankingRefreshTrigger = 0;

  @override
  void initState() {
    super.initState();

    pageController = PageController(
      initialPage: currentIndex,
    );
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  // ============================================
  // CHANGEMENT DE PAGE
  // ============================================

  void changePage(
    int index, {
    bool animate = true,
  }) {
    if (index == currentIndex) {
      return;
    }

    setState(() {
      currentIndex = index;

      // ========================================
      // CLASSEMENT
      // ========================================
      //
      // Index 1 = Classement.
      //
      // À chaque ouverture de l'onglet,
      // on augmente le compteur afin que
      // RankingScreen recharge les données
      // Supabase.

      if (index == 1) {
        rankingRefreshTrigger++;
      }
    });

    if (animate) {
      pageController.animateToPage(
        index,
        duration: const Duration(
          milliseconds: 260,
        ),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      // ========================================
      // 0 - VOTE
      // ========================================

      const VoteScreen(),

      // ========================================
      // 1 - CLASSEMENT
      // ========================================

      RankingScreen(
        refreshTrigger: rankingRefreshTrigger,
      ),

      // ========================================
      // 2 - EXPLORER
      // ========================================

      const ExploreScreen(),

      // ========================================
      // 3 - SOCIAL
      // ========================================

      const SocialScreen(),

      // ========================================
      // 4 - PROFIL
      // ========================================

      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.black,

      body: PageView(
        controller: pageController,

        // Swipe horizontal activé.
        physics: const PageScrollPhysics(),

        onPageChanged: (index) {
          if (index == currentIndex) {
            return;
          }

          setState(() {
            currentIndex = index;

            if (index == 1) {
              rankingRefreshTrigger++;
            }
          });
        },

        children: pages,
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        backgroundColor: Colors.black,
        indicatorColor: Colors.white12,

        onDestinationSelected: (index) {
          changePage(
            index,
          );
        },

        destinations: const [
          // ====================================
          // VOTE
          // ====================================

          NavigationDestination(
            icon: Icon(
              Icons.compare_arrows,
            ),
            selectedIcon: Icon(
              Icons.compare_arrows,
            ),
            label: 'Vote',
          ),

          // ====================================
          // CLASSEMENT
          // ====================================

          NavigationDestination(
            icon: Icon(
              Icons.emoji_events_outlined,
            ),
            selectedIcon: Icon(
              Icons.emoji_events,
            ),
            label: 'Classement',
          ),

          // ====================================
          // EXPLORER
          // ====================================

          NavigationDestination(
            icon: Icon(
              Icons.explore_outlined,
            ),
            selectedIcon: Icon(
              Icons.explore,
            ),
            label: 'Explorer',
          ),

          // ====================================
          // SOCIAL
          // ====================================

          NavigationDestination(
            icon: Icon(
              Icons.people_outline,
            ),
            selectedIcon: Icon(
              Icons.people,
            ),
            label: 'Social',
          ),

          // ====================================
          // PROFIL
          // ====================================

          NavigationDestination(
            icon: Icon(
              Icons.person_outline,
            ),
            selectedIcon: Icon(
              Icons.person,
            ),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}