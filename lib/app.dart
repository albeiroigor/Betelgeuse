import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/profiles.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'features/board/board_page.dart';
import 'features/login/login_page.dart';
import 'github/client.dart';

class BetelgeuseApp extends StatelessWidget {
  const BetelgeuseApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeNotifier()..load(),
      child: Consumer<ThemeNotifier>(
        builder: (_, themeNotifier, _) {
          final theme = AppThemes.of(themeNotifier.current);
          return MaterialApp(
            title: 'Betelgeuse',
            debugShowCheckedModeBanner: false,
            theme: theme.theme,
            home: const Gate(),
          );
        },
      ),
    );
  }
}

class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  final _store = ProfileStore();

  List<Profile> profiles = [];
  Profile? active;
  String? token;
  GitHub? _gh;
  bool ready = false;
  bool adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var loaded = await _store.loadProfiles();
    var activeId = await _store.loadActiveId();

    if (loaded.isEmpty) {
      final legacy = await _store.readLegacyToken();
      if (legacy != null) {
        final gh = GitHub(legacy);
        try {
          final user = await gh.me();
          final profile = Profile.fromUser(user);
          await _store.saveProfile(profile);
          await _store.saveToken(profile.id, legacy);
          await _store.setActiveId(profile.id);
          loaded = [profile];
          activeId = profile.id;
        } catch (_) {
          const profile = Profile(id: 'legacy', login: 'GitHub');
          await _store.saveProfile(profile);
          await _store.saveToken(profile.id, legacy);
          await _store.setActiveId(profile.id);
          loaded = [profile];
          activeId = profile.id;
        }
        await _store.clearLegacyToken();
      }
    }

    Profile? current;
    String? token;
    if (loaded.isNotEmpty) {
      final preferred = loaded.firstWhere(
        (p) => p.id == activeId,
        orElse: () => loaded.first,
      );
      final ordered = [preferred, ...loaded.where((p) => p.id != preferred.id)];
      for (final profile in ordered) {
        final stored = await _store.tokenFor(profile.id);
        if (stored != null) {
          current = profile;
          token = stored;
          break;
        }
        await _store.removeProfile(profile.id);
      }
      loaded = await _store.loadProfiles();
      await _store.setActiveId(current?.id);
    }

    if (!mounted) return;
    setState(() {
      profiles = loaded;
      active = current;
      this.token = token;
      _gh = token == null ? null : GitHub(token);
      ready = true;
    });
  }

  Future<void> _login(String newToken) async {
    final gh = GitHub(newToken);
    final user = await gh.me();
    final profile = Profile.fromUser(user);
    await _store.saveProfile(profile);
    await _store.saveToken(profile.id, newToken);
    await _store.setActiveId(profile.id);
    final updated = await _store.loadProfiles();
    if (!mounted) return;
    setState(() {
      profiles = updated;
      active = profile;
      token = newToken;
      _gh = gh;
      adding = false;
    });
  }

  Future<void> _switchProfile(String id) async {
    final profile = profiles.firstWhere((p) => p.id == id);
    final newToken = await _store.tokenFor(id);
    if (newToken == null) {
      await _store.removeProfile(id);
      final updated = await _store.loadProfiles();
      if (!mounted) return;
      setState(() => profiles = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esa cuenta ya no tiene sesión guardada.'),
        ),
      );
      return;
    }
    await _store.setActiveId(id);
    if (!mounted) return;
    setState(() {
      active = profile;
      token = newToken;
      _gh = GitHub(newToken);
      adding = false;
    });
  }

  Future<void> _logout() async {
    final current = active;
    if (current == null) return;
    await _store.removeProfile(current.id);
    final remaining = await _store.loadProfiles();
    Profile? next;
    String? nextToken;
    if (remaining.isNotEmpty) {
      next = remaining.first;
      nextToken = await _store.tokenFor(next.id);
      await _store.setActiveId(nextToken == null ? null : next.id);
    }
    if (!mounted) return;
    setState(() {
      profiles = remaining;
      active = nextToken == null ? null : next;
      token = nextToken;
      _gh = nextToken == null ? null : GitHub(nextToken);
      adding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (adding || active == null || token == null) {
      return Login(
        onToken: _login,
        onCancel: active == null ? null : () => setState(() => adding = false),
      );
    }
    return BoardPage(
      key: ValueKey(active!.id),
      gh: _gh!,
      profile: active!,
      profiles: profiles,
      onSwitchProfile: _switchProfile,
      onAddProfile: () => setState(() => adding = true),
      onLogout: _logout,
    );
  }
}
