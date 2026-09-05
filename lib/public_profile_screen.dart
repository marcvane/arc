import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;

  const PublicProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  State<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

class _PublicProfileScreenState
    extends State<PublicProfileScreen> {
  final SupabaseClient supabase =
      Supabase.instance.client;

  Map<String, dynamic>? profile;
  Map<String, dynamic>? friendRequest;

  bool isLoading = true;
  bool isFriendLoading = false;
  bool isReportLoading = false;

  // Vrai si NOUS avons bloqué cet utilisateur.
  bool isBlocked = false;

  // Vrai si CET utilisateur nous a bloqués.
  bool isBlockedByOther = false;

  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadEverything();
  }

  // ==============================
  // CALCULER L'ÂGE
  // ==============================

  int? calculateAgeFromBirthDate(
    dynamic birthDateValue,
  ) {
    if (birthDateValue == null) {
      return null;
    }

    final birthDate = DateTime.tryParse(
      birthDateValue.toString(),
    );

    if (birthDate == null) {
      return null;
    }

    final today = DateTime.now();

    int age =
        today.year - birthDate.year;

    if (today.month < birthDate.month ||
        (today.month == birthDate.month &&
            today.day < birthDate.day)) {
      age--;
    }

    return age;
  }

  // ==============================
  // CHARGEMENT COMPLET
  // ==============================

  Future<void> loadEverything() async {
    try {
      await loadProfile();
      await loadBlockStatus();

      if (!isBlocked && !isBlockedByOther) {
        await loadFriendStatus();
      } else {
        friendRequest = null;
      }

      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = null;
      });
    } catch (error) {
      debugPrint(
        'Erreur chargement profil public : $error',
      );

      if (!mounted) return;

      setState(() {
        errorMessage =
            'Impossible de charger ce profil.';
        isLoading = false;
      });
    }
  }

  // ==============================
  // PROFIL + CAMPUS + FORMATION
  // ==============================

  Future<void> loadProfile() async {
    final response = await supabase
        .from('profiles')
        .select(
          '''
          *,
          campuses(
            id,
            name,
            slug,
            city,
            country
          ),
          clans(
            id,
            name,
            slug
          )
          ''',
        )
        .eq(
          'id',
          widget.userId,
        )
        .single();

    profile =
        Map<String, dynamic>.from(response);
  }

  // ==============================
  // VÉRIFIER LE BLOCAGE
  // ==============================

  Future<void> loadBlockStatus() async {
    final currentUser =
        supabase.auth.currentUser;

    if (currentUser == null ||
        currentUser.id == widget.userId) {
      isBlocked = false;
      isBlockedByOther = false;
      return;
    }

    final blockedByMe = await supabase
        .from('blocks')
        .select('id')
        .eq(
          'blocker_id',
          currentUser.id,
        )
        .eq(
          'blocked_id',
          widget.userId,
        )
        .maybeSingle();

    final blockedByOther = await supabase
        .from('blocks')
        .select('id')
        .eq(
          'blocker_id',
          widget.userId,
        )
        .eq(
          'blocked_id',
          currentUser.id,
        )
        .maybeSingle();

    isBlocked =
        blockedByMe != null;

    isBlockedByOther =
        blockedByOther != null;
  }

  // ==============================
  // STATUT AMITIÉ
  // ==============================

  Future<void> loadFriendStatus() async {
    final currentUser =
        supabase.auth.currentUser;

    if (currentUser == null) {
      friendRequest = null;
      return;
    }

    if (currentUser.id == widget.userId) {
      friendRequest = null;
      return;
    }

    final sent = await supabase
        .from('friend_requests')
        .select()
        .eq(
          'sender_id',
          currentUser.id,
        )
        .eq(
          'receiver_id',
          widget.userId,
        )
        .maybeSingle();

    if (sent != null) {
      friendRequest =
          Map<String, dynamic>.from(sent);
      return;
    }

    final received = await supabase
        .from('friend_requests')
        .select()
        .eq(
          'sender_id',
          widget.userId,
        )
        .eq(
          'receiver_id',
          currentUser.id,
        )
        .maybeSingle();

    if (received != null) {
      friendRequest =
          Map<String, dynamic>.from(
        received,
      );
      return;
    }

    friendRequest = null;
  }

  // ==============================
  // ENVOYER DEMANDE
  // ==============================

  Future<void> sendFriendRequest() async {
    final currentUser =
        supabase.auth.currentUser;

    if (currentUser == null) {
      showMessage(
        'Utilisateur non connecté.',
      );
      return;
    }

    if (currentUser.id == widget.userId) {
      return;
    }

    setState(() {
      isFriendLoading = true;
    });

    try {
      await loadBlockStatus();

      if (isBlocked) {
        if (!mounted) return;

        setState(() {
          isFriendLoading = false;
        });

        showMessage(
          'Débloque cet utilisateur avant de l’ajouter.',
        );
        return;
      }

      if (isBlockedByOther) {
        if (!mounted) return;

        setState(() {
          isFriendLoading = false;
        });

        showMessage(
          'Impossible d’envoyer cette demande.',
        );
        return;
      }

      await loadFriendStatus();

      if (friendRequest != null) {
        if (!mounted) return;

        setState(() {
          isFriendLoading = false;
        });

        return;
      }

      await supabase
          .from('friend_requests')
          .insert({
        'sender_id': currentUser.id,
        'receiver_id': widget.userId,
        'status': 'pending',
      });

      await loadFriendStatus();

      if (!mounted) return;

      setState(() {
        isFriendLoading = false;
      });

      showArcSuccess(
        'Demande envoyée',
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        isFriendLoading = false;
      });

      if (error.code == '23505') {
        showMessage(
          'Une demande existe déjà.',
        );

        await loadFriendStatus();

        if (mounted) {
          setState(() {});
        }
      } else {
        showMessage(
          error.message,
        );
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isFriendLoading = false;
      });

      showMessage(
        'Impossible d’envoyer la demande.',
      );
    }
  }

  // ==============================
  // ACCEPTER DEMANDE
  // ==============================

  Future<void> acceptFriendRequest() async {
    final request = friendRequest;

    if (request == null) return;

    setState(() {
      isFriendLoading = true;
    });

    try {
      await loadBlockStatus();

      if (isBlocked ||
          isBlockedByOther) {
        if (!mounted) return;

        setState(() {
          isFriendLoading = false;
        });

        showMessage(
          'Impossible d’accepter cette demande.',
        );

        return;
      }

      await supabase
          .from('friend_requests')
          .update({
        'status': 'accepted',
      }).eq(
        'id',
        request['id'],
      );

      await loadFriendStatus();

      if (!mounted) return;

      setState(() {
        isFriendLoading = false;
      });

      showMessage(
        'Vous êtes maintenant amis.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isFriendLoading = false;
      });

      showMessage(
        'Impossible d’accepter la demande.',
      );
    }
  }

  // ==============================
  // REFUSER DEMANDE
  // ==============================

  Future<void> rejectFriendRequest() async {
    final request =
        friendRequest;

    if (request == null) return;

    setState(() {
      isFriendLoading = true;
    });

    try {
      await supabase
          .from('friend_requests')
          .delete()
          .eq(
            'id',
            request['id'],
          );

      friendRequest = null;

      if (!mounted) return;

      setState(() {
        isFriendLoading = false;
      });

      showMessage(
        'Demande refusée.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isFriendLoading = false;
      });

      showMessage(
        'Impossible de refuser la demande.',
      );
    }
  }

  // ==============================
  // ANNULER DEMANDE
  // ==============================

  Future<void> cancelFriendRequest() async {
    final request =
        friendRequest;

    if (request == null) return;

    setState(() {
      isFriendLoading = true;
    });

    try {
      await supabase
          .from('friend_requests')
          .delete()
          .eq(
            'id',
            request['id'],
          );

      friendRequest = null;

      if (!mounted) return;

      setState(() {
        isFriendLoading = false;
      });

      showMessage(
        'Demande annulée.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isFriendLoading = false;
      });

      showMessage(
        'Impossible d’annuler la demande.',
      );
    }
  }

  // ==============================
  // SUPPRIMER AMI
  // ==============================

  Future<void> removeFriend() async {
    final request =
        friendRequest;

    if (request == null) return;

    setState(() {
      isFriendLoading = true;
    });

    try {
      await supabase
          .from('friend_requests')
          .delete()
          .eq(
            'id',
            request['id'],
          );

      friendRequest = null;

      if (!mounted) return;

      setState(() {
        isFriendLoading = false;
      });

      showMessage(
        'Ami supprimé.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isFriendLoading = false;
      });

      showMessage(
        'Impossible de supprimer cet ami.',
      );
    }
  }

  // ==============================
  // BLOQUER
  // ==============================

  Future<void> blockUser() async {
    final currentUser =
        supabase.auth.currentUser;

    if (currentUser == null) return;

    setState(() {
      isFriendLoading = true;
    });

    try {
      await supabase
          .from('blocks')
          .insert({
        'blocker_id':
            currentUser.id,
        'blocked_id':
            widget.userId,
      });

      await supabase
          .from('friend_requests')
          .delete()
          .or(
            'and(sender_id.eq.${currentUser.id},receiver_id.eq.${widget.userId}),'
            'and(sender_id.eq.${widget.userId},receiver_id.eq.${currentUser.id})',
          );

      friendRequest = null;

      if (!mounted) return;

      setState(() {
        isBlocked = true;
        isBlockedByOther = false;
        isFriendLoading = false;
      });

      showMessage(
        'Utilisateur bloqué.',
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        isFriendLoading = false;
      });

      if (error.code == '23505') {
        setState(() {
          isBlocked = true;
          friendRequest = null;
        });

        showMessage(
          'Cet utilisateur est déjà bloqué.',
        );
      } else {
        showMessage(
          'Impossible de bloquer cet utilisateur.',
        );
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isFriendLoading = false;
      });

      showMessage(
        'Impossible de bloquer cet utilisateur.',
      );
    }
  }

  // ==============================
  // CONFIRMER BLOCAGE
  // ==============================

  Future<void> confirmBlockUser() async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor:
              const Color(0xFF181818),

          title: Text(
            'Bloquer @${profile?['username'] ?? 'Utilisateur'} ?',
            style: const TextStyle(
              color: Colors.white,
            ),
          ),

          content: const Text(
            'L’amitié sera supprimée et vous ne pourrez plus vous envoyer de messages ou de demandes d’amitié.',
            style: TextStyle(
              color: Colors.white70,
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'Annuler',
              ),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text(
                'Bloquer',
                style: TextStyle(
                  color:
                      Colors.redAccent,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await blockUser();
    }
  }

  // ==============================
  // DÉBLOQUER
  // ==============================

  Future<void> unblockUser() async {
    final currentUser =
        supabase.auth.currentUser;

    if (currentUser == null) return;

    setState(() {
      isFriendLoading = true;
    });

    try {
      await supabase
          .from('blocks')
          .delete()
          .eq(
            'blocker_id',
            currentUser.id,
          )
          .eq(
            'blocked_id',
            widget.userId,
          );

      if (!mounted) return;

      setState(() {
        isBlocked = false;
        isFriendLoading = false;
      });

      await loadFriendStatus();

      if (!mounted) return;

      setState(() {});

      showMessage(
        'Utilisateur débloqué.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isFriendLoading = false;
      });

      showMessage(
        'Impossible de débloquer cet utilisateur.',
      );
    }
  }

  // ==============================
  // SIGNALER
  // ==============================

  Future<void> openReportDialog() async {
    final currentUser =
        supabase.auth.currentUser;

    if (currentUser == null) {
      showMessage(
        'Utilisateur non connecté.',
      );
      return;
    }

    if (currentUser.id == widget.userId) {
      return;
    }

    String? selectedReason;

    final detailsController =
        TextEditingController();

    final reportData =
        await showDialog<Map<String, String>?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              backgroundColor:
                  const Color(0xFF181818),

              title: Text(
                'Signaler @${profile?['username'] ?? 'Utilisateur'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              content:
                  SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pourquoi souhaites-tu signaler ce profil ?',
                      style: TextStyle(
                        color:
                            Colors.white70,
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    RadioGroup<String>(
                      groupValue:
                          selectedReason,

                      onChanged: (value) {
                        setDialogState(() {
                          selectedReason =
                              value;
                        });
                      },

                      child: const Column(
                        children: [
                          RadioListTile<String>(
                            value:
                                'harassment',
                            contentPadding:
                                EdgeInsets.zero,
                            title: Text(
                              'Harcèlement ou menace',
                              style:
                                  TextStyle(
                                color:
                                    Colors.white,
                              ),
                            ),
                          ),

                          RadioListTile<String>(
                            value:
                                'inappropriate_content',
                            contentPadding:
                                EdgeInsets.zero,
                            title: Text(
                              'Contenu inapproprié',
                              style:
                                  TextStyle(
                                color:
                                    Colors.white,
                              ),
                            ),
                          ),

                          RadioListTile<String>(
                            value:
                                'impersonation',
                            contentPadding:
                                EdgeInsets.zero,
                            title: Text(
                              'Faux profil ou usurpation d’identité',
                              style:
                                  TextStyle(
                                color:
                                    Colors.white,
                              ),
                            ),
                          ),

                          RadioListTile<String>(
                            value:
                                'spam',
                            contentPadding:
                                EdgeInsets.zero,
                            title: Text(
                              'Spam',
                              style:
                                  TextStyle(
                                color:
                                    Colors.white,
                              ),
                            ),
                          ),

                          RadioListTile<String>(
                            value:
                                'other',
                            contentPadding:
                                EdgeInsets.zero,
                            title: Text(
                              'Autre',
                              style:
                                  TextStyle(
                                color:
                                    Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    TextField(
                      controller:
                          detailsController,
                      maxLength: 500,
                      maxLines: 4,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                      ),
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Détails (facultatif)',
                        hintText:
                            'Explique brièvement le problème...',
                        labelStyle:
                            TextStyle(
                          color:
                              Colors.white60,
                        ),
                        hintStyle:
                            TextStyle(
                          color:
                              Colors.white30,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child: const Text(
                    'Annuler',
                  ),
                ),

                ElevatedButton(
                  onPressed:
                      selectedReason == null
                          ? null
                          : () {
                              Navigator.pop(
                                dialogContext,
                                {
                                  'reason':
                                      selectedReason!,
                                  'details':
                                      detailsController
                                          .text
                                          .trim(),
                                },
                              );
                            },
                  child: const Text(
                    'Envoyer',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    detailsController.dispose();

    if (reportData == null) {
      return;
    }

    await submitReport(
      reason:
          reportData['reason']!,
      details:
          reportData['details'] ?? '',
    );
  }

  // ==============================
  // ENVOYER LE SIGNALEMENT
  // ==============================

  Future<void> submitReport({
    required String reason,
    required String details,
  }) async {
    if (isReportLoading) {
      return;
    }

    final currentUser =
        supabase.auth.currentUser;

    if (currentUser == null) {
      showMessage(
        'Utilisateur non connecté.',
      );
      return;
    }

    if (currentUser.id == widget.userId) {
      showMessage(
        'Tu ne peux pas signaler ton propre profil.',
      );
      return;
    }

    setState(() {
      isReportLoading = true;
    });

    try {
      await supabase
          .from('reports')
          .insert({
        'reporter_id':
            currentUser.id,
        'reported_user_id':
            widget.userId,
        'reason':
            reason,
        'details':
            details.isEmpty
                ? null
                : details,
      });

      if (!mounted) return;

      setState(() {
        isReportLoading = false;
      });

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor:
                const Color(0xFF181818),

            title: const Text(
              'Signalement envoyé',
              style: TextStyle(
                color: Colors.white,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            content: const Text(
              'Merci. Ton signalement a bien été transmis.',
              style: TextStyle(
                color: Colors.white70,
              ),
            ),

            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                  );
                },
                child: const Text(
                  'OK',
                ),
              ),
            ],
          );
        },
      );
    } on PostgrestException catch (error) {
      debugPrint(
        'Erreur signalement Supabase : ${error.message}',
      );

      if (!mounted) return;

      setState(() {
        isReportLoading = false;
      });

      showMessage(
        'Impossible d’envoyer le signalement.',
      );
    } catch (error) {
      debugPrint(
        'Erreur signalement : $error',
      );

      if (!mounted) return;

      setState(() {
        isReportLoading = false;
      });

      showMessage(
        'Impossible d’envoyer le signalement.',
      );
    }
  }

  // ==============================
  // CHAT
  // ==============================

  void openChat() {
    if (isBlocked ||
        isBlockedByOther) {
      return;
    }

    final username =
        profile?['username']
                as String? ??
            'Utilisateur';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatScreen(
          otherUserId:
              widget.userId,
          otherUsername:
              username,
        ),
      ),
    ).then((_) async {
      await loadBlockStatus();

      if (!isBlocked &&
          !isBlockedByOther) {
        await loadFriendStatus();
      } else {
        friendRequest = null;
      }

      if (mounted) {
        setState(() {});
      }
    });
  }

  // ==============================
  // FEEDBACK ARC
  // ==============================

  void showArcSuccess(
    String message,
  ) {
    if (!mounted) return;

    final overlay = Overlay.of(context);

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 28,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 22,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(
                      24,
                    ),
                    border: Border.all(
                      color: Colors.white12,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: 0.45,
                        ),
                        blurRadius: 24,
                        offset: const Offset(
                          0,
                          10,
                        ),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/arc_logo.png',
                        height: 48,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(
                        height: 14,
                      ),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);

    Future.delayed(
      const Duration(
        milliseconds: 1400,
      ),
      () {
        if (entry.mounted) {
          entry.remove();
        }
      },
    );
  }

  // ==============================
  // MESSAGE
  // ==============================

  void showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(message),
      ),
    );
  }

  // ==============================
  // SECTION SOCIALE
  // ==============================

  Widget buildFriendSection() {
    final currentUser =
        supabase.auth.currentUser;

    if (currentUser == null ||
        currentUser.id ==
            widget.userId) {
      return const SizedBox.shrink();
    }

    if (isFriendLoading) {
      return const SizedBox(
        height: 52,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child:
                CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (isBlocked) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed:
              unblockUser,
          icon: const Icon(
            Icons.lock_open,
          ),
          label: const Text(
            'Débloquer',
          ),
        ),
      );
    }

    if (isBlockedByOther) {
      return const SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton(
          onPressed: null,
          child: Text(
            'Indisponible',
          ),
        ),
      );
    }

    if (friendRequest == null) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child:
                ElevatedButton.icon(
              onPressed:
                  sendFriendRequest,
              icon: const Icon(
                Icons
                    .person_add_alt_1,
              ),
              label:
                  const Text(
                'Ajouter',
              ),
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          TextButton.icon(
            onPressed:
                confirmBlockUser,
            icon: const Icon(
              Icons.block,
              color:
                  Colors.redAccent,
            ),
            label: const Text(
              'Bloquer',
              style: TextStyle(
                color:
                    Colors.redAccent,
              ),
            ),
          ),
        ],
      );
    }

    final currentUserId =
        currentUser.id;

    final senderId =
        friendRequest!['sender_id']
            as String;

    final status =
        friendRequest!['status']
                as String? ??
            'pending';

    if (status == 'accepted') {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        removeFriend,
                    icon:
                        const Icon(
                      Icons.people,
                    ),
                    label:
                        const Text(
                      'Amis ✓',
                    ),
                  ),
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: SizedBox(
                  height: 52,
                  child:
                      ElevatedButton.icon(
                    onPressed:
                        openChat,
                    icon:
                        const Icon(
                      Icons
                          .chat_bubble_outline,
                    ),
                    label:
                        const Text(
                      'Message',
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 8,
          ),

          TextButton.icon(
            onPressed:
                confirmBlockUser,
            icon: const Icon(
              Icons.block,
              color:
                  Colors.redAccent,
            ),
            label: const Text(
              'Bloquer',
              style: TextStyle(
                color:
                    Colors.redAccent,
              ),
            ),
          ),
        ],
      );
    }

    if (senderId ==
        currentUserId) {
      return Column(
        children: [
          SizedBox(
            width:
                double.infinity,
            height: 52,
            child:
                OutlinedButton.icon(
              onPressed:
                  cancelFriendRequest,
              icon: const Icon(
                Icons.schedule,
              ),
              label:
                  const Text(
                'Demande envoyée',
              ),
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          TextButton.icon(
            onPressed:
                confirmBlockUser,
            icon: const Icon(
              Icons.block,
              color:
                  Colors.redAccent,
            ),
            label: const Text(
              'Bloquer',
              style: TextStyle(
                color:
                    Colors.redAccent,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child:
                    ElevatedButton.icon(
                  onPressed:
                      acceptFriendRequest,
                  icon:
                      const Icon(
                    Icons.check,
                  ),
                  label:
                      const Text(
                    'Accepter',
                  ),
                ),
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child: SizedBox(
                height: 52,
                child:
                    OutlinedButton.icon(
                  onPressed:
                      rejectFriendRequest,
                  icon:
                      const Icon(
                    Icons.close,
                  ),
                  label:
                      const Text(
                    'Refuser',
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 8,
        ),

        TextButton.icon(
          onPressed:
              confirmBlockUser,
          icon: const Icon(
            Icons.block,
            color:
                Colors.redAccent,
          ),
          label: const Text(
            'Bloquer',
            style: TextStyle(
              color:
                  Colors.redAccent,
            ),
          ),
        ),
      ],
    );
  }

  // ==============================
  // CARTE CAMPUS DU PROFIL
  // ==============================

  Widget buildCampusSection() {
    final campusData =
        profile?['campuses'];

    final clanData =
        profile?['clans'];

    if (campusData == null) {
      return const SizedBox.shrink();
    }

    final campus =
        Map<String, dynamic>.from(
      campusData as Map,
    );

    final campusName =
        campus['name']
                ?.toString() ??
            'Campus';

    final city =
        campus['city']
                ?.toString() ??
            '';

    final country =
        campus['country']
                ?.toString() ??
            '';

    String clanName = '';

    if (clanData is Map) {
      clanName =
          clanData['name']
                  ?.toString() ??
              '';
    }

    String location = '';

    if (city.isNotEmpty &&
        country.isNotEmpty) {
      location =
          '$city • $country';
    } else if (city.isNotEmpty) {
      location = city;
    } else if (country.isNotEmpty) {
      location = country;
    }

    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.all(
        18,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white10,

        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          const Row(
            children: [
              Icon(
                Icons.school_outlined,
                color:
                    Colors.white54,
                size: 18,
              ),

              SizedBox(
                width: 8,
              ),

              Text(
                'CAMPUS',
                style:
                    TextStyle(
                  color:
                      Colors.white54,
                  fontSize:
                      11,
                  letterSpacing:
                      2,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          Text(
            campusName,
            style:
                const TextStyle(
              color:
                  Colors.white,
              fontSize:
                  19,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          if (location.isNotEmpty) ...[
            const SizedBox(
              height: 4,
            ),

            Text(
              location,
              style:
                  const TextStyle(
                color:
                    Colors.white38,
                fontSize:
                    13,
              ),
            ),
          ],

          if (clanName.isNotEmpty) ...[
            const SizedBox(
              height: 16,
            ),

            Container(
              width:
                  double.infinity,

              padding:
                  const EdgeInsets.symmetric(
                horizontal:
                    14,
                vertical:
                    12,
              ),

              decoration:
                  BoxDecoration(
                color:
                    Colors.white.withValues(
                  alpha: 0.06,
                ),

                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),

              child: Row(
                children: [
                  const Icon(
                    Icons
                        .groups_2_outlined,
                    color:
                        Colors.white54,
                    size:
                        20,
                  ),

                  const SizedBox(
                    width:
                        10,
                  ),

                  Expanded(
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [
                        const Text(
                          'FORMATION',
                          style:
                              TextStyle(
                            color:
                                Colors.white38,
                            fontSize:
                                10,
                            letterSpacing:
                                1.4,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height:
                              3,
                        ),

                        Text(
                          clanName,
                          style:
                              const TextStyle(
                            color:
                                Colors.white,
                            fontSize:
                                15,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==============================
  // BUILD
  // ==============================

  @override
  Widget build(
    BuildContext context,
  ) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor:
            Colors.black,
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (profile == null ||
        errorMessage != null) {
      return Scaffold(
        backgroundColor:
            Colors.black,

        appBar: AppBar(
          backgroundColor:
              Colors.black,
        ),

        body: Center(
          child: Text(
            errorMessage ??
                'Profil introuvable.',
            style:
                const TextStyle(
              color:
                  Colors.white,
            ),
          ),
        ),
      );
    }

    final username =
        profile!['username']
                as String? ??
            'Utilisateur';

    final calculatedAge =
        calculateAgeFromBirthDate(
      profile!['birth_date'],
    );

    final oldAge =
        (profile!['age'] as num?)
            ?.toInt();

    final age =
        calculatedAge ?? oldAge;

    final bio =
        profile!['bio']
                as String? ??
            '';

    final elo =
        (profile!['elo']
                    as num?)
                ?.toInt() ??
            1500;

    final league =
        profile!['league']
                as String? ??
            'Non classé';

    final photoUrls =
        <String>[
      if (profile![
                  'photo_1_url']
              is String &&
          (profile![
                      'photo_1_url']
                  as String)
              .isNotEmpty)
        profile![
                'photo_1_url']
            as String,

      if (profile![
                  'photo_2_url']
              is String &&
          (profile![
                      'photo_2_url']
                  as String)
              .isNotEmpty)
        profile![
                'photo_2_url']
            as String,

      if (profile![
                  'photo_3_url']
              is String &&
          (profile![
                      'photo_3_url']
                  as String)
              .isNotEmpty)
        profile![
                'photo_3_url']
            as String,
    ];

    final currentUser =
        supabase.auth.currentUser;

    final isOwnProfile =
        currentUser?.id ==
            widget.userId;

    return Scaffold(
      backgroundColor:
          Colors.black,

      appBar: AppBar(
        backgroundColor:
            Colors.black,
        foregroundColor:
            Colors.white,

        actions: [
          if (!isOwnProfile)
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
              ),

              color:
                  const Color(
                0xFF181818,
              ),

              onSelected: (value) {
                if (value ==
                    'report') {
                  openReportDialog();
                }

                if (value ==
                    'block') {
                  confirmBlockUser();
                }
              },

              itemBuilder:
                  (context) => [
                const PopupMenuItem<String>(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(
                        Icons
                            .flag_outlined,
                        color:
                            Colors.white70,
                      ),
                      SizedBox(
                        width: 12,
                      ),
                      Text(
                        'Signaler',
                        style:
                            TextStyle(
                          color:
                              Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                if (!isBlocked)
                  const PopupMenuItem<String>(
                    value: 'block',
                    child: Row(
                      children: [
                        Icon(
                          Icons.block,
                          color:
                              Colors.redAccent,
                        ),
                        SizedBox(
                          width: 12,
                        ),
                        Text(
                          'Bloquer',
                          style:
                              TextStyle(
                            color:
                                Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh:
            loadEverything,

        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),

          padding:
              const EdgeInsets.all(
            24,
          ),

          children: [
            Center(
              child: SizedBox(
                height: 420,

                child:
                    photoUrls.isEmpty
                        ? Container(
                            decoration:
                                BoxDecoration(
                              color:
                                  Colors.white10,
                              borderRadius:
                                  BorderRadius.circular(
                                24,
                              ),
                            ),
                            child:
                                const Center(
                              child:
                                  Icon(
                                Icons.person,
                                size: 90,
                                color:
                                    Colors.white38,
                              ),
                            ),
                          )
                        : PageView.builder(
                            itemCount:
                                photoUrls.length,

                            itemBuilder:
                                (
                              context,
                              index,
                            ) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(
                                  horizontal:
                                      4,
                                ),

                                child:
                                    ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(
                                    24,
                                  ),

                                  child:
                                      Image.network(
                                    photoUrls[index],
                                    width:
                                        double.infinity,
                                    fit:
                                        BoxFit.cover,

                                    errorBuilder:
                                        (
                                      context,
                                      error,
                                      stackTrace,
                                    ) {
                                      return Container(
                                        color:
                                            Colors.white10,
                                        child:
                                            const Center(
                                          child:
                                              Icon(
                                            Icons.person,
                                            size:
                                                90,
                                            color:
                                                Colors.white38,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ),

            const SizedBox(
              height: 22,
            ),

            Text(
              '@$username',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    Colors.white,
                fontSize: 28,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            if (age != null) ...[
              const SizedBox(
                height: 6,
              ),

              Text(
                '$age ans',
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color:
                      Colors.white54,
                ),
              ),
            ],

            if (bio.isNotEmpty) ...[
              const SizedBox(
                height: 20,
              ),

              Text(
                bio,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color:
                      Colors.white70,
                  fontSize:
                      16,
                ),
              ),
            ],

            const SizedBox(
              height: 24,
            ),

            buildFriendSection(),

            // ============================
            // CAMPUS + FORMATION
            // ============================

            if (profile?['campuses'] !=
                null) ...[
              const SizedBox(
                height: 30,
              ),

              buildCampusSection(),
            ],

            const SizedBox(
              height: 30,
            ),

            // ============================
            // LIGUE + ELO
            // ============================

            Container(
              padding:
                  const EdgeInsets.all(
                20,
              ),

              decoration:
                  BoxDecoration(
                color:
                    Colors.white10,

                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),

              child: Column(
                children: [
                  Text(
                    league,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontSize:
                          21,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    '$elo Elo',
                    style:
                        const TextStyle(
                      color:
                          Colors.white70,
                      fontSize:
                          18,
                    ),
                  ),
                ],
              ),
            ),

            if (isReportLoading) ...[
              const SizedBox(
                height: 24,
              ),

              const Center(
                child:
                    CircularProgressIndicator(),
              ),
            ],

            const SizedBox(
              height: 30,
            ),
          ],
        ),
      ),
    );
  }
}