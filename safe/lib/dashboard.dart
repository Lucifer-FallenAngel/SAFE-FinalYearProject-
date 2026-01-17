import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'utils/secure_storage.dart';
import 'utils/api_helper.dart';
import 'chat.dart';

class DashboardPage extends StatefulWidget {
  final int userId;
  final String userName;
  final String? profilePic;
  final IO.Socket? socket;

  const DashboardPage({
    super.key,
    required this.userId,
    required this.userName,
    this.profilePic,
    this.socket,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late IO.Socket _socket;

  bool _socketReady = false;
  bool isLoading = true;

  String? _serverBaseUrl;

  List<Map<String, dynamic>> users = [];
  Set<int> onlineUserIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initAsync();
  }

  // -------------------------
  // 🔌 ASYNC INITIALIZATION
  // -------------------------
  Future<void> _initAsync() async {
    _serverBaseUrl = await SecureStorage.getBackendUrl();

    if (_serverBaseUrl == null || _serverBaseUrl!.isEmpty) {
      debugPrint("❌ No base URL found");
      return;
    }

    _socket =
        widget.socket ??
        IO.io(
          _serverBaseUrl!,
          IO.OptionBuilder()
              .setTransports(['websocket'])
              .enableAutoConnect()
              .build(),
        );

    _socketReady = true;

    _initSocketListeners();
    await _fetchUsers();
  }

  // -------------------------
  // 🔊 SOCKET LISTENERS
  // -------------------------
  void _initSocketListeners() {
    _socket.off('online-users-updated');
    _socket.off('new-message-arrived');

    _socket.onConnect((_) {
      _socket.emit('user-online', widget.userId);
    });

    _socket.on('online-users-updated', (data) {
      if (!mounted || data is! List) return;

      setState(() {
        onlineUserIds = Set<int>.from(
          data.map((e) => int.tryParse(e.toString()) ?? 0),
        )..remove(0);
      });
    });

    _socket.on('new-message-arrived', (_) {
      _fetchUsers();
    });
  }

  // -------------------------
  // 👥 FETCH USERS
  // -------------------------
  Future<void> _fetchUsers() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final res = await ApiHelper.get('/users?myId=${widget.userId}');
      if (res.statusCode == 200 && mounted) {
        final List data = jsonDecode(res.body);
        setState(() {
          users = data.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // -------------------------
  // 👋 GREETING
  // -------------------------
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  // -------------------------
  // 🧹 CLEANUP
  // -------------------------
  @override
  void dispose() {
    _tabController.dispose();

    if (_socketReady && widget.socket == null) {
      _socket.disconnect();
    }

    super.dispose();
  }

  // -------------------------
  // 🧱 UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final onlineUsers = users
        .where((u) => onlineUserIds.contains(u['id']))
        .toList();

    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(16, statusBarHeight + 16, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 26,
                        backgroundImage: widget.profilePic != null
                            ? NetworkImage(widget.profilePic!)
                            : const AssetImage('images/default_user.png')
                                  as ImageProvider,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          widget.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: [
                    Tab(text: "All (${users.length})"),
                    Tab(text: "Online (${onlineUsers.length})"),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUserList(users),
                      _buildUserList(onlineUsers),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // -------------------------
  // 👤 USER LIST
  // -------------------------
  Widget _buildUserList(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return const Center(
        child: Text(
          "No users yet",
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchUsers,
      child: ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, i) {
          final u = list[i];
          final isOnline = onlineUserIds.contains(u['id']);
          final unread = (u['unread'] as num?)?.toInt() ?? 0;

          final profileImage =
              u['profile_pic'] != null && _serverBaseUrl != null
              ? NetworkImage(
                  "$_serverBaseUrl/uploads/profile_pics/${u['profile_pic']}",
                )
              : const AssetImage('images/default_user.png') as ImageProvider;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            onTap: () async {
              if (!_socketReady) return;

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatPage(
                    myId: widget.userId,
                    otherUser: u,
                    socket: _socket,
                  ),
                ),
              );
              _fetchUsers();
            },
            leading: Stack(
              children: [
                CircleAvatar(radius: 26, backgroundImage: profileImage),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            title: Text(
              u['name'],
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              isOnline ? "Online" : "Offline",
              style: TextStyle(
                color: isOnline ? Colors.green : Colors.grey[600],
                fontSize: 12,
              ),
            ),
            trailing: unread > 0
                ? Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unread.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }
}
