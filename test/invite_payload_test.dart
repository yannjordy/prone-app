import 'package:flutter_test/flutter_test.dart';
import 'package:connectflow_app/core/backend/invite_payload.dart';

InvitePayload sample({String url = 'https://xjckbqbqxcwzcrlmuvzf.supabase.co', String key = 'eyJhbGciOiJIUzI1NiJ9.abc.def'}) {
  return InvitePayload(
    projectId: 'p-1234',
    name: 'ODA Seller',
    description: 'Ventes en ligne',
    photo: 'base64photo',
    backendUrl: url,
    apiKey: key,
    orgId: 'org-1',
    inviter: 'Yann',
    joinCode: '7K2M9X',
    createdAt: '2026-09-28T12:00:00.000',
  );
}

void main() {
  group('InvitePayload encode/decode', () {
    test('roundtrip conserve toutes les donnees', () {
      final original = sample();
      final decoded = InvitePayload.decode(original.encode());

      expect(decoded, isNotNull);
      expect(decoded!.projectId, original.projectId);
      expect(decoded.name, original.name);
      expect(decoded.description, original.description);
      expect(decoded.photo, original.photo);
      expect(decoded.backendUrl, original.backendUrl);
      expect(decoded.apiKey, original.apiKey);
      expect(decoded.orgId, original.orgId);
      expect(decoded.inviter, original.inviter);
      expect(decoded.joinCode, original.joinCode);
      expect(decoded.createdAt, original.createdAt);
    });

    test('le lien est auto-suffisant (prefixe prone://join/)', () {
      final link = sample().link;
      expect(link.startsWith('prone://join/'), isTrue);
      expect(InvitePayload.tryParse(link), isNotNull);
    });

    test('le code utilise le prefixe PRONE:', () {
      final code = sample().code;
      expect(code.startsWith('PRONE:'), isTrue);
      expect(InvitePayload.tryParse(code), isNotNull);
    });

    test('encode sans padding =', () {
      expect(sample().encode().contains('='), isFalse);
    });

    test('decode accepte le padding absent (longueurs non multiples de 4)', () {
      for (final key in ['a', 'ab', 'abc', 'abcd', 'abcde']) {
        final p = sample(key: key);
        expect(InvitePayload.decode(p.encode()), isNotNull, reason: 'cle=$key');
      }
    });
  });

  group('InvitePayload.tryParse', () {
    test('accepte brut, lien et code', () {
      final p = sample();
      expect(InvitePayload.tryParse(p.encode())!.projectId, 'p-1234');
      expect(InvitePayload.tryParse(p.link)!.projectId, 'p-1234');
      expect(InvitePayload.tryParse(p.code)!.projectId, 'p-1234');
      expect(InvitePayload.tryParse('  ${p.link}  ')!.projectId, 'p-1234');
    });

    test('rejette les entrees invalides', () {
      expect(InvitePayload.tryParse(''), isNull);
      expect(InvitePayload.tryParse('   '), isNull);
      expect(InvitePayload.tryParse('nimporte quoi'), isNull);
      expect(InvitePayload.tryParse('https://exemple.com/join/abc'), isNull);
      expect(InvitePayload.tryParse(proneInviteOnly), isNull);
    });

    test('rejette un payload sans id de projet', () {
      expect(InvitePayload.decode('eyJ2IjoxfQ'), isNull);
    });

    test('rejette un json qui n est pas un objet', () {
      expect(InvitePayload.decode('WzFd'), isNull);
    });
  });

  group('InvitePayload.legacyProjectId', () {
    test('recupere l id d un ancien lien', () {
      expect(InvitePayload.legacyProjectId('prone://invite/abc-123'), 'abc-123');
      expect(InvitePayload.legacyProjectId('prone://invite/abc-123?x=1'), 'abc-123');
      expect(InvitePayload.legacyProjectId('PRONE://INVITE/abc-123'), 'abc-123');
    });

    test('retourne null sur les nouveaux liens', () {
      expect(InvitePayload.legacyProjectId(sample().link), isNull);
      expect(InvitePayload.legacyProjectId('autre chose'), isNull);
    });
  });

  group('InvitePayload.fromProject / host', () {
    test('cree la charge utile depuis la ligne projet', () {
      final payload = InvitePayload.fromProject({
        'id': 'p-9',
        'name': 'WhatsApp Bot',
        'description': 'desc',
        'photo': '',
        'backend_url': 'https://api.exemple.com/v1',
        'api_key': 'cle',
        'organization_id': 'org-7',
      }, inviter: 'Yann', joinCode: 'ABC123');

      expect(payload.projectId, 'p-9');
      expect(payload.backendUrl, 'https://api.exemple.com/v1');
      expect(payload.orgId, 'org-7');
      expect(payload.inviter, 'Yann');
      expect(payload.joinCode, 'ABC123');
      expect(payload.hasBackend, isTrue);
      expect(payload.host, 'api.exemple.com');
      expect(InvitePayload.decode(payload.encode())!.name, 'WhatsApp Bot');
    });

    test('host est vide sans backend', () {
      final payload = InvitePayload(projectId: 'p', name: 'n');
      expect(payload.hasBackend, isFalse);
      expect(payload.host, '');
    });
  });
}

const proneInviteOnly = 'prone://invite/p-1';
