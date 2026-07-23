/// Modèles liés à la famille et au tchat.
/// Conventions identiques à entries.dart : JSON ISO-8601 UTC côté API.

class FamilyMember {
  final String deviceId;
  final String displayName;
  final String role; // 'CREATOR' | 'MEMBER'
  final DateTime joinedAt;

  FamilyMember({
    required this.deviceId,
    required this.displayName,
    required this.role,
    required this.joinedAt,
  });

  bool get isCreator => role == 'CREATOR';

  factory FamilyMember.fromJson(Map<String, dynamic> j) => FamilyMember(
        deviceId: j['deviceId'] as String,
        displayName: j['displayName'] as String,
        role: j['role'] as String,
        joinedAt: DateTime.parse(j['joinedAt'] as String).toLocal(),
      );
}

class FamilyInvitation {
  final String token;
  final String url;
  final DateTime expiresAt;

  FamilyInvitation({
    required this.token,
    required this.url,
    required this.expiresAt,
  });

  factory FamilyInvitation.fromJson(Map<String, dynamic> j) =>
      FamilyInvitation(
        token: j['token'] as String,
        url: j['url'] as String,
        expiresAt: DateTime.parse(j['expiresAt'] as String).toLocal(),
      );
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime sentAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.sentAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        senderId: j['senderId'] as String,
        senderName: j['senderName'] as String,
        text: j['text'] as String,
        sentAt: DateTime.parse(j['sentAt'] as String).toLocal(),
      );
}
