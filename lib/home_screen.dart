import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/vote_screen.dart';
import 'ranking_screen.dart';
import 'explore_screen.dart';
import 'social_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Identité visuelle d'ARC.
  static const Color _arcGold = Color(0xFFD3AE70);
  static const Color _inactiveColor = Color(0xFFBEBEBE);

  int currentIndex = 0;
  late final PageController pageController;

  // Continue à déclencher le chargement du classement à chaque ouverture.
  int rankingRefreshTrigger = 0;

  // Photo principale du profil connecté (Supabase).
  String? _profilePhotoUrl;
  int _photoRequestId = 0;

  @override
  void initState() {
    super.initState();
    pageController = PageController(initialPage: currentIndex);
    _loadProfilePhoto();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  // ============================================
  // PHOTO DE PROFIL POUR LA NAVIGATION
  // ============================================

  Future<void> _loadProfilePhoto() async {
    final requestId = ++_photoRequestId;
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      if (mounted && requestId == _photoRequestId) {
        setState(() => _profilePhotoUrl = null);
      }
      return;
    }

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('photo_1_url')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted || requestId != _photoRequestId) return;

      final photo = profile?['photo_1_url'] as String?;
      setState(() {
        _profilePhotoUrl = photo != null && photo.trim().isNotEmpty
            ? photo.trim()
            : null;
      });
    } catch (error) {
      // Une erreur réseau ne doit jamais bloquer la navigation.
      debugPrint('Impossible de charger la photo du profil : $error');
    }
  }

  Widget _fallbackProfileIcon(bool selected) {
    return Container(
      color: const Color(0xFF252525),
      alignment: Alignment.center,
      child: Icon(
        Icons.person,
        color: selected ? _arcGold : _inactiveColor,
        size: 21,
      ),
    );
  }

  Widget _profileNavIcon(bool selected) {
    final imageUrl = _profilePhotoUrl;

    return Container(
      width: 32,
      height: 32,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? _arcGold : _inactiveColor,
          width: selected ? 2 : 1,
        ),
      ),
      child: ClipOval(
        child: imageUrl == null
            ? _fallbackProfileIcon(selected)
            : Image.network(
                imageUrl,
                key: ValueKey(imageUrl),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                width: 26,
                height: 26,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) {
                  return _fallbackProfileIcon(selected);
                },
              ),
      ),
    );
  }

  // ============================================
  // CHANGEMENT DE PAGE
  // ============================================

  void changePage(int index, {bool animate = true}) {
    if (index == currentIndex) {
      if (index == 4) _loadProfilePhoto();
      return;
    }

    final previousIndex = currentIndex;

    setState(() {
      currentIndex = index;
      if (index == 1) rankingRefreshTrigger++;
    });

    // Rafraîchir l'avatar en ouvrant ou quittant le profil.
    if (previousIndex == 4 || index == 4) {
      _loadProfilePhoto();
    }

    if (!pageController.hasClients) return;

    if (animate) {
      pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      pageController.jumpToPage(index);
    }
  }

  void _onPageChanged(int index) {
    if (index == currentIndex) return;

    final previousIndex = currentIndex;

    setState(() {
      currentIndex = index;
      if (index == 1) rankingRefreshTrigger++;
    });

    // Même comportement lors d'un swipe horizontal.
    if (previousIndex == 4 || index == 4) {
      _loadProfilePhoto();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const VoteScreen(),
      RankingScreen(refreshTrigger: rankingRefreshTrigger),
      const ExploreScreen(),
      const SocialScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView(
        controller: pageController,
        physics: const PageScrollPhysics(),
        onPageChanged: _onPageChanged,
        children: pages,
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
            (states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                color: selected ? _arcGold : _inactiveColor,
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
              );
            },
          ),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          height: 74,
          backgroundColor: Colors.black,
          indicatorColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) => changePage(index),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.compare_arrows, color: _inactiveColor),
              selectedIcon: Icon(Icons.compare_arrows, color: _arcGold),
              label: 'Vote',
            ),
            const NavigationDestination(
              icon: Icon(Icons.emoji_events_outlined, color: _inactiveColor),
              selectedIcon: Icon(Icons.emoji_events, color: _arcGold),
              label: 'Classement',
            ),
            const NavigationDestination(
              icon: Icon(Icons.explore_outlined, color: _inactiveColor),
              selectedIcon: Icon(Icons.explore, color: _arcGold),
              label: 'Explorer',
            ),
            const NavigationDestination(
              icon: Icon(Icons.people_outline, color: _inactiveColor),
              selectedIcon: Icon(Icons.people, color: _arcGold),
              label: 'Social',
            ),
            NavigationDestination(
              icon: _profileNavIcon(false),
              selectedIcon: _profileNavIcon(true),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
