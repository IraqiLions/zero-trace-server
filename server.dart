import 'dart:convert';
import 'dart:io';

void main() async {
  final portStr = Platform.environment['PORT'] ?? '8080';
  final port = int.parse(portStr);

  // الرمز السري الخاص بك للوصول إلى السجلات والأسماء (يمكنك تغييره هنا)
  const String adminSecretKey = 'Baghdad2026';

  // المتصلون اللحظيون في الذاكرة (RAM)
  final Map<String, WebSocket> activeUsers = {};

  // سجل الحماية (يحتفظ بآخر 500 حركة دخول وخروج في الذاكرة المؤقتة)
  final List<String> auditLogs = [];

  void addLog(String event) {
    // توقيت بغداد (UTC+3)
    final baghdadTime = DateTime.now().toUtc().add(const Duration(hours: 3));
    final timeStr = baghdadTime.toString().substring(0, 19);
    auditLogs.add('[$timeStr] $event');
    if (auditLogs.length > 500) {
      auditLogs.removeAt(0);
    }
  }

  addLog('=== تم تشغيل السيرفر السحابي بنجاح ===');

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  print('خادم التوصيل السحابي يعمل الآن على المنفذ: $port');

  await for (HttpRequest request in server) {
    // 1. اتصال WebSocket للتطبيق والويب
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      final socket = await WebSocketTransformer.upgrade(request);
      String? currentUsername;

      socket.listen(
        (rawMessage) {
          try {
            final data = jsonDecode(rawMessage as String);
            final type = data['type'];

            if (type == 'register') {
              currentUsername = (data['username'] as String).trim().toLowerCase();
              activeUsers[currentUsername!] = socket;
              addLog('دخول متصل: @$currentUsername | المتصلون الآن: ${activeUsers.length}');
            } else if (type == 'check_presence') {
              final target = (data['targetUser'] as String).trim().toLowerCase();
              final isOnline = activeUsers.containsKey(target);
              socket.add(jsonEncode({
                'type': 'presence_result',
                'targetUser': target,
                'isOnline': isOnline,
              }));
            } else if (type == 'relay_message') {
              final target = (data['targetUser'] as String).trim().toLowerCase();
              final targetSocket = activeUsers[target];
              if (targetSocket != null && targetSocket.readyState == WebSocket.open) {
                targetSocket.add(jsonEncode({
                  'type': 'new_message',
                  'sender': currentUsername,
                  'content': data['content'],
                  'isImage': data['isImage'] ?? false,
                  'burnSeconds': data['burnSeconds'] ?? 6,
                }));
              }
            }
          } catch (_) {}
        },
        onDone: () {
          if (currentUsername != null && activeUsers[currentUsername] == socket) {
            activeUsers.remove(currentUsername);
            addLog('خروج متصل: @$currentUsername | المتصلون الآن: ${activeUsers.length}');
          }
        },
        onError: (_) {
          if (currentUsername != null && activeUsers[currentUsername] == socket) {
            activeUsers.remove(currentUsername);
          }
        },
      );
    } 
    // 2. مسار السجلات السري الخاص بك (/admin-logs?key=Baghdad2026)
    else if (request.uri.path == '/admin-logs') {
      final key = request.uri.queryParameters['key'];
      if (key != adminSecretKey) {
        request.response.statusCode = HttpStatus.forbidden;
        request.response.write('Access Denied');
        await request.response.close();
        continue;
      }

      request.response.headers.contentType = ContentType('text', 'plain', charset: 'utf-8');
      final buffer = StringBuffer();
      buffer.writeln('=================================================');
      buffer.writeln('تقرير الحماية والمتصلين - Zero-Trace Server');
      buffer.writeln('=================================================');
      buffer.writeln('عدد المتصلين الفعّالين الآن: ${activeUsers.length}');
      buffer.writeln('أسماء المتصلين حالياً: ${activeUsers.isEmpty ? "لا يوجد أحد" : activeUsers.keys.map((u) => "@$u").join(" , ")}');
      buffer.writeln('-------------------------------------------------');
      buffer.writeln('سجل حركات الدخول والخروج (Audit Log):');
      for (final line in auditLogs) {
        buffer.writeln(line);
      }
      buffer.writeln('=================================================\n');

      request.response.write(buffer.toString());
      await request.response.close();
    } 
    // 3. الصفحة الافتراضية
    else {
      request.response.write('Zero-Trace Relay Server is Online and Ready!');
      await request.response.close();
    }
  }
}
