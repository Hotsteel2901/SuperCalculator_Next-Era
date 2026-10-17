import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/history/history_repository.dart';
import '../../core/ui/feature_widgets.dart';

/// Cross-platform symbol palette for plotting expressions. The target editor
/// remains the source of truth, so selection replacement, cursor placement and
/// normal keyboard/IME editing all behave like direct typing.
class QuickInputPanel extends ConsumerStatefulWidget {
  const QuickInputPanel({
    required this.target,
    required this.onChanged,
    required this.onSubmit,
    super.key,
  });

  final TextEditingController target;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  static Future<void> show({
    required BuildContext context,
    required TextEditingController target,
    required ValueChanged<String> onChanged,
    required VoidCallback onSubmit,
  }) {
    final size = MediaQuery.sizeOf(context);
    // The symbol panel replaces the phone's software keyboard while open;
    // hiding the IME gives the keypad and recent-history list usable space.
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    final panel = QuickInputPanel(
      target: target,
      onChanged: onChanged,
      onSubmit: onSubmit,
    );
    if (size.width >= 640) {
      return showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 760,
              maxHeight: math.min(760.0, size.height * .9),
            ),
            child: Padding(padding: const EdgeInsets.all(16), child: panel),
          ),
        ),
      );
    }

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: math.min(760.0, size.height * .9),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: panel,
        ),
      ),
    );
  }

  @override
  ConsumerState<QuickInputPanel> createState() => _QuickInputPanelState();
}

class _QuickInputPanelState extends ConsumerState<QuickInputPanel> {
  final List<TextEditingValue> _undo = <TextEditingValue>[];
  final List<TextEditingValue> _redo = <TextEditingValue>[];
  final Map<String, int> _usage = <String, int>{};
  late final List<List<FocusNode>> _keyFocusNodes = _quickInputCategories
      .map(
        (category) => List<FocusNode>.generate(
          category.keys.length,
          (index) => FocusNode(debugLabel: '${category.id} key $index'),
        ),
      )
      .toList(growable: false);
  int _categoryIndex = 0;
  int _focusedKeyIndex = 0;
  int _gridColumns = 4;
  String _expression = '';

  @override
  void initState() {
    super.initState();
    _expression = widget.target.text;
    widget.target.addListener(_syncExpression);
  }

