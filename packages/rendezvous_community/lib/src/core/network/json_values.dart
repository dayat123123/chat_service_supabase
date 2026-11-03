List<Map<String, dynamic>> jsonList(Object? value) => [
  if (value is List)
    for (final item in value)
      if (item is Map) Map<String, dynamic>.from(item),
];

Map<String, dynamic> jsonMap(Object? value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
