import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/message_composer.dart';
import 'package:rendezvous_community/src/features/media/presentation/widgets/document_attachments.dart';

import '../../support/fakes.dart';

const _pdf = Attachment(
  path: 'rooms/r-cs/a-1/f.pdf',
  bucket: 'cs-documents',
  mime: 'application/pdf',
  name: 'Formulir Penarikan.pdf',
  size: 182000,
);

class _DocumentMedia extends Fake implements MediaRepository {
  final uploads = <String>[];

  @override
  Future<Uri> documentUri(Attachment attachment) async => Uri.parse('https://api.test/${attachment.path}');

  @override
  Future<Attachment> uploadSupportDocument(String roomId, Uint8List bytes, {required String name}) async {
    uploads.add('$roomId/$name');
    return Attachment(path: 'rooms/$roomId/u-1/x.pdf', bucket: 'cs-documents', mime: 'application/pdf', name: name);
  }
}

Widget _app(Widget child, {MediaRepository? media, ChatRepository? chat}) => MaterialApp(
  locale: const Locale('id'),
  localizationsDelegates: CommunityLocalizations.localizationsDelegates,
  supportedLocales: CommunityLocalizations.supportedLocales,
  home: Scaffold(
    body: CommunityScope(
      dependencies: FakeDependencies(chat: chat, mediaRepository: media),
      child: child,
    ),
  ),
);

void main() {
  final now = DateTime.now().toUtc();
  const nadia = UserSummary(id: 'a-1', username: 'cs_cs0045', displayName: 'Nadia', isVerified: true);

  FakeChatRepository repository() => FakeChatRepository(
    rooms: [
      ChatRoom(id: 'r-cs', type: RoomType.support, name: 'CS OLT', createdAt: now, lastReadAt: now),
      ChatRoom(id: 'dm', type: RoomType.direct, createdAt: now, lastReadAt: now, otherUser: nadia),
    ],
    members: [
      RoomMember(user: me, lastReadAt: now, lastDeliveredAt: now, joinedAt: now),
      RoomMember(user: nadia, lastReadAt: now, lastDeliveredAt: now, joinedAt: now),
    ],
    messages: [
      ChatMessage(
        id: 'm-1',
        roomId: 'r-cs',
        senderId: nadia.id,
        sender: nadia,
        body: 'Silakan isi formulir ini',
        attachments: const [_pdf],
        senderRole: SenderRole.agent,
        createdAt: now,
      ),
    ],
  );

  testWidgets('support chat offers images and PDFs while other chats offer images only', (tester) async {
    final chat = repository();
    await tester.pumpWidget(
      _app(
        CommunityChatRoom(roomId: 'dm', repository: chat),
        chat: chat,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Tambah gambar'), findsOneWidget);
    expect(find.byTooltip('Lampirkan gambar atau PDF'), findsNothing);

    await tester.pumpWidget(
      _app(
        CommunityChatRoom(roomId: 'r-cs', repository: chat, composer: const MessageComposer(allowDocuments: true)),
        chat: chat,
        media: _DocumentMedia(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Lampirkan gambar atau PDF'), findsOneWidget);
    expect(find.text('Formulir Penarikan.pdf'), findsOneWidget);
    expect(find.text('PDF · 178 KB'), findsOneWidget);
    await chat.dispose();
  });

  testWidgets('a PDF card opens the signed URL', (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      _app(
        DocumentAttachments(
          attachments: const [_pdf],
          color: Colors.black,
          onOpen: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
        media: _DocumentMedia(),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Buka Formulir Penarikan.pdf'));
    await tester.pumpAndSettle();
    expect(opened, [Uri.parse('https://api.test/rooms/r-cs/a-1/f.pdf')]);
  });

  testWidgets('a PDF that cannot be opened explains the failure', (tester) async {
    await tester.pumpWidget(
      _app(
        DocumentAttachments(attachments: const [_pdf], color: Colors.black, onOpen: (_) async => false),
        media: _DocumentMedia(),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Buka Formulir Penarikan.pdf'));
    await tester.pumpAndSettle();
    expect(find.text('Dokumen tidak bisa dibuka. Coba lagi.'), findsOneWidget);
  });

  test('sendDocument uploads the PDF and sends it as an attachment', () async {
    final chat = repository();
    final media = _DocumentMedia();
    final cubit = ChatRoomCubit(chat: chat, media: media, me: () async => me, roomId: 'r-cs');
    await cubit.load();

    await cubit.sendDocument(Uint8List(10), 'Bukti Transfer.pdf');

    expect(media.uploads, ['r-cs/Bukti Transfer.pdf']);
    expect(chat.sentAttachments.single.single.bucket, 'cs-documents');
    expect(cubit.state.uploading, isFalse);
    await cubit.close();
    await chat.dispose();
  });
}
