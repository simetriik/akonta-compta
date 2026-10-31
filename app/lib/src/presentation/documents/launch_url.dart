import 'package:url_launcher/url_launcher.dart';
import '../../core/errors/errors.dart';

/// Ouvre une URL dans le navigateur ou l'application associée.
Future<void> launchExternalUrl(String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw const AppError.business('Impossible d\'ouvrir ce lien.');
  }
}
