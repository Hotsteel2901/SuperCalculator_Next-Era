import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/design_tokens.dart';
import '../../app/theme/squircle_border.dart';
import '../../core/history/history_repository.dart';
import '../../core/settings/app_settings.dart';
import '../../core/ui/expressive/expressive_widgets.dart';
import '../../core/ui/expressive/motion.dart';
import '../../core/ui/feature_widgets.dart';
import 'symbol_catalog.dart';

/// Rebuilt quick input surface for plotting expressions.
///
/// Design goals:
///  * the editor stays the source of truth, so caret, selection and IME editing
///    behave exactly like typing;
///  * the panel never rebuilds the whole grid on every keystroke — the preview
///    and the submit button listen to the controller directly;
///  * every symbol is reachable from the keyboard, and long-press pins it;
///  * the same widget adapts to a phone sheet, a desktop side panel or a dialog.
class QuickInputPanel extends ConsumerStatefulWidget {
  const QuickInputPanel({
    required this.target,
    required this.onChanged,
    required this.onSubmit,
    this.onClose,
    super.key,
  });

  final TextEditingController target;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback? onClose;

  static Future<void> show({
    required BuildContext context,
    required TextEditingController target,
    required ValueChanged<String> onChanged,
    required VoidCallback onSubmit,
    QuickPanelLayout layout = QuickPanelLayout.automatic,
  }) async {
    final size = MediaQuery.sizeOf(context);
    // The symbol panel replaces the phone's software keyboard while open;
    // hiding the IME gives the keypad usable space.
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
    }

    final resolved = _resolveLayout(layout, size);
    final panel = QuickInputPanel(
      target: target,
      onChanged: onChanged,
      onSubmit: onSubmit,
      onClose: () => Navigator.of(context).maybePop(),
    );

    switch (resolved) {
      case QuickPanelLayout.bottomSheet:
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
          showDragHandle: true,
          sheetAnimationStyle: const AnimationStyle(
            duration: Duration(milliseconds: 320),
            reverseDuration: Duration(milliseconds: 220),
          ),
          builder: (sheetContext) => SizedBox(
            height: math.min(780, size.height * 0.93),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: panel,
            ),
          ),
        );
      case QuickPanelLayout.dialog:
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 28,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 780,
                maxHeight: math.min(780, size.height * 0.92),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: panel,
              ),
            ),
          ),
        );
      case QuickPanelLayout.sidePanel:
      case QuickPanelLayout.automatic:
        await showGeneralDialog<void>(
          context: context,
          barrierDismissible: true,
          barrierLabel: MaterialLocalizations.of(context)
              .modalBarrierDismissLabel,
          barrierColor: Colors.black.withValues(alpha: 0.32),
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (dialogContext, _, _) => Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Material(
              color: Theme.of(dialogContext).colorScheme.surfaceContainerLow,
              child: SizedBox(
                width: math.min(460, size.width),
                height: size.height,
                child: SafeArea(
                  left: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                    child: panel,
                  ),
                ),
              ),
            ),
          ),
          transitionBuilder: (context, animation, _, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(opacity: curved, child: child),
            );
          },
        );
    }
  }

  static QuickPanelLayout _resolveLayout(QuickPanelLayout layout, Size size) {
    if (layout != QuickPanelLayout.automatic) {
      // A side panel cannot fit on a phone; fall back to the sheet.
      if (layout == QuickPanelLayout.sidePanel && size.width < 720) {
        return QuickPanelLayout.bottomSheet;
      }
      return layout;
    }
    if (size.width >= 980) return QuickPanelLayout.sidePanel;
    if (size.width >= 720) return QuickPanelLayout.dialog;
    return QuickPanelLayout.bottomSheet;
  }

  @override
  ConsumerState<QuickInputPanel> createState() => _QuickInputPanelState();
}

enum _PanelView { symbols, history }

