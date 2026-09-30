import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectflow_app/core/local/local_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalBackend backend;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backend = LocalBackend();
  });

  test('projet sans membre enregistre : createur = admin', () async {
    expect(await backend.resolveRole('proj-sans-membre'), 'admin');
  });

  test('identite connue via member_id_<projet>', () async {
    final p = await backend.createProject('Gate A', '');
    final admin = await backend.addMember('org-1', 'Yann', 'yann@x.co', 'admin', projectId: p['id'] as String);
    final viewer = await backend.addMember('org-1', 'Alice', 'alice@x.co', 'viewer', projectId: p['id'] as String);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('member_id_${p['id']}', viewer['id'] as String);

    expect(await backend.resolveRole(p['id'] as String), 'viewer');
    expect(admin['role'], 'admin');
  });

  test('identite resolue par email de profil', () async {
    final p = await backend.createProject('Gate B', '');
    await backend.addMember('org-1', 'Yann', 'yann@x.co', 'admin', projectId: p['id'] as String);
    await backend.addMember('org-1', 'Alice', 'alice@x.co', 'viewer', projectId: p['id'] as String);

    SharedPreferences.setMockInitialValues({
      'profile_email': 'alice@x.co',
      'profile_name': 'Alice',
    });

    expect(await backend.resolveRole(p['id'] as String), 'viewer');
  });

  test('identite non resolue parmi plusieurs membres = interdit', () async {
    final p = await backend.createProject('Gate C', '');
    await backend.addMember('org-1', 'Yann', 'yann@x.co', 'admin', projectId: p['id'] as String);
    await backend.addMember('org-1', 'Alice', 'alice@x.co', 'viewer', projectId: p['id'] as String);

    SharedPreferences.setMockInitialValues({
      'profile_email': 'inconnu@x.co',
      'profile_name': 'Inconnu',
    });

    expect(await backend.resolveRole(p['id'] as String), '',
        reason: 'role inconnu doit bloquer toute ecriture');
  });

  test('unique membre = cet appareil, sans aucune preference', () async {
    final p = await backend.createProject('Gate D', '');
    await backend.addMember('org-1', 'Bob', 'bob@x.co', 'editor', projectId: p['id'] as String);

    expect(await backend.resolveRole(p['id'] as String), 'editor');
  });

  test('le role change quand l admin modifie le grade', () async {
    final p = await backend.createProject('Gate E', '');
    final m = await backend.addMember('org-1', 'Zoe', 'zoe@x.co', 'editor', projectId: p['id'] as String);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('member_id_${p['id']}', m['id'] as String);

    expect(await backend.resolveRole(p['id'] as String), 'editor');
    await backend.updateMember(m['id'] as String, {'role': 'admin'});
    expect(await backend.resolveRole(p['id'] as String), 'admin');
  });
}
