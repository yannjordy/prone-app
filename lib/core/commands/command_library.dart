import 'package:flutter/material.dart';
import '../../app/app.dart';

class CommandLibrary {
  static final List<Command> commands = [
    // System
    Command(
      name: 'help',
      description: 'Afficher toutes les commandes',
      category: 'System',
      icon: 'assets/icons/alert-circle.svg',
      execute: (params) => _help(),
    ),
    Command(
      name: 'status',
      description: 'État général du projet',
      category: 'System',
      icon: 'assets/icons/activity.svg',
      execute: (params) => _status(),
    ),
    Command(
      name: 'ping',
      description: 'Test de connexion',
      category: 'System',
      icon: 'assets/icons/zap.svg',
      execute: (params) => _ping(),
    ),
    Command(
      name: 'restart',
      description: 'Redémarrer le service',
      category: 'System',
      icon: 'assets/icons/log-out.svg',
      execute: (params) => _restart(),
    ),
    Command(
      name: 'version',
      description: 'Version du projet',
      category: 'System',
      icon: 'assets/icons/grid.svg',
      execute: (params) => _version(),
    ),
    Command(
      name: 'uptime',
      description: 'Temps de fonctionnement',
      category: 'System',
      icon: 'assets/icons/clock.svg',
      execute: (params) => _uptime(),
    ),

    // Database
    Command(
      name: 'tables',
      description: 'Lister toutes les tables',
      category: 'Database',
      icon: 'assets/icons/grid.svg',
      execute: (params) => _tables(),
    ),
    Command(
      name: 'count',
      description: 'Compter les lignes d\'une table',
      category: 'Database',
      icon: 'assets/icons/users.svg',
      params: ['table'],
      execute: (params) => _count(params),
    ),
    Command(
      name: 'query',
      description: 'Exécuter une requête SQL',
      category: 'Database',
      icon: 'assets/icons/search.svg',
      params: ['sql'],
      execute: (params) => _query(params),
    ),
    Command(
      name: 'schema',
      description: 'Structure d\'une table',
      category: 'Database',
      icon: 'assets/icons/terminal.svg',
      params: ['table'],
      execute: (params) => _schema(params),
    ),
    Command(
      name: 'last',
      description: 'Dernières entrées d\'une table',
      category: 'Database',
      icon: 'assets/icons/clock.svg',
      params: ['table', 'limit'],
      execute: (params) => _last(params),
    ),
    Command(
      name: 'search',
      description: 'Rechercher dans une table',
      category: 'Database',
      icon: 'assets/icons/search.svg',
      params: ['table', 'field', 'value'],
      execute: (params) => _search(params),
    ),

    // API
    Command(
      name: 'endpoints',
      description: 'Lister les endpoints API',
      category: 'API',
      icon: 'assets/icons/globe.svg',
      execute: (params) => _endpoints(),
    ),
    Command(
      name: 'requests',
      description: 'Dernières requêtes API',
      category: 'API',
      icon: 'assets/icons/monitor.svg',
      execute: (params) => _requests(),
    ),
    Command(
      name: 'errors',
      description: 'Erreurs récentes',
      category: 'API',
      icon: 'assets/icons/alert-circle.svg',
      execute: (params) => _errors(),
    ),
    Command(
      name: 'health',
      description: 'Santé des services',
      category: 'API',
      icon: 'assets/icons/activity.svg',
      execute: (params) => _health(),
    ),

    // Workflows
    Command(
      name: 'workflows',
      description: 'Lister les workflows',
      category: 'Workflows',
      icon: 'assets/icons/connections.svg',
      execute: (params) => _workflows(),
    ),
    Command(
      name: 'run',
      description: 'Exécuter un workflow',
      category: 'Workflows',
      icon: 'assets/icons/arrow-right.svg',
      params: ['id'],
      execute: (params) => _run(params),
    ),
    Command(
      name: 'history',
      description: 'Historique des exécutions',
      category: 'Workflows',
      icon: 'assets/icons/clock.svg',
      execute: (params) => _history(),
    ),

    // Data
    Command(
      name: 'users',
      description: 'Lister les utilisateurs',
      category: 'Data',
      icon: 'assets/icons/users.svg',
      execute: (params) => _users(),
    ),
    Command(
      name: 'user',
      description: 'Détails d\'un utilisateur',
      category: 'Data',
      icon: 'assets/icons/profile.svg',
      params: ['id'],
      execute: (params) => _user(params),
    ),
    Command(
      name: 'orders',
      description: 'Dernières commandes',
      category: 'Data',
      icon: 'assets/icons/cart.svg',
      execute: (params) => _orders(),
    ),
    Command(
      name: 'products',
      description: 'Lister les produits',
      category: 'Data',
      icon: 'assets/icons/grid.svg',
      execute: (params) => _products(),
    ),
  ];

