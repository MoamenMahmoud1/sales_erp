import 'package:flutter/material.dart';

/// Opt-in styling scope for one intentionally prominent content surface.
///
/// Shared cards remain neutral by default; only screens that explicitly opt in
/// can give a designated surface richer visual treatment.
class FeaturedCardTheme extends ThemeExtension<FeaturedCardTheme> {
  const FeaturedCardTheme({this.enabled = false});

  final bool enabled;

  @override
  FeaturedCardTheme copyWith({bool? enabled}) =>
      FeaturedCardTheme(enabled: enabled ?? this.enabled);

  @override
  FeaturedCardTheme lerp(ThemeExtension<FeaturedCardTheme>? other, double t) {
    if (other is! FeaturedCardTheme) return this;
    return FeaturedCardTheme(enabled: t < 0.5 ? enabled : other.enabled);
  }
}
