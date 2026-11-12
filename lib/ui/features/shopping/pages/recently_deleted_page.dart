import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/quantity_unit_formatter.dart';
import '../../../../cubits/shopping_cubit.dart';
import '../../../../models/grocery_item.dart';
import '../../../common/widgets/empty_state.dart';
import '../../../common/widgets/undo_toast.dart';

/// Lists shopping items deleted within the last
/// [ShoppingCubit.deletedRetention] and lets the user restore them or delete
/// them forever. Expects a [ShoppingCubit] above it in the tree.
class RecentlyDeletedPage extends StatelessWidget {
  const RecentlyDeletedPage({super.key});

  Future<void> _restore(BuildContext context, GroceryItem item) async {
    final cubit = context.read<ShoppingCubit>();
    final originalDeletedAt = ShoppingCubit.deletedMoment(item);
    await cubit.restoreItems([item.id], uncheck: true);
    if (!context.mounted) return;
    showUndoToast(
      context,
      icon: Icons.restore,
      message: item.name.isEmpty
          ? 'Item restored'
          : '"${item.name}" restored to your list',
      onUndo: () => cubit.deleteItem(item.id, deletedAt: originalDeletedAt),
    );
  }

  Future<void> _restoreAll(
    BuildContext context,
    List<GroceryItem> items,
  ) async {
    final cubit = context.read<ShoppingCubit>();
    final originals = {
      for (final i in items) i.id: ShoppingCubit.deletedMoment(i),
    };
    await cubit.restoreItems(originals.keys.toList(), uncheck: true);
    if (!context.mounted) return;
    showUndoToast(
      context,
      icon: Icons.restore,
      message: items.length == 1
          ? '1 item restored'
          : '${items.length} items restored',
      onUndo: () async {
        for (final entry in originals.entries) {
          await cubit.deleteItem(entry.key, deletedAt: entry.value);
        }
      },
    );
  }

  Future<void> _emptyAll(BuildContext context, List<GroceryItem> items) async {
    final cubit = context.read<ShoppingCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Empty Recently Deleted?'),
        content: Text(
          items.length == 1
              ? '1 item will be permanently deleted. This cannot be undone.'
              : '${items.length} items will be permanently deleted. '
                    'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await cubit.permanentlyDelete(items.map((i) => i.id).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShoppingCubit, ShoppingState>(
      buildWhen: (prev, curr) => prev.recentlyDeleted != curr.recentlyDeleted,
      builder: (context, state) {
        final items = state.recentlyDeleted;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Recently Deleted'),
            actions: [
              if (items.isNotEmpty)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'restoreAll') {
                      _restoreAll(context, items);
                    } else if (value == 'empty') {
                      _emptyAll(context, items);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'restoreAll',
                      child: Row(
                        children: [
                          Icon(Icons.restore, size: 20),
                          SizedBox(width: 8),
                          Text('Restore all'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'empty',
                      child: Row(
                        children: [
                          Icon(Icons.delete_forever, size: 20),
                          SizedBox(width: 8),
                          Text('Empty'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                const _RetentionBanner(),
                Expanded(
                  child: items.isEmpty
                      ? const EmptyStateWidget(
                          icon: Icons.delete_outline,
                          message: 'No recently deleted items',
                          subMessage:
                              'Items you delete from your shopping list '
                              'show up here for 7 days.',
                        )
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _RecentlyDeletedTile(
                              key: ValueKey('deleted_${item.id}'),
                              item: item,
                              onRestore: () => _restore(context, item),
                              onDeleteForever: () => context
                                  .read<ShoppingCubit>()
                                  .permanentlyDelete([item.id]),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RetentionBanner extends StatelessWidget {
  const _RetentionBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Items are permanently deleted after 7 days.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentlyDeletedTile extends StatelessWidget {
  final GroceryItem item;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  const _RecentlyDeletedTile({
    super.key,
    required this.item,
    required this.onRestore,
    required this.onDeleteForever,
  });

  static String _formatAgo(Duration d) {
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return d.inDays == 1 ? '1 day ago' : '${d.inDays} days ago';
  }

  static String _formatLeft(Duration d) {
    if (d.inDays >= 1) {
      return d.inDays == 1 ? '1 day left' : '${d.inDays} days left';
    }
    if (d.inHours >= 1) return '${d.inHours} h left';
    return 'less than an hour left';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final deletedAt = ShoppingCubit.deletedMoment(item);
    final ago = now.difference(deletedAt);
    final left = deletedAt.add(ShoppingCubit.deletedRetention).difference(now);

    final qty = item.quantity % 1 == 0
        ? item.quantity.toInt().toString()
        : item.quantity.toString();
    final unit = formatQuantityUnit(item.unit, item.quantity);
    final qtyLabel = unit == null || unit.isEmpty ? '×$qty' : '$qty $unit';

    return Dismissible(
      key: ValueKey('dismiss_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        color: scheme.error,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Delete forever', style: TextStyle(color: scheme.onError)),
            const SizedBox(width: 8),
            Icon(Icons.delete_forever, color: scheme.onError),
          ],
        ),
      ),
      onDismissed: (_) => onDeleteForever(),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.surfaceContainerHighest,
          child: Text(item.category.emoji),
        ),
        title: Text(
          item.name.isEmpty ? '(unnamed)' : item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$qtyLabel · Deleted ${_formatAgo(ago)} · ${_formatLeft(left)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: 'Restore',
          icon: const Icon(Icons.restore),
          onPressed: onRestore,
        ),
      ),
    );
  }
}
