import 'package:hilla_ride/core/models/app_models.dart';

enum RideMessageType {
  text,
  voice,
}

extension RideMessageTypeX on RideMessageType {
  String get value => name;

  static RideMessageType fromString(String? value) {
    if (value == RideMessageType.voice.name) {
      return RideMessageType.voice;
    }
    return RideMessageType.text;
  }
}

class RideMessage {
  const RideMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.type = RideMessageType.text,
    this.voiceUrl = '',
    this.voiceDurationMs = 0,
  });

  final String id;
  final String senderId;
  final UserRole senderRole;
  final String senderName;
  final String text;
  final DateTime? createdAt;
  final RideMessageType type;
  final String voiceUrl;
  final int voiceDurationMs;

  bool get isVoice =>
      type == RideMessageType.voice || voiceUrl.trim().isNotEmpty;

  factory RideMessage.fromMap(String id, Map<String, dynamic> data) {
    final voiceUrl = data['voiceUrl'] as String? ?? '';
    final type = RideMessageTypeX.fromString(data['type'] as String?);
    return RideMessage(
      id: id,
      senderId: data['senderId'] as String? ?? '',
      senderRole: UserRoleX.fromString(data['senderRole'] as String?),
      senderName: data['senderName'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate() as DateTime?,
      type: voiceUrl.isNotEmpty && type == RideMessageType.text
          ? RideMessageType.voice
          : type,
      voiceUrl: voiceUrl,
      voiceDurationMs: (data['voiceDurationMs'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderRole': senderRole.name,
      'senderName': senderName,
      'text': text,
      'type': type.value,
      if (voiceUrl.isNotEmpty) 'voiceUrl': voiceUrl,
      if (voiceDurationMs > 0) 'voiceDurationMs': voiceDurationMs,
      'createdAt': createdAt,
    };
  }
}

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.userId,
    required this.userRole,
    required this.userName,
    required this.phone,
    required this.message,
    required this.createdAt,
    this.isFromManager = false,
    this.status = 'open',
  });

  final String id;
  final String userId;
  final UserRole userRole;
  final String userName;
  final String phone;
  final String message;
  final DateTime? createdAt;
  final bool isFromManager;
  final String status;

  factory SupportMessage.fromMap(String id, Map<String, dynamic> data) {
    return SupportMessage(
      id: id,
      userId: data['userId'] as String? ?? '',
      userRole: UserRoleX.fromString(data['userRole'] as String?),
      userName: data['userName'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      message: data['message'] as String? ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate() as DateTime?,
      isFromManager: data['isFromManager'] as bool? ?? false,
      status: data['status'] as String? ?? 'open',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userRole': userRole.name,
      'userName': userName,
      'phone': phone,
      'message': message,
      'isFromManager': isFromManager,
      'status': status,
    };
  }
}

class SupportContactInfo {
  const SupportContactInfo({
    required this.phone,
    required this.whatsapp,
    required this.email,
  });

  final String phone;
  final String whatsapp;
  final String email;

  static const defaults = SupportContactInfo(
    phone: '+9647735349061',
    whatsapp: '+9647735349061',
    email: 'hellotuktuk3@gmail.com',
  );

  factory SupportContactInfo.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    return SupportContactInfo(
      phone: data['phone'] as String? ?? defaults.phone,
      whatsapp: data['whatsapp'] as String? ?? defaults.whatsapp,
      email: data['email'] as String? ?? defaults.email,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phone': phone,
      'whatsapp': whatsapp,
      'email': email,
    };
  }
}