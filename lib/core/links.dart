import 'package:url_launcher/url_launcher.dart';

Future<void> openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

Future<void> openGitHub(String? url) async {
  if (url != null && url.startsWith('https://github.com/')) {
    await openUrl(url);
  }
}
