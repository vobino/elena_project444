import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../data/app_settings.dart';
import '../services/sync_service.dart';
import '../theme.dart';

/// Tchat : fonctionnalité en ligne uniquement.
/// Contrat REST (backend Spring Boot) :
///   POST {base}/api/v1/chat   body = {"message": "..."}  -> {"reply": "..."}
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final List<({bool me, String text})> _messages = [];
  bool _online = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    SyncService.instance.isOnline.then((v) {
      if (mounted) setState(() => _online = v);
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add((me: true, text: text));
      _controller.clear();
      _sending = true;
    });
    try {
      final base = AppSettings.instance.apiBaseUrl;
      final res = await http
          .post(Uri.parse('$base/api/v1/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'message': text}))
          .timeout(const Duration(seconds: 20));
      final reply = res.statusCode == 200
          ? (jsonDecode(res.body)['reply'] as String? ?? '…')
          : 'Service indisponible (${res.statusCode}).';
      if (mounted) setState(() => _messages.add((me: false, text: reply)));
    } catch (_) {
      if (mounted) {
        setState(() => _messages.add(
            (me: false, text: 'Connexion impossible. Réessaie plus tard.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Tchat')),
      body: !_online
          ? const _OfflineNotice(
          text:
          'Le tchat nécessite une connexion internet.\nToutes les autres fonctions restent disponibles hors ligne.')
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                return Align(
                  alignment: m.me
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(
                      color: m.me
                          ? p.chat.withValues(alpha: 0.25)
                          : p.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(m.text,
                        style: const TextStyle(fontSize: 16)),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Écris un message…',
                        border: OutlineInputBorder(
                          borderRadius:
                          BorderRadius.all(Radius.circular(24)),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paramètres : accessibles en ligne uniquement. Activation d'abonnement,
/// puis (et seulement alors) édition du nom de l'enfant.
/// Contrat REST : POST {base}/api/v1/subscription/activate -> 200 {"active": true}
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _online = false;
  bool _loadingSub = false;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: AppSettings.instance.childName);
    _urlCtrl = TextEditingController(text: AppSettings.instance.apiBaseUrl);
    SyncService.instance.isOnline.then((v) {
      if (mounted) setState(() => _online = v);
    });
  }

  Future<void> _activate() async {
    setState(() => _loadingSub = true);
    try {
      final base = AppSettings.instance.apiBaseUrl;
      final res = await http
          .post(Uri.parse('$base/api/v1/subscription/activate'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        await AppSettings.instance.setSubscriptionActive(true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Activation impossible pour le moment.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur réseau.')));
      }
    } finally {
      if (mounted) setState(() => _loadingSub = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = AppSettings.instance.subscriptionActive;

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: !_online
          ? const _OfflineNotice(
          text:
          'Les paramètres nécessitent une connexion internet.\nLe suivi reste disponible hors ligne.')
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // URL de l'API (utile en dev pour pointer vers Spring Boot local)
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: 'URL du serveur',
              helperText: 'Ex. http://10.0.2.2:8080 (émulateur Android)',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) =>
                AppSettings.instance.setApiBaseUrl(v.trim()),
          ),
          const SizedBox(height: 24),

          if (!sub) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Abonnement requis',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text(
                      "Active ton abonnement pour personnaliser l'application (nom de l'enfant).",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadingSub ? null : _activate,
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52)),
                      child: _loadingSub
                          ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2))
                          : const Text("Activer l'abonnement"),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: "Nom de l'enfant",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                await AppSettings.instance
                    .setChildName(_nameCtrl.text.trim());
                if (context.mounted) Navigator.of(context).pop();
              },
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: const Text('Enregistrer'),
            ),
          ],
        ],
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  final String text;
  const _OfflineNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off,
                size: 64, color: p.text.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}