import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/design_tokens.dart';
import '../../core/ui/feature_widgets.dart';
import '../../l10n/generated/app_localizations.dart';

const String _authorName = 'Hotsteel2901';
const String _githubProfileUrl = 'https://github.com/Hotsteel2901';
const String _codebergProfileUrl = 'https://codeberg.org/hotsteel';
const String _githubRepoUrl =
    'https://github.com/Hotsteel2901/SuperCalculator_Next-Era';
const String _codebergRepoUrl =
    'https://codeberg.org/hotsteel/SuperCalculator_Next-Era';
const String _licenseUrl = 'https://www.gnu.org/licenses/agpl-3.0.html';

/// About page with the author, both source repositories and the license.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = SuperCalcDesignTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return FeaturePageFrame(
      title: l10n.about,
      icon: Icons.info_outline,
      subtitle: l10n.aboutTagline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: EdgeInsets.all(tokens.pagePadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.calculate_outlined,
                    size: 48,
                    color: scheme.onPrimaryContainer,
                  ),
                  SizedBox(width: tokens.cardGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.appTitle,
                          style: textTheme.titleLarge?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.versionLabel(l10n.version),
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        SizedBox(height: tokens.controlGap),
                        Text(
                          l10n.aboutBody,
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: tokens.cardGap),
          FeatureCard(
            title: l10n.aboutAuthor,
            icon: Icons.person_outline,
            child: const Column(
              children: <Widget>[
                _LinkTile(
                  icon: Icons.person_outline,
                  title: '$_authorName · GitHub',
                  url: _githubProfileUrl,
                ),
                Divider(),
                _LinkTile(
                  icon: Icons.person_outline,
                  title: '$_authorName · Codeberg',
                  url: _codebergProfileUrl,
                ),
              ],
            ),
          ),
          SizedBox(height: tokens.cardGap),
          FeatureCard(
            title: l10n.aboutSourceCode,
            icon: Icons.code,
            child: const Column(
              children: <Widget>[
                _LinkTile(
                  icon: Icons.code,
                  title: 'GitHub',
                  url: _githubRepoUrl,
                ),
                Divider(),
                _LinkTile(
                  icon: Icons.code,
                  title: 'Codeberg',
                  url: _codebergRepoUrl,
                ),
              ],
            ),
          ),
          SizedBox(height: tokens.cardGap),
          FeatureCard(
            title: l10n.aboutLicense,
            icon: Icons.gavel_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(l10n.licenseName, style: textTheme.titleMedium),
                SizedBox(height: tokens.controlGap),
                Text(
                  l10n.aboutBuiltWith,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: tokens.controlGap),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    onPressed: () => _openUrl(context, _licenseUrl),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l10n.licenseView),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openUrl(BuildContext context, String url) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (opened) return;
  await Clipboard.setData(ClipboardData(text: url));
  messenger.showSnackBar(SnackBar(content: Text(l10n.linkOpenFailed)));
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.icon, required this.title, required this.url});

  final IconData icon;
  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: scheme.primary),
      title: Text(title),
      subtitle: SelectableText(
        url,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: scheme.primary),
      ),
      trailing: IconButton(
        tooltip: l10n.copyLink,
        icon: const Icon(Icons.copy_all_outlined),
        onPressed: () => _copyUrl(context, url),
      ),
      onTap: () => _openUrl(context, url),
    );
  }
}

Future<void> _copyUrl(BuildContext context, String url) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: url));
  messenger.showSnackBar(SnackBar(content: Text(l10n.linkCopied)));
}
