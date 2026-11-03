abstract final class CommunityAnalyticsEvent {
  static const feedOpen = 'feed_open';
  static const postCreate = 'post_create';
  static const commentCreate = 'comment_create';
  static const messageSend = 'message_send';
  static const stockTap = 'stock_tap';
  static const orderTap = 'order_tap';
  static const search = 'search';
  static const shareChart = 'share_chart';

  static const all = {feedOpen, postCreate, commentCreate, messageSend, stockTap, orderTap, search, shareChart};
}

class AnalyticsEvent {
  const AnalyticsEvent(this.name, this.props, this.timestamp);

  final String name;
  final Map<String, Object> props;
  final DateTime timestamp;

  Map<String, Object> toJson() => {
    'event': name,
    'ts': timestamp.toUtc().toIso8601String(),
    if (props.isNotEmpty) 'props': props,
  };
}

class AnalyticsResult {
  const AnalyticsResult({this.accepted = 0, this.dropped = 0, this.disabled = false});

  final int accepted;
  final int dropped;
  final bool disabled;
}

final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
final _stockCode = RegExp(r'^[A-Z][A-Z0-9]{1,11}$');
final _hashtag = RegExp(r'^[a-z0-9_]{2,50}$');

const _enumValues = <String, Set<String>>{
  'source': {
    'feed',
    'post',
    'comment',
    'chat',
    'search',
    'profile',
    'notification',
    'stock',
    'hashtag',
    'trending',
    'push',
    'deep_link',
    'share',
    'other',
  },
  'scope': {'global', 'following', 'stock', 'user', 'hashtag', 'bookmarks', 'trending'},
  'type': {
    'all',
    'posts',
    'users',
    'stocks',
    'hashtags',
    'direct',
    'group',
    'stock',
    'support',
    'text',
    'image',
    'post',
  },
  'side': {'buy', 'sell'},
  'interval': {'intraday', '1d', '1w', '1m', '3m', '6m', '1y', '5y', 'all'},
};

const _idKeys = {'post_id', 'room_id', 'target_id', 'notification_id'};
const _countKeys = {'result_count', 'position', 'query_length', 'duration_ms'};
const _flagKeys = {'has_attachment', 'has_poll', 'is_reply'};

Map<String, Object> sanitizeAnalyticsProps(Map<String, Object?> props) {
  final clean = <String, Object>{};
  props.forEach((key, value) {
    if (value == null) return;
    if (key == 'stock_code' && value is String) {
      final code = value.trim().replaceFirst(r'$', '').toUpperCase();
      if (_stockCode.hasMatch(code)) clean[key] = code;
    } else if (_idKeys.contains(key) && value is String && _uuid.hasMatch(value)) {
      clean[key] = value.toLowerCase();
    } else if (key == 'hashtag' && value is String) {
      final tag = value.trim().replaceFirst('#', '').toLowerCase();
      if (_hashtag.hasMatch(tag)) clean[key] = tag;
    } else if (_enumValues[key]?.contains(value) ?? false) {
      clean[key] = value;
    } else if (_countKeys.contains(key) && value is int && value >= 0) {
      clean[key] = value;
    } else if (_flagKeys.contains(key) && value is bool) {
      clean[key] = value;
    }
  });
  return clean;
}