  static Command? findCommand(String input) {
    if (!input.startsWith('/')) return null;
    final parts = input.substring(1).split(' ');
    final name = parts[0].toLowerCase();
    final params = parts.length > 1 ? parts.sublist(1).cast<String>() : <String>[];

    for (var cmd in commands) {
      if (cmd.name == name) {
        cmd.currentParams = params;
        return cmd;
      }
    }
    return null;
  }

  static String _help() {
    final categories = <String, List<Command>>{};
    for (var cmd in commands) {
      categories.putIfAbsent(cmd.category, () => []).add(cmd);
    }

    var result = '📋 Commandes disponibles :\n\n';
    for (var entry in categories.entries) {
      result += '── ${entry.key} ──\n';
      for (var cmd in entry.value) {
        final params = cmd.params != null ? ' <${cmd.params!.join(', ')}>' : '';
        result += '${cmd.icon} /${cmd.name}$params - ${cmd.description}\n';
      }
      result += '\n';
    }
    result += '💡 Exemples :\n/status\n/count users\n/last orders 10\n/search users email john';
    return result;
  }

  static String _status() {
    return '📊 État du projet :\n\n'
        '✅ API        - Online\n'
        '✅ Database   - Connected\n'
        '✅ Cache      - Online\n'
        '✅ Queue      - Running\n\n'
        'CPU: 23% | RAM: 512MB/1GB\n'
        'Latence: 45ms';
  }

  static String _ping() {
    return 'Pong ! 🏓\nLatence: 45ms\nTimestamp: ${DateTime.now()}';
  }

  static String _restart() {
    return '🔄 Redémarrage en cours...\n\n'
        '1. Arrêt des services...\n'
        '2. Nettoyage du cache...\n'
        '3. Démarrage...\n\n'
        '✅ Redémarrage terminé !';
  }

  static String _version() {
    return '📦 Version du projet :\n\n'
        'App: 1.0.0\n'
        'API: 2.3.1\n'
        'Flutter: 3.44.1\n'
        'Dart: 3.12.1';
  }

  static String _uptime() {
    return '⏱️ Uptime :\n\n'
        'Service: 15j 4h 32min\n'
        'Dernier redémarrage: il y a 15 jours\n'
        'Disponibilité: 99.9%';
  }

  static String _tables() {
    return '📋 Tables dans la base de données :\n\n'
        '1. users (1,234 lignes)\n'
        '2. orders (5,678 lignes)\n'
        '3. products (89 lignes)\n'
        '4. workflows (12 lignes)\n'
        '5. executions (23,456 lignes)\n'
        '6. api_keys (45 lignes)\n'
        '7. connections (8 lignes)';
  }

  static String _count(List<String> params) {
    if (params.isEmpty) return '❌ Usage: /count <table>';
    final table = params[0];
    final counts = {
      'users': '1,234',
      'orders': '5,678',
      'products': '89',
      'workflows': '12',
      'executions': '23,456',
      'api_keys': '45',
      'connections': '8',
    };
    final count = counts[table.toLowerCase()] ?? '0';
    return '🔢 Nombre de lignes dans "$table" :\n\n$count lignes';
  }

