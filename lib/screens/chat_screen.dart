import 'dart:async';
import 'package:flutter/material.dart';
import '../data/sample_data.dart';
import '../models/chat_model.dart';
import '../services/auth_service.dart';
import '../services/aws_storage_service.dart';
import '../services/privacy_filter_service.dart';
import '../services/voice_room_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/user_profile_dialog.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<ChatThread> _threads;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _populateThreads();
    VoiceRoomManager().syncFollowsFromServer().then((_) {
      if (mounted) _populateThreads();
    });
  }

  void _populateThreads() {
    final friends = AuthService().friends;
    final friendThreads = <ChatThread>[];

    for (final f in friends) {
      friendThreads.add(
        ChatThread(
          id: f.id,
          title: f.name,
          subtitle: f.statusText.isNotEmpty ? f.statusText : 'Tap to start direct chat',
          time: 'Active',
          iconColor: f.avatarColor,
          unreadCount: 0,
          isGroup: false,
          messages: [
            ChatMessage(
              id: 'init_${f.id}',
              senderName: f.name,
              senderInitial: f.initial,
              senderColor: f.avatarColor,
              message: 'Hey! Let\'s play games together on Play Friends 🎉',
              time: 'Recently',
              isMe: false,
            ),
          ],
        ),
      );
    }

    // Keep sample direct chats only if friend list is empty
    final dms = friendThreads.isNotEmpty
        ? friendThreads
        : SampleData.chatThreads.where((t) => !t.isGroup).toList();
    final groups = SampleData.chatThreads.where((t) => t.isGroup).toList();

    setState(() {
      _threads = [...dms, ...groups];
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<ChatThread> get _dmThreads => _threads.where((t) => !t.isGroup).toList();
  List<ChatThread> get _groupThreads =>
      _threads.where((t) => t.isGroup).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages & Social'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryBlueLight,
          indicatorWeight: 3,
          labelColor: AppColors.primaryBlueLight,
          unselectedLabelColor: AppColors.textMuted,
          tabs: [
            Tab(text: 'Direct (${_dmThreads.length})'),
            Tab(text: 'Room Chats (${_groupThreads.length})'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildThreadList(_dmThreads),
            _buildThreadList(_groupThreads),
          ],
        ),
      ),
    );
  }

  Widget _buildThreadList(List<ChatThread> list) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 56,
                color: AppColors.textMuted.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 14),
              const Text(
                'No Conversations Yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Add friends or join game rooms to chat with players!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final thread = list[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder, width: 1),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openConversationDetail(thread),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (!thread.isGroup) {
                          UserProfileDialog.show(
                            context,
                            name: thread.title,
                            avatarColor: thread.iconColor,
                          );
                        }
                      },
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: thread.iconColor,
                        child: Icon(
                          thread.isGroup
                              ? Icons.groups_rounded
                              : Icons.person_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  thread.title,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                thread.time,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  thread.subtitle,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (thread.unreadCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlue,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${thread.unreadCount}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openConversationDetail(ChatThread thread) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(thread: thread),
      ),
    );
  }
}

class ChatConversationScreen extends StatefulWidget {
  final ChatThread thread;

  const ChatConversationScreen({super.key, required this.thread});

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  late List<ChatMessage> _messages;
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _liveSyncTimer;

