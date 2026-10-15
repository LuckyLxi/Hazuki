# liquid_glass_widgets override

This directory vendors `liquid_glass_widgets` 1.13.0 from pub.dev with local
patches for Hazuki. Bottom-tab indicators track relative movement from the press
origin, preventing the indicator from jumping to an off-center touch when the
horizontal drag recognizer first activates. Raw pointer movement updates the
indicator during Flutter's gesture-slop window, before a horizontal drag is
formally recognized, while preserving the original interactive spring effect.

The extra button retains `transformOffset`, `transformScale`, `ignorePointer`,
and `glowOpacity` so Hazuki's back-to-top action can morph out of the favorites
tab without changing the navigation layout. Hidden buttons are excluded from
pointer input, keyboard focus, and accessibility semantics. These properties
are also supported by the upstream menu constructor.

`GlassMorphController.preserveLegacyMotion` retains the v0.29.5 springs,
closing velocity, shape curves, and settling behavior. Hazuki enables it for
the existing back-to-top action so upgrading does not change that animation;
other library surfaces keep the upstream motion profile.

Upstream API changes moved the extra-button configuration into
`lib/widgets/surfaces/shared/tab_bar_extra_button.dart`; bottom layouts now use
the configuration directly, so no forwarding patch is necessary.

The upstream iOS plugin and renamed `liquid_glass_render.frag` shader are
included. Keep the remaining files aligned with the 1.13.0 pub.dev archive
(SHA-256: `b66e9f72535bf7c50ffc2442693b8bbb50026e90b3674f9b0e7ae80c55c3c77c`).
