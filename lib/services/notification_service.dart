import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  static final SupabaseClient _supabase =
      Supabase.instance.client;

  // ==============================
  // INITIALISATION
  // ==============================

  static Future<void> initialize() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    // Demande l'autorisation de recevoir
    // des notifications.
    final settings =
        await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus ==
            AuthorizationStatus.denied ||
        settings.authorizationStatus ==
            AuthorizationStatus.notDetermined) {
      return;
    }

    // ==============================
    // TOKEN ACTUEL
    // ==============================

    final token = await _messaging.getToken();

    if (token != null) {
      await _saveToken(token);
    }

    // ==============================
    // CHANGEMENT DU TOKEN
    // ==============================

    _messaging.onTokenRefresh.listen(
      (newToken) async {
        await _saveToken(newToken);
      },
    );

    // ==============================
    // NOTIFICATION REÇUE
    // APP OUVERTE
    // ==============================

    FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) {
        final notification =
            message.notification;

        if (notification != null) {
          debugPrint(
            'Notification reçue : '
            '${notification.title} - '
            '${notification.body}',
          );
        }
      },
    );
  }

  // ==============================
  // ENREGISTRER LE TOKEN
  // ==============================

  static Future<void> _saveToken(
    String token,
  ) async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    String platform = 'unknown';

    if (Platform.isAndroid) {
      platform = 'android';
    } else if (Platform.isIOS) {
      platform = 'ios';
    }

    try {
      await _supabase
          .from('push_tokens')
          .upsert(
        {
          'user_id': user.id,
          'token': token,
          'platform': platform,
          'updated_at': DateTime.now()
              .toUtc()
              .toIso8601String(),
        },
        onConflict: 'token',
      );
    } catch (error) {
      debugPrint(
        'Impossible d’enregistrer '
        'le token Firebase : $error',
      );
    }
  }

  // ==============================
  // SUPPRIMER LES TOKENS
  // ==============================

  static Future<void>
      removeCurrentUserTokens() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    await _supabase
        .from('push_tokens')
        .delete()
        .eq(
          'user_id',
          user.id,
        );
  }
}