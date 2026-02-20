import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
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
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _databaseService.getOrCreateChat(_currentUserId, widget.peerId).then((chatId) {
      if (mounted) setState(() => _chatId = chatId);
    });
  }

  void _sendMessage({String? text, String? imageUrl}) {
    if ((text != null && text.isNotEmpty || imageUrl != null) && _chatId != null) {
      _databaseService.sendMessage(
        _chatId!, 
        _currentUserId, 
        text,
        imageUrl: imageUrl,
        expireDuration: _selectedDuration
      );
      _messageController.clear();
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (pickedFile != null && _chatId != null) {
      setState(() => _isSending = true);
      try {
        String url = await _databaseService.uploadChatImage(File(pickedFile.path), _chatId!);
        _sendMessage(imageUrl: url);
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
    }
  }

  void _showDurationPicker() {
    final loc = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(loc.translate('vanishing_msgs'), style: const TextStyle(fontWeight: FontWeight.bold))),
            ListTile(leading: const Icon(Icons.timer_off), title: Text(loc.translate('all')), onTap: () { setState(() => _selectedDuration = null); Navigator.pop(context); }),
            ListTile(leading: const Icon(Icons.history), title: const Text("1 h"), onTap: () { setState(() => _selectedDuration = const Duration(hours: 1)); Navigator.pop(context); }),
            ListTile(leading: const Icon(Icons.today), title: const Text("1 d"), onTap: () { setState(() => _selectedDuration = const Duration(days: 1)); Navigator.pop(context); }),
          ],
        ),
      ),
    );
  }

  void _showOptionsMenu() {
    final loc = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: Text(loc.translate('block_user'), style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmBlock();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(loc.translate('view_media')),
              onTap: () {
                Navigator.pop(context);
                // Tu można dodać prostą galerię zdjęć z czatu
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmBlock() {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.translate('confirm_block')),
        actions: [
          TextButton(child: Text(loc.translate('cancel')), onPressed: () => Navigator.pop(ctx)),
          TextButton(
            child: Text(loc.translate('block_user'), style: const TextStyle(color: Colors.red)),
            onPressed: () async {
              await _databaseService.blockUser(_currentUserId, widget.peerId);
              if (mounted) {
                Navigator.pop(ctx);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.translate('user_blocked'))));
              }
            },
          ),
        ],
      ),
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
            icon: Icon(_selectedDuration == null ? Icons.timer_off : Icons.timer, color: _selectedDuration == null ? Colors.white54 : Colors.orange),
            onPressed: _showDurationPicker,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showOptionsMenu,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _chatId == null
                  ? const Center(child: CircularProgressIndicator())
                  : StreamBuilder<QuerySnapshot>(
                      stream: _databaseService.getChatMessages(_chatId!),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        final messages = snapshot.data!.docs;
                        return ListView.builder(
                          reverse: true,
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = messages[index].data() as Map<String, dynamic>;
                            final isMe = msg['senderId'] == _currentUserId;
                            return _buildMessageBubble(msg, isMe, loc);
                          },
                        );
                      },
                    ),
            ),
            if (_isSending) const LinearProgressIndicator(backgroundColor: Colors.transparent, color: Colors.green),
            _buildMessageInput(loc),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe, AppLocalizations loc) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? Colors.green.shade900 : AppColors.surfaceColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (msg['imageUrl'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(msg['imageUrl'], fit: BoxFit.cover, loadingBuilder: (_, child, progress) {
                    return progress == null ? child : const Center(child: CircularProgressIndicator());
                  }),
                ),
              ),
            if (msg['text'] != null && msg['text'].toString().isNotEmpty)
              Text(msg['text'], style: const TextStyle(color: Colors.white, fontSize: 16)),
            if (msg['expiresAt'] != null && _selectedDuration != null)
              Text(
                "${loc.translate('msg_expires_in')}: ${DateFormat('HH:mm').format((msg['expiresAt'] as Timestamp).toDate())}",
                style: const TextStyle(fontSize: 9, color: Colors.white60),
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
          IconButton(icon: const Icon(Icons.add_a_photo, color: Colors.grey), onPressed: _pickImage),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(24)),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(hintText: loc.translate('chat_hint'), border: InputBorder.none),
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.send, color: Colors.green), onPressed: () => _sendMessage(text: _messageController.text)),
        ],
      ),
    );
  }
}
