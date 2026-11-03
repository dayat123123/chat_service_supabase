import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/legal/domain/entities/legal_document.dart';

part 'legal_document_model.freezed.dart';
part 'legal_document_model.g.dart';

@freezed
abstract class LegalDocumentModel with _$LegalDocumentModel {
  const factory LegalDocumentModel({
    required String id,
    required String kind,
    required int version,
    required String title,
    @Default('') String body,
    String? changeSummary,
    required DateTime effectiveAt,
    @JsonKey(name: 'required') @Default(false) bool isRequired,
    @JsonKey(name: 'accepted') @Default(false) bool isAccepted,
  }) = _LegalDocumentModel;

  const LegalDocumentModel._();

  factory LegalDocumentModel.fromJson(Map<String, dynamic> json) => _$LegalDocumentModelFromJson(json);

  static LegalDocumentKind kindOf(String value) => switch (value) {
    'terms' => LegalDocumentKind.terms,
    'community_guidelines' => LegalDocumentKind.communityGuidelines,
    'privacy' => LegalDocumentKind.privacy,
    _ => LegalDocumentKind.other,
  };

  LegalDocument toEntity() {
    final summary = changeSummary?.trim();
    return LegalDocument(
      id: id,
      kind: kindOf(kind),
      version: version,
      title: title,
      body: body,
      changeSummary: summary == null || summary.isEmpty ? null : summary,
      effectiveAt: effectiveAt,
      isRequired: isRequired,
      isAccepted: isAccepted,
    );
  }
}