class _QuickInputPanelState extends ConsumerState<QuickInputPanel> {
  final List<TextEditingValue> _undo = <TextEditingValue>[];
  final List<TextEditingValue> _redo = <TextEditingValue>[];
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode(debugLabel: 'quick input search');
  final FocusNode _gridFocus = FocusNode(debugLabel: 'quick input grid');
  final Map<String, FocusNode> _keyFocus = <String, FocusNode>{};

  QuickSymbolStore? _store;
  SymbolGroup? _group = SymbolGroup.basic;
  bool _favoritesView = false;
  bool _recentsView = false;
  String _query = '';
  int _columns = 4;
  _PanelView _view = _PanelView.symbols;
  Timer? _repeat;
  String? _focusedId;

  @override
  void initState() {
    super.initState();
    _loadStore();
    widget.target.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _gridFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _repeat?.cancel();
    widget.target.removeListener(_onTextChanged);
    _search.dispose();
    _searchFocus.dispose();
    _gridFocus.dispose();
    for (final node in _keyFocus.values) {
      node.dispose();
    }
    _store?.dispose();
    super.dispose();
  }

  Future<void> _loadStore() async {
    final store = await QuickSymbolStore.load();
    if (!mounted) return;
    setState(() => _store = store);
  }

  void _onTextChanged() {
    // The preview and the submit button listen to the controller themselves;
    // the panel only needs a repaint when the structure of the expression
    // changes the status pill. Repainting the whole grid here would drop frames
    // while typing fast.
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Editing model
  // ---------------------------------------------------------------------------

  TextEditingValue _snapshot() {
    final value = widget.target.value;
    final selection = value.selection;
    if (!selection.isValid || selection.start < 0 || selection.end < 0) {
      return value.copyWith(
        selection: TextSelection.collapsed(offset: value.text.length),
      );
    }
    return value.copyWith(
      selection: TextSelection(
        baseOffset: selection.baseOffset.clamp(0, value.text.length).toInt(),
        extentOffset: selection.extentOffset
            .clamp(0, value.text.length)
            .toInt(),
        affinity: selection.affinity,
        isDirectional: selection.isDirectional,
      ),
    );
  }

  void _pushUndo(TextEditingValue value) {
    _undo.add(value);
    if (_undo.length > 80) _undo.removeAt(0);
    _redo.clear();
  }

  void _setValue(TextEditingValue value) {
    widget.target.value = value;
    widget.onChanged(value.text);
  }

  bool get _haptics => ref.read(appSettingsProvider).haptics;

  void _insert(MathSymbol symbol) {
    final value = _snapshot();
    final selection = value.selection;
    final selectedText = selection.textInside(value.text);
    _pushUndo(value);

    String replacement;
    int caret;
    if (symbol.wrapsSelection && selectedText.isNotEmpty) {
      final prefix = symbol.caretBack == 0
          ? symbol.insertion
          : symbol.insertion.substring(
              0,
              symbol.insertion.length - symbol.caretBack,
            );
      final suffix = symbol.caretBack == 0
          ? ''
          : symbol.insertion.substring(
              symbol.insertion.length - symbol.caretBack,
            );
      replacement = '$prefix$selectedText$suffix';
      caret = selection.start + replacement.length;
    } else if (symbol.insertion == '(' ||
        symbol.insertion == '[' ||
        symbol.insertion == '{') {
      const closers = <String, String>{'(': ')', '[': ']', '{': '}'};
      final next = selection.end < value.text.length
          ? value.text[selection.end]
          : '';
      replacement = next == closers[symbol.insertion]
          ? symbol.insertion
          : '${symbol.insertion}${closers[symbol.insertion]}';
      caret = selection.start + 1;
    } else {
      replacement = symbol.insertion;
      caret = selection.start + replacement.length - symbol.caretBack;
    }

    final text = value.text.replaceRange(
      selection.start,
      selection.end,
      replacement,
    );
    _setValue(
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(
          offset: caret.clamp(0, text.length).toInt(),
        ),
      ),
    );
    if (_haptics) HapticFeedback.selectionClick();
    _store?.recordUsage(symbol.id);
  }

