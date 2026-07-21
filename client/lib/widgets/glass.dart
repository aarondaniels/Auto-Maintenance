/// App-specific glass helpers layered on top of `package:liquid_glass_widgets`
/// (real GPU shader refraction/lighting — see the package for the actual
/// glass primitives: [GlassAppBar], [GlassTabBar], [GlassIconButton],
/// [GlassButton], [GlassModalSheet], etc., all re-exported here).
library;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

export 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Height reserved at the top of scrollable content so it rests just below
/// the floating [GlassAppBar] at first paint, and can be seen refracting
/// through it once scrolled up.
double glassTopInset(BuildContext context) =>
    MediaQuery.of(context).padding.top + 44.0;

/// Height reserved at the bottom of scrollable content / floating action
/// buttons so they clear the floating [GlassTabBar.bottom].
double glassBottomInset(BuildContext context) =>
    64.0 + 24.0 + MediaQuery.of(context).padding.bottom;
