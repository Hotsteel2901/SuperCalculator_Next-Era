import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'SuperCalculator - Next Era'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @plotting.
  ///
  /// In en, this message translates to:
  /// **'Plotting'**
  String get plotting;

  /// No description provided for @calculus.
  ///
  /// In en, this message translates to:
  /// **'Calculus'**
  String get calculus;

  /// No description provided for @equations.
  ///
  /// In en, this message translates to:
  /// **'Equations'**
  String get equations;

  /// No description provided for @ode.
  ///
  /// In en, this message translates to:
  /// **'ODE'**
  String get ode;

  /// No description provided for @signals.
  ///
  /// In en, this message translates to:
  /// **'Signals'**
  String get signals;

  /// No description provided for @dataAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get dataAnalysis;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @linearAlgebra.
  ///
  /// In en, this message translates to:
  /// **'Linear algebra'**
  String get linearAlgebra;

  /// No description provided for @tools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'One fast workbench for exploring mathematics'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'SuperCalculator - Next Era brings function and multi-curve plotting, parameter controls, intersection markers and free coordinate points together with calculus, equations, ODE, data, matrices and finance.'**
  String get welcomeBody;

  /// No description provided for @openPlotter.
  ///
  /// In en, this message translates to:
  /// **'Open plotting workbench'**
  String get openPlotter;

  /// No description provided for @migrationStatus.
  ///
  /// In en, this message translates to:
  /// **'Next Era v6.0.0'**
  String get migrationStatus;

  /// No description provided for @expression.
  ///
  /// In en, this message translates to:
  /// **'Expression'**
  String get expression;

  /// No description provided for @argumentX.
  ///
  /// In en, this message translates to:
  /// **'x value'**
  String get argumentX;

  /// No description provided for @evaluate.
  ///
  /// In en, this message translates to:
  /// **'Evaluate'**
  String get evaluate;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @quickExamples.
  ///
  /// In en, this message translates to:
  /// **'Quick examples'**
  String get quickExamples;

  /// No description provided for @result.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get result;

  /// No description provided for @plotPreview.
  ///
  /// In en, this message translates to:
  /// **'Plot preview'**
  String get plotPreview;

  /// No description provided for @backend.
  ///
  /// In en, this message translates to:
  /// **'Backend'**
  String get backend;

  /// No description provided for @nativeFfi.
  ///
  /// In en, this message translates to:
  /// **'Native FFI'**
  String get nativeFfi;

  /// No description provided for @wasm.
  ///
  /// In en, this message translates to:
  /// **'WebAssembly'**
  String get wasm;

  /// No description provided for @dartFallback.
  ///
  /// In en, this message translates to:
  /// **'Dart fallback'**
  String get dartFallback;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @computing.
  ///
  /// In en, this message translates to:
  /// **'Computing…'**
  String get computing;

  /// No description provided for @invalidExpression.
  ///
  /// In en, this message translates to:
  /// **'Could not evaluate this expression.'**
  String get invalidExpression;

  /// No description provided for @noResult.
  ///
  /// In en, this message translates to:
  /// **'Enter an expression and evaluate it.'**
  String get noResult;

  /// No description provided for @featureComingSoon.
  ///
  /// In en, this message translates to:
  /// **'This capability is part of the Next Era feature set and will keep gaining native and replaceable backend implementations.'**
  String get featureComingSoon;

  /// No description provided for @aboutBody.
  ///
  /// In en, this message translates to:
  /// **'SuperCalculator - Next Era uses a Flutter application shell with replaceable native and Dart computation backends, while preserving the shared C core and the legacy platform capability set.'**
  String get aboutBody;

  /// The application version shown on the About page
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLabel(Object version);

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'6.0.0'**
  String get version;

  /// Number of points currently rendered in the plot preview
  ///
  /// In en, this message translates to:
  /// **'{count} sampled points'**
  String plotPoints(Object count);

  /// Screen reader summary for the plot preview
  ///
  /// In en, this message translates to:
  /// **'Function plot for {expression}, with {count} finite samples.'**
  String accessibilityPlotSummary(Object count, Object expression);

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme, Material You dynamic color and expressive intensity.'**
  String get settingsSubtitle;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeMode;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @monetTitle.
  ///
  /// In en, this message translates to:
  /// **'Material You dynamic color'**
  String get monetTitle;

  /// No description provided for @monetDescription.
  ///
  /// In en, this message translates to:
  /// **'Derive the palette from your wallpaper and system accent color.'**
  String get monetDescription;

  /// No description provided for @monetUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available on this device.'**
  String get monetUnavailable;

  /// No description provided for @expressiveIntensity.
  ///
  /// In en, this message translates to:
  /// **'Expressive intensity'**
  String get expressiveIntensity;

  /// No description provided for @intensityFoundational.
  ///
  /// In en, this message translates to:
  /// **'Foundational'**
  String get intensityFoundational;

  /// No description provided for @intensityExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get intensityExcellent;

  /// No description provided for @intensityTransformative.
  ///
  /// In en, this message translates to:
  /// **'Transformative'**
  String get intensityTransformative;

  /// No description provided for @intensityFoundationalDescription.
  ///
  /// In en, this message translates to:
  /// **'Clarity and familiarity first.'**
  String get intensityFoundationalDescription;

  /// No description provided for @intensityExcellentDescription.
  ///
  /// In en, this message translates to:
  /// **'Stronger color, type and shape while preserving established patterns.'**
  String get intensityExcellentDescription;

  /// No description provided for @intensityTransformativeDescription.
  ///
  /// In en, this message translates to:
  /// **'Bold shapes and motion for hero moments, with the same accessibility contract.'**
  String get intensityTransformativeDescription;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'A cross-platform scientific calculator and plotting workbench.'**
  String get aboutTagline;

  /// No description provided for @aboutAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get aboutAuthor;

  /// No description provided for @aboutSourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get aboutSourceCode;

  /// No description provided for @aboutLicense.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get aboutLicense;

  /// No description provided for @licenseName.
  ///
  /// In en, this message translates to:
  /// **'GNU Affero General Public License v3.0 or later'**
  String get licenseName;

  /// No description provided for @licenseView.
  ///
  /// In en, this message translates to:
  /// **'View license'**
  String get licenseView;

  /// No description provided for @aboutBuiltWith.
  ///
  /// In en, this message translates to:
  /// **'Built with Flutter, Riverpod and a replaceable C/Dart computation backend.'**
  String get aboutBuiltWith;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied to the clipboard.'**
  String get linkCopied;

  /// No description provided for @linkOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link; it was copied instead.'**
  String get linkOpenFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
