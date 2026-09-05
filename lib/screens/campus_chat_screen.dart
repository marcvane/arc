import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/campus_chat_service.dart';

class CampusChatScreen extends StatefulWidget {
  final String campusId;
  final String campusName;

  const CampusChatScreen({
    super.key,
    required this.campusId,
    required this.campusName,
  });

  @override
  State<CampusChatScreen> createState() =>
      _CampusChatScreenState();
}

class _CampusChatScreenState
    extends State<CampusChatScreen> {
  final TextEditingController messageController =
      TextEditingController();

  final ScrollController scrollController =
      ScrollController();

  List<Map<String, dynamic>> messages = [];

  bool isLoading = true;
  bool isSending = false;

  String? errorMessage;

  RealtimeChannel? realtimeChannel;

  String? get currentUserId =>
      CampusChatService.currentUserId;

  @override
  void initState() {
    super.initState();

    loadMessages();
    startRealtime();
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();

    if (realtimeChannel != null) {
      Supabase.instance.client.removeChannel(
        realtimeChannel!,
      );
    }

    super.dispose();
  }

  // ============================================
  // CHARGER LES MESSAGES
  // ============================================

  Future<void> loadMessages({
    bool showLoader = true,
  }) async {
    if (showLoader && mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final result =
          await CampusChatService.getMessages(
        campusId: widget.campusId,
      );

      if (!mounted) return;

      setState(() {
        messages = result;
        isLoading = false;
        errorMessage = null;
      });

      scrollToBottom();
    } catch (error) {
      debugPrint(
        'Erreur chargement chat Campus : $error',
      );

      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
            'Impossible de charger le chat.';
      });
    }
  }

  // ============================================
  // REALTIME
  // ============================================

  void startRealtime() {
    realtimeChannel =
        Supabase.instance.client
            .channel(
      'campus_chat_${widget.campusId}',
    )
            .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'campus_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'campus_id',
        value: widget.campusId,
      ),
      callback: (payload) {
        loadMessages(
          showLoader: false,
        );
      },
    ).subscribe();
  }

  // ============================================
  // ENVOYER
  // ============================================

  Future<void> sendMessage() async {
    if (isSending) return;

    final content =
        messageController.text.trim();

    if (content.isEmpty) {
      return;
    }

    if (content.length > 500) {
      showMessage(
        'Ton message ne peut pas dépasser 500 caractères.',
      );

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      isSending = true;
    });

    try {
      await CampusChatService.sendMessage(
        campusId: widget.campusId,
        content: content,
      );

      messageController.clear();

      if (!mounted) return;

      setState(() {
        isSending = false;
      });

      await loadMessages(
        showLoader: false,
      );
    } catch (error) {
      debugPrint(
        'Erreur envoi message : $error',
      );

      if (!mounted) return;

      setState(() {
        isSending = false;
      });

      showMessage(
        'Impossible d’envoyer le message.',
      );
    }
  }

  // ============================================
  // SUPPRIMER
  // ============================================

  Future<void> deleteMessage(
    Map<String, dynamic> message,
  ) async {
    final messageId =
        message['id']?.toString();

    if (messageId == null) {
      return;
    }

    final confirmed =
        await showModalBottomSheet<bool>(
      context: context,
      backgroundColor:
          const Color(0xFF181818),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.all(20),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration:
                      BoxDecoration(
                    color: Colors.white24,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Supprimer le message',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(
                      context,
                      true,
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(
                    Icons.close,
                    color: Colors.white70,
                  ),
                  title: const Text(
                    'Annuler',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(
                      context,
                      false,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await CampusChatService.deleteMessage(
        messageId,
      );

      await loadMessages(
        showLoader: false,
      );
    } catch (error) {
      debugPrint(
        'Erreur suppression message : $error',
      );

      showMessage(
        'Impossible de supprimer ce message.',
      );
    }
  }

  // ============================================
  // SCROLL
  // ============================================

  void scrollToBottom() {
    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!scrollController.hasClients) {
          return;
        }

        scrollController.animateTo(
          scrollController
              .position
              .maxScrollExtent,
          duration:
              const Duration(
            milliseconds: 250,
          ),
          curve: Curves.easeOut,
        );
      },
    );
  }

  // ============================================
  // MESSAGE UI
  // ============================================

  void showMessage(
    String text,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(text),
      ),
    );
  }

  // ============================================
  // DATE / HEURE
  // ============================================

  String formatTime(
    dynamic rawDate,
  ) {
    if (rawDate == null) {
      return '';
    }

    try {
      final date =
          DateTime.parse(
        rawDate.toString(),
      ).toLocal();

      final now =
          DateTime.now();

      final sameDay =
          date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;

      final hour =
          date.hour
              .toString()
              .padLeft(2, '0');

      final minute =
          date.minute
              .toString()
              .padLeft(2, '0');

      if (sameDay) {
        return '$hour:$minute';
      }

      final day =
          date.day
              .toString()
              .padLeft(2, '0');

      final month =
          date.month
              .toString()
              .padLeft(2, '0');

      return '$day/$month • $hour:$minute';
    } catch (_) {
      return '';
    }
  }

  // ============================================
  // BUILD
  // ============================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,

        // Empêche Material 3 de modifier la couleur
        // de l'AppBar lorsque le contenu défile.
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,

        titleSpacing: 0,

        title: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              widget.campusName,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const Text(
              'Chat public',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight:
                    FontWeight.normal,
              ),
            ),
          ],
        ),
      ),

      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(),

            Expanded(
              child:
                  _buildMessagesArea(),
            ),

            _buildComposer(),
          ],
        ),
      ),
    );
  }

  // ============================================
  // HEADER
  // ============================================

  Widget _buildHeader() {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 12,
      ),

      decoration:
          const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white12,
          ),
        ),
      ),

      child: const Row(
        children: [
          Icon(
            Icons.public,
            color: Colors.white38,
            size: 16,
          ),

          SizedBox(width: 8),

          Expanded(
            child: Text(
              'Tous les membres de ton campus '
              'peuvent participer.',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // ZONE MESSAGES
  // ============================================

  Widget _buildMessagesArea() {
    if (isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.forum_outlined,
                color: Colors.white24,
                size: 50,
              ),

              const SizedBox(height: 16),

              Text(
                errorMessage!,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color: Colors.white54,
                ),
              ),

              const SizedBox(height: 18),

              OutlinedButton(
                onPressed:
                    loadMessages,
                child:
                    const Text(
                  'Réessayer',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (messages.isEmpty) {
      return RefreshIndicator(
        onRefresh: () =>
            loadMessages(
          showLoader: false,
        ),
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height:
                  MediaQuery.sizeOf(
                        context,
                      ).height *
                      0.48,

              child: Center(
                child: Padding(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 35,
                  ),
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,

                        decoration:
                            const BoxDecoration(
                          color:
                              Colors.white10,
                          shape:
                              BoxShape.circle,
                        ),

                        child:
                            const Icon(
                          Icons
                              .forum_outlined,
                          color:
                              Colors.white70,
                          size: 32,
                        ),
                      ),

                      const SizedBox(
                        height: 18,
                      ),

                      const Text(
                        'Le chat est vide',
                        style:
                            TextStyle(
                          color:
                              Colors.white,
                          fontSize: 20,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      const Text(
                        'Sois le premier à parler '
                        'sur ton campus.',
                        textAlign:
                            TextAlign.center,
                        style:
                            TextStyle(
                          color:
                              Colors.white38,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          loadMessages(
        showLoader: false,
      ),

      child: ListView.builder(
        controller:
            scrollController,

        physics:
            const AlwaysScrollableScrollPhysics(),

        padding:
            const EdgeInsets.fromLTRB(
          14,
          18,
          14,
          18,
        ),

        itemCount:
            messages.length,

        itemBuilder:
            (context, index) {
          return _buildMessage(
            messages[index],
          );
        },
      ),
    );
  }

  // ============================================
  // UN MESSAGE
  // ============================================

  Widget _buildMessage(
    Map<String, dynamic> message,
  ) {
    final userId =
        message['user_id']
            ?.toString();

    final isMine =
        userId != null &&
            userId ==
                currentUserId;

    final profileRaw =
        message['profiles'];

    final profile =
        profileRaw is Map
            ? Map<String, dynamic>.from(
                profileRaw,
              )
            : <String, dynamic>{};

    final username =
        profile['username']
                ?.toString() ??
            'Utilisateur';

    final photo =
        profile['photo_1_url']
            ?.toString();

    final content =
        message['content']
                ?.toString() ??
            '';

    final time =
        formatTime(
      message['created_at'],
    );

    return GestureDetector(
      onLongPress: isMine
          ? () {
              deleteMessage(
                message,
              );
            }
          : null,

      child: Padding(
        padding:
            const EdgeInsets.only(
          bottom: 15,
        ),

        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor:
                  Colors.white12,

              backgroundImage:
                  photo != null &&
                          photo.isNotEmpty
                      ? NetworkImage(
                          photo,
                        )
                      : null,

              child:
                  photo == null ||
                          photo.isEmpty
                      ? const Icon(
                          Icons.person,
                          color:
                              Colors.white38,
                          size: 20,
                        )
                      : null,
            ),

            const SizedBox(width: 11),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '@$username',
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,

                          style:
                              const TextStyle(
                            color:
                                Colors.white,
                            fontSize: 13,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ),

                      if (isMine) ...[
                        const SizedBox(
                          width: 6,
                        ),

                        const Text(
                          'toi',
                          style:
                              TextStyle(
                            color:
                                Colors.white30,
                            fontSize: 10,
                          ),
                        ),
                      ],

                      const SizedBox(
                        width: 8,
                      ),

                      Text(
                        time,
                        style:
                            const TextStyle(
                          color:
                              Colors.white24,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 5,
                  ),

                  Text(
                    content,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // CHAMP DE SAISIE
  // ============================================

  Widget _buildComposer() {
    return Container(
      padding:
          EdgeInsets.fromLTRB(
        12,
        9,
        12,
        9 +
            MediaQuery.paddingOf(
              context,
            ).bottom,
      ),

      decoration:
          const BoxDecoration(
        color: Colors.black,

        border: Border(
          top: BorderSide(
            color: Colors.white12,
          ),
        ),
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.end,

        children: [
          Expanded(
            child: Container(
              constraints:
                  const BoxConstraints(
                minHeight: 46,
                maxHeight: 120,
              ),

              decoration:
                  BoxDecoration(
                color:
                    Colors.white10,

                borderRadius:
                    BorderRadius.circular(
                  24,
                ),
              ),

              child: TextField(
                controller:
                    messageController,

                minLines: 1,
                maxLines: 4,

                maxLength: 500,

                textCapitalization:
                    TextCapitalization
                        .sentences,

                style:
                    const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),

                decoration:
                    const InputDecoration(
                  hintText:
                      'Écris un message…',

                  hintStyle:
                      TextStyle(
                    color:
                        Colors.white30,
                  ),

                  border:
                      InputBorder.none,

                  counterText: '',

                  contentPadding:
                      EdgeInsets.symmetric(
                    horizontal: 17,
                    vertical: 13,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          SizedBox(
            width: 46,
            height: 46,

            child: Material(
              color: Colors.white,
              shape:
                  const CircleBorder(),

              child: InkWell(
                customBorder:
                    const CircleBorder(),

                onTap: isSending
                    ? null
                    : sendMessage,

                child: Center(
                  child: isSending
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
                          Icons
                              .arrow_upward_rounded,
                          color:
                              Colors.black,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}