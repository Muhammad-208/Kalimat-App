import 'package:flutter/widgets.dart';

/// Breakpoints (logical px / dp). A 7" tablet is ~600dp wide, 10"+ ~900dp.
class KBreak {
  KBreak._();
  static const tablet = 600.0; // 7" and up
  static const large = 900.0; // 10"–13"
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isTablet => screenWidth >= KBreak.tablet;
  bool get isLargeTablet => screenWidth >= KBreak.large;

  /// A scale factor for hero display type (wordmark, root glyphs) on tablets.
  double get displayScale => isLargeTablet ? 1.3 : (isTablet ? 1.15 : 1.0);
}

/// Caps content width and centers it, so text lines don't stretch edge-to-edge
/// on a tablet. On a phone it's a no-op (screen is narrower than [maxWidth]).
///
/// Uses top-center alignment so it works for both scroll views and lists.
class AdaptiveContent extends StatelessWidget {
  const AdaptiveContent({
    super.key,
    required this.child,
    this.maxWidth = 680, // comfortable reading measure
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}
