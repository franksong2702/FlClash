import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TVRemoteNavigation extends StatefulWidget {
  final Widget child;

  const TVRemoteNavigation({super.key, required this.child});

  @override
  State<TVRemoteNavigation> createState() => _TVRemoteNavigationState();
}

class _TVRemoteNavigationState extends State<TVRemoteNavigation> {
  final _rootFocusNode = FocusNode(debugLabel: 'TVRemoteNavigationRoot');

  @override
  void dispose() {
    _rootFocusNode.dispose();
    super.dispose();
  }

  bool get _isTextEditing {
    final context = FocusManager.instance.primaryFocus?.context;
    return context?.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _moveFocus(TraversalDirection direction) {
    if (_isTextEditing) {
      return;
    }
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null || primaryFocus == _rootFocusNode) {
      FocusScope.of(context).nextFocus();
      _ensurePrimaryFocusVisible();
      return;
    }

    final focusContext = primaryFocus.context;
    final policy = FocusTraversalGroup.maybeOf(focusContext ?? context);
    final didMove = policy?.inDirection(primaryFocus, direction) ?? false;
    if (!didMove) {
      FocusScope.of(context).nextFocus();
    }
    _ensurePrimaryFocusVisible();
  }

  void _activateFocus() {
    if (_isTextEditing) {
      return;
    }
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) {
      FocusScope.of(context).nextFocus();
      return;
    }
    Actions.maybeInvoke(focusContext, const ActivateIntent());
  }

  void _ensurePrimaryFocusVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final focusContext = FocusManager.instance.primaryFocus?.context;
      if (focusContext == null) {
        return;
      }
      Scrollable.ensureVisible(
        focusContext,
        duration: commonDuration,
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!system.isAndroid) {
      return widget.child;
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowUp): () {
          _moveFocus(TraversalDirection.up);
        },
        const SingleActivator(LogicalKeyboardKey.arrowDown): () {
          _moveFocus(TraversalDirection.down);
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          _moveFocus(TraversalDirection.left);
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          _moveFocus(TraversalDirection.right);
        },
        const SingleActivator(LogicalKeyboardKey.select): _activateFocus,
        const SingleActivator(LogicalKeyboardKey.enter): _activateFocus,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _activateFocus,
      },
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Focus(
          focusNode: _rootFocusNode,
          autofocus: true,
          child: widget.child,
        ),
      ),
    );
  }
}
