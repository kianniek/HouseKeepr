import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../contracts/health_data_store.dart';
import '../registry/health_mini_app.dart';
import '../registry/open_gym_launcher.dart';
import '../storage/local_health_data_store.dart';

/// Umbrella hub screen listing all HealthKeepr on-demand modules.
///
/// Inherits all colors and typography from the host app's [Theme.of(context)].
class HealthKeeprHubScreen extends StatefulWidget {
  const HealthKeeprHubScreen({
    super.key,
    this.store,
    this.modules,
  });

  /// Optional custom [HealthDataStore]. Defaults to a lazily initialized
  /// [LocalHealthDataStore] backed by `health_keepr.db`.
  final HealthDataStore? store;

  /// Optional override of registered mini-apps (useful for testing).
  final List<HealthMiniApp>? modules;

  @override
  State<HealthKeeprHubScreen> createState() => _HealthKeeprHubScreenState();
}

class _HealthKeeprHubScreenState extends State<HealthKeeprHubScreen> {
  late final HealthDataStore _store;
  late final bool _ownsStore;

  @override
  void initState() {
    super.initState();
    _ownsStore = widget.store == null;
    _store = widget.store ?? LocalHealthDataStore();
  }

  @override
  void dispose() {
    if (_ownsStore) {
      _store.close();
    }
    super.dispose();
  }

  List<HealthMiniApp> _buildModules() {
    return widget.modules ?? <HealthMiniApp>[OpenGymLauncher.descriptor()];
  }

  Future<void> _launchModule(HealthMiniApp module) async {
    await module.onLaunch(context, _store);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _confirmClearModuleData(HealthMiniApp module) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Clear ${module.title} data?'),
        content: const Text(
          'This removes all local data stored on this device for this module. '
          'Your HouseKeepr household data will not be affected.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear data'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _store.clearModuleData(module.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cleared local data for ${module.title}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final modules = _buildModules();

    return Scaffold(
      appBar: AppBar(
        title: const Text('HealthKeepr'),
        actions: <Widget>[
          PopupMenuButton<String>(
            tooltip: 'Local storage options',
            onSelected: (value) async {
              if (value.startsWith('clear:')) {
                final id = value.substring('clear:'.length);
                final match = modules.where((m) => m.id == id).firstOrNull;
                if (match != null) {
                  await _confirmClearModuleData(match);
                }
              }
            },
            itemBuilder: (context) => modules
                .map(
                  (m) => PopupMenuItem<String>(
                    value: 'clear:${m.id}',
                    child: Text('Clear ${m.title} local data'),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.health_and_safety_rounded,
                    size: 32,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Private & On-Device',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Health modules are downloaded on demand and stored '
                          'locally in health_keepr.db, separate from your '
                          'household sync.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Modules',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: modules.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 260,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, index) {
              final module = modules[index];
              return _ModuleCard(
                module: module,
                onTap: () => _launchModule(module),
                onLongPress: () => _confirmClearModuleData(module),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.onTap,
    required this.onLongPress,
  });

  final HealthMiniApp module;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                    child: _buildModuleIcon(module, colorScheme.onPrimaryContainer),
                  ),
                  Chip(
                    label: Text(
                      module.isInstalled ? 'Ready' : 'On-Demand',
                      style: theme.textTheme.labelSmall,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                module.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                module.subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModuleIcon(HealthMiniApp module, Color iconColor) {
    final asset = module.iconAsset;
    if (asset == null) {
      return Icon(module.icon);
    }
    if (asset.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        asset,
        package: module.iconAssetPackage,
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      );
    }
    return ImageIcon(
      AssetImage(asset, package: module.iconAssetPackage),
      size: 24,
    );
  }
}
