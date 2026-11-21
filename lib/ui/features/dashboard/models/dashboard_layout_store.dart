import 'package:shared_preferences/shared_preferences.dart';

enum DashboardWidgetId { weather, calendar, shopping, medications }

class DashboardLayout {
  final List<DashboardWidgetId> order;
  final Set<DashboardWidgetId> hidden;

  const DashboardLayout({required this.order, required this.hidden});

  factory DashboardLayout.defaults() => const DashboardLayout(
    order: DashboardWidgetId.values,
    hidden: <DashboardWidgetId>{},
  );
}

class DashboardLayoutStore {
  static const String orderKey = 'dashboard_widget_order_v1';
  static const String hiddenKey = 'dashboard_hidden_widgets_v1';

  final SharedPreferences? _prefs;

  const DashboardLayoutStore({SharedPreferences? prefs}) : _prefs = prefs;

  Future<SharedPreferences> get _preferences async =>
      _prefs ?? await SharedPreferences.getInstance();

  Future<DashboardLayout> load() async {
    final prefs = await _preferences;
    final rawOrder = prefs.getStringList(orderKey);
    final rawHidden = prefs.getStringList(hiddenKey);

    final byName = {for (final id in DashboardWidgetId.values) id.name: id};

    final order = <DashboardWidgetId>[];
    if (rawOrder != null) {
      for (final name in rawOrder) {
        final id = byName[name];
        if (id != null && !order.contains(id)) {
          order.add(id);
        }
      }
    }
    for (final id in DashboardWidgetId.values) {
      if (!order.contains(id)) {
        order.add(id);
      }
    }

    final hidden = <DashboardWidgetId>{};
    if (rawHidden != null) {
      for (final name in rawHidden) {
        final id = byName[name];
        if (id != null) {
          hidden.add(id);
        }
      }
    }

    return DashboardLayout(order: order, hidden: hidden);
  }

  Future<void> saveOrder(List<DashboardWidgetId> order) async {
    final prefs = await _preferences;
    await prefs.setStringList(orderKey, order.map((id) => id.name).toList());
  }

  Future<void> saveHidden(Set<DashboardWidgetId> hidden) async {
    final prefs = await _preferences;
    await prefs.setStringList(hiddenKey, hidden.map((id) => id.name).toList());
  }
}
