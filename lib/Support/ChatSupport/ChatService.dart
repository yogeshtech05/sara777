import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path/path.dart' as p;
import '../../ulits/Constents.dart';

class ChatMessage {
  final int id;
  final int senderId;
  final int receiverId;
  final String message;
  final String type;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.type,
    required this.createdAt,
  });

  /// Parses API `created_at` whether it is ISO-8601 (UTC or offset), naive
  /// datetime, or unix seconds/milliseconds. Always returns a local [DateTime]
  /// suitable for displaying with [DateTime.hour]/[DateTime.minute].
  static DateTime parseCreatedAt(dynamic value) {
    if (value == null) return DateTime.now();

    if (value is int) {
      final ms = value < 1000000000000 ? value * 1000 : value;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    }
    if (value is double) {
      final v = value.toInt();
      final ms = v < 1000000000000 ? v * 1000 : v;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    }

    var s = value.toString().trim();
    if (s.isEmpty) return DateTime.now();

    // Integer string = unix (seconds or ms)
    if (RegExp(r'^\d{10,13}$').hasMatch(s)) {
      final n = int.parse(s);
      final ms = n < 1000000000000 ? n * 1000 : n;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    }

    // "YYYY-MM-DD HH:mm:ss" → ISO-like (Dart prefers T between parts)
    if (s.contains(' ') && !s.contains('T') && RegExp(r'^\d{4}-\d{2}-\d{2} ').hasMatch(s)) {
      s = s.replaceFirst(' ', 'T');
    }

    final parsed = DateTime.tryParse(s);
    if (parsed != null) {
      return parsed.isUtc ? parsed.toLocal() : parsed;
    }

    return DateTime.now();
  }

  /// Text / caption, or absolute image URL — [full_image_url] sirf image/video ke liye.
  ///
  /// Null-safe: API `"full_image_url":null` par pehle `?.toString().trim()` galat tha —
  /// Dart me `null?.toString()` ke baad `.trim()` null par chal sakta hai → parse crash / khali chat.
  static String _resolveMessageContent(Map<String, dynamic> json) {
    final type = (json['type'] ?? 'text').toString().toLowerCase();

    String? fullUrl;
    final fu = json['full_image_url'];
    if (fu != null) {
      final t = fu.toString().trim();
      if (t.isNotEmpty && t.toLowerCase() != 'null') fullUrl = t;
    }

    if ((type == 'image' || type == 'video') && fullUrl != null) {
      return fullUrl;
    }

    var m = json['message']?.toString() ?? '';
    // API kabhi URL [image] field me bhejti hai
    if ((type == 'image' || type == 'video') && m.isEmpty) {
      final im = json['image'];
      if (im != null) {
        final t = im.toString().trim();
        if (t.isNotEmpty && t.toLowerCase() != 'null') m = t;
      }
    }

    if ((type == 'image' || type == 'video') &&
        m.isNotEmpty &&
        !m.startsWith('http')) {
      final origin = Uri.parse(Constant.apiEndpoint).origin;
      final path = m.startsWith('/') ? m : '/$m';
      m = '$origin$path';
    }
    return m;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final raw = json['created_at'] ?? json['createdAt'] ?? json['timestamp'];
    final type = json['type']?.toString() ?? 'text';
    return ChatMessage(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      senderId: int.tryParse(json['sender_id']?.toString() ?? '0') ?? 0,
      receiverId: int.tryParse(json['receiver_id']?.toString() ?? '0') ?? 0,
      message: _resolveMessageContent(json),
      type: type,
      createdAt: parseCreatedAt(raw),
    );
  }
}

class ChatService {
  final GetStorage _storage = GetStorage();

  /// Admin chat partner (receiver_id jab user admin ko message bheje).
  static const int adminId = 1;

