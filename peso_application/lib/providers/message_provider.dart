import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../services/supabase_service.dart';

class MessageProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  final Uuid _uuid = const Uuid();

  List<Conversation> _conversations = [];
  List<Message> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  String? _currentConversationId;

  static String formatErrorForUI(Object error) {
    final text = error.toString().toLowerCase();

    if (text.contains('failed host lookup') ||
        text.contains('no address associated with hostname') ||
        text.contains('socketexception') ||
        text.contains('connection refused') ||
        text.contains('connection timed out') ||
        text.contains('network is unreachable') ||
        text.contains('failed to connect')) {
      return 'Unable to connect to the service. Please check your internet connection and try again.';
    }

    if (text.contains('permission denied') ||
        text.contains('row level security') ||
        text.contains('policy') ||
        text.contains('rls')) {
      return 'You are not allowed to access or send this message.';
    }

    return 'Unable to load messages. Please try again.';
  }

  List<Conversation> get conversations => _conversations;
  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  String? get currentConversationId => _currentConversationId;

  /// Count only recent conversations so the app badge reflects fresh activity.
  int get unreadConversationCount {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return _conversations
        .where(
          (conversation) =>
              conversation.lastMessage != null &&
              conversation.lastMessage!.trim().isNotEmpty &&
              conversation.lastMessageTimestamp != null &&
              conversation.lastMessageTimestamp!.isAfter(cutoff),
        )
        .length;
  }

  Future<void> loadConversations(String userId) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _conversations = await _supabaseService.getUserConversations(userId);

      // Subscribe to real-time conversation updates (new messages, last message changes)
      try {
        _supabaseService.subscribeToConversations(
          userId: userId,
          onChange: (record) {
            try {
              final isParticipant =
                  record['participant1_id'] == userId ||
                  record['participant2_id'] == userId;
              if (!isParticipant) return;
              final updatedConversation = Conversation.fromJson(record);
              final index = _conversations.indexWhere(
                (c) => c.id == updatedConversation.id,
              );
              if (index != -1) {
                _conversations[index] = updatedConversation;
              } else {
                _conversations.insert(0, updatedConversation);
              }
              notifyListeners();
            } catch (_) {}
          },
        );
      } catch (_) {}
    } catch (e) {
      _conversations = [];
      _error = formatErrorForUI(e);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMessages(String conversationId) async {
    if (_currentConversationId == conversationId) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _messages = await _supabaseService.getConversationMessages(
        conversationId,
      );
      _currentConversationId = conversationId;

      // Subscribe to real-time message updates for this conversation
      try {
        _supabaseService.subscribeToMessages(
          conversationId: conversationId,
          onChange: (record) {
            unawaited(_addRealtimeMessage(record));
          },
        );
      } catch (_) {}
    } catch (e) {
      _messages = [];
      _error = formatErrorForUI(e);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _addRealtimeMessage(Map<String, dynamic> record) async {
    try {
      final newMessage = await _supabaseService.hydrateMessageRecord(record);
      if (!_messages.any((message) => message.id == newMessage.id)) {
        _messages.add(newMessage);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String receiverId,
    required String content,
  }) async {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      return false;
    }

    _isSending = true;
    _error = null;
    notifyListeners();

    final message = Message(
      id: _uuid.v4(),
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      receiverId: receiverId,
      content: trimmedContent,
      timestamp: DateTime.now(),
      isRead: false,
    );

    try {
      final success = await _supabaseService.sendMessage(message);
      _isSending = false;

      if (success) {
        _messages.add(message);

        await _supabaseService.updateConversationLastMessage(
          conversationId,
          trimmedContent,
          message.timestamp,
        );

        final index = _conversations.indexWhere((c) => c.id == conversationId);
        if (index != -1) {
          _conversations[index] = _conversations[index].copyWith(
            lastMessage: trimmedContent,
            lastMessageTimestamp: message.timestamp,
          );
        }

        notifyListeners();
        return true;
      }

      _error = 'Unable to send message. Please try again.';
      notifyListeners();
      return false;
    } catch (e) {
      _isSending = false;
      _error = formatErrorForUI(e);
      notifyListeners();
      return false;
    }
  }

  void clearMessages() {
    _messages = [];
    _currentConversationId = null;
    notifyListeners();
  }
}
