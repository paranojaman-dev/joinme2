import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:joinme2/services/database_service.dart';
import 'package:joinme2/utils/app_localizations.dart';
import 'package:joinme2/utils/constants.dart';

class ChatScreen extends StatefulWidget {
  final String peerId;
  final String peerName;

  const ChatScreen({required this.peerId, required this.peerName, super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final DatabaseService _databaseService = DatabaseService();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  String? _chatId;
  Duration? _selectedDuration;

  @override
  void initState() {
    super.initState();
    _databaseService.getOrCreateChat(_currentUserId, widget.peerId).then((chatId) {
      if (mounted) {
        setState(() {
          _chatId = chatId;
        });
      }
    });
  }

  void _sendMessage() {
    if (_messageController.text.isNotEmpty && _chatId != null) {
      _databaseService.sendMessage(
        _chatId!, 
        _currentUserId, 
        _messageController.text,
        expireDuration: _selectedDuration
      );
      _messageController.clear();
    }
  }

  void _showDurationPicker() {
    final loc = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: Text(loc.translate('vanishing_msgs'), style: const TextStyle(fontWeight: FontWeight.bold))),
              ListTile(
                leading: const Icon(Icons.timer_off),
                title: Text(loc.translate('all')),
                onTap: () {
                  setState(() => _selectedDuration = null);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text("1 h"),
                onTap: () {
                  setState(() => _selectedDuration = const Duration(hours: 1));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.today),
                title: const Text("1 d"),
                onTap: () {
                  setState(() => _selectedDuration = const Duration(days: 1));
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.peerName),
        actions: [
          IconButton(
            icon: Icon(
              _selectedDuration == null ? Icons.timer_off : Icons.timer,
              color: _selectedDuration == null ? Colors.white54 : Colors.orange,
            ),
            onPressed: _showDurationPicker,
          )
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // SUBTELNE LOGO W TLE (15% Widoczności)
            Positioned.fill(
              child: Opacity(
                opacity: 0.15,
                child: Center(child: Icon(Icons.chair, size: 300, color: Colors.green.shade400)),
              ),
            ),
            Column(
              children: [
                Expanded(
                  child: _chatId == null
                      ? const Center(child: CircularProgressIndicator())
                      : StreamBuilder<QuerySnapshot>(
                          stream: _databaseService.getChatMessages(_chatId!),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                            
                            final messages = snapshot.data!.docs;
                            if (messages.isEmpty) {
                              return Center(child: Text(loc.translate('no_msgs'), style: const TextStyle(color: Colors.grey)));
                            }

                            return ListView.builder(
                              reverse: true,
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final message = messages[index].data() as Map<String, dynamic>;
                                final isMe = message['senderId'] == _currentUserId;
                                return Align(
                                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                    decoration: BoxDecoration(
                                      // CIEMNIEJSZY ZIELONY DLA MOICH WIADOMOŚCI
                                      color: isMe ? Colors.green.shade900 : AppColors.surfaceColor,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
                                        bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                                      ),
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        Text(message['text'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16)),
                                        if (message['expiresAt'] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              "${loc.translate('msg_expires_in')}: ${DateFormat('HH:mm').format((message['expiresAt'] as Timestamp).toDate())}",
                                              style: const TextStyle(fontSize: 9, color: Colors.white60, fontStyle: FontStyle.italic),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
                if (_selectedDuration != null)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    color: Colors.orange.withOpacity(0.1),
                    width: double.infinity,
                    child: Text(
                      loc.translate('vanishing_msgs'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                _buildMessageInput(loc),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: AppColors.surfaceColor,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.timer_outlined, color: Colors.grey),
            onPressed: _showDurationPicker,
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: loc.translate('chat_hint'),
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.green.shade700,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
