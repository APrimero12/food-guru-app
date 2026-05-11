// lib/views/messages/dms_page.dart
//
// Full DM inbox — conversation list on the left, chat on the right
// (on narrow screens the two panels swap in/out like a mobile chat app).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:appdevproject/models/user_model.dart';
import 'package:appdevproject/providers/user_provider.dart';
import 'package:appdevproject/services/follow_service.dart';
import 'package:appdevproject/services/message_service.dart';
import 'package:appdevproject/services/user_services.dart';

class DmsPage extends StatefulWidget {
  const DmsPage({super.key});

  @override
  State<DmsPage> createState() => _DmsPageState();
}

class _DmsPageState extends State<DmsPage> {
  final MessageService _messageService = MessageService();
  final FollowService  _followService  = FollowService();
  final UserService    _userService    = UserService();

  // Currently open conversation partner.
  UserModel? _selectedUser;

  // Cache of fetched user profiles (uid → model).
  final Map<String, UserModel> _userCache = {};

  // ── helpers ────────────────────────────────────────────────────────────────

  Future<UserModel?> _fetchUser(String uid) async {
    if (_userCache.containsKey(uid)) return _userCache[uid];
    final user = await _userService.getUser(uid);
    if (user != null) _userCache[uid] = user;
    return user;
  }

