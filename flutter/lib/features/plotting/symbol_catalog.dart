import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart' show IconData, Icons;
import 'package:shared_preferences/shared_preferences.dart';

/// Groups shown in the quick input panel.
///
/// The order here is the order of the tabs: the most frequently used groups come
/// first, and the list stays short enough to scroll horizontally on a phone.
enum SymbolGroup {
  basic('Basic', '基本', Icons.bolt_rounded),
  functions('Functions', '函数', Icons.functions_rounded),
  trig('Trig', '三角', Icons.waves_rounded),
  logexp('Log / Exp', '对数 / 指数', Icons.trending_up_rounded),
  operators('Operators', '运算符', Icons.calculate_rounded),
  compare('Compare', '比较', Icons.compare_arrows_rounded),
  rounding('Rounding', '取整', Icons.straighten_rounded),
  brackets('Brackets', '括号', Icons.data_array_rounded),
  constants('Constants', '常数', Icons.numbers_rounded),
  variables('Variables', '变量', Icons.tag_rounded);

  const SymbolGroup(this.labelEn, this.labelZh, this.icon);

  final String labelEn;
  final String labelZh;
  final IconData icon;
}

/// A single insertable symbol.
///
/// [caretBack] positions the caret inside the inserted text (for example
/// `sqrt()` places it between the parentheses). When [wrapsSelection] is true
/// and the editor has a selection, the selection is wrapped instead of replaced,
/// which is the behaviour users expect from function keys.
class MathSymbol {
  const MathSymbol({
    required this.id,
    required this.label,
    required this.insertion,
    required this.group,
    required this.descriptionEn,
    required this.descriptionZh,
    this.caretBack = 0,
    this.wrapsSelection = false,
    this.keywords = '',
  });

  final String id;
  final String label;
  final String insertion;
  final SymbolGroup group;
  final String descriptionEn;
  final String descriptionZh;
  final int caretBack;
  final bool wrapsSelection;
  final String keywords;

  /// Whether [query] matches the label, description, insertion or keywords.
  bool matches(String query) {
    if (query.isEmpty) return true;
    final needle = query.toLowerCase();
    return label.toLowerCase().contains(needle) ||
        insertion.toLowerCase().contains(needle) ||
        descriptionEn.toLowerCase().contains(needle) ||
        descriptionZh.contains(query) ||
        keywords.toLowerCase().contains(needle);
  }
}

