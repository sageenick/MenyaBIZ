import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ScrollTopWrapper extends StatefulWidget {
  final Widget Function(ScrollController controller) builder;
  final double bottom;

  const ScrollTopWrapper({
    super.key,
    required this.builder,
    this.bottom = 84,
  });

  @override
  State<ScrollTopWrapper> createState() => _ScrollTopWrapperState();
}

class _ScrollTopWrapperState extends State<ScrollTopWrapper> {
  final ScrollController _controller = ScrollController();
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final show = _controller.offset > 250;
    if (show != _show) {
      setState(() => _show = show);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.builder(_controller),
        Positioned(
          right: 24,
          bottom: widget.bottom,
          child: AnimatedOpacity(
            opacity: _show ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_show,
              child: FloatingActionButton.small(
                heroTag: null,
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryGreen,
                elevation: 4,
                onPressed: () {
                  if (_controller.hasClients) {
                    _controller.animateTo(
                      0,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                    );
                  }
                },
                child: const Icon(Icons.keyboard_arrow_up, size: 28),
              ),
            ),
          ),
        ),
      ],
    );
  }
}