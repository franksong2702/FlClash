import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'constant.dart';
import 'network.dart';

final remoteInputServer = RemoteInputServer();

class RemoteInputServer {
  final _random = Random.secure();
  final _sessions = <String, RemoteInputSession>{};
  HttpServer? _server;

  Future<RemoteInputSession> createSession({
    required String title,
    String initialValue = '',
  }) async {
    await _ensureStarted();
    final id = _createId();
    final host = await _getLocalIpAddress();
    final port = _server!.port;
    final session = RemoteInputSession._(
      server: this,
      id: id,
      title: title,
      initialValue: initialValue,
      url: 'http://${_formatHost(host)}:$port/input/$id',
    );
    _sessions[id] = session;
    return session;
  }

  Future<void> close() async {
    final sessions = _sessions.values.toList();
    _sessions.clear();
    for (final session in sessions) {
      session._disposeNotifier();
    }
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _ensureStarted() async {
    if (_server != null) {
      return;
    }
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server = server;
    unawaited(_listen(server));
  }

  Future<void> _listen(HttpServer server) async {
    await for (final request in server) {
      try {
        await _handleRequest(request);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Remote input request error: $e');
        }
        _writeHtml(
          request,
          _page('Remote input', '<p>Request failed.</p>'),
          statusCode: HttpStatus.internalServerError,
        );
      }
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final pathSegments = request.uri.pathSegments;
    if (pathSegments.length != 2 || pathSegments.first != 'input') {
      _writeHtml(
        request,
        _page('Not found', '<p>Input session not found.</p>'),
        statusCode: HttpStatus.notFound,
      );
      return;
    }

    final session = _sessions[pathSegments[1]];
    if (session == null) {
      _writeHtml(
        request,
        _page('Expired', '<p>This input session is closed or expired.</p>'),
        statusCode: HttpStatus.notFound,
      );
      return;
    }

    if (request.method == 'GET') {
      _writeHtml(request, _buildInputPage(session));
      return;
    }

    if (request.method == 'POST') {
      final body = await utf8.decoder.bind(request).join();
      final params = Uri.splitQueryString(body, encoding: utf8);
      final value = params['value']?.trim() ?? '';
      if (value.isEmpty) {
        _writeHtml(
          request,
          _buildInputPage(session, error: 'Please enter a value.'),
          statusCode: HttpStatus.badRequest,
        );
        return;
      }
      session._setValue(value);
      _writeHtml(
        request,
        _page(
          session.title,
          '<p class="success">Submitted. You can return to FlClash on your TV.</p>',
        ),
      );
      return;
    }

    _writeHtml(
      request,
      _page('Method not allowed', '<p>Method not allowed.</p>'),
      statusCode: HttpStatus.methodNotAllowed,
    );
  }

  void _removeSession(String id) {
    _sessions.remove(id);
  }

  String _createId() {
    final bytes = List<int>.generate(18, (_) => _random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  Future<String> _getLocalIpAddress() async {
    final interfaces = await NetworkInterface.list(includeLoopback: false)
      ..sort((a, b) {
        if (a.isWifi && !b.isWifi) return -1;
        if (!a.isWifi && b.isWifi) return 1;
        if (a.includesIPv4 && !b.includesIPv4) return -1;
        if (!a.includesIPv4 && b.includesIPv4) return 1;
        return 0;
      });
    for (final interface in interfaces) {
      final addresses = interface.addresses;
      if (addresses.isEmpty) {
        continue;
      }
      addresses.sort((a, b) {
        if (a.isIPv4 && !b.isIPv4) return -1;
        if (!a.isIPv4 && b.isIPv4) return 1;
        return 0;
      });
      return addresses.first.address;
    }
    return localhost;
  }

  String _formatHost(String host) {
    return host.contains(':') ? '[$host]' : host;
  }

  String _buildInputPage(RemoteInputSession session, {String? error}) {
    final escape = const HtmlEscape().convert;
    final initialValue = escape(session.initialValue);
    final title = escape(session.title);
    final errorHtml = error == null ? '' : '<p class="error">${escape(error)}</p>';
    return _page(
      title,
      '''
      <form method="post">
        <label for="value">Input</label>
        <textarea id="value" name="value" autofocus rows="6">$initialValue</textarea>
        $errorHtml
        <button type="submit">Submit</button>
      </form>
      ''',
    );
  }

  String _page(String title, String body) {
    final escape = const HtmlEscape().convert;
    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escape(title)}</title>
  <style>
    body {
      margin: 0;
      padding: 24px;
      color: #111827;
      background: #f8fafc;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    main {
      max-width: 560px;
      margin: 0 auto;
    }
    h1 {
      margin: 0 0 20px;
      font-size: 24px;
      line-height: 1.25;
    }
    label {
      display: block;
      margin-bottom: 8px;
      color: #334155;
      font-size: 14px;
      font-weight: 600;
    }
    textarea {
      box-sizing: border-box;
      width: 100%;
      min-height: 160px;
      padding: 12px;
      border: 1px solid #cbd5e1;
      border-radius: 8px;
      font: inherit;
      resize: vertical;
      background: white;
    }
    button {
      width: 100%;
      margin-top: 16px;
      padding: 12px 16px;
      border: 0;
      border-radius: 8px;
      color: white;
      background: #2563eb;
      font: inherit;
      font-weight: 700;
    }
    .success {
      padding: 14px 16px;
      border-radius: 8px;
      color: #14532d;
      background: #dcfce7;
    }
    .error {
      color: #b91c1c;
    }
  </style>
</head>
<body>
  <main>
    <h1>${escape(title)}</h1>
    $body
  </main>
</body>
</html>
''';
  }

  void _writeHtml(
    HttpRequest request,
    String html, {
    int statusCode = HttpStatus.ok,
  }) {
    final response = request.response;
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.html;
    response.write(html);
    unawaited(response.close());
  }
}

class RemoteInputSession {
  final RemoteInputServer _server;
  final String id;
  final String title;
  final String initialValue;
  final String url;
  final ValueNotifier<String?> valueNotifier = ValueNotifier(null);
  bool _disposed = false;

  RemoteInputSession._({
    required RemoteInputServer server,
    required this.id,
    required this.title,
    required this.initialValue,
    required this.url,
  }) : _server = server;

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _server._removeSession(id);
    _disposeNotifier();
  }

  void _setValue(String value) {
    if (_disposed) {
      return;
    }
    valueNotifier.value = value;
  }

  void _disposeNotifier() {
    if (!_disposed) {
      _disposed = true;
    }
    valueNotifier.dispose();
  }
}
