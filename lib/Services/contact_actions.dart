import 'package:url_launcher/url_launcher.dart';

String _intl(String phone) {
  final p = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (p.startsWith('+')) return p.substring(1);
  if (p.startsWith('00')) return p.substring(2);
  if (p.startsWith('0')) return '250${p.substring(1)}';
  if (p.startsWith('250')) return p;
  return '250$p';
}

Future<bool> callNumber(String phone) async {
  try {
    return await launchUrl(
      Uri(scheme: 'tel', path: phone.replaceAll(' ', '')),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}

Future<bool> openWhatsApp(String phone, String message) async {
  try {
    return await launchUrl(
      Uri.parse('https://wa.me/${_intl(phone)}?text=${Uri.encodeComponent(message)}'),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}