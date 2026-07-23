import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../data/app_settings.dart';
import '../data/family_prefs.dart';
import '../models/family_models.dart';

/// Tchat temps réel via WebSocket STOMP.
///
/// Le serveur expose /ws (SockJS désactivé, WebSocket natif).
/// - abonnement : /topic/families/{familyId}/chat
/// - envoi      : /app/families/{familyId}/chat
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  StompClient? _client;
  final _controller = StreamController<ChatMessage>.broadcast();
  final _connected = StreamController<bool>.broadcast();

  /// Messages entrants (temps réel).
  Stream<ChatMessage> get messages => _controller.stream;

  /// État de la connexion, pour afficher un bandeau "hors ligne".
  Stream<bool> get connectionState => _connected.stream;

  bool get isConnected => _client?.connected ?? false;

  FamilyPrefs get _prefs => FamilyPrefs.instance;

  /// Transforme http(s)://host/... en ws(s)://host/ws
  String get _wsUrl {
    final base = AppSettings.instance.apiBaseUrl;
    final uri = Uri.parse(base);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://${uri.authority}/ws';
  }

  void connect() {
    if (!_prefs.hasFamily) return;
    if (_client?.connected ?? false) return;

    _client = StompClient(
      config: StompConfig(
        url: _wsUrl,
        onConnect: _onConnect,
        onWebSocketError: (e) => _connected.add(false),
        onDisconnect: (_) => _connected.add(false),
        // Le handshake porte le JWT : le serveur valide dans un
        // ChannelInterceptor et refuse la connexion si le token est
        // invalide ou si le membre a été retiré de la famille.
        stompConnectHeaders: {
          'Authorization': 'Bearer ${_prefs.authToken}',
          'X-Device-Id': _prefs.deviceId,
        },
        webSocketConnectHeaders: {
          'Authorization': 'Bearer ${_prefs.authToken}',
        },
        reconnectDelay: const Duration(seconds: 5),
      ),
    );
    _client!.activate();
  }

  void _onConnect(StompFrame frame) {
    _connected.add(true);
    _client!.subscribe(
      destination: '/topic/families/${_prefs.familyId}/chat',
      callback: (f) {
        if (f.body == null) return;
        try {
          final json = jsonDecode(f.body!) as Map<String, dynamic>;
          _controller.add(ChatMessage.fromJson(json));
        } catch (_) {
          // Message malformé : on ignore plutôt que de casser le stream.
        }
      },
    );
  }

  void send(String text) {
    final t = text.trim();
    if (t.isEmpty || !isConnected) return;
    _client!.send(
      destination: '/app/families/${_prefs.familyId}/chat',
      body: jsonEncode({
        'text': t,
        'senderId': _prefs.deviceId,
        'senderName': _prefs.displayName,
      }),
    );
  }

  void disconnect() {
    _client?.deactivate();
    _client = null;
    _connected.add(false);
  }
}
