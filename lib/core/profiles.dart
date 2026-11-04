import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../github/models.dart';

class Profile {
  final String id;
  final String login;
  final String? name;
  final String? avatarUrl;
  final String? bio;

  const Profile({
    required this.id,
    required this.login,
    this.name,
    this.avatarUrl,
    this.bio,
  });

  factory Profile.fromUser(GithubUser user) => Profile(
    id: user.id,
    login: user.login,
    name: user.name,
    avatarUrl: user.avatarUrl,
    bio: user.bio,
  );

  String get displayName =>
      name?.trim().isNotEmpty == true ? name!.trim() : login;

  String get githubUrl => 'https://github.com/$login';

  Map<String, dynamic> toJson() => {
    'id': id,
    'login': login,
    'name': name,
    'avatarUrl': avatarUrl,
    'bio': bio,
  };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    login: json['login'] as String,
    name: json['name'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    bio: json['bio'] as String?,
  );
}

class ProfileStore {
  static const _profilesKey = 'betelgeuse_profiles';
  static const _activeKey = 'betelgeuse_active_profile';
  static const _legacyTokenKey = 'betelgeuse_token';
  static const _tokenPrefix = 'betelgeuse_token_';

  static const _secure = FlutterSecureStorage();

  Future<List<Profile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profilesKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final item in list)
          Profile.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> saveProfile(Profile profile) async {
    final profiles = await loadProfiles();
    final index = profiles.indexWhere((p) => p.id == profile.id);
    if (index == -1) {
      profiles.add(profile);
    } else {
      profiles[index] = profile;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _profilesKey,
      jsonEncode([for (final p in profiles) p.toJson()]),
    );
  }

  Future<void> removeProfile(String id) async {
    final profiles = await loadProfiles();
    profiles.removeWhere((p) => p.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _profilesKey,
      jsonEncode([for (final p in profiles) p.toJson()]),
    );
    await _secure.delete(key: '$_tokenPrefix$id');
    if (await loadActiveId() == id) await setActiveId(null);
  }

  Future<String?> loadActiveId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeKey);
  }

  Future<void> setActiveId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_activeKey);
    } else {
      await prefs.setString(_activeKey, id);
    }
  }

  Future<String?> tokenFor(String id) => _secure.read(key: '$_tokenPrefix$id');

  Future<void> saveToken(String id, String token) =>
      _secure.write(key: '$_tokenPrefix$id', value: token);

  Future<String?> readLegacyToken() => _secure.read(key: _legacyTokenKey);

  Future<void> clearLegacyToken() => _secure.delete(key: _legacyTokenKey);
}
