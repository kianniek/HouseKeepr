import 'package:flutter/widgets.dart';

/// Applies [padding] plus the current bottom keyboard inset ([MediaQuery.viewInsetsOf])
/// in a dedicated leaf widget so IME animation ticks only relayout padding without
/// rebuilding the wrapped [child] subtree.
class KeyboardInsetPadding extends StatelessWidget {
  final EdgeInsets padding;
  final Widget child;

  const KeyboardInsetPadding({
    super.key,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: padding.copyWith(bottom: padding.bottom + bottomInset),
      child: child,
    );
  }
}
