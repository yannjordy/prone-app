import 'dart:convert';

/// Charge utile d'invitation a un projet Prone.
///
/// Elle transporte le nom du projet **ainsi que l'URL du backend et la cle
/// API** : c'est ce qui permet a une deuxieme personne de rejoindre le projet
/// comme un groupe WhatsApp et de voir exactement les memes donnees reelles
/// (les donnees ne viennent pas de Prone mais du backend deja connecte).
///
/// Le format est du base64url sur du JSON : c'est de l'encodage, pas du
/// chiffrement. Quiconque recoit le lien ou le QR possede la cle API.
class InvitePayload {
  static const int version = 1;
  static const String linkPrefix = 'prone://join/';
  static const String codePrefix = 'PRONE:';
  static const String legacyPrefix = 'prone://invite/';

  final String projectId;
  final String name;
  final String description;
  final String photo;
  final String backendUrl;
  final String apiKey;
  final String orgId;
  final String inviter;
  final String joinCode;
  final String createdAt;

  const InvitePayload({
    required this.projectId,
    required this.name,
    this.description = '',
    this.photo = '',
    this.backendUrl = '',
    this.apiKey = '',
    this.orgId = '',
    this.inviter = '',
    this.joinCode = '',
    this.createdAt = '',
  });

  bool get hasBackend => backendUrl.trim().isNotEmpty;

  /// Nom d'hote affichable (sans reveler l'entierete de l'URL).
  String get host {
    final raw = backendUrl.trim();
    if (raw.isEmpty) return '';
    try {
      final uri = Uri.parse(raw);
      return uri.host.isNotEmpty ? uri.host : raw;
    } catch (_) {
      return raw;
    }
  }

  /// Taille maximale d'un QR Code (niveau de correction M) en octets UTF-8.
  static const int maxQrBytes = 2900;

  /// Photo et description sont VOLONTAIREMENT absentes : une photo en base64
  /// fait des dizaines de Ko et depasse la capacite du QR (d'ou le code
  /// illisible). Elles arrivent par la synchro _prone_projects.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'v': version,
        'id': projectId,
        'n': name,
        'd': description.length > 120 ? description.substring(0, 120) : description,
        'u': backendUrl,
        'k': apiKey,
        'o': orgId,
        'b': inviter,
        'c': joinCode,
      };

  /// true si le lien tient dans un QR Code.
  bool get fitsQr => utf8.encode(link).length <= maxQrBytes;

  String encode() {
    final json = jsonEncode(toJson());
    final b64 = base64Url.encode(utf8.encode(json));
    return b64.replaceAll('=', '');
  }

  /// Lien complet, auto-suffisant : le receveur n'a besoin d'aucune info
  /// supplémentaire pour rejoindre.
  String get link => '$linkPrefix${encode()}';

  /// Code a copier/coller (meme charge utile, autre préfixe).
  String get code => '$codePrefix${encode()}';

  static String _pad(String s) {
    final mod = s.length % 4;
    return mod == 0 ? s : s + '=' * (4 - mod);
  }

  static InvitePayload? decode(String encoded) {
    var raw = encoded.trim();
    if (raw.isEmpty) return null;
    final lower = raw.toLowerCase();
    if (lower.startsWith(linkPrefix)) raw = raw.substring(linkPrefix.length);
    if (raw.toUpperCase().startsWith(codePrefix)) raw = raw.substring(codePrefix.length);
    if (raw.isEmpty) return null;
    try {
      final bytes = base64Url.decode(_pad(raw));
      final json = jsonDecode(utf8.decode(bytes));
      if (json is! Map<String, dynamic>) return null;
      final id = json['id'];
      final name = json['n'];
      if (id is! String || id.isEmpty) return null;
      if (name is! String || name.isEmpty) return null;
      return InvitePayload(
        projectId: id,
        name: name,
        description: json['d'] is String ? json['d'] as String : '',
        photo: json['p'] is String ? json['p'] as String : '',
        backendUrl: json['u'] is String ? json['u'] as String : '',
        apiKey: json['k'] is String ? json['k'] as String : '',
        orgId: json['o'] is String ? json['o'] as String : '',
        inviter: json['b'] is String ? json['b'] as String : '',
        joinCode: json['c'] is String ? json['c'] as String : '',
        createdAt: json['t'] is String ? json['t'] as String : '',
      );
    } catch (_) {
      return null;
    }
  }

  /// Analyse n'importe quelle forme d'entree : QR scanne, lien, code, texte
  /// brut colle. Retourne null si le contenu est illisible.
  static InvitePayload? tryParse(String input) {
    var raw = input.trim();
    if (raw.isEmpty) return null;
    final lower = raw.toLowerCase();
    if (lower.startsWith(linkPrefix)) {
      raw = raw.substring(linkPrefix.length);
    } else if (lower.startsWith(legacyPrefix)) {
      return null;
    } else if (raw.contains('://')) {
      return null;
    }
    return decode(raw);
  }

  /// Anciens QR `prone://invite/<idProjet>` : ne contiennent aucune donnee
  /// backend, on recupere juste l'id pour une reprise sur le meme appareil.
  static String? legacyProjectId(String input) {
    final raw = input.trim();
    final lower = raw.toLowerCase();
    if (!lower.startsWith(legacyPrefix)) return null;
    final rest = raw.substring(legacyPrefix.length);
    final id = rest.split(RegExp(r'[/?#\s]')).first;
    return id.isEmpty ? null : id;
  }

  factory InvitePayload.fromProject(
    Map<String, dynamic> project, {
    required String inviter,
    String orgId = '',
    String joinCode = '',
  }) {
    String str(String key) {
      final v = project[key];
      return v is String ? v : '';
    }

    return InvitePayload(
      projectId: str('id'),
      name: str('name'),
      description: str('description'),
      photo: str('photo'),
      backendUrl: str('backend_url'),
      apiKey: str('api_key'),
      orgId: orgId.isNotEmpty ? orgId : str('organization_id'),
      inviter: inviter,
      joinCode: joinCode.isNotEmpty ? joinCode : str('join_code'),
      createdAt: DateTime.now().toIso8601String(),
    );
  }
}
