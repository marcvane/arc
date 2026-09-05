import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String version = '1.0';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Politique de confidentialité',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            Text(
              'Politique de confidentialité',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'ARC — Version 1.0',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Dernière mise à jour : août 2026',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 13,
              ),
            ),
            SizedBox(height: 32),

            // ==========================================
            // 1. RESPONSABLE
            // ==========================================

            _PrivacySection(
              title: '1. Responsable du traitement',
              text:
                  'ARC est responsable du traitement des données '
                  'personnelles réalisé dans le cadre de l’application.\n\n'
                  'Responsable : ARC\n'
                  'Contact : contact@arcapp.fr',
            ),

            // ==========================================
            // 2. DONNÉES DE COMPTE
            // ==========================================

            _PrivacySection(
              title: '2. Données de compte',
              text:
                  'Lors de la création et de l’utilisation d’un compte '
                  'ARC, certaines informations sont traitées afin de '
                  'permettre l’accès au service. Elles peuvent notamment '
                  'comprendre l’adresse e-mail, le nom d’utilisateur, '
                  'la date de naissance ou l’âge ainsi que les '
                  'informations techniques nécessaires à '
                  'l’authentification du compte.',
            ),

            // ==========================================
            // 3. PROFIL
            // ==========================================

            _PrivacySection(
              title: '3. Données du profil',
              text:
                  'L’utilisateur peut ajouter différentes informations '
                  'à son profil, notamment un nom d’utilisateur, une '
                  'description et des photos. Certaines de ces informations '
                  'sont destinées à être visibles par les autres '
                  'utilisateurs conformément au fonctionnement d’ARC.',
            ),

            // ==========================================
            // 4. PHOTOS
            // ==========================================

            _PrivacySection(
              title: '4. Photos',
              text:
                  'Les photos ajoutées par l’utilisateur sont stockées '
                  'afin de permettre leur affichage dans ARC. La photo '
                  'principale peut notamment être présentée lors des '
                  'affrontements de looks. Les autres photos peuvent '
                  'être visibles depuis le profil de l’utilisateur.',
            ),

            // ==========================================
            // 5. VOTES ET ELO
            // ==========================================

            _PrivacySection(
              title: '5. Votes, affrontements et classement',
              text:
                  'ARC traite les informations liées aux votes et aux '
                  'affrontements afin d’assurer le fonctionnement du '
                  'système de classement. Cela peut notamment comprendre '
                  'les votes effectués, les utilisateurs concernés, '
                  'les résultats des affrontements, le score Elo, '
                  'la ligue et l’historique du classement.',
            ),

            // ==========================================
            // 6. SOCIAL
            // ==========================================

            _PrivacySection(
              title: '6. Fonctionnalités sociales',
              text:
                  'Lorsque l’utilisateur utilise les fonctionnalités '
                  'sociales d’ARC, certaines informations nécessaires '
                  'à leur fonctionnement peuvent être enregistrées, '
                  'notamment les demandes d’amitié, leur statut, '
                  'les relations entre utilisateurs et les blocages.',
            ),

            // ==========================================
            // 7. MESSAGES
            // ==========================================

            _PrivacySection(
              title: '7. Messagerie',
              text:
                  'Lorsque la messagerie ARC est utilisée, les informations '
                  'nécessaires à son fonctionnement peuvent être traitées, '
                  'notamment l’identité des participants, le contenu des '
                  'messages ainsi que les informations techniques et '
                  'temporelles associées aux échanges.',
            ),

            // ==========================================
            // 8. NOTIFICATIONS
            // ==========================================

            _PrivacySection(
              title: '8. Notifications',
              text:
                  'ARC peut utiliser des identifiants techniques liés '
                  'aux notifications afin d’envoyer des notifications '
                  'sur l’appareil de l’utilisateur. Ces identifiants '
                  'peuvent notamment être générés ou traités par les '
                  'services de notification utilisés par ARC.',
            ),

            // ==========================================
            // 9. FINALITÉS
            // ==========================================

            _PrivacySection(
              title: '9. Pourquoi ces données sont utilisées',
              text:
                  'Les données personnelles sont utilisées notamment '
                  'pour créer et sécuriser les comptes, authentifier '
                  'les utilisateurs, afficher les profils, permettre '
                  'les affrontements et les votes, calculer les scores '
                  'et classements, permettre les fonctionnalités sociales '
                  'et la messagerie, envoyer des notifications, lutter '
                  'contre les abus et assurer le fonctionnement et '
                  'la sécurité d’ARC.',
            ),

            // ==========================================
            // 10. BASES JURIDIQUES
            // ==========================================

            _PrivacySection(
              title: '10. Bases juridiques',
              text:
                  'Selon la fonctionnalité concernée, les traitements '
                  'réalisés par ARC peuvent être nécessaires à '
                  'l’exécution du service demandé par l’utilisateur, '
                  'reposer sur le respect d’une obligation légale, '
                  'sur l’intérêt légitime d’ARC à assurer la sécurité '
                  'et le bon fonctionnement du service ou, lorsque '
                  'cela est requis, sur le consentement de l’utilisateur.',
            ),

            // ==========================================
            // 11. VISIBILITÉ
            // ==========================================

            _PrivacySection(
              title: '11. Informations visibles par les autres utilisateurs',
              text:
                  'Certaines informations ont vocation à être visibles '
                  'dans ARC, notamment le nom d’utilisateur, certaines '
                  'informations du profil, les photos, la ligue et le '
                  'classement Elo. Les informations d’authentification '
                  'telles que l’adresse e-mail ou le mot de passe ne '
                  'sont pas destinées à être affichées publiquement.',
            ),

            // ==========================================
            // 12. PRESTATAIRES
            // ==========================================

            _PrivacySection(
              title: '12. Prestataires techniques',
              text:
                  'ARC utilise des prestataires techniques nécessaires '
                  'au fonctionnement du service. Supabase peut notamment '
                  'être utilisé pour l’authentification, la base de '
                  'données, certaines fonctions serveur et le stockage '
                  'des photos. Firebase peut notamment être utilisé '
                  'pour certaines fonctionnalités techniques telles '
                  'que les notifications.\n\n'
                  'Ces prestataires peuvent traiter certaines données '
                  'uniquement dans la mesure nécessaire à la fourniture '
                  'de leurs services respectifs.',
            ),

            // ==========================================
            // 13. DESTINATAIRES
            // ==========================================

            _PrivacySection(
              title: '13. Destinataires des données',
              text:
                  'Les données sont accessibles dans la mesure nécessaire '
                  'au fonctionnement d’ARC, aux prestataires techniques '
                  'utilisés par le service et, pour les informations '
                  'publiques du profil, aux autres utilisateurs d’ARC. '
                  'Certaines informations peuvent également être '
                  'communiquées lorsqu’une obligation légale l’impose.',
            ),

            // ==========================================
            // 14. TRANSFERTS
            // ==========================================

            _PrivacySection(
              title: '14. Transferts internationaux',
              text:
                  'Certains prestataires techniques utilisés par ARC '
                  'peuvent traiter des données depuis des pays situés '
                  'en dehors de l’Espace économique européen. Lorsque '
                  'la réglementation l’exige, ces transferts doivent '
                  'être encadrés par un mécanisme reconnu par le RGPD, '
                  'tel qu’une décision d’adéquation ou des clauses '
                  'contractuelles types.',
            ),

            // ==========================================
            // 15. CONSERVATION
            // ==========================================

            _PrivacySection(
              title: '15. Conservation des données',
              text:
                  'Les données liées au compte sont conservées pendant '
                  'la durée nécessaire au fonctionnement du compte et '
                  'du service. Certaines informations peuvent être '
                  'conservées pendant une durée supplémentaire lorsqu’une '
                  'obligation légale, un besoin de sécurité, la prévention '
                  'des abus ou la défense de droits le justifie.',
            ),

            // ==========================================
            // 16. SUPPRESSION
            // ==========================================

            _PrivacySection(
              title: '16. Suppression du compte',
              text:
                  'L’utilisateur peut demander la suppression de son '
                  'compte depuis ARC. La suppression entraîne la '
                  'suppression ou, lorsque cela est approprié, '
                  'l’anonymisation des données associées au compte, '
                  'sous réserve des données dont la conservation '
                  'temporaire reste nécessaire pour respecter une '
                  'obligation légale, assurer la sécurité du service '
                  'ou défendre un droit.',
            ),

            // ==========================================
            // 17. SÉCURITÉ
            // ==========================================

            _PrivacySection(
              title: '17. Sécurité',
              text:
                  'ARC met en œuvre des mesures techniques et '
                  'organisationnelles destinées à protéger les données '
                  'personnelles contre les accès non autorisés, la perte, '
                  'l’altération, la destruction ou la divulgation '
                  'inappropriée. Aucun système informatique ne pouvant '
                  'garantir une sécurité absolue, ces mesures sont '
                  'adaptées autant que possible aux risques identifiés.',
            ),

            // ==========================================
            // 18. MINEURS
            // ==========================================

            _PrivacySection(
              title: '18. Utilisateurs mineurs',
              text:
                  'ARC est destiné aux utilisateurs âgés d’au moins '
                  '13 ans. Des règles particulières relatives au '
                  'consentement et à la protection des données des '
                  'mineurs peuvent s’appliquer selon l’âge de '
                  'l’utilisateur, le traitement concerné et le pays '
                  'dans lequel il réside.',
            ),

            // ==========================================
            // 19. DROITS RGPD
            // ==========================================

            _PrivacySection(
              title: '19. Droits des utilisateurs',
              text:
                  'Dans les conditions prévues par le RGPD et la '
                  'réglementation applicable, l’utilisateur peut '
                  'notamment disposer d’un droit d’accès à ses données, '
                  'de rectification, d’effacement, de limitation du '
                  'traitement, d’opposition et de portabilité. '
                  'Lorsqu’un traitement repose sur le consentement, '
                  'celui-ci peut être retiré dans les conditions '
                  'prévues par la réglementation.',
            ),

            // ==========================================
            // 20. EXERCER SES DROITS
            // ==========================================

            _PrivacySection(
              title: '20. Exercer ses droits',
              text:
                  'Pour toute question concernant les données personnelles '
                  'ou pour exercer les droits prévus par la réglementation, '
                  'l’utilisateur peut contacter ARC à l’adresse suivante :\n\n'
                  'contact@arcapp.fr\n\n'
                  'Une vérification de l’identité peut être demandée '
                  'lorsqu’elle est nécessaire afin d’éviter qu’une '
                  'personne non autorisée accède aux données d’un autre '
                  'utilisateur.',
            ),

            // ==========================================
            // 21. CNIL
            // ==========================================

            _PrivacySection(
              title: '21. Réclamation',
              text:
                  'L’utilisateur dispose également du droit '
                  'd’introduire une réclamation auprès de l’autorité '
                  'de contrôle compétente. En France, l’autorité de '
                  'contrôle compétente est la Commission nationale '
                  'de l’informatique et des libertés (CNIL).',
            ),

            // ==========================================
            // 22. MODIFICATIONS
            // ==========================================

            _PrivacySection(
              title: '22. Modification de la politique',
              text:
                  'Cette politique peut être modifiée afin de tenir '
                  'compte de l’évolution d’ARC, de ses fonctionnalités, '
                  'des technologies utilisées ou des exigences légales. '
                  'La version applicable est indiquée dans ARC. Lorsque '
                  'cela est nécessaire, les utilisateurs pourront être '
                  'informés d’une modification importante.',
            ),

            SizedBox(height: 24),

            Divider(
              color: Colors.white12,
            ),

            SizedBox(height: 20),

            Text(
              'Pour toute question relative à la confidentialité '
              'et aux données personnelles : contact@arcapp.fr',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                height: 1.5,
              ),
            ),

            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ============================================
// SECTION
// ============================================

class _PrivacySection extends StatelessWidget {
  final String title;
  final String text;

  const _PrivacySection({
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 26,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 8,
          ),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}