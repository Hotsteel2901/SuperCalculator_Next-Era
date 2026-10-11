// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'SuperCalculator - Next Era';

  @override
  String get home => '首页';

  @override
  String get plotting => '绘图';

  @override
  String get calculus => '微积分';

  @override
  String get equations => '方程';

  @override
  String get ode => '微分方程';

  @override
  String get signals => '信号处理';

  @override
  String get dataAnalysis => '数据分析';

  @override
  String get statistics => '统计概率';

  @override
  String get linearAlgebra => '线性代数';

  @override
  String get tools => '工具';

  @override
  String get settings => '设置';

  @override
  String get about => '关于';

  @override
  String get welcomeTitle => '一个工作台，清晰探索数学';

  @override
  String get welcomeBody =>
      'SuperCalculator - Next Era 将函数与多曲线绘图、参数控制、交点标记和自由坐标标点，与微积分、方程、ODE、数据、矩阵和金融计算统一起来。';

  @override
  String get openPlotter => '打开绘图工作台';

  @override
  String get migrationStatus => 'Next Era v6.0.0';

  @override
  String get expression => '表达式';

  @override
  String get argumentX => 'x 值';

  @override
  String get evaluate => '计算';

  @override
  String get clear => '清空';

  @override
  String get quickExamples => '快速示例';

  @override
  String get result => '结果';

  @override
  String get plotPreview => '绘图预览';

  @override
  String get backend => '计算后端';

  @override
  String get nativeFfi => '原生 FFI';

  @override
  String get wasm => 'WebAssembly';

  @override
  String get dartFallback => 'Dart 回退';

  @override
  String get ready => '就绪';

  @override
  String get computing => '计算中…';

  @override
  String get invalidExpression => '无法计算此表达式。';

  @override
  String get noResult => '输入表达式后点击计算。';

  @override
  String get featureComingSoon => '此能力属于 Next Era 功能集，将持续接入原生与可替换计算后端。';

  @override
  String get aboutBody =>
      'SuperCalculator - Next Era 使用 Flutter 应用壳、可替换的原生与 Dart 计算后端，并保留共享 C 核心及旧平台能力。';

  @override
  String versionLabel(Object version) {
    return '版本 $version';
  }

  @override
  String get version => '6.0.0';

  @override
  String plotPoints(Object count) {
    return '已采样 $count 个点';
  }

  @override
  String accessibilityPlotSummary(Object count, Object expression) {
    return '表达式 $expression 的函数图，共有 $count 个有效采样点。';
  }

  @override
  String get settingsSubtitle => '主题、Material You 动态取色与 Expressive 强度。';

  @override
  String get appearance => '外观';

  @override
  String get themeMode => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get monetTitle => 'Material You 动态取色';

  @override
  String get monetDescription => '从壁纸与系统强调色派生配色。';

  @override
  String get monetUnavailable => '当前设备不支持。';

  @override
  String get expressiveIntensity => 'Expressive 强度';

  @override
  String get intensityFoundational => '基础';

  @override
  String get intensityExcellent => '出色';

  @override
  String get intensityTransformative => '变革';

  @override
  String get intensityFoundationalDescription => '清晰与熟悉优先。';

  @override
  String get intensityExcellentDescription => '在保留既有模式的前提下强化色彩、字体与形状。';

  @override
  String get intensityTransformativeDescription =>
      '为高光时刻采用更大胆的形状与动效，同时保持同样的无障碍契约。';

  @override
  String get aboutTagline => '跨平台科学计算与函数绘图工作台。';

  @override
  String get aboutAuthor => '作者';

  @override
  String get aboutSourceCode => '源代码';

  @override
  String get aboutLicense => '许可';

  @override
  String get licenseName => 'GNU Affero 通用公共许可证 v3.0 或更高版本';

  @override
  String get licenseView => '查看许可';

  @override
  String get aboutBuiltWith => '使用 Flutter、Riverpod 与可替换的 C/Dart 计算后端构建。';

  @override
  String get copyLink => '复制链接';

  @override
  String get linkCopied => '链接已复制到剪贴板。';

  @override
  String get linkOpenFailed => '无法打开链接，已改为复制。';
}
