import 'package:freezed_annotation/freezed_annotation.dart';

part 'legal_document.freezed.dart';

enum LegalDocumentKind { terms, communityGuidelines, privacy, other }

@freezed
abstract class LegalDocument with _$LegalDocument {
  const factory LegalDocument({
    required String id,
    required LegalDocumentKind kind,
    required int version,
    required String title,
    required String body,
    String? changeSummary,
    required DateTime effectiveAt,
    @Default(false) bool isRequired,
    @Default(false) bool isAccepted,
  }) = _LegalDocument;

  const LegalDocument._();

  bool get isPending => isRequired && !isAccepted;

  bool get isUpdate => version > 1;
}
