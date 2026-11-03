enum ModerationStatus { visible, held, hidden }

ModerationStatus? parseModerationStatus(Object? value) =>
    value is String ? ModerationStatus.values.asNameMap()[value] : null;
