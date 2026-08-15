# liquid_glass_widgets override

This directory vendors `liquid_glass_widgets` 0.29.5 with one local gesture
fix: bottom-tab indicators track the pointer's relative movement from the press
origin, preventing the indicator from jumping to an off-center touch when the
horizontal drag recognizer first activates. Raw pointer movement updates the
indicator during Flutter's gesture-slop window, before a horizontal drag is
formally recognized, while preserving the original interactive spring effect.
