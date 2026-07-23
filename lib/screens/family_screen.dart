import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../data/family_prefs.dart';
import '../models/family_models.dart';
import '../services/chat_service.dart';
import '../services/family_service.dart';
import '../theme.dart';
import 'qr_scan_screen.dart';

/// Gestion de la famille : création, adhésion, membres, invitations.
class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _prefs = FamilyPrefs.instance;
  final _svc = FamilyService.instance;

  List<FamilyMember> _members = [];
  List<FamilyInvitation> _invites = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_prefs.hasFamily) _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final members = await _svc.members();
      final invites = _prefs.isCreator ? await _svc.invitations() : <FamilyInvitation>[];
      if (!mounted) return;
      setState(() {
        _members = members;
        _invites = invites;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
      if (!mounted) return;
      setState(() {});
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      _snack(e.toString());
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: Text(_prefs.hasFamily ? (_prefs.familyName ?? 'Famille') : 'Famille'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: _loading && _members.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _prefs.hasFamily
                ? _buildFamily(p)
                : _buildNoFamily(p),
          ),
        ),
      ),
    );
  }

  // ─────────────── Pas encore de famille ───────────────

  Widget _buildNoFamily(AppPalette p) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.family_restroom, size: 64, color: p.chat),
          const SizedBox(height: 16),
          Text(
            'Créez votre famille pour partager le suivi de bébé et discuter avec vos proches.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: p.textMuted),
          ),
          const SizedBox(height: 32),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.chat,
              foregroundColor: p.onAccent,
              minimumSize: const Size.fromHeight(60),
              textStyle:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            onPressed: _showCreateDialog,
            child: const Text('Créer ma famille'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: p.chat,
              minimumSize: const Size.fromHeight(60),
              textStyle:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            onPressed: _showJoinDialog,
            child: const Text('Rejoindre une famille'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent)),
          ],
        ],
      ),
    );
  }

  Future<void> _showCreateDialog() async {
    final familyCtrl = TextEditingController(text: 'Ma famille');
    final nameCtrl = TextEditingController(text: _prefs.displayName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Créer ma famille'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: familyCtrl,
              decoration: const InputDecoration(labelText: 'Nom de la famille'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Votre prénom'),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Créer')),
        ],
      ),
    );
    if (ok != true) return;
    if (nameCtrl.text.trim().isEmpty) return _snack('Prénom requis');
    await _run(() async {
      await _svc.createFamily(
        familyName: familyCtrl.text.trim(),
        displayName: nameCtrl.text.trim(),
      );
      ChatService.instance.connect();
    });
  }

  Future<void> _showJoinDialog() async {
    final tokenCtrl = TextEditingController();
    final nameCtrl = TextEditingController(text: _prefs.displayName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Rejoindre une famille'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tokenCtrl,
                decoration: const InputDecoration(
                  labelText: 'Lien ou code d\'invitation',
                  hintText: 'Collez le lien reçu',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              // Alternative au collage : scanner le QR du créateur.
              OutlinedButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scanner le QR code'),
                onPressed: () async {
                  final scanned = await Navigator.of(ctx).push<String>(
                    MaterialPageRoute(builder: (_) => const QrScanScreen()),
                  );
                  if (scanned != null) {
                    setDialogState(() => tokenCtrl.text = scanned);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Votre prénom'),
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Rejoindre')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (tokenCtrl.text.trim().isEmpty) return _snack('Lien requis');
    if (nameCtrl.text.trim().isEmpty) return _snack('Prénom requis');
    await _run(() async {
      await _svc.joinFamily(
        inviteToken: tokenCtrl.text.trim(),
        displayName: nameCtrl.text.trim(),
      );
      ChatService.instance.connect();
    });
  }

  // ─────────────── Famille existante ───────────────

  Widget _buildFamily(AppPalette p) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _sectionTitle('Membres', p),
          for (final m in _members) _memberTile(m, p),
          const SizedBox(height: 24),
          if (_prefs.isCreator) ...[
            _sectionTitle('Inviter', p),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: p.chat,
                foregroundColor: p.onAccent,
                minimumSize: const Size.fromHeight(56),
              ),
              icon: const Icon(Icons.qr_code_2),
              label: const Text('Générer une invitation',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              onPressed: _createInvitation,
            ),
            const SizedBox(height: 16),
            if (_invites.isNotEmpty) ...[
              _sectionTitle('Liens actifs', p),
              for (final i in _invites) _inviteTile(i, p),
            ],
          ] else ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Quitter la famille'),
              onPressed: _confirmLeave,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String s, AppPalette p) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
    child: Text(
      s.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 1,
        fontWeight: FontWeight.w700,
        color: p.textMuted,
      ),
    ),
  );

  Widget _memberTile(FamilyMember m, AppPalette p) {
    final isMe = m.deviceId == _prefs.deviceId;
    return Card(
      color: p.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (m.isCreator ? p.chat : p.history)
              .withValues(alpha: 0.18),
          child: Text(
            m.displayName.isNotEmpty ? m.displayName[0].toUpperCase() : '?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: m.isCreator ? p.chat : p.history,
            ),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                m.displayName + (isMe ? ' (moi)' : ''),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (m.isCreator) ...[
              const SizedBox(width: 6),
              Icon(Icons.star_rounded, size: 16, color: p.chat),
            ],
          ],
        ),
        subtitle: Text(
          'Depuis le ${DateFormat('d MMM', 'fr').format(m.joinedAt)}',
          style: TextStyle(color: p.textMuted, fontSize: 12),
        ),
        // Le créateur peut retirer les autres, jamais lui-même.
        trailing: (_prefs.isCreator && !m.isCreator)
            ? IconButton(
          icon: const Icon(Icons.person_remove_outlined),
          color: Colors.redAccent,
          onPressed: () => _confirmRemove(m),
        )
            : null,
      ),
    );
  }

  Widget _inviteTile(FamilyInvitation i, AppPalette p) {
    final expired = i.expiresAt.isBefore(DateTime.now());
    return Card(
      color: p.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(Icons.link, color: expired ? p.textMuted : p.measure),
        title: Text(
          i.token.substring(0, i.token.length.clamp(0, 8)),
          style: const TextStyle(
              fontFamily: 'monospace', fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          expired
              ? 'Expiré'
              : 'Expire le ${DateFormat('d MMM à HH:mm', 'fr').format(i.expiresAt)}',
          style: TextStyle(
            color: expired ? Colors.redAccent : p.textMuted,
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.qr_code_2),
              onPressed: () => _showInviteSheet(i),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Colors.redAccent,
              onPressed: () => _run(() => _svc.revokeInvitation(i.token)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createInvitation() async {
    setState(() => _loading = true);
    try {
      final inv = await _svc.createInvitation();
      if (!mounted) return;
      setState(() => _loading = false);
      await _showInviteSheet(inv);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(e.toString());
    }
  }

  /// Feuille d'invitation : QR code à scanner + lien à partager.
  Future<void> _showInviteSheet(FamilyInvitation inv) {
    final p = context.palette;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Inviter un proche',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Faites scanner ce QR code, ou envoyez le lien.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  // Fond blanc obligatoire : un QR sur fond sombre
                  // n'est pas lisible par la plupart des scanners.
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: QrImageView(
                  data: inv.url,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SelectableText(
              inv.url,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: p.textMuted),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.chat,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copier'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: inv.url));
                      HapticFeedback.lightImpact();
                      _snack('Lien copié');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: p.chat,
                      foregroundColor: p.onAccent,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: const Icon(Icons.share),
                    label: const Text('Partager'),
                    onPressed: () => Share.share(
                      'Rejoins notre famille sur BibiTrack : ${inv.url}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Expire le ${DateFormat('d MMMM à HH:mm', 'fr').format(inv.expiresAt)}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: p.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(FamilyMember m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Retirer ${m.displayName} ?'),
        content: const Text(
          'Cette personne perdra immédiatement l\'accès au tchat et au suivi de bébé.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (ok == true) await _run(() => _svc.removeMember(m.deviceId));
  }

  Future<void> _confirmLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter la famille ?'),
        content: const Text(
            'Vous n\'aurez plus accès au tchat ni au suivi partagé.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _svc.leave();
    ChatService.instance.disconnect();
    if (!mounted) return;
    setState(() {
      _members = [];
      _invites = [];
    });
  }
}