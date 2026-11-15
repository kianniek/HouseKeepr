import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../generated/app_localizations.dart';
import '../../../../services/recipe_import_service.dart';

/// Opens a recipe URL in an in-app WebView (using the device's real browser
/// engine) so sites behind WAFs/bot-checks (e.g. HTTP 403) load normally, then
/// extracts the recipe's HTML/JSON-LD and returns an [ImportedRecipe].
class RecipeWebViewExtractorPage extends StatefulWidget {
  final String url;
  final RecipeImportService service;

  const RecipeWebViewExtractorPage({
    super.key,
    required this.url,
    required this.service,
  });

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  State<RecipeWebViewExtractorPage> createState() =>
      _RecipeWebViewExtractorPageState();
}

class _RecipeWebViewExtractorPageState
    extends State<RecipeWebViewExtractorPage> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _isExtracting = false;
  bool _hasAutoExtracted = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageFinished: (_) {
            if (!_hasAutoExtracted) {
              _hasAutoExtracted = true;
              // Give client-side scripts a brief moment to hydrate JSON-LD/DOM
              Future.delayed(const Duration(milliseconds: 600), () {
                if (mounted) _tryExtract(manual: false);
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _tryExtract({required bool manual}) async {
    if (_isExtracting || !mounted) return;
    setState(() => _isExtracting = true);

    try {
      final rawResult = await _controller.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );
      final html = _decodeJsString(rawResult);
      if (html == null || html.isEmpty) {
        if (manual && mounted) {
          _showSnack('Could not read page content yet.');
        }
        return;
      }

      final recipe = widget.service.parseHtml(html, url: widget.url);
      if (mounted) {
        Navigator.of(context).pop(recipe);
      }
    } catch (e) {
      if (manual && mounted) {
        _showSnack(e.toString());
      }
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  String? _decodeJsString(Object? raw) {
    if (raw == null) return null;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
        try {
          final decoded = json.decode(trimmed);
          if (decoded is String) return decoded;
        } catch (_) {}
      }
      return raw;
    }
    return raw.toString();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sourceName = RecipeImportService.deriveSourceName(widget.url);

    return Scaffold(
      appBar: AppBar(
        title: Text(sourceName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _isExtracting ? null : () => _tryExtract(manual: true),
              icon: _isExtracting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_done, size: 18),
              label: Text(l10n.extractRecipe),
            ),
          ),
        ],
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(value: _progress / 100),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
