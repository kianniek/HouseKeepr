import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/widget_settings.dart';
import '../../../../services/theme_controller.dart';
import '../../../../services/widget_service.dart';
import '../../../common/app_theme.dart';

/// Hub screen listing each home-screen widget and opening its dedicated settings.
class WidgetSettingsPage extends StatelessWidget {
  final int? appWidgetId;

  const WidgetSettingsPage({super.key, this.appWidgetId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home Screen Widgets')),
      body: ListView(
        children: [
          const _WidgetThemeSection(),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.medication_outlined),
            title: const Text('Pill Reminder Widget'),
            subtitle: const Text(
              'Hide unused toggles, customize title & dose counts',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    PillWidgetSettingsPage(appWidgetId: appWidgetId),
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.shopping_cart_outlined),
            title: const Text('Shopping List Widget'),
            subtitle: const Text(
              'Hide checked items & toggle compact item count',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ShoppingWidgetSettingsPage(appWidgetId: appWidgetId),
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.coffee_outlined),
            title: const Text('Coffee Picker Widget'),
            subtitle: const Text(
              'Custom recipe pool & recipe subtitle visibility',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    CoffeeWidgetSettingsPage(appWidgetId: appWidgetId),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetThemeSection extends StatefulWidget {
  const _WidgetThemeSection();

  @override
  State<_WidgetThemeSection> createState() => _WidgetThemeSectionState();
}

class _WidgetThemeSectionState extends State<_WidgetThemeSection> {
  WidgetSettingsRepository? _repo;
  WidgetSettings _settings = const WidgetSettings();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = WidgetSettingsRepository(prefs);
    if (!mounted) return;
    setState(() {
      _repo = repo;
      _settings = repo.load();
    });
  }

  Future<void> _update(WidgetSettings next) async {
    setState(() => _settings = next);
    await _repo?.save(next);
    await WidgetService.instance.applyWidgetSettings(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'Widget Appearance',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.palette_outlined),
          title: const Text('Match App Theme'),
          subtitle: const Text(
            'Use the same color palette and light/dark mode as the app',
          ),
          value: _settings.widgetFollowAppTheme,
          onChanged: (v) =>
              _update(_settings.copyWith(widgetFollowAppTheme: v)),
        ),
        if (!_settings.widgetFollowAppTheme) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppThemeType.values
                  .where(
                    (t) =>
                        t != AppThemeType.dynamic ||
                        ThemeController.instance.isDynamicSupported,
                  )
                  .map((t) {
                    final selected = _settings.widgetThemeType == t.name;
                    return ChoiceChip(
                      label: Text(t.label),
                      selected: selected,
                      onSelected: (_) =>
                          _update(_settings.copyWith(widgetThemeType: t.name)),
                    );
                  })
                  .toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'system', label: Text('System')),
                  ButtonSegment(value: 'light', label: Text('Light')),
                  ButtonSegment(value: 'dark', label: Text('Dark')),
                ],
                selected: {_settings.widgetThemeMode},
                onSelectionChanged: (sel) {
                  if (sel.isNotEmpty) {
                    _update(_settings.copyWith(widgetThemeMode: sel.first));
                  }
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

typedef _WidgetSettingsBuilder =
    List<Widget> Function(
      BuildContext context,
      WidgetSettings settings,
      Future<void> Function(WidgetSettings next) updateSettings,
    );

class _SingleWidgetSettingsScaffold extends StatefulWidget {
  final String title;
  final int? appWidgetId;
  final _WidgetSettingsBuilder builder;

  const _SingleWidgetSettingsScaffold({
    required this.title,
    this.appWidgetId,
    required this.builder,
  });

  @override
  State<_SingleWidgetSettingsScaffold> createState() =>
      _SingleWidgetSettingsScaffoldState();
}

class _SingleWidgetSettingsScaffoldState
    extends State<_SingleWidgetSettingsScaffold> {
  static const _widgetActionsChannel = MethodChannel(
    'housekeepr/widget_actions',
  );

  WidgetSettingsRepository? _repository;
  WidgetSettings _settings = const WidgetSettings();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = WidgetSettingsRepository(prefs);
    if (!mounted) return;
    setState(() {
      _repository = repo;
      _settings = repo.load();
      _loading = false;
    });
  }

  Future<void> _updateSettings(WidgetSettings next) async {
    setState(() => _settings = next);
    await _repository?.save(next);
    await WidgetService.instance.applyWidgetSettings(next);
  }

  Future<void> _saveAndFinish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _repository?.save(_settings);
      await WidgetService.instance.applyWidgetSettings(_settings);
      if (widget.appWidgetId != null) {
        try {
          await _widgetActionsChannel.invokeMethod(
            'finishWidgetConfiguration',
            {'appWidgetId': widget.appWidgetId},
          );
        } catch (_) {}
      }
      if (mounted) {
        Navigator.of(context).maybePop();
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWidgetConfig = widget.appWidgetId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (isWidgetConfig)
            TextButton(
              onPressed: _loading || _saving ? null : _saveAndFinish,
              child: const Text('Save'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: widget.builder(context, _settings, _updateSettings),
            ),
      bottomNavigationBar: isWidgetConfig && !_loading
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveAndFinish,
                  icon: const Icon(Icons.check),
                  label: const Text('Save & Return Home'),
                ),
              ),
            )
          : null,
    );
  }
}