  @override
  void didUpdateWidget(covariant QuickInputPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      oldWidget.target.removeListener(_syncExpression);
      widget.target.addListener(_syncExpression);
      _expression = widget.target.text;
    }
  }

  @override
  void dispose() {
    widget.target.removeListener(_syncExpression);
    for (final categoryNodes in _keyFocusNodes) {
      for (final node in categoryNodes) {
        node.dispose();
      }
    }
    super.dispose();
  }

  void _syncExpression() {
    if (mounted && _expression != widget.target.text) {
      setState(() => _expression = widget.target.text);
    }
  }

  TextEditingValue _snapshot() {
    final value = widget.target.value;
    return value.copyWith(selection: _safeSelection(value));
  }

  TextSelection _safeSelection(TextEditingValue value) {
    final selection = value.selection;
    if (!selection.isValid || selection.start < 0 || selection.end < 0) {
      return TextSelection.collapsed(offset: value.text.length);
    }
    return TextSelection(
      baseOffset: selection.baseOffset.clamp(0, value.text.length).toInt(),
      extentOffset: selection.extentOffset.clamp(0, value.text.length).toInt(),
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );
  }

  void _pushUndo() {
    _undo.add(_snapshot());
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
  }

  void _setValue(TextEditingValue value) {
    widget.target.value = value;
    widget.onChanged(value.text);
    if (mounted) setState(() => _expression = value.text);
  }

  void _insert(_QuickKey key) {
    final value = _snapshot();
    final selection = _safeSelection(value);
    final start = selection.start;
    final end = selection.end;
    _pushUndo();
    final text = value.text.replaceRange(start, end, key.insertion);
    final caret = (start + key.insertion.length - key.caretBack)
        .clamp(0, text.length)
        .toInt();
    _setValue(
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: caret),
      ),
    );
    setState(() {
      _usage.update(key.label, (count) => count + 1, ifAbsent: () => 1);
    });
  }

  void _backspace() {
    final value = _snapshot();
    final selection = _safeSelection(value);
    final start = selection.start == selection.end
        ? math.max(0, selection.start - 1).toInt()
        : selection.start;
    final end = selection.end;
    if (start == end) return;
    _pushUndo();
    final text = value.text.replaceRange(start, end, '');
    _setValue(
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: start),
      ),
    );
  }

  void _clear() {
    if (widget.target.text.isEmpty) return;
    _pushUndo();
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

  KeyEventResult _handleGridKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keys = _quickInputCategories[_categoryIndex].keys;
    final primaryFocus = FocusManager.instance.primaryFocus;
    final current = primaryFocus == null
        ? -1
        : _keyFocusNodes[_categoryIndex].indexOf(primaryFocus);
    final index = current < 0 ? _focusedKeyIndex : current;
    final logicalKey = event.logicalKey;
    final next = logicalKey == LogicalKeyboardKey.arrowLeft
        ? math.max(0, index - 1).toInt()
        : logicalKey == LogicalKeyboardKey.arrowRight
        ? math.min(keys.length - 1, index + 1).toInt()
        : logicalKey == LogicalKeyboardKey.arrowUp
        ? math.max(0, index - _gridColumns).toInt()
        : logicalKey == LogicalKeyboardKey.arrowDown
        ? math.min(keys.length - 1, index + _gridColumns).toInt()
        : -1;
    if (next < 0) return KeyEventResult.ignored;
    _focusedKeyIndex = next;
    _keyFocusNodes[_categoryIndex][next].requestFocus();
    return KeyEventResult.handled;
  }

  void _submit() {
    Navigator.of(context).pop();
    widget.onSubmit();
  }

  bool get _balanced {
    final stack = <String>[];
    const pairs = <String, String>{')': '(', ']': '[', '}': '{'};
    for (final codeUnit in _expression.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      if (char == '(' || char == '[' || char == '{') {
        stack.add(char);
      } else if (pairs.containsKey(char)) {
        if (stack.isEmpty || stack.removeLast() != pairs[char]) return false;
      }
    }
    return stack.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final history = ref.watch(calculationHistoryProvider);
    final category = _quickInputCategories[_categoryIndex];
    final mostUsed = _usage.entries.isEmpty
        ? null
        : _usage.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final status = _expression.trim().isEmpty
        ? nextEraText(context, 'Expression is empty', '表达式为空')
        : _balanced
        ? nextEraText(context, 'Brackets balanced', '括号匹配')
        : nextEraText(context, 'Check brackets', '请检查括号');
    final statusColor = _expression.trim().isEmpty
        ? colors.onSurfaceVariant
        : _balanced
        ? colors.primary
        : colors.error;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            _undoStep,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undoStep,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true):
            _redoStep,
        const SingleActivator(LogicalKeyboardKey.keyY, meta: true): _redoStep,
        const SingleActivator(LogicalKeyboardKey.backspace): _backspace,
        const SingleActivator(LogicalKeyboardKey.backspace, control: true):
            _backspace,
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: Focus(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.keyboard_alt_outlined, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nextEraText(context, 'Quick input', '快捷输入'),
                    style: textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: _close,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 6),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          nextEraText(context, 'Preview', '预览'),
                          style: textTheme.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        if (mostUsed != null)
                          Text(
                            '${mostUsed.key} ×${mostUsed.value}',
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.tertiary,
                            ),
                          ),
                        Text(
                          status,
                          style: textTheme.labelSmall?.copyWith(
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: math.max(32.0, 24 * textScale + 8),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SelectableText(
                            _expression.isEmpty ? '…' : _expression,
                            maxLines: 1,
                            style: textTheme.bodyLarge?.copyWith(
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      nextEraText(
                        context,
                        'Functions place the cursor inside parentheses.',
                        '函数会自动把光标放入括号，直接输入参数即可。',
                      ),
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: math.max(46.0, 46 * textScale),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _quickInputCategories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final item = _quickInputCategories[index];
                  return ChoiceChip(
                    label: Text(
                      _localized(context, item.labelEn, item.labelZh),
                    ),
                    selected: index == _categoryIndex,
                    onSelected: (_) {
                      setState(() {
                        _categoryIndex = index;
                        _focusedKeyIndex = 0;
                      });
                      _keyFocusNodes[index].first.requestFocus();
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth < 420 ? 3 : 4;
                  _gridColumns = columns;
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Focus(
                          onKeyEvent: _handleGridKey,
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisExtent: math.max(
                                    52.0,
                                    52 * textScale,
                                  ),
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemCount: category.keys.length,
                            itemBuilder: (context, index) {
                              final key = category.keys[index];
                              final accent = _categoryColors[category.id]!;
                              return Tooltip(
                                message: _localized(
                                  context,
                                  key.descriptionEn,
                                  key.descriptionZh,
                                ),
                                child: Material(
                                  color: colors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    focusNode:
                                        _keyFocusNodes[_categoryIndex][index],
                                    autofocus:
                                        _categoryIndex == 0 && index == 0,
                                    onFocusChange: (focused) {
                                      if (focused) _focusedKeyIndex = index;
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => _insert(key),
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border(
                                          bottom: BorderSide(
                                            color: accent,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: Text(
                                        key.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: textTheme.titleSmall?.copyWith(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildHistory(context, history),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.start,
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _undo.isEmpty ? null : _undoStep,
                  icon: const Icon(Icons.undo),
                  label: Text(nextEraText(context, 'Undo', '撤销')),
                ),
                OutlinedButton.icon(
                  onPressed: _backspace,
                  icon: const Icon(Icons.backspace_outlined),
                  label: Text(nextEraText(context, 'Backspace', '退格')),
                ),
                OutlinedButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(nextEraText(context, 'Clear', '清空')),
                ),
                FilledButton.icon(
                  onPressed: _expression.trim().isEmpty ? null : _submit,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(nextEraText(context, 'Insert & plot', '插入并绘制')),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                nextEraText(
                  context,
                  'Arrow keys move · Enter inserts · Ctrl/⌘+Z/Y undo/redo · Esc closes',
                  '方向键移动 · Enter 插入 · Ctrl/⌘+Z/Y 撤销/重做 · Esc 关闭',
                ),
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory(BuildContext context, List<HistoryEntry> history) {
    final colors = Theme.of(context).colorScheme;
    final entries = history.take(6).toList(growable: false);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      leading: const Icon(Icons.history),
      title: Text(nextEraText(context, 'Recent expressions', '最近表达式')),
      subtitle: Text(
        entries.isEmpty
            ? nextEraText(context, 'No expressions yet', '暂无绘图记录')
            : nextEraText(
                context,
                '${entries.length} recent',
                '最近 ${entries.length} 条',
              ),
      ),
      children: <Widget>[
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              nextEraText(
                context,
                'Expressions you plot will appear here.',
                '绘制过的表达式会显示在这里。',
              ),
            ),
          )
        else ...<Widget>[
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: ref.read(calculationHistoryProvider.notifier).clear,
              icon: const Icon(Icons.delete_outline),
              label: Text(nextEraText(context, 'Clear history', '清空历史')),
            ),
          ),
          for (final entry in entries)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.add_to_photos_outlined,
                color: colors.primary,
              ),
              title: Text(
                _expressionFromHistory(entry.expression),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              subtitle: Text(entry.result),
              onTap: () {
                final expression = _expressionFromHistory(entry.expression);
                _pushUndo();
                _setValue(
                  TextEditingValue(
                    text: expression,
                    selection: TextSelection.collapsed(
                      offset: expression.length,
                    ),
                  ),
                );
              },
            ),
        ],
      ],
    );
  }

  String _expressionFromHistory(String value) {
    final separator = value.indexOf(': ');
    return separator < 0 ? value : value.substring(separator + 2);
  }

  String _localized(BuildContext context, String english, String chinese) =>
      nextEraText(context, english, chinese);

  void _close() => Navigator.of(context).maybePop();
}

class _QuickCategory {
  const _QuickCategory(this.id, this.labelEn, this.labelZh, this.keys);

  final String id;
  final String labelEn;
  final String labelZh;
  final List<_QuickKey> keys;
}

class _QuickKey {
  const _QuickKey(
    this.label,
    this.insertion,
    this.caretBack,
    this.descriptionEn,
    this.descriptionZh,
  );

  final String label;
  final String insertion;
  final int caretBack;
  final String descriptionEn;
  final String descriptionZh;
}

const _quickInputCategories = <_QuickCategory>[
  _QuickCategory('basic', 'Basic', '基本', <_QuickKey>[
    _QuickKey('x²', '^2', 0, 'Square: x^2', '平方：x^2'),
    _QuickKey('x³', '^3', 0, 'Cube: x^3', '立方：x^3'),
    _QuickKey('xⁿ', '^', 0, 'Power: x^n', '任意次幂：x^n'),
    _QuickKey('√', 'sqrt()', 1, 'Square root', '平方根'),
    _QuickKey('|x|', 'abs()', 1, 'Absolute value', '绝对值'),
    _QuickKey('eˣ', 'exp()', 1, 'Exponential function', '指数函数'),
    _QuickKey('x!', '!', 0, 'Factorial', '阶乘'),
    _QuickKey('−x', '-', 0, 'Negate / subtract', '取负 / 减法'),
  ]),
  _QuickCategory('operators', 'Operators', '运算符', <_QuickKey>[
    _QuickKey('+', ' + ', 0, 'Addition', '加法'),
    _QuickKey('−', ' - ', 0, 'Subtraction', '减法'),
    _QuickKey('×', '*', 0, 'Multiplication', '乘法'),
    _QuickKey('÷', '/', 0, 'Division', '除法'),
    _QuickKey('^', '^', 0, 'Power', '幂运算'),
    _QuickKey('mod', ' mod ', 0, 'Remainder', '取余'),
    _QuickKey('±', '+/-', 0, 'Plus or minus', '正负号'),
    _QuickKey('%', '/100', 0, 'Percent', '百分比'),
  ]),
  _QuickCategory('algebra', 'Algebra', '代数', <_QuickKey>[
    _QuickKey('asinh', 'asinh()', 1, 'Inverse hyperbolic sine', '反双曲正弦'),
    _QuickKey('acosh', 'acosh()', 1, 'Inverse hyperbolic cosine', '反双曲余弦'),
    _QuickKey('atanh', 'atanh()', 1, 'Inverse hyperbolic tangent', '反双曲正切'),
    _QuickKey('sinh', 'sinh()', 1, 'Hyperbolic sine', '双曲正弦'),
    _QuickKey('cosh', 'cosh()', 1, 'Hyperbolic cosine', '双曲余弦'),
    _QuickKey('tanh', 'tanh()', 1, 'Hyperbolic tangent', '双曲正切'),
    _QuickKey('abs', 'abs()', 1, 'Absolute value', '绝对值'),
    _QuickKey('√', 'sqrt()', 1, 'Square root', '平方根'),
  ]),
  _QuickCategory('compare', 'Compare', '比较', <_QuickKey>[
    _QuickKey('<', ' < ', 0, 'Less than', '小于'),
    _QuickKey('>', ' > ', 0, 'Greater than', '大于'),
    _QuickKey('≤', ' <= ', 0, 'Less than or equal', '小于等于'),
    _QuickKey('≥', ' >= ', 0, 'Greater than or equal', '大于等于'),
    _QuickKey('=', ' = ', 0, 'Equal', '等于'),
    _QuickKey('≠', ' != ', 0, 'Not equal', '不等于'),
  ]),
  _QuickCategory('logexp', 'Log/Exp', '对数/指数', <_QuickKey>[
    _QuickKey('ln', 'ln()', 1, 'Natural logarithm', '自然对数'),
    _QuickKey('log', 'log()', 1, 'Base-10 logarithm', '常用对数'),
    _QuickKey('eˣ', 'exp()', 1, 'Exponential function', '指数函数'),
    _QuickKey('e', 'e', 0, "Euler's number", '自然常数 e'),
    _QuickKey('10ˣ', '10^', 0, 'Ten to a power', '10 的幂'),
    _QuickKey('lg', 'log10()', 1, 'Base-10 logarithm', '常用对数'),
  ]),
  _QuickCategory('trig', 'Trig', '三角', <_QuickKey>[
    _QuickKey('sin', 'sin()', 1, 'Sine (radians)', '正弦（弧度）'),
    _QuickKey('cos', 'cos()', 1, 'Cosine (radians)', '余弦（弧度）'),
    _QuickKey('tan', 'tan()', 1, 'Tangent (radians)', '正切（弧度）'),
    _QuickKey('asin', 'asin()', 1, 'Inverse sine', '反正弦'),
    _QuickKey('acos', 'acos()', 1, 'Inverse cosine', '反余弦'),
    _QuickKey('atan', 'atan()', 1, 'Inverse tangent', '反正切'),
    _QuickKey('π', 'pi', 0, 'Pi', '圆周率'),
    _QuickKey('°', '*pi/180', 0, 'Degrees to radians', '角度转弧度'),
  ]),
  _QuickCategory('rounding', 'Rounding', '取整', <_QuickKey>[
    _QuickKey('floor', 'floor()', 1, 'Round down', '向下取整'),
    _QuickKey('ceil', 'ceil()', 1, 'Round up', '向上取整'),
    _QuickKey('round', 'round()', 1, 'Round to nearest integer', '四舍五入'),
    _QuickKey('trunc', 'trunc()', 1, 'Truncate fractional part', '截断小数部分'),
    _QuickKey('min', 'min(,)', 2, 'Minimum of two values', '两个数的最小值'),
    _QuickKey('max', 'max(,)', 2, 'Maximum of two values', '两个数的最大值'),
  ]),
  _QuickCategory('special', 'Special', '特殊', <_QuickKey>[
    _QuickKey('(', '(', 0, 'Open parenthesis', '左括号'),
    _QuickKey(')', ')', 0, 'Close parenthesis', '右括号'),
    _QuickKey('()', '()', 1, 'Empty parentheses', '空括号'),
    _QuickKey(',', ',', 0, 'Separate arguments', '分隔参数'),
    _QuickKey('!', '!', 0, 'Factorial', '阶乘'),
    _QuickKey('|x|', 'abs()', 1, 'Absolute value', '绝对值'),
    _QuickKey('=', ' = ', 0, 'Equal', '等于'),
    _QuickKey('Space', ' ', 0, 'Insert a space', '插入空格'),
  ]),
  _QuickCategory('constants', 'Constants', '常数', <_QuickKey>[
    _QuickKey('π', 'pi', 0, 'Pi', '圆周率'),
    _QuickKey('e', 'e', 0, "Euler's number", '自然常数 e'),
    _QuickKey('φ', '1.618033988749895', 0, 'Golden ratio', '黄金比例'),
    _QuickKey('τ', '2*pi', 0, 'Tau (2 pi)', '圆周率的两倍'),
    _QuickKey('∞', '1e308', 0, 'Large finite approximation', '极大有限数近似'),
    _QuickKey('π/2', 'pi/2', 0, 'Pi over two', '圆周率的一半'),
    _QuickKey('π/3', 'pi/3', 0, 'Pi over three', '圆周率的三分之一'),
    _QuickKey('π/4', 'pi/4', 0, 'Pi over four', '圆周率的四分之一'),
    _QuickKey('π/6', 'pi/6', 0, 'Pi over six', '圆周率的六分之一'),
    _QuickKey('2π', '2*pi', 0, 'Two pi', '两倍圆周率'),
  ]),
];

const _categoryColors = <String, Color>{
  'basic': Color(0xFF536DDE),
  'operators': Color(0xFF00A6B2),
  'algebra': Color(0xFF459A68),
  'compare': Color(0xFFE5A500),
  'logexp': Color(0xFF3678C8),
  'trig': Color(0xFF8C5CC7),
  'rounding': Color(0xFFE58538),
  'special': Color(0xFFD34E91),
  'constants': Color(0xFFD14949),
};
