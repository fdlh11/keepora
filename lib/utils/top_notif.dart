import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

OverlayEntry? _activeTopNotif;
Timer? _topNotifTimer;

void showTopNotif(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration duration = const Duration(seconds: 3),
}) {
  _topNotifTimer?.cancel();
  _activeTopNotif?.remove();
  _activeTopNotif = null;

  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _TopNotifWidget(
      message: message,
      isError: isError,
      onDismiss: () {
        if (_activeTopNotif == entry) {
          entry.remove();
          _activeTopNotif = null;
        }
      },
    ),
  );

  _activeTopNotif = entry;
  overlay.insert(entry);

  _topNotifTimer = Timer(duration, () {
    if (_activeTopNotif == entry) {
      entry.remove();
      _activeTopNotif = null;
    }
  });
}

class _TopNotifWidget extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  const _TopNotifWidget({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  @override
  State<_TopNotifWidget> createState() => _TopNotifWidgetState();
}

class _TopNotifWidgetState extends State<_TopNotifWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 10;
    final bgColor =
        widget.isError ? const Color(0xFFDC2626) : const Color(0xFF004AAD);

    return Positioned(
      top: topPadding,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.primaryDelta != null && details.primaryDelta! < -4) {
                  widget.onDismiss();
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.isError
                          ? Icons.error_outline_rounded
                          : Icons.check_circle_outline_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}