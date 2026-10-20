import 'package:flutter/material.dart';

class ChatMessage {
  final String id;
  final String senderName;
  final String senderInitial;
  final Color senderColor;
  final String message;
  final String time;
  final bool isMe;

  const ChatMessage({
    required this.id,
    required this.senderName,
    required this.senderInitial,
    required this.senderColor,
    required this.message,
    required this.time,
    required this.isMe,
  });
}

class ChatThread {
  final String id;
  final String title;
  final String subtitle;
  final String time;
  final int unreadCount;
  final bool isGroup;
  final Color iconColor;
  final List<ChatMessage> messages;

  const ChatThread({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.unreadCount,
    required this.isGroup,
    required this.iconColor,
    required this.messages,
  });
}
