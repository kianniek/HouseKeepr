import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Default time the undo toast stays visible.
const Duration kUndoToastDuration = Duration(seconds: 6);

/// Shows a Gmail-style "undo toast": a small floating bar at the bottom of the
/// screen with a [message], a visible countdown and an UNDO button.
///
/// - Auto-dismisses after [duration].
/// - Pressing Ctrl+Z (Windows/Linux/web) or Cmd+Z (macOS) while the toast is
///   visible triggers [onUndo], unless focus is inside a text field.
/// - [onUndo] runs at most once.
/// - Showing a new toast replaces the current one; the keyboard shortcut then
///   always applies to the latest action.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showUndoToast(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
  Duration duration = kUndoToastDuration,
  IconData? icon,
  String undoLabel = 'UNDO',
}) {
  final messenger = ScaffoldMessenger.of(context);

  // Replace any previous toast (and its shortcut handler).
  _UndoToastController.active?.detach();
  final controller = _UndoToastController(messenger: messenger, onUndo: onUndo)
    ..attach();

  messenger.hideCurrentSnackBar();
  final feature = messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: duration,
      // Newer Flutter versions keep SnackBars with an action open forever by
      // default; an undo toast must count down and disappear.
      persist: false,
      dismissDirection: DismissDirection.horizontal,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsetsDirectional.only(end: 8),
      clipBehavior: Clip.antiAlias,
      content: _UndoToastContent(
        message: message,
        icon: icon,
        duration: duration,
      ),
      action: SnackBarAction(
        label: undoLabel,
        // SnackBarAction hides the toast itself.
        onPressed: () => controller.trigger(hide: false),
      ),
    ),
  );
  feature.closed.then((_) => controller.detach());
  return feature;
}

class _UndoToastController {
  static _UndoToastController? active;

  final ScaffoldMessengerState messenger;
  final VoidCallback onUndo;
  bool _undone = false;
  bool _attached = false;

  _UndoToastController({required this.messenger, required this.onUndo});

  void attach() {
    if (_attached) return;
    _attached = true;
    active = this;
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    HardwareKeyboard.instance.removeHandler(_onKey);
    if (identical(active, this)) active = null;
  }

  void trigger({bool hide = true}) {
    if (_undone) return;
    _undone = true;
    detach();
    if (hide) {
      messenger.hideCurrentSnackBar(reason: SnackBarClosedReason.action);
    }
    onUndo();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.keyZ) return false;
    final keyboard = HardwareKeyboard.instance;
    if (!(keyboard.isControlPressed || keyboard.isMetaPressed)) return false;
    // Ctrl+Shift+Z is conventionally "redo".
    if (keyboard.isShiftPressed || keyboard.isAltPressed) return false;
    if (_isTextInputFocused()) return false;
    trigger();
    return true;
  }

  static bool _isTextInputFocused() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;
    if (focusContext.widget is EditableText) return true;
    return focusContext.findAncestorStateOfType<EditableTextState>() != null;
  }
}

class _UndoToastContent extends StatelessWidget {
  final String message;
  final IconData? icon;
  final Duration duration;

  const _UndoToastContent({
    required this.message,
    required this.icon,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // SnackBar content defaults to onInverseSurface on an inverseSurface bar.
    final fg = scheme.onInverseSurface;
    //final totalSeconds = duration.inMilliseconds / 1000.0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 0.0),
      duration: duration,
      builder: (context, remaining, _) {
        //final secondsLeft = (remaining * totalSeconds).ceil();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 10),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: fg),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // SizedBox(
                  //   width: 24,
                  //   height: 24,
                  //   child: Stack(
                  //     alignment: Alignment.center,
                  //     children: [
                  //       CircularProgressIndicator(
                  //         value: remaining,
                  //         strokeWidth: 2,
                  //         color: scheme.inversePrimary,
                  //         backgroundColor: fg.withValues(alpha: 0.2),
                  //       ),
                  //       Text(
                  //         '$secondsLeft',
                  //         key: const ValueKey('undo_toast_seconds'),
                  //         style: Theme.of(context).textTheme.labelSmall
                  //             ?.copyWith(color: fg),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: remaining,
              minHeight: 3,
              color: scheme.inversePrimary,
              backgroundColor: Colors.transparent,
            ),
          ],
        );
      },
    );
  }
}
