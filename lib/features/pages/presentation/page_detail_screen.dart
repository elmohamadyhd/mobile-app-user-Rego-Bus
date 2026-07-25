import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/pages/presentation/cms_html_document.dart';
import 'package:safaria/features/pages/presentation/providers/pages_providers.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/pages/cms_page_paths.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

class PageDetailScreen extends ConsumerStatefulWidget {
  const PageDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<PageDetailScreen> createState() => _PageDetailScreenState();
}

class _PageDetailScreenState extends ConsumerState<PageDetailScreen> {
  WebViewController? _controller;
  String? _loadedContent;

  String _fallbackTitle(AppLocalizations l10n) {
    if (widget.slug == CmsPagePaths.termsSlug) {
      return l10n.cmsPageTermsTitle;
    }
    if (widget.slug == CmsPagePaths.privacySlug) {
      return l10n.cmsPagePrivacyTitle;
    }
    return l10n.cmsPageGenericTitle;
  }

  void _ensureHtmlLoaded(String content) {
    if (_loadedContent == content && _controller != null) return;
    final locale = Localizations.localeOf(context);
    final html = wrapCmsHtml(
      content: content,
      lang: locale.languageCode,
      rtl: Directionality.of(context) == TextDirection.rtl,
    );
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(AppColors.bgElevated)
      ..loadHtmlString(html);
    setState(() {
      _controller = controller;
      _loadedContent = content;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(pageDetailProvider(widget.slug));

    final title = async.maybeWhen(
      data: (page) => page.title,
      orElse: () => _fallbackTitle(l10n),
    );

    return Scaffold(
      backgroundColor: AppColors.bgElevated,
      appBar: AppBar(
        backgroundColor: AppColors.bgElevated,
        foregroundColor: AppColors.textPrimary,
        title: Text(title, style: AppTypography.title),
        elevation: 0,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.cmsPageLoadError,
                textAlign: TextAlign.center,
                style: AppTypography.body,
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: l10n.cmsPageRetry,
                onPressed: () {
                  setState(() {
                    _controller = null;
                    _loadedContent = null;
                  });
                  ref.invalidate(pageDetailProvider(widget.slug));
                },
              ),
            ],
          ),
        ),
        data: (page) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _ensureHtmlLoaded(page.content);
          });
          final controller = _controller;
          if (controller == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return WebViewWidget(controller: controller);
        },
      ),
    );
  }
}
