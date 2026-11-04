import 'package:flutter_test/flutter_test.dart';

import 'package:betelgeuse/core/app_info.dart';
import 'package:betelgeuse/core/profiles.dart';

void main() {
  test('Profile hace round-trip de sus metadatos', () {
    const profile = Profile(
      id: 'user-1',
      login: 'octocat',
      name: 'The Octocat',
      avatarUrl: 'https://avatars.githubusercontent.com/u/1',
      bio: 'Hola',
    );

    final restored = Profile.fromJson(profile.toJson());

    expect(restored.id, 'user-1');
    expect(restored.login, 'octocat');
    expect(restored.displayName, 'The Octocat');
    expect(restored.bio, 'Hola');
  });

  test('ReleaseInfo detecta versiones más nuevas', () {
    const release = ReleaseInfo(
      tag: 'v0.3.0',
      name: '0.3.0',
      url: 'https://github.com/example/repo/releases/tag/v0.3.0',
      notes: '',
    );

    expect(release.isNewerThan('0.2.0'), isTrue);
    expect(release.isNewerThan('0.3.0'), isFalse);
    expect(release.isNewerThan('0.4.0'), isFalse);
  });
}