  static String _query(List<String> params) {
    if (params.isEmpty) return '❌ Usage: /query <sql>';
    final sql = params.join(' ');
    return '🔍 Résultat de la requête :\n\n$sql\n\n'
        '--- Résultat ---\n'
        '| id | name      | email           |\n'
        '|----|-----------|------------------|\n'
        '| 1  | John Doe  | john@test.com   |\n'
        '| 2  | Jane Smith| jane@test.com   |\n'
        '| 3  | Bob Wilson| bob@test.com    |\n\n'
        '3 lignes trouvées';
  }

  static String _schema(List<String> params) {
    if (params.isEmpty) return '❌ Usage: /schema <table>';
    final table = params[0];
    return '📐 Structure de la table "$table"\n'
        '┌──────────────┬──────────────┬──────┐\n'
        '│ Colonne      │ Type         │ Null │\n'
        '├──────────────┼──────────────┼──────┤\n'
        '│ id           │ uuid         │ NON  │\n'
        '│ name         │ varchar(255) │ NON  │\n'
        '│ email        │ varchar(255) │ OUI  │\n'
        '│ created_at   │ timestamp    │ NON  │\n'
        '│ updated_at   │ timestamp    │ NON  │\n'
        '└──────────────┴──────────────┴──────┘';
  }

  static String _last(List<String> params) {
    if (params.isEmpty) return '❌ Usage: /last <table> [limit]';
    final table = params[0];
    final limit = params.length > 1 ? params[1] : '5';
    return '📜 Dernières $limit entrées de "$table"\n'
        '┌──────┬─────────────────┬────────────┐\n'
        '│ id   │ name            │ date       │\n'
        '├──────┼─────────────────┼────────────┤\n'
        '│ 45   │ New Product     │ 2024-01-15 │\n'
        '│ 44   │ Another Item    │ 2024-01-15 │\n'
        '│ 43   │ Test Product    │ 2024-01-15 │\n'
        '│ 42   │ Featured Item   │ 2024-01-15 │\n'
        '│ 41   │ Last Product    │ 2024-01-15 │\n'
        '└──────┴─────────────────┴────────────┘';
  }

  static String _search(List<String> params) {
    if (params.length < 3) return '❌ Usage: /search <table> <field> <value>';
    final field = params[1];
    final val = params[2];
    return '🔎 Résultats de recherche\n'
        '┌──────┬────────────────┬──────────┐\n'
        '│ id   │ $field${' ' * (14 - field.length)}│ type     │\n'
        '├──────┼────────────────┼──────────┤\n'
        '│ 12   │ $val${' ' * (14 - val.length)}│ exact    │\n'
        '│ 23   │ ${val}X${' ' * (13 - val.length)}│ partiel  │\n'
        '└──────┴────────────────┴──────────┘';
  }

  static String _endpoints() {
    return '🌐 Endpoints API\n'
        '┌────────┬──────────────────────┐\n'
        '│ Méthode│ Endpoint             │\n'
        '├────────┼──────────────────────┤\n'
        '│ GET    │ /api/users           │\n'
        '│ GET    │ /api/users/:id       │\n'
        '│ POST   │ /api/users           │\n'
        '│ PUT    │ /api/users/:id       │\n'
        '│ DELETE │ /api/users/:id       │\n'
        '│ GET    │ /api/orders          │\n'
        '│ POST   │ /api/orders          │\n'
        '│ GET    │ /api/products        │\n'
        '│ POST   │ /api/webhooks/:id    │\n'
        '└────────┴──────────────────────┘';
  }

  static String _requests() {
    return '📨 Dernières requêtes\n'
        '┌────────┬──────┬──────────────────┬──────┐\n'
        '│ Heure  │ Méthode│ Endpoint       │ Code │\n'
        '├────────┼──────┼──────────────────┼──────┤\n'
        '│ 14:32  │ GET  │ /api/users       │ 200  │\n'
        '│ 14:31  │ POST │ /api/orders      │ 201  │\n'
        '│ 14:30  │ GET  │ /api/products    │ 200  │\n'
        '│ 14:28  │ POST │ /api/auth/login  │ 200  │\n'
        '│ 14:25  │ GET  │ /api/users/123   │ 200  │\n'
        '└────────┴──────┴──────────────────┴──────┘';
  }

