import 'package:flutter/material.dart';

class CoverViewWidget extends StatelessWidget {
  final List<Widget> children;
  final bool isLongPressed;
  final ImageProvider? image;
  final bool isComfortableGrid;
  final Widget? bottomTextWidget;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;

  const CoverViewWidget({
    super.key,
    this.children = const [],
    this.isComfortableGrid = false,
    this.bottomTextWidget,
    required this.onTap,
    this.image,
    this.onLongPress,
    this.isLongPressed = false,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(5),
      child: Column(
        children: [
          Expanded(
            child: Material(
              borderRadius: BorderRadius.circular(5),
              color: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                onSecondaryTap: onSecondaryTap,
                child: Container(
                  color: isLongPressed
                      ? primaryColor.withValues(alpha: 0.4)
                      : Colors.transparent,
                  child: image == null
                      ? (isComfortableGrid
                            ? Column(
                                children: [
                                  ...children,
                                  if (bottomTextWidget != null)
                                    bottomTextWidget!,
                                ],
                              )
                            : Stack(children: children))
                      : Ink.image(
                          fit: BoxFit.cover,
                          image: image!,
                          child: Stack(children: children),
                        ),
                ),
              ),
            ),
          ),
          if (isComfortableGrid && bottomTextWidget != null) bottomTextWidget!,
        ],
      ),
    );
  }
}
