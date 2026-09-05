import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
          'Conditions d’utilisation',
        ),
      ),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            Text(
              'Conditions Générales d’Utilisation',
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
            // 1. OBJET
            // ==========================================

            _TermsSection(
              title: '1. Objet',
              text:
                  'ARC est une application sociale centrée sur les looks '
                  'et le style vestimentaire. Elle permet notamment aux '
                  'utilisateurs de créer un profil, de présenter des photos '
                  'de leurs tenues, de participer à des affrontements de '
                  'looks, de voter, d’obtenir un classement et d’utiliser '
                  'des fonctionnalités sociales.',
            ),

            // ==========================================
            // 2. ACCEPTATION
            // ==========================================

            _TermsSection(
              title: '2. Acceptation des conditions',
              text:
                  'La création d’un compte ARC implique l’acceptation des '
                  'présentes Conditions Générales d’Utilisation ainsi que '
                  'de la Politique de confidentialité applicable au service. '
                  'L’utilisateur doit prendre connaissance de ces documents '
                  'avant de créer son compte.',
            ),

            // ==========================================
            // 3. AGE
            // ==========================================

            _TermsSection(
              title: '3. Âge minimum',
              text:
                  'L’utilisation d’ARC est réservée aux personnes âgées '
                  'd’au moins 13 ans. L’utilisateur doit fournir une date '
                  'de naissance exacte lors de la création de son profil. '
                  'ARC peut prendre les mesures nécessaires lorsqu’un compte '
                  'ne respecte pas les conditions d’âge applicables.',
            ),

            // ==========================================
            // 4. COMPTE
            // ==========================================

            _TermsSection(
              title: '4. Compte utilisateur',
              text:
                  'Chaque utilisateur est responsable des informations '
                  'fournies lors de la création et de l’utilisation de son '
                  'compte. Il doit notamment préserver la confidentialité '
                  'de ses identifiants de connexion et ne pas permettre à '
                  'une autre personne d’utiliser son compte de manière '
                  'frauduleuse ou abusive.',
            ),

            // ==========================================
            // 5. PROFIL
            // ==========================================

            _TermsSection(
              title: '5. Profil et informations',
              text:
                  'L’utilisateur peut notamment renseigner un nom '
                  'd’utilisateur, une date de naissance, une description '
                  'et des photos. Les informations publiées sur le profil '
                  'peuvent être visibles par d’autres utilisateurs selon '
                  'le fonctionnement d’ARC.',
            ),

            // ==========================================
            // 6. PHOTOS
            // ==========================================

            _TermsSection(
              title: '6. Photos et contenus',
              text:
                  'L’utilisateur doit uniquement publier des photos et '
                  'contenus qu’il est autorisé à utiliser et à rendre '
                  'visibles sur ARC. Il reste responsable des contenus '
                  'qu’il publie.',
            ),

            _TermsSection(
              title: '7. Contenus interdits',
              text:
                  'Il est interdit de publier des contenus illégaux, '
                  'haineux, menaçants, pornographiques, violents, '
                  'discriminatoires, frauduleux ou portant atteinte aux '
                  'droits, à la vie privée ou à l’image d’une autre '
                  'personne. Les contenus destinés à harceler, humilier '
                  'ou intimider un utilisateur sont également interdits.',
            ),

            // ==========================================
            // 8. DROITS SUR LES CONTENUS
            // ==========================================

            _TermsSection(
              title: '8. Droits sur les contenus',
              text:
                  'L’utilisateur conserve les droits qu’il détient sur '
                  'les contenus qu’il publie. Il autorise toutefois ARC, '
                  'pendant la durée nécessaire au fonctionnement du '
                  'service, à héberger, stocker, afficher et présenter '
                  'ces contenus dans l’application, notamment sur les '
                  'profils et lors des affrontements de looks.',
            ),

            // ==========================================
            // 9. VOTES
            // ==========================================

            _TermsSection(
              title: '9. Votes et affrontements',
              text:
                  'Les affrontements proposés par ARC ont pour objet de '
                  'comparer des looks et des styles vestimentaires. '
                  'Les votes ne sont pas destinés à déterminer la valeur, '
                  'la beauté ou la valeur personnelle d’un utilisateur.',
            ),

            // ==========================================
            // 10. ELO
            // ==========================================

            _TermsSection(
              title: '10. Elo et classement',
              text:
                  'ARC peut utiliser un système de score, notamment un '
                  'système Elo, ainsi que des ligues ou classements. '
                  'Ces résultats dépendent des votes réalisés dans '
                  'l’application et constituent uniquement des mécanismes '
                  'de fonctionnement et de divertissement propres à ARC.',
            ),

            // ==========================================
            // 11. MANIPULATION
            // ==========================================

            _TermsSection(
              title: '11. Manipulation du service',
              text:
                  'Il est interdit de manipuler artificiellement les votes, '
                  'les scores, les classements ou les fonctionnalités ARC. '
                  'Sont notamment interdits l’utilisation de comptes '
                  'multiples à des fins de manipulation, les systèmes '
                  'automatisés de vote, l’exploitation abusive de failles '
                  'ou toute tentative de fraude.',
            ),

            // ==========================================
            // 12. SOCIAL
            // ==========================================

            _TermsSection(
              title: '12. Fonctionnalités sociales',
              text:
                  'ARC peut permettre aux utilisateurs de rechercher '
                  'd’autres profils, d’envoyer ou accepter des demandes '
                  'd’amitié et d’utiliser des fonctionnalités de '
                  'messagerie. Chaque utilisateur est responsable de son '
                  'comportement dans le cadre de ces interactions.',
            ),

            // ==========================================
            // 13. COMPORTEMENT
            // ==========================================

            _TermsSection(
              title: '13. Comportement des utilisateurs',
              text:
                  'Le harcèlement, les menaces, le spam, les escroqueries, '
                  'l’usurpation d’identité, les sollicitations abusives '
                  'ainsi que toute utilisation destinée à nuire à une '
                  'autre personne ou au fonctionnement d’ARC sont interdits.',
            ),

            // ==========================================
            // 14. BLOCAGE
            // ==========================================

            _TermsSection(
              title: '14. Blocage et sécurité',
              text:
                  'ARC peut proposer des outils permettant notamment de '
                  'bloquer certains utilisateurs. Le blocage peut empêcher '
                  'ou limiter les demandes d’amitié, les messages et '
                  'certaines autres interactions entre les comptes '
                  'concernés.',
            ),

            // ==========================================
            // 15. MODÉRATION
            // ==========================================

            _TermsSection(
              title: '15. Modération',
              text:
                  'ARC peut retirer ou rendre inaccessible un contenu, '
                  'limiter certaines fonctionnalités, suspendre ou '
                  'supprimer un compte lorsqu’une telle mesure est '
                  'nécessaire pour faire respecter les présentes '
                  'conditions, protéger les utilisateurs, assurer la '
                  'sécurité du service ou respecter la loi.',
            ),

            // ==========================================
            // 16. DISPONIBILITÉ
            // ==========================================

            _TermsSection(
              title: '16. Disponibilité du service',
              text:
                  'ARC peut évoluer, être modifié, interrompu temporairement '
                  'ou voir certaines fonctionnalités ajoutées, modifiées '
                  'ou supprimées. ARC ne garantit pas une disponibilité '
                  'permanente et sans interruption du service.',
            ),

            // ==========================================
            // 17. SUPPRESSION
            // ==========================================

            _TermsSection(
              title: '17. Suppression du compte',
              text:
                  'L’utilisateur peut demander la suppression de son compte '
                  'depuis l’application lorsque cette fonctionnalité est '
                  'disponible. La suppression entraîne la suppression ou '
                  'l’anonymisation des données associées au compte selon '
                  'leur nature, sous réserve des informations dont la '
                  'conservation serait nécessaire pour respecter une '
                  'obligation légale, assurer la sécurité du service ou '
                  'constater, exercer ou défendre un droit.',
            ),

            // ==========================================
            // 18. RESPONSABILITÉ
            // ==========================================

            _TermsSection(
              title: '18. Responsabilité',
              text:
                  'Chaque utilisateur demeure responsable de son utilisation '
                  'd’ARC, de ses publications et de ses interactions avec '
                  'les autres utilisateurs. ARC met en œuvre des moyens '
                  'raisonnables pour assurer le fonctionnement et la '
                  'sécurité du service, sans pouvoir garantir l’absence '
                  'totale d’erreurs, d’interruptions ou de comportements '
                  'inappropriés de tiers.',
            ),

            // ==========================================
            // 19. MODIFICATIONS
            // ==========================================

            _TermsSection(
              title: '19. Modification des conditions',
              text:
                  'Les présentes conditions peuvent évoluer afin de tenir '
                  'compte des modifications d’ARC, de nouvelles '
                  'fonctionnalités ou des exigences légales et '
                  'réglementaires. Lorsque cela est nécessaire, les '
                  'utilisateurs pourront être informés d’une nouvelle '
                  'version et une nouvelle acceptation pourra être demandée.',
            ),

            // ==========================================
            // 20. DROIT APPLICABLE
            // ==========================================

            _TermsSection(
              title: '20. Droit applicable',
              text:
                  'Les présentes conditions sont soumises au droit français, '
                  'sans priver les utilisateurs consommateurs des '
                  'protections impératives dont ils bénéficient en vertu '
                  'de la réglementation applicable.',
            ),

            SizedBox(height: 24),

            Divider(
              color: Colors.white12,
            ),

            SizedBox(height: 20),

            Text(
              'En utilisant ARC, l’utilisateur s’engage à respecter '
              'les présentes Conditions Générales d’Utilisation.',
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

class _TermsSection extends StatelessWidget {
  final String title;
  final String text;

  const _TermsSection({
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
        crossAxisAlignment:
            CrossAxisAlignment.start,
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