part of 'password_lock_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Filled boxes indicator
// ─────────────────────────────────────────────────────────────────────────────

class PasswordLockFilledBoxes extends StatelessWidget {
  const PasswordLockFilledBoxes({
    super.key,
    required this.length,
    this.maxLength = 4,
    this.highlightError = false,
  });

  final int length;
  final int maxLength;
  final bool highlightError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(maxLength, (index) {
        final filled = index < length;
        final accentColor = highlightError
            ? colorScheme.error
            : colorScheme.primary;
        return Padding(
          padding: EdgeInsets.only(right: index == maxLength - 1 ? 0 : 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            width: 52,
            height: 60,
            decoration: BoxDecoration(
              color: filled
                  ? accentColor.withValues(alpha: 0.14)
                  : colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: filled
                    ? accentColor.withValues(alpha: 0.7)
                    : colorScheme.outlineVariant.withValues(alpha: 0.6),
                width: filled ? 1.6 : 1,
              ),
            ),
            child: Center(
              child: AnimatedScale(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                scale: filled ? 1 : 0.4,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: filled ? 1 : 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Numeric keypad
// ─────────────────────────────────────────────────────────────────────────────

class PasswordLockNumericKeypad extends StatelessWidget {
  const PasswordLockNumericKeypad({
    super.key,
    required this.onDigitPressed,
    required this.onBackspacePressed,
    this.onBiometricPressed,
    this.showBiometricButton = false,
    this.enabled = true,
    this.maxWidth = 360,
    this.buttonHeight = 74,
    this.spacing = 12,
    this.borderRadius = 22,
    this.digitFontSize = 28,
    this.letterFontSize = 15,
  });

  final ValueChanged<String> onDigitPressed;
  final VoidCallback onBackspacePressed;
  final VoidCallback? onBiometricPressed;
  final bool showBiometricButton;
  final bool enabled;
  final double maxWidth;
  final double buttonHeight;
  final double spacing;
  final double borderRadius;
  final double digitFontSize;
  final double letterFontSize;

  static const Map<String, String> _letters = <String, String>{
    '1': '',
    '2': 'ABC',
    '3': 'DEF',
    '4': 'GHI',
    '5': 'JKL',
    '6': 'MNO',
    '7': 'PQRS',
    '8': 'TUV',
    '9': 'WXYZ',
    '0': '+',
  };

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        children: [
          _buildRow(context, const ['1', '2', '3']),
          SizedBox(height: spacing),
          _buildRow(context, const ['4', '5', '6']),
          SizedBox(height: spacing),
          _buildRow(context, const ['7', '8', '9']),
          SizedBox(height: spacing),
          Row(
            children: [
              Expanded(
                child: showBiometricButton
                    ? _PasswordKeyButton(
                        icon: Icons.fingerprint_rounded,
                        onPressed: enabled ? onBiometricPressed : null,
                        buttonHeight: buttonHeight,
                        borderRadius: borderRadius,
                      )
                    : SizedBox(height: buttonHeight),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: _PasswordDigitButton(
                  digit: '0',
                  letters: _letters['0']!,
                  enabled: enabled,
                  onPressed: () => onDigitPressed('0'),
                  buttonHeight: buttonHeight,
                  borderRadius: borderRadius,
                  digitFontSize: digitFontSize,
                  letterFontSize: letterFontSize,
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: _PasswordKeyButton(
                  icon: Icons.backspace_outlined,
                  onPressed: enabled ? onBackspacePressed : null,
                  buttonHeight: buttonHeight,
                  borderRadius: borderRadius,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, List<String> digits) {
    return Row(
      children: [
        for (var i = 0; i < digits.length; i++) ...[
          Expanded(
            child: _PasswordDigitButton(
              digit: digits[i],
              letters: _letters[digits[i]] ?? '',
              enabled: enabled,
              onPressed: () => onDigitPressed(digits[i]),
              buttonHeight: buttonHeight,
              borderRadius: borderRadius,
              digitFontSize: digitFontSize,
              letterFontSize: letterFontSize,
            ),
          ),
          if (i != digits.length - 1) SizedBox(width: spacing),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private button widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PasswordDigitButton extends StatelessWidget {
  const _PasswordDigitButton({
    required this.digit,
    required this.letters,
    required this.enabled,
    required this.onPressed,
    required this.buttonHeight,
    required this.borderRadius,
    required this.digitFontSize,
    required this.letterFontSize,
  });

  final String digit;
  final String letters;
  final bool enabled;
  final VoidCallback onPressed;
  final double buttonHeight;
  final double borderRadius;
  final double digitFontSize;
  final double letterFontSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: enabled ? onPressed : null,
        child: Ink(
          height: buttonHeight,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  digit,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: digitFontSize,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
                if (letters.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    letters,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: letterFontSize,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                      height: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordKeyButton extends StatelessWidget {
  const _PasswordKeyButton({
    required this.icon,
    required this.onPressed,
    required this.buttonHeight,
    required this.borderRadius,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double buttonHeight;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onPressed,
        child: Ink(
          height: buttonHeight,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Center(
            child: Icon(icon, color: colorScheme.onSurfaceVariant, size: 28),
          ),
        ),
      ),
    );
  }
}
