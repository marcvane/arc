import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'public_profile_screen.dart';
import 'chat_screen.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool isLoading = true;
  String? errorMessage;

  List<Map<String, dynamic>> receivedRequests = [];
  List<Map<String, dynamic>> friends = [];
  List<Map<String, dynamic>> conversations = [];

  Map<String, int> unreadMessagesByUser = {};

  @override
  void initState() {
    super.initState();
    loadSocialData();
  }

  // ==============================
  // CHARGEMENT SOCIAL
  // ==============================

  Future<void> loadSocialData() async {
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Utilisateur non connecté.';
      });

      return;
    }

    try {
      // ==============================
      // DEMANDES REÇUES
      // ==============================

      final requestRows = await supabase
          .from('friend_requests')
          .select()
          .eq('receiver_id', currentUser.id)
          .eq('status', 'pending')
          .order(
            'created_at',
            ascending: false,
          );

      // ==============================
      // AMITIÉS
      // ==============================

      final acceptedRows = await supabase
          .from('friend_requests')
          .select()
          .eq('status', 'accepted')
          .or(
            'sender_id.eq.${currentUser.id},receiver_id.eq.${currentUser.id}',
          )
          .order(
            'created_at',
            ascending: false,
          );

      // ==============================
      // TOUS MES MESSAGES
      // ==============================

      final messageRows = await supabase
          .from('messages')
          .select(
            'id, sender_id, receiver_id, content, created_at, read_at',
          )
          .or(
            'sender_id.eq.${currentUser.id},receiver_id.eq.${currentUser.id}',
          )
          .order(
            'created_at',
            ascending: false,
          );

      final requests =
          List<Map<String, dynamic>>.from(requestRows);

      final accepted =
          List<Map<String, dynamic>>.from(acceptedRows);

      final allMessages =
          List<Map<String, dynamic>>.from(messageRows);

      // ==============================
      // NON-LUS
      // ==============================

      final Map<String, int> unreadCounts = {};

      for (final message in allMessages) {
        final senderId =
            message['sender_id'] as String?;

        final receiverId =
            message['receiver_id'] as String?;

        final readAt = message['read_at'];

        if (senderId != null &&
            receiverId == currentUser.id &&
            readAt == null) {
          unreadCounts[senderId] =
              (unreadCounts[senderId] ?? 0) + 1;
        }
      }

      // ==============================
      // IDS DES PROFILS
      // ==============================

      final profileIds = <String>{};

      for (final request in requests) {
        final senderId =
            request['sender_id'] as String?;

        if (senderId != null) {
          profileIds.add(senderId);
        }
      }

      for (final friendship in accepted) {
        final senderId =
            friendship['sender_id'] as String?;

        final receiverId =
            friendship['receiver_id'] as String?;

        if (senderId != null &&
            senderId != currentUser.id) {
          profileIds.add(senderId);
        }

        if (receiverId != null &&
            receiverId != currentUser.id) {
          profileIds.add(receiverId);
        }
      }

      // Ajoute aussi les utilisateurs présents
      // dans les conversations.
      for (final message in allMessages) {
        final senderId =
            message['sender_id'] as String?;

        final receiverId =
            message['receiver_id'] as String?;

        if (senderId != null &&
            senderId != currentUser.id) {
          profileIds.add(senderId);
        }

        if (receiverId != null &&
            receiverId != currentUser.id) {
          profileIds.add(receiverId);
        }
      }

      // ==============================
      // PROFILS
      // ==============================

      final Map<String, Map<String, dynamic>>
          profilesById = {};

      if (profileIds.isNotEmpty) {
        final profileRows = await supabase
            .from('profiles')
            .select(
              'id, username, photo_1_url, elo, league',
            )
            .inFilter(
              'id',
              profileIds.toList(),
            );

        for (final row in profileRows) {
          final profile =
              Map<String, dynamic>.from(row);

          final id =
              profile['id'] as String?;

          if (id != null) {
            profilesById[id] = profile;
          }
        }
      }

      // ==============================
      // CONSTRUCTION DEMANDES
      // ==============================

      final loadedRequests =
          <Map<String, dynamic>>[];

      for (final request in requests) {
        final senderId =
            request['sender_id'] as String?;

        if (senderId == null) continue;

        final senderProfile =
            profilesById[senderId];

        if (senderProfile == null) continue;

        loadedRequests.add({
          'request': request,
          'profile': senderProfile,
        });
      }

      // ==============================
      // CONSTRUCTION AMIS
      // ==============================

      final loadedFriends =
          <Map<String, dynamic>>[];

      for (final friendship in accepted) {
        final senderId =
            friendship['sender_id'] as String?;

        final receiverId =
            friendship['receiver_id'] as String?;

        String? friendId;

        if (senderId == currentUser.id) {
          friendId = receiverId;
        } else if (receiverId == currentUser.id) {
          friendId = senderId;
        }

        if (friendId == null) continue;

        final friendProfile =
            profilesById[friendId];

        if (friendProfile == null) continue;

        loadedFriends.add({
          'friendship': friendship,
          'profile': friendProfile,
        });
      }

      // ==============================
      // CONSTRUCTION CONVERSATIONS
      // ==============================

      final Map<String, Map<String, dynamic>>
          conversationsByUser = {};

      for (final message in allMessages) {
        final senderId =
            message['sender_id'] as String?;

        final receiverId =
            message['receiver_id'] as String?;

        if (senderId == null ||
            receiverId == null) {
          continue;
        }

        String? otherUserId;

        if (senderId == currentUser.id) {
          otherUserId = receiverId;
        } else if (receiverId == currentUser.id) {
          otherUserId = senderId;
        }

        if (otherUserId == null ||
            otherUserId == currentUser.id) {
          continue;
        }

        if (conversationsByUser
            .containsKey(otherUserId)) {
          continue;
        }

        final otherProfile =
            profilesById[otherUserId];

        if (otherProfile == null) {
          continue;
        }

        conversationsByUser[otherUserId] = {
          'profile': otherProfile,
          'lastMessage': message,
        };
      }

      final loadedConversations =
          conversationsByUser.values.toList();

      if (!mounted) return;

      setState(() {
        receivedRequests = loadedRequests;
        friends = loadedFriends;
        conversations = loadedConversations;

        unreadMessagesByUser = unreadCounts;

        isLoading = false;
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;

        errorMessage =
            'Impossible de charger Social : $error';
      });
    }
  }

  // ==============================
  // ACCEPTER DEMANDE
  // ==============================

  Future<void> acceptRequest(
    Map<String, dynamic> request,
  ) async {
    try {
      await supabase
          .from('friend_requests')
          .update({
            'status': 'accepted',
          })
          .eq(
            'id',
            request['id'],
          );

      showMessage('Demande acceptée.');

      await loadSocialData();
    } catch (_) {
      showMessage(
        'Impossible d’accepter la demande.',
      );
    }
  }

  // ==============================
  // REFUSER DEMANDE
  // ==============================

  Future<void> rejectRequest(
    Map<String, dynamic> request,
  ) async {
    try {
      await supabase
          .from('friend_requests')
          .delete()
          .eq(
            'id',
            request['id'],
          );

      showMessage('Demande refusée.');

      await loadSocialData();
    } catch (_) {
      showMessage(
        'Impossible de refuser la demande.',
      );
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ==============================
  // PROFIL
  // ==============================

  void openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(
          userId: userId,
        ),
      ),
    ).then(
      (_) {
        loadSocialData();
      },
    );
  }

  // ==============================
  // CHAT
  // ==============================

  void openChat({
    required String userId,
    required String username,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          otherUserId: userId,
          otherUsername: username,
        ),
      ),
    ).then(
      (_) {
        loadSocialData();
      },
    );
  }

  // ==============================
  // AVATAR
  // ==============================

  Widget buildAvatar(
    Map<String, dynamic> profile,
  ) {
    final photoUrl =
        profile['photo_1_url'] as String?;

    if (photoUrl == null ||
        photoUrl.isEmpty) {
      return const CircleAvatar(
        radius: 27,
        backgroundColor: Colors.white10,
        child: Icon(
          Icons.person,
          color: Colors.white54,
        ),
      );
    }

    return CircleAvatar(
      radius: 27,
      backgroundColor: Colors.white10,
      backgroundImage:
          NetworkImage(photoUrl),
    );
  }

  // ==============================
  // BADGE
  // ==============================

  Widget buildUnreadBadge(int count) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(
        minWidth: 22,
        minHeight: 22,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
      ),
      decoration: const BoxDecoration(
        color: Colors.redAccent,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ==============================
  // BOUTON CHAT
  // ==============================

  Widget buildChatButton({
    required String userId,
    required String username,
  }) {
    final unreadCount =
        unreadMessagesByUser[userId] ?? 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Envoyer un message',
          onPressed: () {
            openChat(
              userId: userId,
              username: username,
            );
          },
          icon: Icon(
            unreadCount > 0
                ? Icons.chat_bubble
                : Icons.chat_bubble_outline,
            color: Colors.white,
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child:
                buildUnreadBadge(unreadCount),
          ),
      ],
    );
  }

  // ==============================
  // DEMANDES
  // ==============================

  Widget buildRequestsTab() {
    if (receivedRequests.isEmpty) {
      return RefreshIndicator(
        onRefresh: loadSocialData,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Center(
              child: Text(
                'Aucune demande d’amitié.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadSocialData,
      child: ListView.separated(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: receivedRequests.length,
        separatorBuilder: (_, _) =>
            const Divider(
          color: Colors.white12,
        ),
        itemBuilder: (context, index) {
          final item =
              receivedRequests[index];

          final request =
              item['request']
                  as Map<String, dynamic>;

          final profile =
              item['profile']
                  as Map<String, dynamic>;

          final username =
              profile['username']
                      as String? ??
                  'Utilisateur';

          final userId =
              profile['id'] as String;

          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: GestureDetector(
              onTap: () {
                openProfile(userId);
              },
              child: buildAvatar(profile),
            ),
            title: GestureDetector(
              onTap: () {
                openProfile(userId);
              },
              child: Text(
                '@$username',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
            subtitle: const Text(
              'veut t’ajouter',
              style: TextStyle(
                color: Colors.white54,
              ),
            ),
            trailing: Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Accepter',
                  onPressed: () {
                    acceptRequest(request);
                  },
                  icon: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  tooltip: 'Refuser',
                  onPressed: () {
                    rejectRequest(request);
                  },
                  icon: const Icon(
                    Icons.cancel_outlined,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==============================
  // MESSAGES
  // ==============================

  Widget buildMessagesTab() {
    if (conversations.isEmpty) {
      return RefreshIndicator(
        onRefresh: loadSocialData,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Center(
              child: Icon(
                Icons.chat_bubble_outline,
                size: 42,
                color: Colors.white24,
              ),
            ),
            SizedBox(height: 14),
            Center(
              child: Text(
                'Aucune conversation.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadSocialData,
      child: ListView.separated(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: conversations.length,
        separatorBuilder: (_, _) =>
            const Divider(
          color: Colors.white12,
        ),
        itemBuilder: (context, index) {
          final conversation =
              conversations[index];

          final profile =
              conversation['profile']
                  as Map<String, dynamic>;

          final lastMessage =
              conversation['lastMessage']
                  as Map<String, dynamic>;

          final userId =
              profile['id'] as String;

          final username =
              profile['username']
                      as String? ??
                  'Utilisateur';

          final content =
              lastMessage['content']
                      as String? ??
                  '';

          final senderId =
              lastMessage['sender_id']
                  as String?;

          final unreadCount =
              unreadMessagesByUser[userId] ??
                  0;

          final isMine =
              senderId ==
                  supabase.auth.currentUser?.id;

          final preview = isMine
              ? 'Vous : $content'
              : content;

          return ListTile(
            contentPadding:
                EdgeInsets.zero,

            onTap: () {
              openChat(
                userId: userId,
                username: username,
              );
            },

            leading:
                buildAvatar(profile),

            title: Text(
              '@$username',
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight:
                    unreadCount > 0
                        ? FontWeight.bold
                        : FontWeight.w600,
              ),
            ),

            subtitle: Text(
              preview,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: TextStyle(
                color: unreadCount > 0
                    ? Colors.white70
                    : Colors.white38,
                fontWeight:
                    unreadCount > 0
                        ? FontWeight.w500
                        : FontWeight.normal,
              ),
            ),

            trailing:
                unreadCount > 0
                    ? buildUnreadBadge(
                        unreadCount,
                      )
                    : const Icon(
                        Icons.chevron_right,
                        color:
                            Colors.white38,
                      ),
          );
        },
      ),
    );
  }

  // ==============================
  // AMIS
  // ==============================

  Widget buildFriendsTab() {
    if (friends.isEmpty) {
      return RefreshIndicator(
        onRefresh: loadSocialData,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Center(
              child: Text(
                'Tu n’as pas encore d’amis.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadSocialData,
      child: ListView.separated(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: friends.length,
        separatorBuilder: (_, _) =>
            const Divider(
          color: Colors.white12,
        ),
        itemBuilder: (context, index) {
          final item = friends[index];

          final profile =
              item['profile']
                  as Map<String, dynamic>;

          final username =
              profile['username']
                      as String? ??
                  'Utilisateur';

          final userId =
              profile['id'] as String;

          final elo =
              (profile['elo'] as num?)
                      ?.toInt() ??
                  1500;

          final league =
              profile['league']
                      as String? ??
                  '';

          final unreadCount =
              unreadMessagesByUser[userId] ??
                  0;

          return ListTile(
            contentPadding:
                EdgeInsets.zero,

            onTap: () {
              openProfile(userId);
            },

            leading:
                buildAvatar(profile),

            title: Row(
              children: [
                Flexible(
                  child: Text(
                    '@$username',
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 7),
                  Container(
                    width: 7,
                    height: 7,
                    decoration:
                        const BoxDecoration(
                      color:
                          Colors.redAccent,
                      shape:
                          BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),

            subtitle: Text(
              league.isNotEmpty
                  ? '$elo Elo · $league'
                  : '$elo Elo',
              style: const TextStyle(
                color: Colors.white54,
              ),
            ),

            trailing:
                buildChatButton(
              userId: userId,
              username: username,
            ),
          );
        },
      ),
    );
  }

  // ==============================
  // BUILD
  // ==============================

  @override
  Widget build(BuildContext context) {
    final totalUnread =
        unreadMessagesByUser.values.fold<int>(
      0,
      (total, count) => total + count,
    );

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.black,

        // ======================================
        // APPBAR
        // Toujours noire, même au scroll
        // ======================================

        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,

          elevation: 0,
          scrolledUnderElevation: 0,

          surfaceTintColor:
              Colors.transparent,
          shadowColor:
              Colors.transparent,

          // ==============================
          // LOGO ARC
          // ==============================

          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/arc_logo.png',
                height: 42,
                fit: BoxFit.contain,
              ),

              if (totalUnread > 0) ...[
                const SizedBox(width: 10),
                buildUnreadBadge(
                  totalUnread,
                ),
              ],
            ],
          ),

          // ==============================
          // ONGLETS SOCIAL
          // ==============================

          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor:
                Colors.white54,

            tabs: [
              Tab(
                text: receivedRequests.isEmpty
                    ? 'Demandes'
                    : 'Demandes (${receivedRequests.length})',
              ),

              Tab(
                text: totalUnread > 0
                    ? 'Messages ($totalUnread)'
                    : 'Messages',
              ),

              Tab(
                text: friends.isEmpty
                    ? 'Amis'
                    : 'Amis (${friends.length})',
              ),
            ],
          ),
        ),

        body: isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(),
              )
            : errorMessage != null
                ? Center(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(
                        24,
                      ),
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Text(
                            errorMessage!,
                            textAlign:
                                TextAlign.center,
                            style:
                                const TextStyle(
                              color:
                                  Colors.white70,
                            ),
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                          ElevatedButton(
                            onPressed:
                                loadSocialData,
                            child: const Text(
                              'Réessayer',
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : TabBarView(
                    children: [
                      buildRequestsTab(),
                      buildMessagesTab(),
                      buildFriendsTab(),
                    ],
                  ),
      ),
    );
  }
}