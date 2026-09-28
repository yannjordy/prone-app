class CommandLibrary {
  /// Catalogue purement declaratif : noms, descriptions, parametres.
  /// Aucune donnee n'est produite ici — chaque commande est executee
  /// contre le backend reel par l'ecran de chat (`_resolveCommand`).
  static final List<Command> commands = [
    // System
    Command(
      name: 'help',
      description: 'Afficher toutes les commandes',
      category: 'System',
      icon: 'assets/icons/alert-circle.svg',
    ),
    Command(
      name: 'status',
      description: 'Tester la connexion au backend',
      category: 'System',
      icon: 'assets/icons/activity.svg',
    ),
    Command(
      name: 'ping',
      description: 'Mesurer la latence reelle',
      category: 'System',
      icon: 'assets/icons/zap.svg',
    ),
    Command(
      name: 'protect',
      description: 'Rapport de surveillance du backend',
      category: 'System',
      icon: 'assets/icons/shield.svg',
    ),
    Command(
      name: 'alerts',
      description: 'Historique des erreurs backend',
      category: 'System',
      icon: 'assets/icons/bell.svg',
    ),
    Command(
      name: 'version',
      description: 'Version et backend connecte',
      category: 'System',
      icon: 'assets/icons/grid.svg',
    ),

    // Database
    Command(
      name: 'tables',
      description: 'Lister les tables du backend',
      category: 'Database',
      icon: 'assets/icons/grid.svg',
    ),
    Command(
      name: 'inspect',
      description: 'Ouvrir l\'inspecteur de tables',
      category: 'Database',
      icon: 'assets/icons/database.svg',
    ),
    Command(
      name: 'table',
      description: 'Afficher les lignes d\'une table',
      category: 'Database',
      icon: 'assets/icons/database.svg',
      params: ['nom'],
    ),
    Command(
      name: 'count',
      description: 'Compter les lignes d\'une table',
      category: 'Database',
      icon: 'assets/icons/users.svg',
      params: ['table'],
    ),
    Command(
      name: 'schema',
      description: 'Structure d\'une table',
      category: 'Database',
      icon: 'assets/icons/terminal.svg',
      params: ['table'],
    ),
    Command(
      name: 'last',
      description: 'Dernières entrées d\'une table',
      category: 'Database',
      icon: 'assets/icons/clock.svg',
      params: ['table', 'limit'],
    ),
    Command(
      name: 'search',
      description: 'Rechercher dans une table',
      category: 'Database',
      icon: 'assets/icons/search.svg',
      params: ['table', 'champ', 'valeur'],
    ),

    // API
    Command(
      name: 'endpoints',
      description: 'Endpoints reels detectes',
      category: 'API',
      icon: 'assets/icons/globe.svg',
    ),
    Command(
      name: 'requests',
      description: 'Requetes effectuees par Prone',
      category: 'API',
      icon: 'assets/icons/monitor.svg',
    ),
    Command(
      name: 'errors',
      description: 'Erreurs enregistrees',
      category: 'API',
      icon: 'assets/icons/alert-circle.svg',
    ),

    // Workflows
    Command(
      name: 'workflows',
      description: 'Lister vos workflows',
      category: 'Workflows',
      icon: 'assets/icons/connections.svg',
    ),
    Command(
      name: 'run',
      description: 'Executer un workflow',
      category: 'Workflows',
      icon: 'assets/icons/arrow-right.svg',
      params: ['id'],
    ),
    Command(
      name: 'history',
      description: 'Historique des executions',
      category: 'Workflows',
      icon: 'assets/icons/clock.svg',
    ),

    // Data
    Command(
      name: 'users',
      description: 'Utilisateurs du backend',
      category: 'Data',
      icon: 'assets/icons/users.svg',
      params: ['recherche'],
    ),
    Command(
      name: 'user',
      description: 'Detail d\'une ligne utilisateurs',
      category: 'Data',
      icon: 'assets/icons/profile.svg',
      params: ['id'],
    ),
    Command(
      name: 'orders',
      description: 'Dernières commandes',
      category: 'Data',
      icon: 'assets/icons/cart.svg',
      params: ['recherche'],
    ),
    Command(
      name: 'products',
      description: 'Produits du backend',
      category: 'Data',
      icon: 'assets/icons/grid.svg',
      params: ['recherche'],
    ),
  ];

  static Command? findCommand(String input) {
    if (!input.startsWith('/')) return null;
    final parts = input.substring(1).trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return null;
    final name = parts[0].toLowerCase();
    final params = parts.length > 1 ? parts.sublist(1).where((p) => p.isNotEmpty).toList() : <String>[];

    for (var cmd in commands) {
      if (cmd.name == name) {
        cmd.currentParams = params;
        return cmd;
      }
    }
    return null;
  }

  static String help() {
    final categories = <String, List<Command>>{};
    for (var cmd in commands) {
      categories.putIfAbsent(cmd.category, () => []).add(cmd);
    }

    var result = '📋 Commandes disponibles :\n\n';
    for (var entry in categories.entries) {
      result += '── ${entry.key} ──\n';
      for (var cmd in entry.value) {
        final params = cmd.params != null && cmd.params!.isNotEmpty ? ' <${cmd.params!.join(', ')}>' : '';
        result += '• /${cmd.name}$params - ${cmd.description}\n';
      }
      result += '\n';
    }
    result += '💡 Exemples :\n/status\n/count users\n/last orders 10\n/search users email john\n\n';
    result += 'Toutes les donnees proviennent de votre backend connecte.';
    return result;
  }
}

class Command {
  final String name;
  final String description;
  final String category;
  final String icon;
  final List<String>? params;
  List<String> currentParams = [];

  Command({
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    this.params,
  });
}
