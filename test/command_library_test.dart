import 'package:flutter_test/flutter_test.dart';
import 'package:connectflow_app/core/commands/command_library.dart';

void main() {
  test('findCommand reconnait toutes les commandes proposees', () {
    final names = CommandLibrary.commands.map((c) => '/${c.name}').toList();
    for (final n in names) {
      expect(CommandLibrary.findCommand(n), isNotNull, reason: '$n doit etre reconnue');
    }
  });

  test('findCommand parse les parametres', () {
    final cmd = CommandLibrary.findCommand('/count users');
    expect(cmd, isNotNull);
    expect(cmd!.name, 'count');
    expect(cmd.currentParams, ['users']);
  });

  test('findCommand gere les espaces en trop', () {
    final cmd = CommandLibrary.findCommand('/ping ');
    expect(cmd, isNotNull);
    expect(cmd!.name, 'ping');
    expect(cmd.currentParams, isEmpty);
  });

  test('findCommand rejecte le texte sans slash', () {
    expect(CommandLibrary.findCommand('bonjour'), isNull);
    expect(CommandLibrary.findCommand(''), isNull);
  });

  test('execute retourne une String pour chaque commande sans param', () {
    for (final cmd in CommandLibrary.commands) {
      if (cmd.params == null || cmd.params!.isEmpty) {
        final res = cmd.execute([]);
        expect(res, isA<String>(), reason: '/${cmd.name} doit retourner une String');
        expect((res as String).isNotEmpty, isTrue);
      }
    }
  });

  test('execute retourne une usage pour commandes obligatoires sans param', () {
    final count = CommandLibrary.findCommand('/count')!;
    final res = count.execute(count.currentParams) as String;
    expect(res, contains('Usage'));
  });
}
