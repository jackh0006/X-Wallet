import '../localized_text.dart';

import 'package:flutter/services.dart';

/// A button that only fires after the pointer is held for [duration]. Used for
/// the last signing step (spec §9: hold-to-confirm). Releasing early visibly
/// drains the fill, so the gesture cannot be completed by a stray tap.
///
/// Keyboard users can hold Space or Enter for the same duration. The hold is
/// not bypassed: a tap, a key tap, or an early release does nothing.
class HoldToConfirm extends StatefulWidget {
  const HoldToConfirm({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.duration = const Duration(milliseconds: 1600),
    this.icon = Icons.lock_outline,
    this.focusNode,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback onConfirmed;
  final Duration duration;
  final IconData icon;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<HoldToConfirm> createState() => _HoldToConfirmState();
}

class _HoldToConfirmState extends State<HoldToConfirm>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed && !_fired) {
            _fired = true;
            widget.onConfirmed();
          }
        });

  bool _fired = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    if (_fired) return;
    _controller.forward(from: _controller.value);
  }

  void _stop() {
    if (_fired) return;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: (node, event) {
        final isHoldKey =
            event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter;
        if (!isHoldKey) return KeyEventResult.ignored;
        if (event is KeyDownEvent) {
          _start();
          return KeyEventResult.handled;
        }
        if (event is KeyUpEvent) {
          _stop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Listener(
        onPointerDown: (_) => _start(),
        onPointerUp: (_) => _stop(),
        onPointerCancel: (_) => _stop(),
        child: Semantics(
          button: true,
          label: '${widget.label}. Press and hold.',
          hint:
              'Hold Space or Enter, or hold the pointer, until the fill '
              'completes. Releasing early cancels.',
          child: LayoutBuilder(
            builder: (context, constraints) => AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final progress = _controller.value;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: accent, width: 1.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(widget.icon, size: 18, color: accent),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  progress > 0
                                      ? 'Keep holding… ${(progress * 100).round()}%'
                                      : '${widget.label} · press and hold',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Container(
                            width: constraints.maxWidth * progress,
                            color: accent.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Last-line confirmation dialog for signing. Returns true only when the hold
/// completed; Cancel and early release return false.
Future<bool> showHoldToConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String label = 'Hold to sign',
  String cancelLabel = 'Cancel',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: 16),
            HoldToConfirm(
              label: label,
              onConfirmed: () {
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(cancelLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}
