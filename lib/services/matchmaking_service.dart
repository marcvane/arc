import 'dart:math';

import '../model/user_model.dart';

class MatchmakingService {
  static const int defaultEloRange = 250;

  static final Random _random = Random();

  // Garde en mémoire les duels récemment affichés.
  static final Set<String> _recentDuels = {};

  // ==============================
  // SUPPRIMER LES PROFILS EN DOUBLE
  // ==============================

  static List<ArcUser> _removeDuplicateUsers(
    List<ArcUser> users,
  ) {
    final Map<String, ArcUser> uniqueUsers = {};

    for (final user in users) {
      uniqueUsers[user.id] = user;
    }

    return uniqueUsers.values.toList();
  }

  // ==============================
  // TROUVER LES CANDIDATS
  // ==============================

  static List<ArcUser> findCandidates({
    required ArcUser referenceUser,
    required List<ArcUser> users,
    int eloRange = defaultEloRange,
  }) {
    final uniqueUsers = _removeDuplicateUsers(users);

    return uniqueUsers.where((user) {
      // Sécurité principale :
      // impossible de s'affronter soi-même.
      if (user.id == referenceUser.id) {
        return false;
      }

      final eloDifference =
          (user.elo - referenceUser.elo).abs();

      // Les deux profils doivent avoir
      // un Elo suffisamment proche.
      if (eloDifference > eloRange) {
        return false;
      }

      final duelKey = _createDuelKey(
        referenceUser.id,
        user.id,
      );

      // Évite de montrer immédiatement
      // le même duel plusieurs fois.
      if (_recentDuels.contains(duelKey)) {
        return false;
      }

      return true;
    }).toList();
  }

  // ==============================
  // CRÉER UN DUEL
  // ==============================

  static List<ArcUser>? createDuel({
    required List<ArcUser> users,
    int eloRange = defaultEloRange,
  }) {
    // Première sécurité :
    // on élimine tous les doublons d'ID
    // AVANT de créer le duel.
    final uniqueUsers =
        _removeDuplicateUsers(users);

    if (uniqueUsers.length < 2) {
      return null;
    }

    final shuffledUsers =
        List<ArcUser>.from(uniqueUsers)
          ..shuffle(_random);

    for (final first in shuffledUsers) {
      final candidates = findCandidates(
        referenceUser: first,
        users: uniqueUsers,
        eloRange: eloRange,
      );

      if (candidates.isEmpty) {
        continue;
      }

      final second =
          candidates[
            _random.nextInt(
              candidates.length,
            )
          ];

      // Sécurité supplémentaire.
      // Cette situation ne devrait plus
      // pouvoir arriver, mais on refuse
      // quand même le duel si les IDs
      // sont identiques.
      if (first.id == second.id) {
        continue;
      }

      _rememberDuel(
        first.id,
        second.id,
      );

      return [
        first,
        second,
      ];
    }

    // Si tous les duels possibles
    // dans cette plage Elo ont déjà
    // été affichés, on réinitialise
    // la mémoire des duels récents.
    if (_recentDuels.isNotEmpty) {
      _recentDuels.clear();

      return createDuel(
        users: uniqueUsers,
        eloRange: eloRange,
      );
    }

    return null;
  }

  // ==============================
  // MÉMORISER UN DUEL
  // ==============================

  static void _rememberDuel(
    String firstId,
    String secondId,
  ) {
    // Sécurité :
    // on ne mémorise jamais
    // un duel A contre A.
    if (firstId == secondId) {
      return;
    }

    _recentDuels.add(
      _createDuelKey(
        firstId,
        secondId,
      ),
    );
  }

  // ==============================
  // CLÉ UNIQUE DU DUEL
  // ==============================

  static String _createDuelKey(
    String firstId,
    String secondId,
  ) {
    final ids = [
      firstId,
      secondId,
    ]..sort();

    return '${ids[0]}_${ids[1]}';
  }

  // ==============================
  // RESET OPTIONNEL
  // ==============================

  static void resetRecentDuels() {
    _recentDuels.clear();
  }
}