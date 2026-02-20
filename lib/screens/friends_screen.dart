import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:joinme2/services/database_service.dart';
import 'package:joinme2/screens/chat_screen.dart';
import 'package:joinme2/utils/app_localizations.dart';
import 'package:joinme2/utils/constants.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _databaseService = DatabaseService();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('friends_chats')),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: loc.translate('friends')),
            Tab(text: loc.translate('friend_requests')),
            Tab(text: loc.translate('blocked')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsList(loc),
          _buildFriendRequestsList(loc),
          _buildBlockedUsersList(loc),
        ],
      ),
    );
  }

  Widget _buildFriendsList(AppLocalizations loc) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _databaseService.getFriends(_currentUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: CircularProgressIndicator());
        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null) return const SizedBox.shrink();
        
        final List<dynamic> friendIds = userData['friends'] ?? [];

        return ListView.builder(
          itemCount: friendIds.length + 1,
          itemBuilder: (context, index) {
            final String targetUid = (index == 0) ? _currentUserId : friendIds[index - 1];
            final bool isMe = index == 0;

            return FutureBuilder<DocumentSnapshot>(
              future: _databaseService.getUserData(targetUid),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData || !userSnapshot.data!.exists) return const SizedBox.shrink();
                
                final data = userSnapshot.data!.data() as Map<String, dynamic>?;
                if (data == null) return const SizedBox.shrink();

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: (data['photoURL'] != null && data['photoURL'].toString().isNotEmpty)
                        ? NetworkImage(data['photoURL'])
                        : null,
                    child: (data['photoURL'] == null || data['photoURL'].toString().isEmpty)
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(isMe ? "${data['displayName']} (${loc.translate('saved_messages')})" : (data['displayName'] ?? '...')),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(
                      peerId: targetUid,
                      peerName: isMe ? loc.translate('saved_messages') : (data['displayName'] ?? '...'),
                    )));
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFriendRequestsList(AppLocalizations loc) {
    return StreamBuilder<QuerySnapshot>(
      stream: _databaseService.getFriendRequests(_currentUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final requests = snapshot.data!.docs;
        if (requests.isEmpty) return Center(child: Text(loc.translate('no_requests')));

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final fromUid = request['from'];
            return FutureBuilder<DocumentSnapshot>(
              future: _databaseService.getUserData(fromUid),
              builder: (context, userSnap) {
                if (!userSnap.hasData || !userSnap.data!.exists) return const SizedBox.shrink();
                final sender = userSnap.data!.data() as Map<String, dynamic>?;
                if (sender == null) return const SizedBox.shrink();

                return ListTile(
                  title: Text("${loc.translate('friend_req_from')} ${sender['displayName']}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _databaseService.acceptFriendRequest(request.id, fromUid, _currentUserId)),
                      IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _databaseService.declineFriendRequest(request.id)),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBlockedUsersList(AppLocalizations loc) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _databaseService.getFriends(_currentUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: CircularProgressIndicator());
        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final List<dynamic> blockedIds = userData?['blockedUsers'] ?? [];
        if (blockedIds.isEmpty) return Center(child: Text(loc.translate('no_blocked')));

        return ListView.builder(
          itemCount: blockedIds.length,
          itemBuilder: (context, index) {
            return FutureBuilder<DocumentSnapshot>(
              future: _databaseService.getUserData(blockedIds[index]),
              builder: (context, userSnap) {
                if (!userSnap.hasData || !userSnap.data!.exists) return const SizedBox.shrink();
                final blocked = userSnap.data!.data() as Map<String, dynamic>?;
                if (blocked == null) return const SizedBox.shrink();

                return ListTile(
                  title: Text(blocked['displayName'] ?? '...'),
                  trailing: TextButton(
                    child: Text(loc.translate('unblock')),
                    onPressed: () => _databaseService.unblockUser(_currentUserId, blockedIds[index]),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
