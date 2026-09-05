import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUsername;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUsername,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  final TextEditingController messageController =
      TextEditingController();

  final ScrollController scrollController =
      ScrollController();

  List<Map<String, dynamic>> messages = [];

  bool isLoading = true;
  bool isSending = false;
  bool isFriend = true;
  bool isBlocked = false;

  String? errorMessage;

  RealtimeChannel? channel;

  String get currentUserId {
    return supabase.auth.currentUser!.id;
  }

  @override
  void initState() {
    super.initState();
    initializeChat();
  }

  Future<void> initializeChat() async {
    await loadMessages();
    await markMessagesAsRead();
    await checkFriendship();
    await checkBlockStatus();

    subscribeToMessages();
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();

    if (channel != null) {
      supabase.removeChannel(channel!);
    }

    super.dispose();
  }

  // ==============================
  // CHARGER LES MESSAGES
  // ==============================

  Future<void> loadMessages() async {
    try {
      final response = await supabase
          .from('messages')
          .select()
          .or(
            'and(sender_id.eq.$currentUserId,receiver_id.eq.${widget.otherUserId}),'
            'and(sender_id.eq.${widget.otherUserId},receiver_id.eq.$currentUserId)',
          )
          .order(
            'created_at',
            ascending: true,
          );

      if (!mounted) return;

      setState(() {
        messages =
            List<Map<String, dynamic>>.from(response);

        isLoading = false;
        errorMessage = null;
      });

      scrollToBottom();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
            'Impossible de charger les messages.';
      });
    }
  }

  // ==============================
  // VÉRIFIER L'AMITIÉ
  // ==============================

  Future<void> checkFriendship() async {
    try {
      final response = await supabase
          .from('friend_requests')
          .select('id')
          .eq(
            'status',
            'accepted',
          )
          .or(
            'and(sender_id.eq.$currentUserId,receiver_id.eq.${widget.otherUserId}),'
            'and(sender_id.eq.${widget.otherUserId},receiver_id.eq.$currentUserId)',
          )
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        isFriend = response != null;
      });
    } catch (error) {
      debugPrint(
        'Impossible de vérifier l’amitié : $error',
      );
    }
  }

  // ==============================
  // VÉRIFIER LE BLOCAGE
  // ==============================

  Future<void> checkBlockStatus() async {
    try {
      final response = await supabase
          .from('blocks')
          .select('id')
          .eq(
            'blocker_id',
            currentUserId,
          )
          .eq(
            'blocked_id',
            widget.otherUserId,
          )
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        isBlocked = response != null;
      });
    } catch (error) {
      debugPrint(
        'Impossible de vérifier le blocage : $error',
      );
    }
  }

  // ==============================
  // MARQUER LES MESSAGES COMME LUS
  // ==============================

  Future<void> markMessagesAsRead() async {
    try {
      await supabase
          .from('messages')
          .update({
            'read_at':
                DateTime.now().toUtc().toIso8601String(),
          })
          .eq(
            'sender_id',
            widget.otherUserId,
          )
          .eq(
            'receiver_id',
            currentUserId,
          )
          .isFilter(
            'read_at',
            null,
          );
    } catch (error) {
      debugPrint(
        'Impossible de marquer les messages comme lus : $error',
      );
    }
  }

  // ==============================
  // TEMPS RÉEL
  // ==============================

  void subscribeToMessages() {
    channel = supabase
        .channel(
          'chat_${currentUserId}_${widget.otherUserId}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            final newMessage =
                Map<String, dynamic>.from(
              payload.newRecord,
            );

            final senderId =
                newMessage['sender_id'];

            final receiverId =
                newMessage['receiver_id'];

            final belongsToConversation =
                (senderId == currentUserId &&
                        receiverId ==
                            widget.otherUserId) ||
                    (senderId ==
                            widget.otherUserId &&
                        receiverId ==
                            currentUserId);

            if (!belongsToConversation) {
              return;
            }

            if (!mounted) return;

            final messageId =
                newMessage['id'];

            final alreadyExists = messages.any(
              (message) =>
                  message['id'] == messageId,
            );

            if (!alreadyExists) {
              setState(() {
                messages.add(newMessage);
              });
            }

            if (senderId == widget.otherUserId &&
                receiverId == currentUserId) {
              await markMessagesAsRead();
            }

            scrollToBottom();
          },
        )
        .subscribe();
  }

  // ==============================
  // ENVOYER UN MESSAGE
  // ==============================

  Future<void> sendMessage() async {
    final content =
        messageController.text.trim();

    if (content.isEmpty ||
        isSending ||
        !isFriend ||
        isBlocked) {
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      final response = await supabase
          .from('messages')
          .insert({
            'sender_id': currentUserId,
            'receiver_id': widget.otherUserId,
            'content': content,
            'read_at': null,
          })
          .select()
          .single();

      messageController.clear();

      final insertedMessage =
          Map<String, dynamic>.from(response);

      if (!mounted) return;

      final alreadyExists = messages.any(
        (message) =>
            message['id'] ==
            insertedMessage['id'],
      );

      if (!alreadyExists) {
        setState(() {
          messages.add(
            insertedMessage,
          );
        });
      }

      scrollToBottom();
    } on PostgrestException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Message impossible : ${error.message}',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible d’envoyer le message.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  // ==============================
  // SUPPRIMER L'AMI
  // ==============================

  Future<void> removeFriend() async {
    try {
      await supabase
          .from('friend_requests')
          .delete()
          .eq(
            'status',
            'accepted',
          )
          .or(
            'and(sender_id.eq.$currentUserId,receiver_id.eq.${widget.otherUserId}),'
            'and(sender_id.eq.${widget.otherUserId},receiver_id.eq.$currentUserId)',
          );

      if (!mounted) return;

      setState(() {
        isFriend = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '@${widget.otherUsername} a été supprimé de tes amis.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible de supprimer cet ami.',
          ),
        ),
      );
    }
  }

  // ==============================
  // CONFIRMER SUPPRESSION AMI
  // ==============================

  Future<void> confirmRemoveFriend() async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor:
              const Color(0xFF181818),

          title: const Text(
            'Supprimer cet ami ?',
            style: TextStyle(
              color: Colors.white,
            ),
          ),

          content: Text(
            'Tu ne pourras plus envoyer de messages à '
            '@${widget.otherUsername} tant que vous ne serez pas de nouveau amis.',
            style: const TextStyle(
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
                'Supprimer',
                style: TextStyle(
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await removeFriend();
    }
  }

  // ==============================
  // BLOQUER
  // ==============================

  Future<void> blockUser() async {
    try {
      // Création du blocage.
      await supabase
          .from('blocks')
          .insert({
        'blocker_id': currentUserId,
        'blocked_id': widget.otherUserId,
      });

      // Suppression de toute relation d'amitié
      // ou demande existante entre les deux comptes.
      await supabase
          .from('friend_requests')
          .delete()
          .or(
            'and(sender_id.eq.$currentUserId,receiver_id.eq.${widget.otherUserId}),'
            'and(sender_id.eq.${widget.otherUserId},receiver_id.eq.$currentUserId)',
          );

      if (!mounted) return;

      setState(() {
        isFriend = false;
        isBlocked = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '@${widget.otherUsername} a été bloqué.',
          ),
        ),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;

      if (error.code == '23505') {
        setState(() {
          isBlocked = true;
          isFriend = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cet utilisateur est déjà bloqué.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Impossible de bloquer : ${error.message}',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible de bloquer cet utilisateur.',
          ),
        ),
      );
    }
  }

  // ==============================
  // CONFIRMER LE BLOCAGE
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
            'Bloquer @${widget.otherUsername} ?',
            style: const TextStyle(
              color: Colors.white,
            ),
          ),

          content: const Text(
            'Vous ne pourrez plus vous envoyer de messages '
            'ni de demandes d’amitié.',
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
                  color: Colors.redAccent,
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
    try {
      await supabase
          .from('blocks')
          .delete()
          .eq(
            'blocker_id',
            currentUserId,
          )
          .eq(
            'blocked_id',
            widget.otherUserId,
          );

      if (!mounted) return;

      setState(() {
        isBlocked = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '@${widget.otherUsername} a été débloqué.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible de débloquer cet utilisateur.',
          ),
        ),
      );
    }
  }

  // ==============================
  // SUPPRESSION CONVERSATION
  // PAS ENCORE ACTIVÉE
  // ==============================

  void comingSoon(
    String action,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$action sera disponible prochainement.',
        ),
      ),
    );
  }

  // ==============================
  // MENU ⋮
  // ==============================

  void showChatMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          const Color(0xFF181818),

      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),

      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(
              vertical: 10,
            ),

            child: Column(
              mainAxisSize:
                  MainAxisSize.min,

              children: [
                ListTile(
                  leading:
                      const Icon(
                    Icons.delete_outline,
                    color: Colors.white,
                  ),

                  title:
                      const Text(
                    'Supprimer la conversation',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),

                  onTap: () {
                    Navigator.pop(
                      context,
                    );

                    comingSoon(
                      'La suppression de conversation',
                    );
                  },
                ),

                if (isFriend)
                  ListTile(
                    leading:
                        const Icon(
                      Icons.person_remove_outlined,
                      color:
                          Colors.redAccent,
                    ),

                    title:
                        const Text(
                      'Supprimer des amis',
                      style: TextStyle(
                        color:
                            Colors.redAccent,
                      ),
                    ),

                    onTap: () {
                      Navigator.pop(
                        context,
                      );

                      confirmRemoveFriend();
                    },
                  ),

                if (!isBlocked)
                  ListTile(
                    leading:
                        const Icon(
                      Icons.block,
                      color:
                          Colors.redAccent,
                    ),

                    title:
                        const Text(
                      'Bloquer',
                      style: TextStyle(
                        color:
                            Colors.redAccent,
                      ),
                    ),

                    onTap: () {
                      Navigator.pop(
                        context,
                      );

                      confirmBlockUser();
                    },
                  ),

                if (isBlocked)
                  ListTile(
                    leading:
                        const Icon(
                      Icons.lock_open,
                      color: Colors.white,
                    ),

                    title:
                        const Text(
                      'Débloquer',
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),

                    onTap: () {
                      Navigator.pop(
                        context,
                      );

                      unblockUser();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==============================
  // SCROLL AUTOMATIQUE
  // ==============================

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!scrollController.hasClients) {
          return;
        }

        scrollController.animateTo(
          scrollController
              .position.maxScrollExtent,

          duration:
              const Duration(
            milliseconds: 250,
          ),

          curve:
              Curves.easeOut,
        );
      },
    );
  }

  // ==============================
  // BULLE MESSAGE
  // ==============================

  Widget buildMessage(
    Map<String, dynamic> message,
  ) {
    final isMine =
        message['sender_id'] ==
            currentUserId;

    final content =
        message['content']
                as String? ??
            '';

    return Align(
      alignment: isMine
          ? Alignment.centerRight
          : Alignment.centerLeft,

      child: Container(
        constraints:
            const BoxConstraints(
          maxWidth: 300,
        ),

        margin:
            const EdgeInsets.symmetric(
          vertical: 4,
          horizontal: 12,
        ),

        padding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 11,
        ),

        decoration:
            BoxDecoration(
          color: isMine
              ? Colors.white
              : Colors.white12,

          borderRadius:
              BorderRadius.circular(
            18,
          ),
        ),

        child: Text(
          content,

          style:
              TextStyle(
            color: isMine
                ? Colors.black
                : Colors.white,

            fontSize: 16,
          ),
        ),
      ),
    );
  }

  // ==============================
  // CHAMP MESSAGE
  // ==============================

  Widget buildMessageInput() {
    if (isBlocked) {
      return SafeArea(
        top: false,

        child: Container(
          width: double.infinity,

          padding:
              const EdgeInsets.all(
            18,
          ),

          decoration:
              const BoxDecoration(
            color: Colors.black,

            border: Border(
              top: BorderSide(
                color:
                    Colors.white12,
              ),
            ),
          ),

          child: const Text(
            'Tu as bloqué cet utilisateur.',
            textAlign:
                TextAlign.center,

            style:
                TextStyle(
              color:
                  Colors.white54,
            ),
          ),
        ),
      );
    }

    if (!isFriend) {
      return SafeArea(
        top: false,

        child: Container(
          width: double.infinity,

          padding:
              const EdgeInsets.all(
            18,
          ),

          decoration:
              const BoxDecoration(
            color: Colors.black,

            border: Border(
              top: BorderSide(
                color:
                    Colors.white12,
              ),
            ),
          ),

          child: const Text(
            'Vous n’êtes plus amis.',
            textAlign:
                TextAlign.center,

            style:
                TextStyle(
              color:
                  Colors.white54,
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,

      child: Container(
        padding:
            const EdgeInsets.fromLTRB(
          12,
          8,
          12,
          10,
        ),

        decoration:
            const BoxDecoration(
          color: Colors.black,

          border: Border(
            top: BorderSide(
              color:
                  Colors.white12,
            ),
          ),
        ),

        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.end,

          children: [
            Expanded(
              child:
                  TextField(
                controller:
                    messageController,

                style:
                    const TextStyle(
                  color:
                      Colors.white,
                ),

                minLines: 1,
                maxLines: 5,
                maxLength: 2000,

                textCapitalization:
                    TextCapitalization
                        .sentences,

                decoration:
                    InputDecoration(
                  hintText:
                      'Message...',

                  hintStyle:
                      const TextStyle(
                    color:
                        Colors.white38,
                  ),

                  counterText: '',

                  filled: true,

                  fillColor:
                      Colors.white10,

                  contentPadding:
                      const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),

                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      24,
                    ),
                    borderSide:
                        BorderSide.none,
                  ),

                  enabledBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      24,
                    ),
                    borderSide:
                        BorderSide.none,
                  ),

                  focusedBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      24,
                    ),

                    borderSide:
                        const BorderSide(
                      color:
                          Colors.white24,
                    ),
                  ),
                ),

                onSubmitted: (_) {
                  sendMessage();
                },
              ),
            ),

            const SizedBox(
              width: 8,
            ),

            SizedBox(
              width: 48,
              height: 48,

              child:
                  IconButton(
                onPressed:
                    isSending
                        ? null
                        : sendMessage,

                style:
                    IconButton.styleFrom(
                  backgroundColor:
                      Colors.white,

                  foregroundColor:
                      Colors.black,
                ),

                icon: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,

                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color:
                              Colors.black,
                        ),
                      )
                    : const Icon(
                        Icons.arrow_upward,
                      ),
              ),
            ),
          ],
        ),
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
    return Scaffold(
      backgroundColor:
          Colors.black,

      appBar: AppBar(
        backgroundColor:
            Colors.black,

        foregroundColor:
            Colors.white,

        title: Text(
          '@${widget.otherUsername}',

          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),

        actions: [
          IconButton(
            onPressed:
                showChatMenu,

            icon:
                const Icon(
              Icons.more_vert,
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(),
                  )
                : errorMessage != null
                    ? Center(
                        child:
                            Text(
                          errorMessage!,

                          style:
                              const TextStyle(
                            color:
                                Colors.white70,
                          ),
                        ),
                      )
                    : messages.isEmpty
                        ? Center(
                            child:
                                Column(
                              mainAxisSize:
                                  MainAxisSize.min,

                              children: [
                                const Icon(
                                  Icons
                                      .chat_bubble_outline,
                                  size: 42,
                                  color:
                                      Colors.white24,
                                ),

                                const SizedBox(
                                  height: 14,
                                ),

                                Text(
                                  'Commence la conversation avec\n@${widget.otherUsername}',

                                  textAlign:
                                      TextAlign.center,

                                  style:
                                      const TextStyle(
                                    color:
                                        Colors.white54,
                                    fontSize:
                                        16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller:
                                scrollController,

                            padding:
                                const EdgeInsets.symmetric(
                              vertical: 12,
                            ),

                            itemCount:
                                messages.length,

                            itemBuilder:
                                (
                              context,
                              index,
                            ) {
                              return buildMessage(
                                messages[index],
                              );
                            },
                          ),
          ),

          buildMessageInput(),
        ],
      ),
    );
  }
}