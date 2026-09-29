import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

/// Source unique de verite pour l'identite de l'utilisateur de cet appareil.
///
/// La page Profil ecrit ici ; la creation de projet, la rejoindre, la
/// creation d'organisation, les invitations et les mentions lisent ici.
/// Les cles sont les memes que celles utilisees par l'ecran Profil
/// historiquement, donc aucun donnee existante n'est perdue.
class UserProfile {
  static const String keyName = 'profile_name';
  static const String keyEmail = 'profile_email';
  static const String keyPhone = 'profile_phone';
  static const String keyBio = 'profile_bio';
  static const String keyPhoto = 'profile_photo';
  static const String keyLanguage = 'profile_language';

  static const List<String> requiredKeys = [
    keyName,
    keyEmail,
    keyPhone,
    keyBio,
    keyPhoto,
    keyLanguage,
  ];

  static Future<Map<String, String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(keyName) ?? '',
      'email': prefs.getString(keyEmail) ?? '',
      'phone': prefs.getString(keyPhone) ?? '',
      'bio': prefs.getString(keyBio) ?? '',
      'language': prefs.getString(keyLanguage) ?? 'Francais',
      'photo': prefs.getString(keyPhoto) ?? '',
    };
  }

  static Future<void> save({
    String? name,
    String? email,
    String? phone,
    String? bio,
    String? language,
    String? photo,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (name != null) await prefs.setString(keyName, name);
    if (email != null) await prefs.setString(keyEmail, email);
    if (phone != null) await prefs.setString(keyPhone, phone);
    if (bio != null) await prefs.setString(keyBio, bio);
    if (language != null) await prefs.setString(keyLanguage, language);
    if (photo != null) await prefs.setString(keyPhoto, photo);
  }

  static Future<String> name() async => (await load())['name']!.trim();

  static Future<String> email() async => (await load())['email']!.trim();

  static Future<String> photo() async => (await load())['photo']!;

  static Future<Uint8List?> photoBytes() async {
    final raw = await photo();
    if (raw.isEmpty) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<String> initials() async {
    final n = await name();
    if (n.isEmpty) return '?';
    return n
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase();
  }

  /// Nom affichable : profil si renseigne, sinon une valeur de repli.
  static Future<String> displayName({String fallback = 'Moi'}) async {
    final n = await name();
    return n.isEmpty ? fallback : n;
  }

  /// Taille en octets de l'identite partagee (nom + email, sans la photo).
  static Future<int> sharedIdentityBytes() async {
    final p = await load();
    return utf8.encode('${p['name']}\n${p['email']}').length;
  }
}

/// Formatage de taille lisible, utilise pour afficher ce qui partage.
String formatDataSize(int bytes) {
  if (bytes < 1024) return '$bytes o';
  if (bytes < 1024 * 1024) {
    final ko = bytes / 1024;
    return '${ko.toStringAsFixed(ko < 10 ? 1 : 0)} Ko';
  }
  final mo = bytes / (1024 * 1024);
  return '${mo.toStringAsFixed(mo < 10 ? 2 : 0)} Mo';
}
