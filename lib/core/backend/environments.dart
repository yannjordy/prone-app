/// Environnements d'un projet : chaque connexion enregistree devient un
/// environnement (dev, prod, recette...). Le nom decide du niveau de
/// protection des ecritures, l'URL et la cle API de celui-ci.
class EnvironmentInfo {
  final String id;
  final String name;
  final String url;
  final String apiKey;
  const EnvironmentInfo({
    required this.id,
    required this.name,
    required this.url,
    required this.apiKey,
  });

  bool get isProduction => name.toLowerCase().contains('prod');
  bool get hasUrl => Environments.normalizeUrl(url).isNotEmpty;

  @override
  String toString() => name;
}

class Environments {
  static String normalizeUrl(String url) => url.trim().replaceAll(RegExp(r'/+$'), '');

  /// Comparaison insensible aux slashs finaux : deux libelles identiques
  /// (avec ou sans "/" final) designent le meme backend.
  static bool sameUrl(String a, String b) {
    final na = normalizeUrl(a);
    final nb = normalizeUrl(b);
    return na.isNotEmpty && na == nb;
  }

  static List<EnvironmentInfo> parse(List<Map<String, dynamic>> rows) {
    final out = <EnvironmentInfo>[];
    for (final r in rows) {
      final name = '${r['name'] ?? ''}'.trim();
      final url = '${r['url'] ?? ''}'.trim();
      if (name.isEmpty && url.isEmpty) continue;
      out.add(EnvironmentInfo(
        id: '${r['id'] ?? ''}',
        name: name.isEmpty ? url : name,
        url: url,
        apiKey: '${r['api_key'] ?? ''}',
      ));
    }
    return out;
  }

  /// Recherche par nom puis par identifiant, sans tenir compte de la casse.
  static EnvironmentInfo? find(List<EnvironmentInfo> envs, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final e in envs) {
      if (e.name.toLowerCase() == q) return e;
    }
    for (final e in envs) {
      if (e.id.toLowerCase() == q) return e;
    }
    for (final e in envs) {
      if (e.name.toLowerCase().startsWith(q)) return e;
    }
    return null;
  }

  /// L'environnement courant : celui dont l'URL correspond au backend actif.
  static EnvironmentInfo? active(List<EnvironmentInfo> envs, String activeUrl) {
    for (final e in envs) {
      if (sameUrl(e.url, activeUrl)) return e;
    }
    return null;
  }
}