/// Dedicated settings screen for the Pill Reminder home-screen widget.
class PillWidgetSettingsPage extends StatelessWidget {
  final int? appWidgetId;

  const PillWidgetSettingsPage({super.key, this.appWidgetId});

  Future<void> _editPillTitle(
    BuildContext context,
    WidgetSettings settings,
    Future<void> Function(WidgetSettings next) updateSettings,
  ) async {
    final controller = TextEditingController(text: settings.pillWidgetTitle);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pill Widget Title'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Title',
            hintText: 'Leave empty to hide header',
          ),
          textCapitalization: TextCapitalization.sentences,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    await updateSettings(settings.copyWith(pillWidgetTitle: result));
  }

  @override
  Widget build(BuildContext context) {
    return _SingleWidgetSettingsScaffold(
      title: 'Pill Reminder Widget',
      appWidgetId: appWidgetId,
      builder: (context, settings, updateSettings) => [
        SwitchListTile(
          title: const Text('Hide unused toggles'),
          subtitle: const Text(
            'Only show Daytime or Evening when doses are scheduled for that slot',
          ),
          value: settings.pillHideUnusedToggles,
          onChanged: (value) =>
              updateSettings(settings.copyWith(pillHideUnusedToggles: value)),
        ),
        ListTile(
          title: const Text('Widget title'),
          subtitle: Text(
            settings.pillWidgetTitle.isEmpty
                ? 'Hidden'
                : settings.pillWidgetTitle,
          ),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => _editPillTitle(context, settings, updateSettings),
        ),
        SwitchListTile(
          title: const Text('Show dose count'),
          subtitle: const Text(
            'Display scheduled dose count next to each switch',
          ),
          value: settings.pillShowDoseCount,
          onChanged: (value) =>
              updateSettings(settings.copyWith(pillShowDoseCount: value)),
        ),
      ],
    );
  }
}

/// Dedicated settings screen for the Shopping List home-screen widget.
class ShoppingWidgetSettingsPage extends StatelessWidget {
  final int? appWidgetId;

  const ShoppingWidgetSettingsPage({super.key, this.appWidgetId});

  @override
  Widget build(BuildContext context) {
    return _SingleWidgetSettingsScaffold(
      title: 'Shopping List Widget',
      appWidgetId: appWidgetId,
      builder: (context, settings, updateSettings) => [
        SwitchListTile(
          title: const Text('Hide checked items'),
          subtitle: const Text('Only show unchecked items on the home screen'),
          value: settings.shoppingHideChecked,
          onChanged: (value) =>
              updateSettings(settings.copyWith(shoppingHideChecked: value)),
        ),
        SwitchListTile(
          title: const Text('Show item count'),
          subtitle: const Text(
            'Display remaining item count on compact widgets',
          ),
          value: settings.shoppingShowItemCount,
          onChanged: (value) =>
              updateSettings(settings.copyWith(shoppingShowItemCount: value)),
        ),
      ],
    );
  }
}

/// Dedicated settings screen for the Coffee Picker home-screen widget.
class CoffeeWidgetSettingsPage extends StatelessWidget {
  final int? appWidgetId;

  const CoffeeWidgetSettingsPage({super.key, this.appWidgetId});

  @override
  Widget build(BuildContext context) {
    return _SingleWidgetSettingsScaffold(
      title: 'Coffee Picker Widget',
      appWidgetId: appWidgetId,
      builder: (context, settings, updateSettings) => [
        SwitchListTile(
          title: const Text('Include custom recipes'),
          subtitle: const Text(
            'Include your custom recipes when spinning on the widget',
          ),
          value: settings.coffeeIncludeCustomRecipes,
          onChanged: (value) => updateSettings(
            settings.copyWith(coffeeIncludeCustomRecipes: value),
          ),
        ),
        SwitchListTile(
          title: const Text('Show recipe subtitle'),
          subtitle: const Text('Display recipe description on the result card'),
          value: settings.coffeeShowSubtitle,
          onChanged: (value) =>
              updateSettings(settings.copyWith(coffeeShowSubtitle: value)),
        ),
      ],
    );
  }
}