/// Static catalog of symbols supported by the expression engine.
///
/// Only functions the engine actually implements are listed, so a key never
/// inserts an expression that fails to parse.
abstract final class SymbolCatalog {
  static const List<MathSymbol> all = <MathSymbol>[
    // Basic
    MathSymbol(
      id: 'sq',
      label: 'x²',
      insertion: '^2',
      group: SymbolGroup.basic,
      descriptionEn: 'Square',
      descriptionZh: '平方',
      keywords: 'square power 2',
    ),
    MathSymbol(
      id: 'cube',
      label: 'x³',
      insertion: '^3',
      group: SymbolGroup.basic,
      descriptionEn: 'Cube',
      descriptionZh: '立方',
      keywords: 'cube power 3',
    ),
    MathSymbol(
      id: 'pow',
      label: 'xⁿ',
      insertion: '^',
      group: SymbolGroup.basic,
      descriptionEn: 'Power: x^n',
      descriptionZh: '任意次幂：x^n',
      keywords: 'power exponent',
    ),
    MathSymbol(
      id: 'sqrt',
      label: '√',
      insertion: 'sqrt()',
      caretBack: 1,
      wrapsSelection: true,
      group: SymbolGroup.basic,
      descriptionEn: 'Square root',
      descriptionZh: '平方根',
      keywords: 'sqrt root',
    ),
    MathSymbol(
      id: 'abs',
      label: '|x|',
      insertion: 'abs()',
      caretBack: 1,
      wrapsSelection: true,
      group: SymbolGroup.basic,
      descriptionEn: 'Absolute value',
      descriptionZh: '绝对值',
      keywords: 'abs absolute magnitude',
    ),
    MathSymbol(
      id: 'inv',
      label: '1/x',
      insertion: '1/',
      group: SymbolGroup.basic,
      descriptionEn: 'Reciprocal',
      descriptionZh: '倒数',
      keywords: 'reciprocal inverse',
    ),
    MathSymbol(
      id: 'fact',
      label: 'x!',
      insertion: '!',
      group: SymbolGroup.basic,
      descriptionEn: 'Factorial',
      descriptionZh: '阶乘',
      keywords: 'factorial',
    ),
    MathSymbol(
      id: 'neg',
      label: '±',
      insertion: '-',
      group: SymbolGroup.basic,
      descriptionEn: 'Negate or subtract',
      descriptionZh: '取负 / 减法',
      keywords: 'minus negative',
    ),

    // Functions
    MathSymbol(
      id: 'exp',
      label: 'eˣ',
      insertion: 'exp()',
      caretBack: 1,
      wrapsSelection: true,
      group: SymbolGroup.functions,
      descriptionEn: 'Exponential function',
      descriptionZh: '指数函数',
      keywords: 'exp exponential e',
    ),
    MathSymbol(
      id: 'floor',
      label: 'floor',
      insertion: 'floor()',
      caretBack: 1,
      wrapsSelection: true,
      group: SymbolGroup.functions,
      descriptionEn: 'Round down',
      descriptionZh: '向下取整',
      keywords: 'floor round down',
    ),
    MathSymbol(
      id: 'ceil',
      label: 'ceil',
      insertion: 'ceil()',
      caretBack: 1,
      wrapsSelection: true,
      group: SymbolGroup.functions,
      descriptionEn: 'Round up',
      descriptionZh: '向上取整',
      keywords: 'ceil round up',
    ),
    MathSymbol(
      id: 'round',
      label: 'round',
      insertion: 'round()',
      caretBack: 1,
      wrapsSelection: true,
      group: SymbolGroup.functions,
      descriptionEn: 'Round to nearest integer',
      descriptionZh: '四舍五入',
      keywords: 'round nearest',
    ),
    MathSymbol(
      id: 'trunc',
      label: 'trunc',
      insertion: 'trunc()',
      caretBack: 1,
      wrapsSelection: true,
      group: SymbolGroup.functions,
      descriptionEn: 'Drop the fractional part',
      descriptionZh: '截断小数部分',
      keywords: 'truncate integer',
    ),
    MathSymbol(
      id: 'min',
      label: 'min',
      insertion: 'min(,)',
      caretBack: 2,
      group: SymbolGroup.functions,
      descriptionEn: 'Smaller of two values',
      descriptionZh: '两个数的最小值',
      keywords: 'minimum min',
    ),
    MathSymbol(
      id: 'max',
      label: 'max',
      insertion: 'max(,)',
      caretBack: 2,
      group: SymbolGroup.functions,
      descriptionEn: 'Larger of two values',
      descriptionZh: '两个数的最大值',
      keywords: 'maximum max',
    ),

    // Trig
    MathSymbol(
      id: 'sin',
      label: 'sin',
      insertion: 'sin()',
      caretBack: 1,
      wrapsSelection: true,
      group: SymbolGroup.trig,
      descriptionEn: 'Sine (radians)',
      descriptionZh: '正弦（弧度）',
      keywords: 'sin sine',
    ),
    MathSymbol(
      id: 'cos',
      label: 'cos',
      insertion: 'cos()',
      caretBack: 1,
      wrapsSelection: true,
      group: SymbolGroup.trig,
      descriptionEn: 'Cosine (radians)',
      descriptionZh: '余弦（弧度）',
      keywords: 'cos cosine',
    ),
    MathSymbol(
      id: 'tan',
      label: 'tan',
      insertion: 'tan()',
      caretBack: 1,
      wrapsSelection: true,
      group: SymbolGroup.trig,
      descriptionEn: 'Tangent (radians)',
      descriptionZh: '正切（弧度）',
      keywords: 'tan tangent',
    ),
    MathSymbol(
      id: 'asin',
      label: 'asin',
      insertion: 'asin()',
      caretBack: 1,
      wrapsSelection: true,
      group: SymbolGroup.trig,
      descriptionEn: 'Inverse sine',
      descriptionZh: '反正弦',
      keywords: 'asin arcsin inverse',
    ),
    MathSymbol(
      id: 'acos',
      label: 'acos',
      insertion: 'acos()',
      caretBack: 1,
      wrapsSelection: true,
      group: SymbolGroup.trig,
      descriptionEn: 'Inverse cosine',
      descriptionZh: '反余弦',
      keywords: 'acos arccos inverse',
    ),
    MathSymbol(
      id: 'atan',
      label: 'atan',
      insertion: 'atan()',
      caretBack: 1,
      wrapsSelection: true,
      group: SymbolGroup.trig,
      descriptionEn: 'Inverse tangent',
      descriptionZh: '反正切',
      keywords: 'atan arctan inverse',
    ),
    MathSymbol(
      id: 'sinh',
      label: 'sinh',
      insertion: 'sinh()',
      caretBack: 1,
      wrapsSelection: true,
      group: SymbolGroup.trig,
      descriptionEn: 'Hyperbolic sine',
      descriptionZh: '双曲正弦',
      keywords: 'sinh hyperbolic',
    ),
    MathSymbol(
      id: 'cosh',
      label: 'cosh',
      insertion: 'cosh()',
      caretBack: 1,
      wrapsSelection: true,
      group: SymbolGroup.trig,
      descriptionEn: 'Hyperbolic cosine',
      descriptionZh: '双曲余弦',
      keywords: 'cosh hyperbolic',
    ),
    MathSymbol(
      id: 'tanh',
      label: 'tanh',
      insertion: 'tanh()',
      caretBack: 1,
      wrapsSelection: true,
      group: SymbolGroup.trig,
      descriptionEn: 'Hyperbolic tangent',
      descriptionZh: '双曲正切',
      keywords: 'tanh hyperbolic',
    ),
    MathSymbol(
      id: 'asinh',
      label: 'asinh',
      insertion: 'asinh()',
      caretBack: 1,
      wrapsSelection: true,
      group: SymbolGroup.trig,
      descriptionEn: 'Inverse hyperbolic sine',
      descriptionZh: '反双曲正弦',
      keywords: 'asinh hyperbolic inverse',
    ),
    MathSymbol(
      id: 'acosh',
      label: 'acosh',
      insertion: 'acosh()',
      caretBack: 1,
      wrapsSelection: true,
      group: SymbolGroup.trig,
      descriptionEn: 'Inverse hyperbolic cosine',
      descriptionZh: '反双曲余弦',
      keywords: 'acosh hyperbolic inverse',
    ),
    MathSymbol(
      id: 'atanh',
      label: 'atanh',
      insertion: 'atanh()',
      caretBack: 1,
      wrapsSelection: true,
      group: SymbolGroup.trig,
      descriptionEn: 'Inverse hyperbolic tangent',
      descriptionZh: '反双曲正切',
      keywords: 'atanh hyperbolic inverse',
    ),
    MathSymbol(
      id: 'deg',
      label: '°→rad',
      insertion: '*pi/180',
      group: SymbolGroup.trig,
      descriptionEn: 'Degrees to radians',
      descriptionZh: '角度转弧度',
      keywords: 'degree radians',
    ),

    // Log / exp
    MathSymbol(
      id: 'ln',
      label: 'ln',
      insertion: 'ln()',
      caretBack: 1,
      wrapsSelection: true,
      group: SymbolGroup.logexp,
      descriptionEn: 'Natural logarithm',
      descriptionZh: '自然对数',
      keywords: 'ln natural log',
    ),
    MathSymbol(
      id: 'log',
      label: 'log',
      insertion: 'log()',
      caretBack: 1,
      wrapsSelection: true,
      group: SymbolGroup.logexp,
      descriptionEn: 'Base-10 logarithm',
      descriptionZh: '常用对数',
      keywords: 'log base 10',
    ),
    MathSymbol(
      id: 'log10',
      label: 'log₁₀',
      insertion: 'log10()',
      caretBack: 1,
      wrapsSelection: true,
      group: SymbolGroup.logexp,
      descriptionEn: 'Base-10 logarithm',
      descriptionZh: '以 10 为底的对数',
      keywords: 'log10 base ten',
    ),
    MathSymbol(
      id: 'pow10',
      label: '10ˣ',
      insertion: '10^',
      group: SymbolGroup.logexp,
      descriptionEn: 'Ten to a power',
      descriptionZh: '10 的幂',
      keywords: '10 power',
    ),

    // Operators
    MathSymbol(
      id: 'add',
      label: '+',
      insertion: ' + ',
      group: SymbolGroup.operators,
      descriptionEn: 'Addition',
      descriptionZh: '加法',
      keywords: 'plus add',
    ),
    MathSymbol(
      id: 'sub',
      label: '−',
      insertion: ' - ',
      group: SymbolGroup.operators,
      descriptionEn: 'Subtraction',
      descriptionZh: '减法',
      keywords: 'minus subtract',
    ),
    MathSymbol(
      id: 'mul',
      label: '×',
      insertion: '*',
      group: SymbolGroup.operators,
      descriptionEn: 'Multiplication',
      descriptionZh: '乘法',
      keywords: 'multiply times',
    ),
    MathSymbol(
      id: 'div',
      label: '÷',
      insertion: '/',
      group: SymbolGroup.operators,
      descriptionEn: 'Division',
      descriptionZh: '除法',
      keywords: 'divide',
    ),
    MathSymbol(
      id: 'powop',
      label: '^',
      insertion: '^',
      group: SymbolGroup.operators,
      descriptionEn: 'Power operator',
      descriptionZh: '幂运算符',
      keywords: 'power caret',
    ),
    MathSymbol(
      id: 'mod',
      label: 'mod',
      insertion: ' mod ',
      group: SymbolGroup.operators,
      descriptionEn: 'Remainder',
      descriptionZh: '取余',
      keywords: 'modulo remainder',
    ),
    MathSymbol(
      id: 'percent',
      label: '%',
      insertion: '/100',
      group: SymbolGroup.operators,
      descriptionEn: 'Percent',
      descriptionZh: '百分比',
      keywords: 'percent hundred',
    ),
    MathSymbol(
      id: 'equals',
      label: '=',
      insertion: ' = ',
      group: SymbolGroup.operators,
      descriptionEn: 'Equals',
      descriptionZh: '等于',
      keywords: 'equal assignment',
    ),
    MathSymbol(
      id: 'space',
      label: '␣',
      insertion: ' ',
      group: SymbolGroup.operators,
      descriptionEn: 'Space',
      descriptionZh: '空格',
      keywords: 'space blank',
    ),

    // Compare
    MathSymbol(
      id: 'lt',
      label: '<',
      insertion: ' < ',
      group: SymbolGroup.compare,
      descriptionEn: 'Less than',
      descriptionZh: '小于',
      keywords: 'less than',
    ),
    MathSymbol(
      id: 'gt',
      label: '>',
      insertion: ' > ',
      group: SymbolGroup.compare,
      descriptionEn: 'Greater than',
      descriptionZh: '大于',
      keywords: 'greater than',
    ),
    MathSymbol(
      id: 'le',
      label: '≤',
      insertion: ' <= ',
      group: SymbolGroup.compare,
      descriptionEn: 'Less than or equal',
      descriptionZh: '小于等于',
      keywords: 'less equal',
    ),
    MathSymbol(
      id: 'ge',
      label: '≥',
      insertion: ' >= ',
      group: SymbolGroup.compare,
      descriptionEn: 'Greater than or equal',
      descriptionZh: '大于等于',
      keywords: 'greater equal',
    ),
    MathSymbol(
      id: 'ne',
      label: '≠',
      insertion: ' != ',
      group: SymbolGroup.compare,
      descriptionEn: 'Not equal',
      descriptionZh: '不等于',
      keywords: 'not equal',
    ),

    // Rounding helpers (readable aliases)
    MathSymbol(
      id: 'rfloor',
      label: '⌊x⌋',
      insertion: 'floor()',
      caretBack: 1,
      wrapsSelection: true,
      group: SymbolGroup.rounding,
      descriptionEn: 'Floor',
      descriptionZh: '向下取整',
      keywords: 'floor',
    ),
    MathSymbol(
      id: 'rceil',
      label: '⌈x⌉',
      insertion: 'ceil()',
      caretBack: 1,
      wrapsSelection: true,
      group: SymbolGroup.rounding,
      descriptionEn: 'Ceiling',
      descriptionZh: '向上取整',
      keywords: 'ceil ceiling',
    ),
    MathSymbol(
      id: 'rround',
      label: '≈',
      insertion: 'round()',
      caretBack: 1,
      wrapsSelection: true,
      group: SymbolGroup.rounding,
      descriptionEn: 'Round',
      descriptionZh: '四舍五入',
      keywords: 'round approx',
    ),

    // Brackets
    MathSymbol(
      id: 'lparen',
      label: '(',
      insertion: '(',
      group: SymbolGroup.brackets,
      descriptionEn: 'Open parenthesis (auto-closes)',
      descriptionZh: '左括号（自动补全右括号）',
      keywords: 'parenthesis open',
    ),
    MathSymbol(
      id: 'rparen',
      label: ')',
      insertion: ')',
      group: SymbolGroup.brackets,
      descriptionEn: 'Close parenthesis',
      descriptionZh: '右括号',
      keywords: 'parenthesis close',
    ),
    MathSymbol(
      id: 'lbracket',
      label: '[',
      insertion: '[',
      group: SymbolGroup.brackets,
      descriptionEn: 'Open bracket (auto-closes)',
      descriptionZh: '左方括号（自动补全）',
      keywords: 'bracket open',
    ),
    MathSymbol(
      id: 'rbracket',
      label: ']',
      insertion: ']',
      group: SymbolGroup.brackets,
      descriptionEn: 'Close bracket',
      descriptionZh: '右方括号',
      keywords: 'bracket close',
    ),
    MathSymbol(
      id: 'lbrace',
      label: '{',
      insertion: '{',
      group: SymbolGroup.brackets,
      descriptionEn: 'Open brace (auto-closes)',
      descriptionZh: '左花括号（自动补全）',
      keywords: 'brace open',
    ),
    MathSymbol(
      id: 'rbrace',
      label: '}',
      insertion: '}',
      group: SymbolGroup.brackets,
      descriptionEn: 'Close brace',
      descriptionZh: '右花括号',
      keywords: 'brace close',
    ),
    MathSymbol(
      id: 'comma',
      label: ',',
      insertion: ',',
      group: SymbolGroup.brackets,
      descriptionEn: 'Argument separator',
      descriptionZh: '参数分隔符',
      keywords: 'comma separator',
    ),

    // Constants
    MathSymbol(
      id: 'pi',
      label: 'π',
      insertion: 'pi',
      group: SymbolGroup.constants,
      descriptionEn: 'Pi',
      descriptionZh: '圆周率',
      keywords: 'pi circle',
    ),
    MathSymbol(
      id: 'e',
      label: 'e',
      insertion: 'e',
      group: SymbolGroup.constants,
      descriptionEn: "Euler's number",
      descriptionZh: '自然常数 e',
      keywords: 'euler e constant',
    ),
    MathSymbol(
      id: 'phi',
      label: 'φ',
      insertion: '1.618033988749895',
      group: SymbolGroup.constants,
      descriptionEn: 'Golden ratio',
      descriptionZh: '黄金比例',
      keywords: 'phi golden ratio',
    ),
    MathSymbol(
      id: 'tau',
      label: 'τ',
      insertion: '2*pi',
      group: SymbolGroup.constants,
      descriptionEn: 'Tau (2π)',
      descriptionZh: '圆周率的两倍',
      keywords: 'tau',
    ),
    MathSymbol(
      id: 'pi2',
      label: 'π/2',
      insertion: 'pi/2',
      group: SymbolGroup.constants,
      descriptionEn: 'Pi over two',
      descriptionZh: '圆周率的一半',
      keywords: 'pi half',
    ),
    MathSymbol(
      id: 'pi3',
      label: 'π/3',
      insertion: 'pi/3',
      group: SymbolGroup.constants,
      descriptionEn: 'Pi over three',
      descriptionZh: '圆周率的三分之一',
      keywords: 'pi third',
    ),
    MathSymbol(
      id: 'pi4',
      label: 'π/4',
      insertion: 'pi/4',
      group: SymbolGroup.constants,
      descriptionEn: 'Pi over four',
      descriptionZh: '圆周率的四分之一',
      keywords: 'pi quarter',
    ),
    MathSymbol(
      id: 'pi6',
      label: 'π/6',
      insertion: 'pi/6',
      group: SymbolGroup.constants,
      descriptionEn: 'Pi over six',
      descriptionZh: '圆周率的六分之一',
      keywords: 'pi sixth',
    ),
    MathSymbol(
      id: 'twopi',
      label: '2π',
      insertion: '2*pi',
      group: SymbolGroup.constants,
      descriptionEn: 'Two pi',
      descriptionZh: '两倍圆周率',
      keywords: 'two pi',
    ),

    // Variables
    MathSymbol(
      id: 'varx',
      label: 'x',
      insertion: 'x',
      group: SymbolGroup.variables,
      descriptionEn: 'Plot variable x',
      descriptionZh: '绘图变量 x',
      keywords: 'x variable',
    ),
    MathSymbol(
      id: 'vary',
      label: 'y',
      insertion: 'y',
      group: SymbolGroup.variables,
      descriptionEn: 'Plot variable y',
      descriptionZh: '绘图变量 y',
      keywords: 'y variable',
    ),
    MathSymbol(
      id: 'vart',
      label: 't',
      insertion: 't',
      group: SymbolGroup.variables,
      descriptionEn: 'Parameter t (maps to x)',
      descriptionZh: '参数 t（映射为 x）',
      keywords: 't parameter',
    ),
  ];