  /// API shapes: top-level [messages], [data] as list or {messages}, [info] list or map.
  static List<dynamic> _extractMessagesArray(Map<String, dynamic> data) {
    final m = data['messages'];
    if (m is List) return m;

    final inner = data['data'];
    if (inner is List) return inner;
    if (inner is Map) {
      for (final k in ['messages', 'chat', 'list', 'records']) {
        final v = inner[k];
        if (v is List) return v;
      }
    }

    final info = data['info'];
    if (info is List) return info;
    if (info is Map) {
      for (final k in ['messages', 'chat', 'list']) {
        final v = info[k];
        if (v is List) return v;
      }
    }

    for (final k in ['chat', 'history', 'records', 'result']) {
      final v = data[k];
      if (v is List) return v;
    }

    return [];
  }

  /// Get current user's ID
  int? get currentUserId {
    // Try 'userId' first as requested
    var idV = _storage.read('userId');
    if (idV == null || idV.toString().isEmpty) {
      // Fallback to 'registerId'
      idV = _storage.read('registerId');
    }
    
    print('[ChatService] Raw ID from storage (userId/regId): $idV (${idV?.runtimeType})');
    return int.tryParse(idV?.toString() ?? '');
  }

  /// Get auth token
  String? get authToken {
    final token = _storage.read('accessToken');
    print('[ChatService] Raw accessToken from storage: ${token != null ? "EXISTS" : "NULL"}');
    return token;
  }