  @override
  void initState() {
    super.initState();
    _messages = List.from(widget.thread.messages);
    _fetchLiveMessages();
    VoiceRoomManager().syncFollowsFromServer();
    _liveSyncTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
      _fetchLiveMessages();
      VoiceRoomManager().syncFollowsFromServer();
    });
  }

  @override
  void dispose() {
    _liveSyncTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveMessages() async {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) return;
    final myName = currentUser.name.trim().toLowerCase();
    final friendName = widget.thread.title.trim().toLowerCase();

    try {
      final remoteMsgs = await AwsStorageService.getDirectMessages(
        userA: myName,
        userB: friendName,
      );

      if (remoteMsgs.isNotEmpty && mounted) {
        final existingIds = _messages.map((m) => m.id).toSet();
        bool addedNew = false;

        for (final m in remoteMsgs) {
          final id = m['id']?.toString() ?? 'm_${m['createdAt']}';
          if (!existingIds.contains(id)) {
            existingIds.add(id);
            final sId = (m['senderId'] ?? '').toString().toLowerCase();
            final isMe = sId == myName;
            final text = m['text']?.toString() ?? '';
            final senderName = isMe ? currentUser.name : widget.thread.title;
            final initial = senderName.isNotEmpty ? senderName[0].toUpperCase() : 'P';

            _messages.add(
              ChatMessage(
                id: id,
                senderName: senderName,
                senderInitial: initial,
                senderColor: isMe ? currentUser.avatarColor : widget.thread.iconColor,
                message: text,
                time: 'Just now',
                isMe: isMe,
              ),
            );
            addedNew = true;
          }
        }

        if (addedNew) {
          setState(() {});
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    } catch (e) {
      debugPrint('ChatScreen _fetchLiveMessages error: $e');
    }
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    // Strict Privacy & Anti-Scam filter
    final check = PrivacyFilterService.checkMessage(text);
    if (!check.isAllowed) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1B4B),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.shield_rounded, color: Colors.amber, size: 26),
              SizedBox(width: 8),
              Text('Security Protection',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(
            check.reason ??
                'Sharing personal contact details (phone numbers, WhatsApp, Instagram, Facebook, or external IDs) is strictly prohibited to ensure safety.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
      return;
    }

    final currentName = AuthService().currentUser?.name ?? 'Me';
    final currentInitial = currentName.isNotEmpty ? currentName[0].toUpperCase() : 'M';
    final newMsgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';

    final newMsg = ChatMessage(
      id: newMsgId,
      senderName: currentName,
      senderInitial: currentInitial,
      senderColor: AuthService().currentUser?.avatarColor ?? AppColors.primaryPurple,
      message: text,
      time: 'Just now',
      isMe: true,
    );

    setState(() {
      _messages.add(newMsg);
      _msgController.clear();
    });

    // Send to AWS DynamoDB
    AwsStorageService.sendDirectMessage(
      senderId: currentName.trim().toLowerCase(),
      receiverId: widget.thread.title.trim().toLowerCase(),
      text: text,
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!widget.thread.isGroup) {
              UserProfileDialog.show(
                context,
                name: widget.thread.title,
                avatarColor: widget.thread.iconColor,
              );
            }
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: widget.thread.iconColor,
                child: Icon(
                  widget.thread.isGroup
                      ? Icons.groups_rounded
                      : Icons.person_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.thread.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!widget.thread.isGroup)
                      ListenableBuilder(
                        listenable: VoiceRoomManager(),
                        builder: (context, _) {
                          final isMutual = VoiceRoomManager()
                              .isMutualFollow(widget.thread.title);
                          return Text(
                            isMutual
                                ? 'Mutual Followers ⭐'
                                : 'Tap to inspect profile',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isMutual
                                  ? AppColors.onlineGreen
                                  : AppColors.textSecondary,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isMe = msg.isMe;

                  return Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.76,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color:
                            isMe ? AppColors.primaryPurple : AppColors.cardBg,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isMe ? 16 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 16),
                        ),
                        border: Border.all(
                          color: isMe
                              ? AppColors.primaryPurpleLight
                                  .withValues(alpha: 0.3)
                              : AppColors.cardBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (!isMe && widget.thread.isGroup)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                msg.senderName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: msg.senderColor,
                                ),
                              ),
                            ),
                          Text(
                            msg.message,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            msg.time,
                            style: TextStyle(
                              fontSize: 10,
                              color:
                                  isMe ? Colors.white70 : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Message Input Field (Direct chat is locked unless mutual follow)
            ListenableBuilder(
              listenable: VoiceRoomManager(),
              builder: (context, _) {
                final vm = VoiceRoomManager();
                final isMutual = widget.thread.isGroup ||
                    vm.isMutualFollow(widget.thread.title) ||
                    (_messages.any((m) => m.isMe) &&
                        _messages.any((m) => !m.isMe));
                final isFollowing = vm.isFollowingUser(widget.thread.title);

                if (!isMutual) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E1B4B),
                      border: Border(
                        top: BorderSide(color: Color(0xFF3B82F6), width: 1),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_rounded,
                                color: AppColors.coinAmber, size: 16),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Direct chat is available when both follow each other',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFollowing
                                    ? AppColors.surfaceLight
                                    : AppColors.primaryPurple,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: Icon(
                                isFollowing
                                    ? Icons.check_circle_rounded
                                    : Icons.person_add_rounded,
                                size: 15,
                                color: isFollowing
                                    ? AppColors.onlineGreen
                                    : Colors.white,
                              ),
                              label: Text(
                                isFollowing
                                    ? 'Followed (Waiting for return follow)'
                                    : '+ Follow ${widget.thread.title}',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () async {
                                final friend = AuthService().friends.where((f) =>
                                    f.name.toLowerCase() == widget.thread.title.toLowerCase()).firstOrNull;
                                await vm.toggleFollowUser(widget.thread.title, tag: friend?.tag);
                                await vm.syncFollowsFromServer();
                                if (mounted) setState(() {});
                              },
                            ),
                            if (isFollowing)
                              IconButton(
                                icon: const Icon(Icons.sync_rounded,
                                    color: AppColors.accentCyan, size: 20),
                                tooltip: 'Check Follow Back Status',
                                onPressed: () async {
                                  await vm.syncFollowsFromServer();
                                  if (mounted) setState(() {});
                                },
                              ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accentCyan,
                                side: const BorderSide(
                                    color: AppColors.accentCyan),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.person_rounded, size: 15),
                              label: const Text('View Profile',
                                  style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                UserProfileDialog.show(
                                  context,
                                  name: widget.thread.title,
                                  avatarColor: widget.thread.iconColor,
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                // Unlocked Message Input Field
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                        top: BorderSide(color: AppColors.cardBorder, width: 1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: const TextStyle(
                                color: AppColors.textMuted, fontSize: 14),
                            filled: true,
                            fillColor: AppColors.cardBg,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide:
                                  const BorderSide(color: AppColors.cardBorder),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send_rounded),
                        color: AppColors.primaryBlueLight,
                        onPressed: _sendMessage,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