  static List<MathSymbol> byGroup(SymbolGroup group) =>
      all.where((symbol) => symbol.group == group).toList(growable: false);

  static MathSymbol? byId(String id) {
    for (final symbol in all) {
      if (symbol.id == id) return symbol;
    }
    return null;
  }

  static List<MathSymbol> search(String query) {
    if (query.trim().isEmpty) return const <MathSymbol>[];
    return all
        .where((symbol) => symbol.matches(query.trim()))
        .toList(growable: false);
  }
}

/// Persists favourites, recents and usage counts for the quick input panel.
///
/// Storage is best-effort: on Web private mode or a locked profile the panel
/// still works with the in-memory state for the current session.
class QuickSymbolStore {
  QuickSymbolStore._(this._preferences);

  static const _favoritesKey = 'supercalculator.quick_input.favorites.v1';
  static const _recentsKey = 'supercalculator.quick_input.recents.v1';
  static const _usageKey = 'supercalculator.quick_input.usage.v1';
  static const int maxRecents = 10;

  final SharedPreferences? _preferences;
  final Set<String> favorites = <String>{};
  final List<String> recents = <String>[];
  final Map<String, int> usage = <String, int>{};
  Timer? _persistTimer;

  static Future<QuickSymbolStore> load() async {
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (_) {
      preferences = null;
    }
    final store = QuickSymbolStore._(preferences);
    try {
      final favorites = preferences?.getStringList(_favoritesKey);
      if (favorites != null) {
        store.favorites.addAll(
          favorites.where((id) => SymbolCatalog.byId(id) != null),
        );
      }
      final recents = preferences?.getStringList(_recentsKey);
      if (recents != null) {
        store.recents.addAll(
          recents.where((id) => SymbolCatalog.byId(id) != null),
        );
      }
      final usage = preferences?.getString(_usageKey);
      if (usage != null) {
        final decoded = jsonDecode(usage);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final value = entry.value;
            if (entry.key is String && value is num) {
              store.usage[entry.key as String] = value.toInt();
            }
          }
        }
      }
    } catch (_) {
      // Corrupt payloads are ignored; defaults keep the panel usable.
    }
    return store;
  }

  bool isFavorite(String id) => favorites.contains(id);

  void toggleFavorite(String id) {
    if (!favorites.remove(id)) favorites.add(id);
    _schedulePersist();
  }

  void recordUsage(String id) {
    usage[id] = (usage[id] ?? 0) + 1;
    recents
      ..remove(id)
      ..insert(0, id);
    if (recents.length > maxRecents) {
      recents.removeRange(maxRecents, recents.length);
    }
    _schedulePersist();
  }

  List<MathSymbol> get favoriteSymbols => favorites
      .map(SymbolCatalog.byId)
      .whereType<MathSymbol>()
      .toList(growable: false);

  List<MathSymbol> get recentSymbols => recents
      .map(SymbolCatalog.byId)
      .whereType<MathSymbol>()
      .toList(growable: false);

  /// Most used symbols, used for the "suggested" row.
  List<MathSymbol> get suggested {
    final entries = usage.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .take(6)
        .map((entry) => SymbolCatalog.byId(entry.key))
        .whereType<MathSymbol>()
        .toList(growable: false);
  }

  /// Coalesces the three writes into one tick; typing a formula can insert
  /// dozens of symbols per second and each platform write crosses a channel.
  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 450), _persist);
  }

  void _persist() {
    final preferences = _preferences;
    if (preferences == null) return;
    preferences.setStringList(_favoritesKey, favorites.toList(growable: false));
    preferences.setStringList(_recentsKey, recents);
    preferences.setString(
      _usageKey,
      jsonEncode(
        usage.map((key, value) => MapEntry<String, String>(key, '$value')),
      ),
    );
  }

  void dispose() {
    _persistTimer?.cancel();
    _persist();
  }
}