  String _relativeTime(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes  <  1) return 'just now';
    if (diff.inMinutes  < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours    < 24) return '${diff.inHours}h ago';
    if (diff.inDays     <  7) return '${diff.inDays}d ago';
    return ts.toDate().toString().substring(0, 10);
  }

  // ── new message sheet ──────────────────────────────────────────────────────

  void _openNewMessageSheet(UserModel currentUser) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NewMessageSheet(
        currentUser:   currentUser,
        followService: _followService,
        onSelect:      (user) => setState(() => _selectedUser = user),
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<UserProvider>(context).currentUser;
    if (currentUser == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.orange));
    }

    final isWide = MediaQuery.of(context).size.width > 700;

    // ── Wide: side-by-side ─────────────────────────────────────────────────
    if (isWide) {
      return Row(
        children: [
          // Left column: conversation list + compose FAB
          SizedBox(
            width: 320,
            child: Stack(
              children: [
                _ConversationList(
                  currentUser:    currentUser,
                  messageService: _messageService,
                  selectedUser:   _selectedUser,
                  fetchUser:      _fetchUser,
                  relativeTime:   _relativeTime,
                  onSelect:       (u) => setState(() => _selectedUser = u),
                ),
                Positioned(
                  right: 12,
                  bottom: 16,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    tooltip: 'New message',
                    onPressed: () => _openNewMessageSheet(currentUser),
                    child: const Icon(Icons.edit_outlined),
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          // Right panel: chat or empty state
          Expanded(
            child: _selectedUser == null
                ? _EmptyChat(onNewMessage: () => _openNewMessageSheet(currentUser))
                : _ChatPanel(
              key:            ValueKey(_selectedUser!.uid),
              currentUser:    currentUser,
              otherUser:      _selectedUser!,
              messageService: _messageService,
              followService:  _followService,
              relativeTime:   _relativeTime,
              onBack:         null,
            ),
          ),
        ],
      );
    }

    // ── Narrow: one panel at a time ────────────────────────────────────────
    if (_selectedUser != null) {
      return _ChatPanel(
        key:            ValueKey(_selectedUser!.uid),
        currentUser:    currentUser,
        otherUser:      _selectedUser!,
        messageService: _messageService,
        followService:  _followService,
        relativeTime:   _relativeTime,
        onBack:         () => setState(() => _selectedUser = null),
      );
    }

    return Stack(
      children: [
        _ConversationList(
          currentUser:    currentUser,
          messageService: _messageService,
          selectedUser:   null,
          fetchUser:      _fetchUser,
          relativeTime:   _relativeTime,
          onSelect:       (u) => setState(() => _selectedUser = u),
        ),
        Positioned(
          right: 16,
          bottom: 20,
          child: FloatingActionButton(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            tooltip: 'New message',
            onPressed: () => _openNewMessageSheet(currentUser),
            child: const Icon(Icons.edit_outlined),
          ),
        ),
      ],
    );
  }
}

// ── Conversation List ─────────────────────────────────────────────────────────

class _ConversationList extends StatelessWidget {
  final UserModel                          currentUser;
  final MessageService                     messageService;
  final UserModel?                         selectedUser;
  final Future<UserModel?> Function(String uid) fetchUser;
  final String             Function(Timestamp? ts) relativeTime;
  final ValueChanged<UserModel>            onSelect;

  const _ConversationList({
    required this.currentUser,
    required this.messageService,
    required this.selectedUser,
    required this.fetchUser,
    required this.relativeTime,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            const Icon(Icons.message_outlined, color: Colors.orange, size: 22),
            const SizedBox(width: 8),
            const Text(
              'Messages',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: messageService.conversationsStream(currentUser.uid),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.orange));
              }

              final docs = snap.data?.docs ?? [];

              if (docs.isEmpty) {
                return _emptyConversations(context);
              }

              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey[200]),
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final participants = List<String>.from(
                      data['participants'] as List<dynamic>? ?? []);
                  final otherUid = participants
                      .firstWhere((id) => id != currentUser.uid, orElse: () => '');
                  if (otherUid.isEmpty) return const SizedBox.shrink();

                  final unread = messageService.unreadCount(data, currentUser.uid);
                  final lastMsg    = data['lastMessage']  as String?  ?? '';
                  final lastSender = data['lastSenderId'] as String?  ?? '';
                  final updatedAt  = data['updatedAt']    as Timestamp?;

                  return FutureBuilder<UserModel?>(
                    future: fetchUser(otherUid),
                    builder: (context, userSnap) {
                      final other = userSnap.data;
                      final name   = other?.name   ?? 'User';
                      final avatar = other?.avatar  ?? '';
                      final uname  = other?.username ?? '';

                      final isSelected = selectedUser?.uid == otherUid;

                      return InkWell(
                        onTap: () {
                          if (other != null) onSelect(other);
                        },
                        child: Container(
                          color: isSelected
                              ? Colors.orange.shade50
                              : Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(children: [
                            // Avatar
                            _Avatar(name: name, avatarUrl: avatar, size: 24),
                            const SizedBox(width: 12),
                            // Text
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: unread > 0
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        relativeTime(updatedAt),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(children: [
                                    Expanded(
                                      child: Text(
                                        '${lastSender == currentUser.uid ? 'You: ' : ''}$lastMsg',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: unread > 0
                                              ? Colors.black87
                                              : Colors.grey[600],
                                          fontWeight: unread > 0
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    if (unread > 0) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius:
                                          BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$unread',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ]),
                                ],
                              ),
                            ),
                          ]),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _emptyConversations(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.message_outlined, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'No conversations yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to message\na follower or someone you follow.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chat Panel ────────────────────────────────────────────────────────────────

class _ChatPanel extends StatefulWidget {
  final UserModel      currentUser;
  final UserModel      otherUser;
  final MessageService messageService;
  final FollowService  followService;
  final String         Function(Timestamp? ts) relativeTime;
  final VoidCallback?  onBack;

  const _ChatPanel({
    super.key,
    required this.currentUser,
    required this.otherUser,
    required this.messageService,
    required this.followService,
    required this.relativeTime,
    required this.onBack,
  });

  @override
  State<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<_ChatPanel> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController       _scrollController = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _safeMarkRead();
  }

  Future<void> _safeMarkRead() async {
    try {
      await widget.messageService.markRead(
        currentUserId: widget.currentUser.uid,
        otherUserId:   widget.otherUser.uid,
      );
    } catch (_) {
      // No conversation doc yet — nothing to mark.
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _inputController.clear();
    try {
      await widget.messageService.sendMessage(
        senderId:   widget.currentUser.uid,
        receiverId: widget.otherUser.uid,
        text:       text,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        _inputController.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final other = widget.otherUser;

    return Column(
      children: [
        // ── header ──────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(children: [
            if (widget.onBack != null)
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            _Avatar(
                name: other.name ?? 'U', avatarUrl: other.avatar ?? '', size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    other.name ?? 'User',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  if (other.username != null)
                    Text(
                      '@${other.username}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                ],
              ),
            ),
          ]),
        ),

        // ── messages ─────────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.messageService.messagesStream(
                widget.currentUser.uid, other.uid),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.orange));
              }

              final docs = snap.data?.docs ?? [];

              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.waving_hand_outlined,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          'No messages yet.\nSay hello to ${other.name ?? 'them'}!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                );
              }

              _scrollToBottom();

              return ListView.builder(
                controller: _scrollController,
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final isMine =
                      (data['senderId'] as String?) == widget.currentUser.uid;
                  final text      = data['text']      as String?  ?? '';
                  final createdAt = data['createdAt'] as Timestamp?;

                  return _Bubble(
                    text:      text,
                    isMine:    isMine,
                    timestamp: widget.relativeTime(createdAt),
                  );
                },
              );
            },
          ),
        ),

        // ── input ─────────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  hintStyle:
                  TextStyle(color: Colors.grey[400], fontSize: 14),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _sending ? Colors.orange.shade200 : Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: _sending
                    ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

// ── New Message Sheet ─────────────────────────────────────────────────────────
// Shown when a user wants to start a fresh conversation.

class _NewMessageSheet extends StatefulWidget {
  final UserModel      currentUser;
  final FollowService  followService;
  final ValueChanged<UserModel> onSelect;

  const _NewMessageSheet({
    required this.currentUser,
    required this.followService,
    required this.onSelect,
  });

  @override
  State<_NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends State<_NewMessageSheet> {
  List<UserModel> _users   = [];
  List<UserModel> _filtered = [];
  bool _loading = true;
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _search.addListener(() {
      final q = _search.text.trim().toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? _users
            : _users.where((u) {
          return (u.name ?? '').toLowerCase().contains(q) ||
              (u.username ?? '').toLowerCase().contains(q);
        }).toList();
      });
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      // Combine following + followers for the recipient list.
      final results = await Future.wait([
        widget.followService.getFollowing(widget.currentUser.uid),
        widget.followService.getFollowers(widget.currentUser.uid),
      ]);
      final all   = <String, UserModel>{};
      for (final u in [...results[0], ...results[1]]) {
        all[u.uid] = u;
      }
      if (mounted) {
        setState(() {
          _users    = all.values.toList();
          _filtered = _users;
          _loading  = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'New Message',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search followers & following…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: Colors.orange),
            )
          else if (_filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No users found.',
                style: TextStyle(color: Colors.grey[500]),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _filtered.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey[200]),
                itemBuilder: (context, i) {
                  final user = _filtered[i];
                  return ListTile(
                    leading: _Avatar(
                        name: user.name ?? 'U',
                        avatarUrl: user.avatar ?? '',
                        size: 20),
                    title: Text(user.name ?? 'User',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: user.username != null
                        ? Text('@${user.username}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500]))
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      widget.onSelect(user);
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ── Small shared widgets ──────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final double size; // radius

  const _Avatar({
    required this.name,
    required this.avatarUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size,
      backgroundColor: Colors.grey[200],
      backgroundImage:
      avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
      child: avatarUrl.isEmpty
          ? Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: size * 0.75,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
        ),
      )
          : null,
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool   isMine;
  final String timestamp;

  const _Bubble({
    required this.text,
    required this.isMine,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
        isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMine ? Colors.orange : Colors.grey[100],
              borderRadius: BorderRadius.only(
                topLeft:     const Radius.circular(18),
                topRight:    const Radius.circular(18),
                bottomLeft:  Radius.circular(isMine ? 18 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 18),
              ),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isMine ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            timestamp,
            style: TextStyle(fontSize: 10, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  final VoidCallback? onNewMessage;

  const _EmptyChat({this.onNewMessage});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.message_outlined, size: 64, color: Colors.grey[200]),
          const SizedBox(height: 16),
          const Text(
            'Select a conversation',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose from your conversations on the left\nor start a new one.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
          if (onNewMessage != null) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onNewMessage,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('New Message'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
