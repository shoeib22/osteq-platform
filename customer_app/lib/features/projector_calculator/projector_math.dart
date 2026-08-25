/// Screen-size / throw-distance geometry for common projector aspect ratios.
///
/// Same relationships BenQ's own projector calculator (projectorcalculator.benq.com)
/// uses: diagonal/width/height are fixed proportions of each other for a given aspect
/// ratio, and throw distance = image width * throw ratio (throw ratio is distance
/// divided by width, both in the same unit, so it's dimensionless).
library;

import 'dart:math' as math;

enum ProjectorAspectRatio {
  ratio4x3('4:3', 4, 3),
  ratio16x9('16:9', 16, 9),
  ratio16x10('16:10', 16, 10),
  ratio21x9('21:9', 64, 27); // 21:9 is commonly the panel ratio 64:27 in cinema displays

  const ProjectorAspectRatio(this.label, this.widthUnits, this.heightUnits);

  final String label;
  final double widthUnits;
  final double heightUnits;

  double get diagonalUnits => math.sqrt(widthUnits * widthUnits + heightUnits * heightUnits);
}

class ScreenDimensions {
  final double diagonalInches;
  final double widthInches;
  final double heightInches;

  const ScreenDimensions({
    required this.diagonalInches,
    required this.widthInches,
    required this.heightInches,
  });

  double get widthMeters => widthInches * 0.0254;
  double get heightMeters => heightInches * 0.0254;
  double get diagonalMeters => diagonalInches * 0.0254;
}

class ThrowDistanceRange {
  final double minMeters;
  final double maxMeters;

  const ThrowDistanceRange({required this.minMeters, required this.maxMeters});

  double get minFeet => minMeters / 0.3048;
  double get maxFeet => maxMeters / 0.3048;
}

class ScreenSizeRange {
  final ScreenDimensions min;
  final ScreenDimensions max;

  const ScreenSizeRange({required this.min, required this.max});
}

/// Given a target screen diagonal, returns its width/height for [ratio].
ScreenDimensions screenFromDiagonal(ProjectorAspectRatio ratio, double diagonalInches) {
  final widthInches = diagonalInches * ratio.widthUnits / ratio.diagonalUnits;
  final heightInches = diagonalInches * ratio.heightUnits / ratio.diagonalUnits;
  return ScreenDimensions(
    diagonalInches: diagonalInches,
    widthInches: widthInches,
    heightInches: heightInches,
  );
}

/// Given a target screen width, returns diagonal/height for [ratio].
ScreenDimensions screenFromWidth(ProjectorAspectRatio ratio, double widthInches) {
  final diagonalInches = widthInches * ratio.diagonalUnits / ratio.widthUnits;
  return screenFromDiagonal(ratio, diagonalInches);
}

/// Throw distance for a given screen width and a single throw ratio.
/// throwRatio = distance / width  =>  distance = width * throwRatio
double throwDistanceMeters(double widthMeters, double throwRatio) => widthMeters * throwRatio;

/// Screen width achievable at a fixed [distanceMeters] for a single throw ratio.
double widthFromThrowDistance(double distanceMeters, double throwRatio) =>
    distanceMeters / throwRatio;

/// For a projector with a throw-ratio zoom range [throwRatioWide, throwRatioTele]
/// (wide = smallest ratio = biggest image at a given distance; tele = largest ratio =
/// smallest/most zoomed-in image), returns the throw-distance range needed to fill a
/// screen of the given diagonal.
ThrowDistanceRange throwDistanceRangeForScreen({
  required ProjectorAspectRatio ratio,
  required double diagonalInches,
  required double throwRatioWide,
  required double throwRatioTele,
}) {
  final widthMeters = screenFromDiagonal(ratio, diagonalInches).widthMeters;
  return ThrowDistanceRange(
    minMeters: throwDistanceMeters(widthMeters, throwRatioWide),
    maxMeters: throwDistanceMeters(widthMeters, throwRatioTele),
  );
}

/// For a projector with a throw-ratio zoom range, returns the range of screen sizes
/// (min..max diagonal) that can be filled from a fixed installation [distanceMeters].
ScreenSizeRange screenSizeRangeForDistance({
  required ProjectorAspectRatio ratio,
  required double distanceMeters,
  required double throwRatioWide,
  required double throwRatioTele,
}) {
  final maxWidthMeters = widthFromThrowDistance(distanceMeters, throwRatioWide); // wide = biggest image
  final minWidthMeters = widthFromThrowDistance(distanceMeters, throwRatioTele); // tele = smallest image
  return ScreenSizeRange(
    min: screenFromWidth(ratio, minWidthMeters / 0.0254),
    max: screenFromWidth(ratio, maxWidthMeters / 0.0254),
  );
}
