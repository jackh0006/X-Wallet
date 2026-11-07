import '../localized_text.dart';

/// One stop on the §10b journey map. [plainStatus] is the one-line plain-words
/// status; [technical] is what the "More" expander shows; [logLines] are the
/// raw lines for this stop only (never another stop's data).
@immutable
class JourneyStop {
  const JourneyStop({
    required this.icon,
    required this.label,
    required this.plainStatus,
    required this.technical,
    this.logLines = const [],
  });

  final IconData icon;
  final String label;
  final String plainStatus;
  final String technical;
  final List<String> logLines;
}

enum JourneyState { waiting, working, ok, problem }

/// Horizontal path with big friendly icons and tappable detail cards:
/// `My phone → Privacy layer → Node → Network → Done`.
class JourneyMap extends StatelessWidget {
  const JourneyMap({
    super.key,
    required this.stops,
    required this.states,
    this.lite = false,
  }) : assert(stops.length == states.length);

  final List<JourneyStop> stops;
  final List<JourneyState> states;
  final bool lite;

  @override
  Widget build(BuildContext context) {
    // Spec §10b: respect the system "reduce motion" setting exactly like the
    // in-app Lite mode, so no pulse or flowing dots remain when it is on.
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final effectiveLite = lite || reduceMotion;
    final done = states.where((state) => state == JourneyState.ok).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < stops.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 21),
                    child: effectiveLite
                        ? Icon(
                            Icons.arrow_forward,
                            size: 18,
                            color: states[i - 1] == JourneyState.ok
                                ? const Color(0xFF69C77A)
                                : Color(0xFF8E8E8E),
                          )
                        : Container(
                            width: 26,
                            height: 3,
                            decoration: BoxDecoration(
                              color: states[i - 1] == JourneyState.ok
                                  ? const Color(0xFF69C77A)
                                  : Color(0xFF8E8E8E),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                  ),
                _StopTile(
                  stop: stops[i],
                  state: states[i],
                  lite: effectiveLite,
                  onTap: () => _showDetails(context, i),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (effectiveLite)
          LinearProgressIndicator(
            value: stops.isEmpty ? 0 : done / stops.length,
            minHeight: 3,
            backgroundColor: Color(0x33808080),
          ),
      ],
    );
  }

  void _showDetails(BuildContext context, int index) {
    final stop = stops[index];
    final state = states[index];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Row(
              children: [
                _StateIcon(state: state, lite: true, size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.label,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stop.plainStatus,
                        style: TextStyle(
                          color: _stateColor(state),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'State: ${_stateWord(state)}',
              style: const TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
            ),
            const Divider(height: 24),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: true,
              title: const Text('More — technical details'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    stop.technical,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: Color(0xFF6E6E6E),
                    ),
                  ),
                ),
                if (stop.logLines.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Raw lines for this stop',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final line in stop.logLines)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText(
                        line,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StopTile extends StatelessWidget {
  const _StopTile({
    required this.stop,
    required this.state,
    required this.lite,
    required this.onTap,
  });

  final JourneyStop stop;
  final JourneyState state;
  final bool lite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${stop.label}. ${_stateWord(state)}. ${stop.plainStatus}',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 88,
          child: Column(
            children: [
              _StateIcon(state: state, lite: lite),
              const SizedBox(height: 5),
              Text(
                stop.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, height: 1.15),
              ),
              const SizedBox(height: 2),
              Text(
                _stateWord(state),
                style: TextStyle(color: _stateColor(state), fontSize: 9.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateIcon extends StatelessWidget {
  const _StateIcon({required this.state, required this.lite, this.size = 42});

  final JourneyState state;
  final bool lite;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (state) {
      JourneyState.waiting => (Icons.circle_outlined, Color(0xFF808080)),
      JourneyState.working => (Icons.autorenew, const Color(0xFF64B5F6)),
      JourneyState.ok => (Icons.check_circle, const Color(0xFF69C77A)),
      JourneyState.problem => (Icons.cancel, const Color(0xFFFF6B6B)),
    };
    final base = Icon(icon, color: color, size: size);
    if (state != JourneyState.working || lite) return base;
    return _Pulse(child: base);
  }
}

/// One slow pulse for the working stop. No shaders and no layout animation, so
/// it stays cheap on a 2 GB phone; Lite mode uses a static icon instead.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});
  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller),
      child: widget.child,
    );
  }
}

Color _stateColor(JourneyState state) => switch (state) {
  JourneyState.waiting => Color(0xFF808080),
  JourneyState.working => const Color(0xFF64B5F6),
  JourneyState.ok => const Color(0xFF69C77A),
  JourneyState.problem => const Color(0xFFFF6B6B),
};

String _stateWord(JourneyState state) => switch (state) {
  JourneyState.waiting => 'waiting',
  JourneyState.working => 'working',
  JourneyState.ok => 'ok',
  JourneyState.problem => 'problem',
};
