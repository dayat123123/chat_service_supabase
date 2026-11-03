import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:rendezvous_community/src/features/account/domain/entities/community_data_export.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus, ShareResultStatus;

typedef CommunityExportSaver = Future<bool> Function(BuildContext context, CommunityDataExport export);

const _jsonFiles = XTypeGroup(
  label: 'JSON',
  extensions: ['json'],
  mimeTypes: [CommunityDataExport.mimeType],
  uniformTypeIdentifiers: ['public.json'],
);

bool get _savesWithDialog =>
    !kIsWeb &&
    switch (defaultTargetPlatform) {
      TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux => true,
      _ => false,
    };

Future<bool> saveCommunityDataExport(BuildContext context, CommunityDataExport export) async {
  final file = XFile.fromData(
    export.bytes,
    mimeType: CommunityDataExport.mimeType,
    name: export.fileName,
    length: export.bytes.length,
  );
  if (_savesWithDialog) {
    final location = await getSaveLocation(suggestedName: export.fileName, acceptedTypeGroups: const [_jsonFiles]);
    if (location == null) return false;
    await file.saveTo(location.path);
    return true;
  }
  final box = context.findRenderObject();
  final origin = box is RenderBox && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;
  final result = await SharePlus.instance.share(
    ShareParams(
      files: [file],
      fileNameOverrides: [export.fileName],
      subject: export.fileName,
      sharePositionOrigin: origin,
    ),
  );
  return result.status != ShareResultStatus.dismissed;
}
