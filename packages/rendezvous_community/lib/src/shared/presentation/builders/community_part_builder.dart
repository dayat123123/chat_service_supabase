import 'package:flutter/widgets.dart';

typedef CommunityPartBuilder<T> = Widget Function(BuildContext context, T details, Widget fallback);

Widget buildCommunityPart<T>(CommunityPartBuilder<T>? builder, BuildContext context, T details, Widget fallback) =>
    builder == null ? fallback : builder(context, details, fallback);