  void _backspace() {
    final value = _snapshot();
    final selection = value.selection;
    final start = selection.start == selection.end
        ? math.max(0, selection.start - 1)
        : selection.start;
    if (start == selection.end) return;
    _pushUndo(value);
    final text = value.text.replaceRange(start, selection.end, '');
    _setValue(
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: start),
      ),
    );
    if (_haptics) HapticFeedback.selectionClick();
  }

  void _startRepeatBackspace() {
    _backspace();
    _repeat?.cancel();
    _repeat = Timer.periodic(const Duration(milliseconds: 70), (_) {
      if (!mounted) return;
      _backspace();
    });
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  void _clear() {
    if (widget.target.text.isEmpty) return;
    _pushUndo(_snapshot());
    _setValue(
      const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      ),
    );
  }

  void _undoStep() {
    if (_undo.isEmpty) return;
    _redo.add(_snapshot());
    _setValue(_undo.removeLast());
  }

  void _redoStep() {
    if (_redo.isEmpty) return;
    _undo.add(_snapshot());
    _setValue(_redo.removeLast());
  }

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _submit() {
    final text = widget.target.text.trim();
    if (text.isEmpty) return;
    _close();
    widget.onSubmit();
  }

  void _replaceWith(String expression) {
    _pushUndo(_snapshot());
    _setValue(
      TextEditingValue(
        text: expression,
        selection: TextSelection.collapsed(offset: expression.length),
      ),
    );
    setState(() => _view = _PanelView.symbols);
  }

  // ---------------------------------------------------------------------------
  // Keyboard
  // ---------------------------------------------------------------------------

  List<MathSymbol> _activeSymbols() {
    if (_query.isNotEmpty) return SymbolCatalog.search(_query);
    if (_favoritesView) return _store?.favoriteSymbols ?? const <MathSymbol>[];
    if (_recentsView) return _store?.recentSymbols ?? const <MathSymbol>[];
    return SymbolCatalog.byGroup(_group ?? SymbolGroup.basic);
  }

  FocusNode _nodeFor(MathSymbol symbol) => _keyFocus.putIfAbsent(
    symbol.id,
    () => FocusNode(debugLabel: 'quick key ${symbol.id}'),
  );

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_searchFocus.hasFocus) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final symbols = _activeSymbols();
    if (symbols.isEmpty && key != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    final current = _focusedId == null
        ? -1
        : symbols.indexWhere((symbol) => symbol.id == _focusedId);
    final index = current < 0 ? 0 : current;

    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      final next = switch (key) {
        LogicalKeyboardKey.arrowLeft => math.max(0, index - 1),
        LogicalKeyboardKey.arrowRight => math.min(
          symbols.length - 1,
          index + 1,
        ),
        LogicalKeyboardKey.arrowUp => math.max(0, index - _columns),
        _ => math.min(symbols.length - 1, index + _columns),
      };
      _focusSymbol(symbols[next]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _insert(symbols[current < 0 ? 0 : current]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _focusSymbol(MathSymbol symbol) {
    setState(() => _focusedId = symbol.id);
    _nodeFor(symbol).requestFocus();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final history = ref.watch(calculationHistoryProvider);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildHeader(context),
        const SizedBox(height: 10),
        _buildPreview(context),
        const SizedBox(height: 10),
        _buildSearch(context),
        const SizedBox(height: 8),
        if (_view == _PanelView.history)
          Expanded(child: _buildHistory(context, history))
        else ...<Widget>[
          _buildTabs(context),
          if (_query.isEmpty && !_favoritesView && !_recentsView)
            _buildSuggested(context),
          const SizedBox(height: 8),
          Expanded(child: _buildGrid(context)),
        ],
        const SizedBox(height: 8),
        _buildActions(context),
        const SizedBox(height: 2),
        Text(
          nextEraText(
            context,
            'Arrows move · Enter inserts · long-press pins · Ctrl/⌘+Z undo',
            '方向键移动 · 回车插入 · 长按收藏 · Ctrl/⌘+Z 撤销',
          ),
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant, fontSize: 10.5),
        ),
      ],
    );

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            _undoStep,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undoStep,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true):
            _redoStep,
        const SingleActivator(LogicalKeyboardKey.keyY, meta: true): _redoStep,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          _searchFocus.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () {
          _searchFocus.requestFocus();
        },
      },
      child: Focus(
        focusNode: _gridFocus,
        onKeyEvent: _handleKey,
        child: content,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = SuperCalcDesignTokens.of(context);
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(9),
          decoration: ShapeDecoration(
            gradient: LinearGradient(
              colors: <Color>[scheme.primary, scheme.tertiary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: const SquircleBorder(radius: 12),
          ),
          child: Icon(
            Icons.keyboard_alt_rounded,
            size: 18,
            color: scheme.onPrimary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                nextEraText(context, 'Quick input', '快捷输入'),
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                nextEraText(
                  context,
                  'Insert symbols without leaving the flow',
                  '不打断输入，直接插入符号',
                ),
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        AnimatedContainer(
          duration: tokens.scaled(const Duration(milliseconds: 200)),
          decoration: ShapeDecoration(
            color: _view == _PanelView.history
                ? scheme.secondaryContainer
                : Colors.transparent,
            shape: const StadiumBorder(),
          ),
          child: AppTooltip(
            message: nextEraText(context, 'Recent expressions', '最近表达式'),
            child: IconButton(
              onPressed: () => setState(
                () => _view = _view == _PanelView.history
                    ? _PanelView.symbols
                    : _PanelView.history,
              ),
              icon: Icon(
                _view == _PanelView.history
                    ? Icons.keyboard_rounded
                    : Icons.history_rounded,
              ),
            ),
          ),
        ),
        AppTooltip(
          message: MaterialLocalizations.of(context).closeButtonTooltip,
          child: IconButton(
            onPressed: _close,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = SuperCalcDesignTokens.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.target,
      builder: (context, value, _) {
        final status = _ExpressionStatus.parse(value.text);
        final color = status.isEmpty
            ? scheme.onSurfaceVariant
            : status.isBalanced
            ? scheme.primary
            : scheme.error;
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          decoration: ShapeDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            shape: SquircleBorder(
              radius: tokens.cornerSmall + 4,
              side: BorderSide(
                color: status.isEmpty
                    ? scheme.outlineVariant.withValues(alpha: 0.5)
                    : color.withValues(alpha: 0.45),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    nextEraText(context, 'Expression', '表达式'),
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  StatusPill(
                    label: status.label(context),
                    icon: status.isEmpty
                        ? Icons.edit_outlined
                        : status.isBalanced
                        ? Icons.check_circle_outline_rounded
                        : Icons.error_outline_rounded,
                    color: color,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 26,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value.text.isEmpty ? 'sin(x) + cos(x)' : value.text,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontFamily: 'monospace',
                        color: value.text.isEmpty
                            ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
                            : scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: <Widget>[
                  Text(
                    '${value.text.length} ${nextEraText(context, 'chars', '字符')}',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${nextEraText(context, 'caret', '光标')} '
                    '${value.selection.baseOffset.clamp(0, value.text.length)}',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  if (status.hasTrailingOperator)
                    Text(
                      nextEraText(context, 'Incomplete', '表达式未完成'),
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: scheme.tertiary),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearch(BuildContext context) {
    return SizedBox(
      height: 46,
      child: TextField(
        controller: _search,
        focusNode: _searchFocus,
        textInputAction: TextInputAction.search,
        onChanged: (value) => setState(() {
          _query = value.trim();
          _favoritesView = false;
          _recentsView = false;
        }),
        decoration: InputDecoration(
          hintText: nextEraText(
            context,
            'Search 70+ symbols (Ctrl+F)',
            '搜索 70+ 符号（Ctrl+F）',
          ),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 4,
          ),
          isDense: true,
        ),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = SuperCalcDesignTokens.of(context);
    final favorites = _store?.favoriteSymbols ?? const <MathSymbol>[];
    final recents = _store?.recentSymbols ?? const <MathSymbol>[];

    Widget chip({
      required String label,
      required IconData icon,
      required bool selected,
      required VoidCallback onTap,
      int? count,
    }) {
      return PressableScale(
        onTap: onTap,
        pressedScale: 0.96,
        child: AnimatedContainer(
          duration: tokens.scaled(const Duration(milliseconds: 200)),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: ShapeDecoration(
            color: selected ? scheme.secondaryContainer : Colors.transparent,
            shape: StadiumBorder(
              side: BorderSide(
                color: selected
                    ? Colors.transparent
                    : scheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 15,
                color: selected
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (count != null && count > 0) ...<Widget>[
                const SizedBox(width: 5),
                Text(
                  '$count',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected
                        ? scheme.onSecondaryContainer.withValues(alpha: 0.7)
                        : scheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          chip(
            label: nextEraText(context, 'Pinned', '收藏'),
            icon: Icons.star_rounded,
            selected: _favoritesView,
            count: favorites.length,
            onTap: () => setState(() {
              _favoritesView = true;
              _recentsView = false;
              _query = '';
              _search.clear();
            }),
          ),
          const SizedBox(width: 6),
          chip(
            label: nextEraText(context, 'Recent', '最近'),
            icon: Icons.history_rounded,
            selected: _recentsView,
            count: recents.length,
            onTap: () => setState(() {
              _recentsView = true;
              _favoritesView = false;
              _query = '';
              _search.clear();
            }),
          ),
          const SizedBox(width: 6),
          for (final group in SymbolGroup.values) ...<Widget>[
            chip(
              label: nextEraText(context, group.labelEn, group.labelZh),
              icon: group.icon,
              selected:
                  !_favoritesView &&
                  !_recentsView &&
                  _query.isEmpty &&
                  _group == group,
              onTap: () => setState(() {
                _group = group;
                _favoritesView = false;
                _recentsView = false;
                _query = '';
                _search.clear();
              }),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggested(BuildContext context) {
    final suggested = _store?.suggested ?? const <MathSymbol>[];
    if (suggested.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: <Widget>[
          Icon(Icons.auto_awesome_rounded, size: 15, color: scheme.tertiary),
          const SizedBox(width: 6),
          Text(
            nextEraText(context, 'Suggested', '建议'),
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: suggested.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final symbol = suggested[index];
                  return PressableScale(
                    onTap: () => _insert(symbol),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: ShapeDecoration(
                        color: scheme.tertiaryContainer.withValues(alpha: 0.6),
                        shape: const StadiumBorder(),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        symbol.label,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontFamily: 'monospace',
                              color: scheme.onTertiaryContainer,
                            ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final symbols = _activeSymbols();
    final scheme = Theme.of(context).colorScheme;

    if (symbols.isEmpty) {
      final message = _query.isNotEmpty
          ? nextEraText(context, 'No symbol matches that search', '没有匹配的符号')
          : _favoritesView
          ? nextEraText(
              context,
              'Long-press a key to pin it here',
              '长按任意按键即可收藏到这里',
            )
          : nextEraText(
              context,
              'Keys you use will appear here',
              '使用过的按键会出现在这里',
            );
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              _query.isNotEmpty
                  ? Icons.search_off_rounded
                  : Icons.star_border_rounded,
              size: 40,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final palette = <Color>[
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      scheme.error,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const minExtent = 74.0;
        final columns = math.max(3, (constraints.maxWidth / minExtent).floor());
        _columns = columns;
        return GridView.builder(
          padding: const EdgeInsets.only(bottom: 4),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 50,
            crossAxisSpacing: 7,
            mainAxisSpacing: 7,
          ),
          itemCount: symbols.length,
          itemBuilder: (context, index) {
            final symbol = symbols[index];
            final accent = palette[symbol.group.index % palette.length];
            return RepaintBoundary(
              child: _SymbolKey(
                symbol: symbol,
                accent: accent,
                pinned: _store?.favorites.contains(symbol.id) ?? false,
                focusNode: _nodeFor(symbol),
                autofocus: false,
                onTap: () => _insert(symbol),
                onLongPress: () {
                  setState(() => _store?.toggleFavorite(symbol.id));
                  HapticFeedback.mediumImpact();
                },
                onFocus: () => _focusedId = symbol.id,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistory(BuildContext context, List<HistoryEntry> history) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = SuperCalcDesignTokens.of(context);
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.history_toggle_off_rounded,
              size: 40,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 10),
            Text(
              nextEraText(
                context,
                'Expressions you plot will appear here',
                '绘制过的表达式会显示在这里',
              ),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: history.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final entry = history[index];
        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: scheme.surfaceContainer,
          onTap: () => _replaceWith(_expressionFromHistory(entry.expression)),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(7),
                decoration: ShapeDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  shape: tokens.keyShape(),
                ),
                child: Icon(
                  Icons.add_chart_rounded,
                  size: 16,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _expressionFromHistory(entry.expression),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontFamily: 'monospace'),
                    ),
                    Text(
                      entry.result,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.north_west_rounded, size: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActions(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = SuperCalcDesignTokens.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // A phone sheet with large touch targets cannot fit four icon actions,
        // "Done" and a labelled primary button on one line.
        final narrow = constraints.maxWidth < 430;
        return _buildActionRow(context, tokens, scheme, narrow: narrow);
      },
    );
  }

  Widget _buildActionRow(
    BuildContext context,
    SuperCalcDesignTokens tokens,
    ColorScheme scheme, {
    required bool narrow,
  }) {
    return Row(
      children: <Widget>[
        _ActionIcon(
          icon: Icons.undo_rounded,
          tooltip: nextEraText(context, 'Undo', '撤销'),
          onPressed: _undo.isEmpty ? null : _undoStep,
        ),
        _ActionIcon(
          icon: Icons.redo_rounded,
          tooltip: nextEraText(context, 'Redo', '重做'),
          onPressed: _redo.isEmpty ? null : _redoStep,
        ),
        _ActionIcon(
          icon: Icons.backspace_outlined,
          tooltip: nextEraText(
            context,
            'Backspace (hold to repeat)',
            '退格（长按连续删除）',
          ),
          onPressed: _backspace,
          onLongPress: _startRepeatBackspace,
          onLongPressEnd: _stopRepeat,
        ),
        _ActionIcon(
          icon: Icons.delete_sweep_outlined,
          tooltip: nextEraText(context, 'Clear', '清空'),
          onPressed: _clear,
        ),
        SizedBox(width: narrow ? 0 : 6),
        const Spacer(),
        if (narrow)
          AppTooltip(
            message: nextEraText(context, 'Close', '关闭'),
            child: IconButton(
              onPressed: _close,
              icon: const Icon(Icons.check_rounded),
            ),
          )
        else
          OutlinedButton(
            onPressed: _close,
            child: Text(nextEraText(context, 'Done', '完成')),
          ),
        SizedBox(width: narrow ? 4 : 8),
        Flexible(
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.target,
            builder: (context, value, _) {
              final enabled = value.text.trim().isNotEmpty;
              return FilledButton.icon(
                onPressed: enabled ? _submit : null,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  narrow
                      ? nextEraText(context, 'Plot', '绘制')
                      : nextEraText(context, 'Insert & plot', '插入并绘制'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: FilledButton.styleFrom(
                  minimumSize: Size(0, tokens.controlMinHeight - 4),
                  backgroundColor: scheme.primary,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _expressionFromHistory(String value) {
    final separator = value.indexOf(': ');
    return separator < 0 ? value : value.substring(separator + 2);
  }
}

/// One key in the symbol grid.
class _SymbolKey extends StatelessWidget {
  const _SymbolKey({
    required this.symbol,
    required this.accent,
    required this.pinned,
    required this.focusNode,
    required this.autofocus,
    required this.onTap,
    required this.onLongPress,
    required this.onFocus,
  });

  final MathSymbol symbol;
  final Color accent;
  final bool pinned;
  final FocusNode focusNode;
  final bool autofocus;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = SuperCalcDesignTokens.of(context);
    return Semantics(
      button: true,
      label:
          '${symbol.label} — ${nextEraText(context, symbol.descriptionEn, symbol.descriptionZh)}',
      child: AppTooltip(
        message:
            '${nextEraText(context, symbol.descriptionEn, symbol.descriptionZh)}\n'
            '${nextEraText(context, 'Long-press to pin', '长按收藏')}',
        child: PressableScale(
          focusNode: focusNode,
          autofocus: autofocus,
          onFocusChange: (focused) {
            if (focused) onFocus();
          },
          onTap: onTap,
          onLongPress: onLongPress,
          pressedScale: 0.9,
          haptics: true,
          child: AnimatedContainer(
            duration: tokens.scaled(const Duration(milliseconds: 180)),
            curve: Curves.easeOutCubic,
            decoration: ShapeDecoration(
              color: accent.withValues(alpha: 0.09),
              shape: SquircleBorder(
                radius: tokens.cornerSmall,
                side: BorderSide(
                  color: accent.withValues(alpha: pinned ? 0.75 : 0.22),
                  width: pinned ? 1.6 : 1,
                ),
              ),
            ),
            child: Stack(
              children: <Widget>[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      symbol.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                if (pinned)
                  Positioned(
                    top: 3,
                    right: 3,
                    child: Icon(Icons.star_rounded, size: 10, color: accent),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.onLongPress,
    this.onLongPressEnd,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final VoidCallback? onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final narrow = MediaQuery.sizeOf(context).width < 430;
    return Padding(
      padding: EdgeInsets.only(right: narrow ? 2 : 4),
      child: AppTooltip(
        message: tooltip,
        child: GestureDetector(
          onLongPress: onLongPress,
          onLongPressEnd: (_) => onLongPressEnd?.call(),
          child: IconButton.filledTonal(
            onPressed: onPressed,
            icon: Icon(icon, size: 20),
            visualDensity: narrow
                ? const VisualDensity(horizontal: -2, vertical: -1)
                : null,
            style: IconButton.styleFrom(
              backgroundColor: scheme.surfaceContainerHigh,
              foregroundColor: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bracket / operator analysis for the live status pill.
class _ExpressionStatus {
  const _ExpressionStatus({
    required this.isEmpty,
    required this.isBalanced,
    required this.hasTrailingOperator,
    required this.depth,
  });

  final bool isEmpty;
  final bool isBalanced;
  final bool hasTrailingOperator;
  final int depth;

  static _ExpressionStatus parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const _ExpressionStatus(
        isEmpty: true,
        isBalanced: true,
        hasTrailingOperator: false,
        depth: 0,
      );
    }
    final stack = <String>[];
    const pairs = <String, String>{')': '(', ']': '[', '}': '{'};
    var balanced = true;
    for (final codeUnit in text.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      if (char == '(' || char == '[' || char == '{') {
        stack.add(char);
      } else if (pairs.containsKey(char)) {
        if (stack.isEmpty || stack.removeLast() != pairs[char]) {
          balanced = false;
        }
      }
    }
    if (stack.isNotEmpty) balanced = false;
    final last = trimmed[trimmed.length - 1];
    final trailing =
        RegExp(r'[+\-*/^<>=!,]').hasMatch(last) ||
        RegExp(r'\bmod\b$').hasMatch(trimmed);
    return _ExpressionStatus(
      isEmpty: false,
      isBalanced: balanced,
      hasTrailingOperator: trailing,
      depth: stack.length,
    );
  }

  String label(BuildContext context) {
    if (isEmpty) return nextEraText(context, 'Empty', '空');
    if (!isBalanced) return nextEraText(context, 'Check brackets', '请检查括号');
    if (hasTrailingOperator) return nextEraText(context, 'Add a value', '补充数值');
    return nextEraText(context, 'Ready', '可以绘制');
  }
}
