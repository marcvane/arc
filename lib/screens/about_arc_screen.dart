import 'package:flutter/material.dart';

class AboutArcScreen extends StatelessWidget {
  const AboutArcScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('À propos d’ARC'),
      ),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),

            // ============================================
            // LOGO
            // ============================================

            Center(
              child: Image.asset(
                'assets/arc_logo.png',
                width: 180,
                fit: BoxFit.contain,
              ),
            ),

            const SizedBox(height: 20),

            const Center(
              child: Text(
                'L’AUDACE A UN NOM.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3,
                ),
              ),
            ),

            const SizedBox(height: 48),

            // ============================================
            // ARC
            // ============================================

            const Text(
              'ARC',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'ARC est une application sociale centrée sur le style '
              'vestimentaire et les looks.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'L’idée est simple : confronter des looks, voter pour '
              'ceux que l’on préfère et progresser dans un classement '
              'construit par la communauté.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'ARC classe les looks et les styles vestimentaires. '
              'L’objectif n’est pas de déterminer la beauté ou la '
              'valeur personnelle des utilisateurs.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 36),

            // ============================================
            // CAMPUS
            // ============================================

            const _AboutSection(
              icon: Icons.school_outlined,
              title: 'Campus',
              text:
                  'ARC permet également aux étudiants de rejoindre '
                  'leur campus et de participer à une expérience '
                  'collective autour de leur communauté.',
            ),

            const _AboutSection(
              icon: Icons.emoji_events_outlined,
              title: 'Classements',
              text:
                  'Les votes alimentent un système de score et de '
                  'classement permettant de suivre sa progression '
                  'dans ARC.',
            ),

            const _AboutSection(
              icon: Icons.people_outline_rounded,
              title: 'Communauté',
              text:
                  'ARC est pensé comme un espace social permettant '
                  'de découvrir des styles, des profils et des '
                  'communautés.',
            ),

            const SizedBox(height: 12),

            const Divider(
              color: Colors.white12,
            ),

            const SizedBox(height: 24),

            // ============================================
            // VERSION
            // ============================================

            const Center(
              child: Text(
                'ARC — Version 1.0',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                ),
              ),
            ),

            const SizedBox(height: 8),

            const Center(
              child: Text(
                '© 2026 ARC',
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ============================================
// SECTION
// ============================================

class _AboutSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _AboutSection({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 28,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF151515),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: Colors.white12,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white70,
              size: 21,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}