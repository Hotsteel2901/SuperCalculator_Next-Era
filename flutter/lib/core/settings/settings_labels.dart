import 'package:flutter/widgets.dart';

import 'app_settings.dart';

bool _zh(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'zh';

/// Localised, human readable labels for the settings enums.
///
/// `enumValue.name` leaked into the UI ("tonalSpot", "excellent", "adaptive"),
/// which reads like a bug even though the underlying value is correct.
String monetStyleLabel(BuildContext context, MonetStyle style) {
  final zh = _zh(context);
  return switch (style) {
    MonetStyle.tonalSpot => zh ? '柔和' : 'Tonal spot',
    MonetStyle.vibrant => zh ? '鲜明' : 'Vibrant',
    MonetStyle.expressive => zh ? '表现力' : 'Expressive',
    MonetStyle.neutral => zh ? '中性' : 'Neutral',
    MonetStyle.monochrome => zh ? '单色' : 'Monochrome',
  };
}

String monetContrastLabel(BuildContext context, MonetContrast contrast) {
  final zh = _zh(context);
  return switch (contrast) {
    MonetContrast.standard => zh ? '标准' : 'Standard',
    MonetContrast.medium => zh ? '中等' : 'Medium',
    MonetContrast.high => zh ? '高' : 'High',
  };
}

String plotResolutionLabel(BuildContext context, PlotResolution value) {
  final zh = _zh(context);
  return switch (value) {
    PlotResolution.adaptive => zh ? '自适应' : 'Adaptive',
    PlotResolution.balanced => zh ? '均衡' : 'Balanced',
    PlotResolution.high => zh ? '高' : 'High',
    PlotResolution.ultra => zh ? '超高' : 'Ultra',
  };
}

String meshDensityLabel(BuildContext context, MeshDensity value) {
  final zh = _zh(context);
  return switch (value) {
    MeshDensity.low => zh ? '低密度' : 'Low',
    MeshDensity.medium => zh ? '中密度' : 'Medium',
    MeshDensity.high => zh ? '高密度' : 'High',
  };
}

String intensityLabel(BuildContext context, ExpressiveIntensity value) {
  final zh = _zh(context);
  return switch (value) {
    ExpressiveIntensity.foundational => zh ? '基础' : 'Foundational',
    ExpressiveIntensity.excellent => zh ? '出色' : 'Excellent',
    ExpressiveIntensity.transformative => zh ? '变革' : 'Transformative',
  };
}
