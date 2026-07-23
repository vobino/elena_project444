import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/app_settings.dart';
import '../data/family_prefs.dart';
import '../models/family_models.dart';
import '../services/chat_service.dart';
import '../services/family_service.dart';
import '../theme.dart';
import 'family_screen.dart';

/// Tchat familial temps réel (WebSocket STOMP).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _prefs = FamilyPrefs.instance;
  final _chat = ChatService.instance;
  final _input = TextEditingController();
  final _scroll = ScrollController();

  final List<ChatMessage> _messages = [];
  StreamSubscription<ChatMessage>? _msgSub;
  StreamSubscription<bool>? _connSub;
  bool _online = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (_prefs.hasFamily) _start();
  }

  Future<void> _start() async {
    _msgSub = _chat.messages.listen((m) {
      setState(() => _messages.add(m));
      _scrollToBottom();
    });
    _connSub = _chat.connectionState.listen((c) {
      if (mounted) setState(() => _online = c);
    });
    _chat.connect();

    try {
      final history = await FamilyService.instance.messageHistory();
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(history);
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _connSub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    HapticFeedback.lightImpact();
    _chat.send(t);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    // Sans famille, on redirige vers l'écran de création.
    if (!_prefs.hasFamily) {
      return Scaffold(
        backgroundColor: p.bg,
        appBar: AppBar(
          title: const Text('Tchat'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.forum_outlined, size: 64, color: p.chat),
                const SizedBox(height: 16),
                Text(
                  'Le tchat est réservé aux membres de votre famille.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: p.textMuted),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: p.chat,
                    foregroundColor: p.onAccent,
                    minimumSize: const Size(220, 56),
                  ),
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const FamilyScreen()));
                    if (!mounted) return;
                    setState(() {});
                    if (_prefs.hasFamily) _start();
                  },
                  child: const Text('Configurer ma famille'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: Text(_prefs.familyName ?? 'Tchat'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.group_outlined),
            tooltip: 'Membres',
            onPressed: () async {
              await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FamilyScreen()));
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                if (!_online)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    color: Colors.orange.withValues(alpha: 0.2),
                    child: Text(
                      'Reconnexion…',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: p.text),
                    ),
                  ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _messages.isEmpty
                          ? Center(
                              child: Text(
                                'Aucun message.\nDites bonjour 👋',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: p.textMuted),
                              ),
                            )
                          : ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.all(12),
                              itemCount: _messages.length,
                              itemBuilder: (_, i) => _bubble(_messages[i], p),
                            ),
                ),
                _composer(p),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bubble(ChatMessage m, AppPalette p) {
    final mine = m.senderId == _prefs.deviceId;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? p.chat : p.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!mine)
              Text(
                m.senderName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: p.history,
                ),
              ),
            Text(
              m.text,
              style: TextStyle(
                fontSize: 15,
                color: mine ? p.onAccent : p.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat.Hm().format(m.sentAt),
              style: TextStyle(
                fontSize: 10,
                color: (mine ? p.onAccent : p.textMuted)
                    .withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer(AppPalette p) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Message…',
                filled: true,
                fillColor: p.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.chat,
              foregroundColor: p.onAccent,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(14),
            ),
            onPressed: _online ? _send : null,
            child: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// Réglages (conservé ici : settings_screen.dart ré-exporte ce fichier)
/// ─────────────────────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlCtrl = TextEditingController();
  final _childCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = AppSettings.instance.apiBaseUrl;
    _childCtrl.text = AppSettings.instance.childName;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _childCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: const Text('Réglages'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextField(
                  controller: _childCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Prénom de l\'enfant',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (v) =>
                      AppSettings.instance.setChildName(v.trim()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL du serveur',
                    hintText: 'https://api.exemple.be',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                  onChanged: (v) =>
                      AppSettings.instance.setApiBaseUrl(v.trim()),
                ),
                const SizedBox(height: 24),
                Card(
                  color: p.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: Icon(Icons.family_restroom, color: p.chat),
                    title: Text(FamilyPrefs.instance.hasFamily
                        ? (FamilyPrefs.instance.familyName ?? 'Ma famille')
                        : 'Configurer ma famille'),
                    subtitle: Text(
                      FamilyPrefs.instance.hasFamily
                          ? (FamilyPrefs.instance.isCreator
                              ? 'Vous êtes le créateur'
                              : 'Membre')
                          : 'Partager le suivi et le tchat',
                      style: TextStyle(color: p.textMuted, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const FamilyScreen()));
                      if (mounted) setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