  static String _errors() {
    return '❌ Erreurs récentes :\n\n'
        '14:32 - Timeout on /api/payments (500ms)\n'
        '14:15 - Rate limit exceeded /api/users\n'
        '13:50 - Connection refused to external API\n\n'
        'Total: 3 erreurs dans les dernières 24h';
  }

  static String _health() {
    return '💚 Santé des services :\n\n'
        '✅ API Server     - Online (23ms)\n'
        '✅ PostgreSQL     - Connected (12ms)\n'
        '✅ Redis Cache    - Online (5ms)\n'
        '✅ Message Queue  - Running\n'
        '⚠️ Email Service  - Slow (340ms)\n'
        '✅ Storage        - Online';
  }

  static String _workflows() {
    return '⚙️ Workflows actifs :\n\n'
        '1. User Registration - Active\n'
        '   Étapes: validate → create → email\n\n'
        '2. Order Processing - Active\n'
        '   Étapes: validate → payment → inventory → notify\n\n'
        '3. Daily Backup - Scheduled\n'
        '   Prochaine exécution: 02:00';
  }

  static String _run(List<String> params) {
    if (params.isEmpty) return '❌ Usage: /run <workflow_id>';
    return '▶️ Exécution du workflow #${params[0]}...\n\n'
        '1. Validation... ✓\n'
        '2. Traitement... ✓\n'
        '3. Enregistrement... ✓\n\n'
        '✅ Workflow exécuté avec succès !\n'
        'Durée: 2.3s';
  }

  static String _history() {
    return '📅 Historique des exécutions :\n\n'
        '14:32 - Order Processing #1234 ✓ 2.3s\n'
        '14:15 - User Registration #567 ✓ 1.1s\n'
        '13:50 - Payment Webhook #890 ✗ timeout\n'
        '13:30 - Daily Cleanup #45 ✓ 45.2s\n'
        '12:00 - Backup Job #12 ✓ 120s';
  }

  static String _users() {
    return '👥 Utilisateurs :\n\n'
        '| id | name           | email            | status |\n'
        '|----|----------------|------------------|--------|\n'
        '| 1  | John Doe       | john@test.com    | active |\n'
        '| 2  | Jane Smith     | jane@test.com    | active |\n'
        '| 3  | Bob Wilson     | bob@test.com     | inactive |\n'
        '| 4  | Alice Brown    | alice@test.com   | active |\n\n'
        'Total: 1,234 utilisateurs';
  }

  static String _user(List<String> params) {
    if (params.isEmpty) return '❌ Usage: /user <id>';
    return '👤 Utilisateur #${params[0]} :\n\n'
        'Nom: John Doe\n'
        'Email: john@test.com\n'
        'Status: Active\n'
        'Créé le: 2024-01-01\n'
        'Dernière connexion: 2024-01-15 14:32\n'
        'Commandes: 45';
  }

  static String _orders() {
    return '🛒 Dernières commandes :\n\n'
        '| id | client     | montant  | status   |\n'
        '|----|------------|----------|----------|\n'
        '| 123| John Doe   | €150.00  | delivered |\n'
        '| 122| Jane Smith | €89.99   | pending  |\n'
        '| 121| Bob Wilson | €245.00  | shipped  |\n'
        '| 120| Alice Brown| €67.50   | delivered |';
  }

  static String _products() {
    return '📦 Produits :\n\n'
        '| id | nom           | stock | prix    |\n'
        '|----|---------------|-------|----------|\n'
        '| 1  | Widget Pro    | 150   | €29.99  |\n'
        '| 2  | Gadget Plus   | 45    | €49.99  |\n'
        '| 3  | Tool Standard | 200   | €19.99  |\n'
        '| 4  | Bundle Pack   | 30    | €99.99  |';
  }
}

class Command {
  final String name;
  final String description;
  final String category;
  final String icon;
  final List<String>? params;
  final Function(List<String>) execute;
  List<String> currentParams = [];

  Command({
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    this.params,
    required this.execute,
  });
}
