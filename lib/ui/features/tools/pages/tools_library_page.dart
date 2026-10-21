import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

import '../widgets/coffee_picker_page.dart';
import '../widgets/tool_personal_budget_page.dart';

class ToolItem {
  final String title;
  final String subtitle;
  final ToolCategory category;
  final IconData icon;
  final Widget destination;

  const ToolItem({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    required this.destination,
  });
}

class ToolsLibraryPage extends StatefulWidget {
  final String? householdId;

  const ToolsLibraryPage({super.key, this.householdId});

  @override
  State<ToolsLibraryPage> createState() => _ToolsLibraryPageState();
}

//enum for the categories of tools, this is used for filtering the tools in the library
enum ToolCategory {
  financeUtilities('Finance'),
  statusUtilities('Status'),
  kitchenUtilities('Kitchen');

  final String displayName;

  const ToolCategory(this.displayName);
}

class _ToolsLibraryPageState extends State<ToolsLibraryPage> {
  ToolCategory? _selectedCategory;
  bool _isGridView = true;

  final List<ToolCategory> _categories = [
    ToolCategory.financeUtilities,
    ToolCategory.statusUtilities,
    ToolCategory.kitchenUtilities,
  ];

  List<ToolItem> get _allTools => [
    ToolItem(
      title: 'Personal Budget Contribution',
      subtitle: 'Calculate your left-over budget',
      category: ToolCategory.financeUtilities,
      icon: Icons.account_balance_wallet,
      destination: PersonalBudgetPage(),
    ),
    ToolItem(
      title: 'Coffee Picker',
      subtitle: 'Spin for a coffee recipe and brew guide',
      category: ToolCategory.kitchenUtilities,
      icon: Icons.coffee,
      destination: CoffeePickerPage(householdId: widget.householdId),
    ),
  ];

  List<ToolItem> get _filteredTools {
    if (_selectedCategory == null) return _allTools;
    return _allTools
        .where((tool) => tool.category == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tools = _filteredTools;

    // Measure average title width using the same style we render titles with.
    final titleStyle = const TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 13,
    );
    double averageTitleWidth = 0;
    double width25Chars = 0;
    if (tools.isNotEmpty) {
      final painter = TextPainter(textDirection: TextDirection.ltr);
      double total = 0;
      for (final t in tools) {
        painter.text = TextSpan(text: t.title, style: titleStyle);
        painter.layout();
        total += painter.width;
      }
      averageTitleWidth = total / tools.length;

      // Measure width needed for 25 characters
      painter.text = TextSpan(text: 'a' * 25, style: titleStyle);
      painter.layout();
      width25Chars = painter.width;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tools Library')),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedCategory == null,
                  onSelected: (_) => setState(() => _selectedCategory = null),
                ),
                const SizedBox(width: 8),
                ..._categories.map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(category.displayName),
                      selected: _selectedCategory == category,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = selected ? category : null;
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          // Tools Count and View Toggle Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.swap_vert,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Name',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                  onPressed: () {
                    setState(() {
                      _isGridView = !_isGridView;
                    });
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;

                if (!_isGridView) {
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: tools.length,
                    itemBuilder: (context, index) {
                      return _ToolCard(tool: tools[index], isGrid: false);
                    },
                  );
                }

                const horizontalPadding = 16.0 * 2;
                const spacing = 16.0;
                final available = maxWidth - horizontalPadding;

                double mobileItemWidth = (available - (spacing * 2)) / 4.0;

                final maxDesiredWidth = width25Chars + 32.0;
                final averageDesired = averageTitleWidth + 32.0;

                final isWide = MediaQuery.of(context).size.width >= 640;
                var desiredItemWidth = isWide
                    ? averageDesired
                    : mobileItemWidth;

                desiredItemWidth = desiredItemWidth.clamp(0, maxDesiredWidth);

                const maxColumns = 3;
                final crossAxisCount =
                    (available / (desiredItemWidth + spacing)).floor().clamp(
                      1,
                      maxColumns,
                    );

                const extraVertical = 56.0;
                final childAspectRatio =
                    desiredItemWidth / (desiredItemWidth + extraVertical);

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: tools.length,
                  itemBuilder: (context, index) {
                    return _ToolCard(tool: tools[index], isGrid: true);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final ToolItem tool;
  final bool isGrid;

  const _ToolCard({required this.tool, required this.isGrid});

  @override
  Widget build(BuildContext context) {
    if (!isGrid) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(tool.icon, color: Colors.grey),
        ),
        title: Text(
          tool.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(tool.subtitle),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => tool.destination),
        ),
      );
    }

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => tool.destination),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    tool.icon,
                    size: 80,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          SizedBox(
            height: 20,
            child: Marquee(
              text: tool.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              startAfter: const Duration(seconds: 3),
              pauseAfterRound: const Duration(seconds: 2),
              blankSpace: 20,
              velocity: 25,
              accelerationCurve: Curves.easeInOutCubic,
              accelerationDuration: const Duration(seconds: 1),
              decelerationDuration: const Duration(seconds: 1),
              decelerationCurve: Curves.easeInOutCubic,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 18,
            child: Marquee(
              text: tool.subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              startAfter: const Duration(seconds: 3),
              pauseAfterRound: const Duration(seconds: 2),
              blankSpace: 20,
              velocity: 25,
              accelerationCurve: Curves.easeInOutCubic,
              accelerationDuration: const Duration(seconds: 1),
              decelerationDuration: const Duration(seconds: 1),
              decelerationCurve: Curves.easeInOutCubic,
            ),
          ),
        ],
      ),
    );
  }
}

// Using package:marquee's Marquee widget instead of custom implementation.
