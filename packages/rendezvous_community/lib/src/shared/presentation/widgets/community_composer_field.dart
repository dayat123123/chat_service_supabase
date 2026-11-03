import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/core/text/social_text_parser.dart';
import 'package:rendezvous_community/src/features/stocks/domain/entities/stock_suggestion.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_avatar.dart';

class CommunityComposerField extends StatefulWidget {
  const CommunityComposerField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onSubmit,
    this.focusNode,
    this.maxLength,
    this.minLines = 1,
    this.maxLines = 6,
    this.enabled = true,
    this.autofocus = false,
    this.enableAutocomplete = true,
    this.decoration,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback? onSubmit;
  final FocusNode? focusNode;
  final int? maxLength;
  final int minLines;
  final int maxLines;
  final bool enabled;
  final bool autofocus;
  final bool enableAutocomplete;
  final InputDecoration? decoration;

  @override
  State<CommunityComposerField> createState() => _CommunityComposerFieldState();
}

sealed class _Suggestion {
  const _Suggestion();
}

class _StockSuggestion extends _Suggestion {
  const _StockSuggestion(this.stock);
  final StockSuggestion stock;
}

class _UserSuggestion extends _Suggestion {
  const _UserSuggestion(this.user);
  final UserSummary user;
}

class _CommunityComposerFieldState extends State<CommunityComposerField> {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  Timer? _debounce;
  ActiveToken? _token;
  List<_Suggestion> _suggestions = const [];
  int _highlight = 0;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.onKeyEvent = _onKey;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;

    if (_suggestions.isNotEmpty) {
      if (key == LogicalKeyboardKey.arrowDown) {
        setState(() => _highlight = (_highlight + 1) % _suggestions.length);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() => _highlight = (_highlight - 1 + _suggestions.length) % _suggestions.length);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape) {
        _clearSuggestions();
        return KeyEventResult.handled;
      }
      if ((key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.tab) && !shift) {
        _apply(_suggestions[_highlight]);
        return KeyEventResult.handled;
      }
    }

    final isEnter = key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter;
    if (isEnter && !shift && event is KeyDownEvent && widget.onSubmit != null && isDesktopPlatform(context)) {
      widget.onSubmit!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onTextChanged() {
    if (!widget.enableAutocomplete) return;
    final value = widget.controller.value;
    final token = value.selection.isCollapsed ? findActiveToken(value.text, value.selection.baseOffset) : null;
    if (token == null || token.query.isEmpty) {
      _clearSuggestions();
      return;
    }
    if (token.trigger == _token?.trigger && token.query == _token?.query) return;
    _token = token;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(token));
  }

  Future<void> _search(ActiveToken token) async {
    final deps = CommunityScope.of(context);
    final id = ++_requestId;
    try {
      final List<_Suggestion> results = token.trigger == r'$'
          ? [
              for (final s in (await deps.callbacks.stockSearch?.call(token.query) ?? const <StockSuggestion>[]).take(
                6,
              ))
                _StockSuggestion(s),
            ]
          : [for (final u in await deps.profiles.searchUsers(token.query, limit: 6)) _UserSuggestion(u)];
      if (!mounted || id != _requestId) return;
      setState(() {
        _suggestions = results;
        _highlight = 0;
      });
    } catch (_) {}
  }

  void _clearSuggestions() {
    _debounce?.cancel();
    _token = null;
    _requestId++;
    if (_suggestions.isNotEmpty) setState(() => _suggestions = const []);
  }

  void _apply(_Suggestion suggestion) {
    final token = _token;
    if (token == null) return;
    final insert = switch (suggestion) {
      _StockSuggestion(:final stock) => '\$${stock.code} ',
      _UserSuggestion(:final user) => '@${user.username} ',
    };
    final text = widget.controller.text;
    final updated = text.replaceRange(token.start, token.end, insert);
    widget.controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: token.start + insert.length),
    );
    _clearSuggestions();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_suggestions.isNotEmpty)
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceContainer,
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                addAutomaticKeepAlives: false,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                itemBuilder: (context, i) {
                  final s = _suggestions[i];
                  final subtitle = switch (s) {
                    _StockSuggestion(:final stock) => stock.name,
                    _UserSuggestion(:final user) => '@${user.username}',
                  };
                  return ListTile(
                    dense: true,
                    selected: i == _highlight,
                    leading: switch (s) {
                      _StockSuggestion() => const Icon(Icons.show_chart),
                      _UserSuggestion(:final user) => CommunityAvatar(user: user, radius: 14),
                    },
                    title: Text(switch (s) {
                      _StockSuggestion(:final stock) => '\$${stock.code}',
                      _UserSuggestion(:final user) => user.name,
                    }),
                    subtitle: subtitle == null ? null : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => _apply(s),
                  );
                },
              ),
            ),
          ),
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          textCapitalization: TextCapitalization.sentences,
          decoration: (widget.decoration ?? const InputDecoration()).copyWith(hintText: widget.hintText),
        ),
      ],
    );
  }
}
