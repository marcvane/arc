import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ContactArcScreen extends StatelessWidget {
  const ContactArcScreen({super.key});

  static const String contactEmail =
      'contact@arcapp.fr';

  Future<void> _copyEmail(
    BuildContext context,
  ) async {
    await Clipboard.setData(
      const ClipboardData(
        text: contactEmail,
      ),
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Adresse e-mail copiée.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Nous contacter'),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // ============================================
              // LOGO
              // ============================================

              Image.asset(
                'assets/arc_logo.png',
                width: 180,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 36),

              const Text(
                'Une question ?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Un problème avec ARC, ton compte '
                'ou simplement quelque chose à nous dire ?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 36),

              // ============================================
              // CONTACT
              // ============================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF151515),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white12,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.mail_outline_rounded,
                      color: Colors.white,
                      size: 28,
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'E-mail',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const SelectableText(
                      contactEmail,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _copyEmail(context);
                        },
                        icon: const Icon(
                          Icons.copy_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'Copier l’adresse',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'Nous ferons notre possible pour répondre '
                'dans les meilleurs délais.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

              const Spacer(),

              const Text(
                'ARC — L’audace a un nom.',
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}