  /// JSON POST bodies
  Map<String, String> get headers {
    final token = authToken;
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// GET calls — sirf Bearer; kuch servers GET par Content-Type se issue karte hain.
  Map<String, String> get _headersGet {
    final token = authToken;
    if (token == null || token.isEmpty) return {};
    return {'Authorization': 'Bearer $token'};
  }

  /// Send a message to admin
  Future<Map<String, dynamic>> sendMessage({
    required String message,
    String type = 'text',
    String? filePath,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        print('[ChatService] ERROR: Cannot send message because userId is null');
        return {'status': false, 'msg': 'User not logged in'};
      }

      final url = '${Constant.apiEndpoint}chat/send';

      if (filePath != null && filePath.isNotEmpty) {
        // multipart/form-data — backend expects file under `image` (not `message`)
        var request = http.MultipartRequest('POST', Uri.parse(url));

        final token = authToken;
        request.headers['Authorization'] = 'Bearer $token';
        // Do not set Content-Type — MultipartRequest sets boundary automatically

        request.fields['sender_id'] = userId.toString();
        request.fields['receiver_id'] = adminId.toString();
        if (message.isNotEmpty) {
          request.fields['message'] = message;
        }
        request.fields['type'] = type;

        final extension = p.extension(filePath).toLowerCase().replaceFirst('.', '');

        String mimeType = 'image';
        String mimeSubtype = 'jpeg';
        String fileFieldName = 'image';

        if (type == 'video') {
          mimeType = 'video';
          fileFieldName = 'video';
          if (extension == 'mov') {
            mimeSubtype = 'quicktime';
          } else if (extension == 'webm') {
            mimeSubtype = 'webm';
          } else {
            mimeSubtype = 'mp4';
          }
        } else if (extension == 'png') {
          mimeSubtype = 'png';
        } else if (extension == 'gif') {
          mimeSubtype = 'gif';
        } else if (extension == 'webp') {
          mimeSubtype = 'webp';
        }

        print(
            '[ChatService] UPLOADING FILE field=$fileFieldName path=$filePath type=$type');

        request.files.add(await http.MultipartFile.fromPath(
          fileFieldName,
          filePath,
          filename: p.basename(filePath),
          contentType: MediaType(mimeType, mimeSubtype),
        ));

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        print('[ChatService] SEND MEDIA RESPONSE: ${response.statusCode}');
        print('  BODY: ${response.body}');

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          return {'status': false, 'msg': 'Failed to upload $type'};
        }
      } else {
        // API doc: multipart/form-data (text bina file ke bhi fields)
        var request = http.MultipartRequest('POST', Uri.parse(url));
        final token = authToken;
        request.headers['Authorization'] = 'Bearer $token';
        request.fields['sender_id'] = userId.toString();
        request.fields['receiver_id'] = adminId.toString();
        request.fields['message'] = message;
        request.fields['type'] = type;

        print('[ChatService] SEND TEXT (multipart) REQUEST:');
        print('  URL: $url');
        print('  FIELDS: ${request.fields}');

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        print('[ChatService] SEND MESSAGE RESPONSE: ${response.statusCode}');
        print('  BODY: ${response.body}');

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          return {
            'status': false,
            'msg': 'Failed to send message',
            'message': 'Failed to send message',
          };
        }
      }
    } catch (e) {
      log('[ChatService] Send Message Error: $e');
      return {'status': false, 'msg': 'Error: $e'};
    }
  }

  /// Get chat history between user and admin
  Future<List<ChatMessage>> getChatHistory() async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return [];
      }

      final uri = Uri.parse('${Constant.apiEndpoint}chat/history').replace(
        queryParameters: {
          'user_id': userId.toString(),
          'receiver_id': adminId.toString(),
        },
      );

      print('[ChatService] GET CHAT HISTORY REQUEST:');
      print('  URL: $uri');
      print('  HEADERS: $_headersGet');

      final response = await http.get(uri, headers: _headersGet);

      print('[ChatService] GET CHAT HISTORY RESPONSE: ${response.statusCode}');
      print('  BODY: ${response.body}');

      if (response.statusCode == 200) {
        final raw = json.decode(response.body);
        if (raw is! Map) return [];

        final data = Map<String, dynamic>.from(raw as Map);
        final List messages = _extractMessagesArray(data);

        if (messages.isNotEmpty) {
          return messages
              .map((msg) => ChatMessage.fromJson(Map<String, dynamic>.from(msg as Map)))
              .toList();
        }
      }
      return [];
    } catch (e) {
      log('[ChatService] Get Chat History Error: $e');
      return [];
    }
  }

  /// Get new messages (polling)
  Future<List<ChatMessage>> getNewMessages({required int lastMessageId}) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return [];
      }

      final uri = Uri.parse('${Constant.apiEndpoint}chat/messages').replace(
        queryParameters: {
          'receiver_id': userId.toString(),
          'last_message_id': lastMessageId.toString(),
        },
      );

      print('[ChatService] GET NEW MESSAGES REQUEST:');
      print('  URL: $uri');
      print('  HEADERS: $_headersGet');

      final response = await http.get(uri, headers: _headersGet);

      print('[ChatService] GET NEW MESSAGES RESPONSE: ${response.statusCode}');
      print('  BODY: ${response.body}');

      if (response.statusCode == 200) {
        final raw = json.decode(response.body);
        if (raw is! Map) return [];

        final data = Map<String, dynamic>.from(raw as Map);
        final List messages = _extractMessagesArray(data);

        if (messages.isNotEmpty) {
          return messages
              .map((msg) => ChatMessage.fromJson(Map<String, dynamic>.from(msg as Map)))
              .toList();
        }
      }
      return [];
    } catch (e) {
      log('[ChatService] Get New Messages Error: $e');
      return [];
    }
  }

  /// Get Unread Message Count
  Future<int> getUnreadCount() async {
    try {
      final userId = currentUserId;
      if (userId == null) return 0;

      final url = '${Constant.apiEndpoint}chat/unread-count';
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          return int.tryParse(data['unread_count']?.toString() ?? '0') ?? 0;
        }
      }
      return 0;
    } catch (e) {
      log('[ChatService] Get Unread Count Error: $e');
      return 0;
    }
  }

  /// Mark Messages as Read
  Future<void> markMessagesAsRead() async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      final url = '${Constant.apiEndpoint}chat/mark-read';
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({
          'user_id': userId,
          'sender_id': adminId,
        }),
      );
      
      if (response.statusCode == 200) {
        log('[ChatService] Messages marked as read successfully');
      }
    } catch (e) {
      log('[ChatService] Mark Messages as Read Error: $e');
    }
  }
}
