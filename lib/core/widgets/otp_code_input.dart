import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Six-digit OTP entry with individual boxes, active-slot highlight, and
/// blinking cursor. Uses a hidden field underneath for keyboard + autofill.
class OtpCodeInput extends StatefulWidget {
  const OtpCodeInput({
    super.key,
    required this.controller,
    this.length = 6,
    this.autofocus = true,
    this.enabled = true,
    this.errorText,
    this.onCompleted,
    this.onChanged,
  });

  final TextEditingController controller;
  final int length;
  final bool autofocus;
  final bool enabled;
  final String? errorText;
  final VoidCallback? onCompleted;
  final ValueChanged<String>? onChanged;

  @override
  State<OtpCodeInput> createState() => _OtpCodeInputState();
}

class _OtpCodeInputState extends State<OtpCodeInput>
    with SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  late final AnimationController _cursorBlink;

  @override
  void initState() {
    super.initState();
    _cursorBlink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..repeat(reverse: true);
    _focusNode.addListener(_handleFocusChange);
    widget.controller.addListener(_handleControllerChange);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.enabled) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
    if (_focusNode.hasFocus) {
      if (!_cursorBlink.isAnimating) _cursorBlink.repeat(reverse: true);
    } else {
      _cursorBlink.stop();
    }
  }

  void _handleControllerChange() {
    if (mounted) setState(() {});
  }

  void _requestFocus() {
    if (!widget.enabled) return;
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
    Future.delayed(const Duration(milliseconds: 40), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _cursorBlink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final code = widget.controller.text;
    final focused = _focusNode.hasFocus && widget.enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 10.0;
            final slots = widget.length;
            final boxWidth =
                ((constraints.maxWidth - gap * (slots - 1)) / slots)
                    .clamp(40.0, 56.0);
            final boxHeight = boxWidth * 1.15;

            return GestureDetector(
              onTap: _requestFocus,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(slots, (index) {
                  final hasDigit = index < code.length;
                  final isActive =
                      focused && index == code.length && code.length < slots;

                  late final Color background;
                  late final Color borderColor;
                  late final double borderWidth;

                  if (hasError) {
                    background = scheme.errorContainer.withValues(alpha: 0.25);
                    borderColor = scheme.error.withValues(
                      alpha: hasDigit || isActive ? 0.85 : 0.45,
                    );
                    borderWidth = isActive ? 2 : 1.25;
                  } else if (hasDigit) {
                    background = scheme.primaryContainer.withValues(alpha: 0.4);
                    borderColor = scheme.primary.withValues(alpha: 0.65);
                    borderWidth = 1.5;
                  } else if (isActive) {
                    background = scheme.primary.withValues(alpha: 0.08);
                    borderColor = scheme.primary;
                    borderWidth = 2;
                  } else {
                    background =
                        scheme.surfaceContainerHighest.withValues(alpha: 0.9);
                    borderColor = scheme.outlineVariant.withValues(alpha: 0.9);
                    borderWidth = 1;
                  }

                  return Padding(
                    padding: EdgeInsets.only(left: index == 0 ? 0 : gap),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      width: boxWidth,
                      height: boxHeight,
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: borderColor,
                          width: borderWidth,
                        ),
                        boxShadow: isActive && !hasError
                            ? [
                                BoxShadow(
                                  color: scheme.primary.withValues(alpha: 0.18),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: hasDigit
                            ? Text(
                                code[index],
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: hasError
                                      ? scheme.error
                                      : scheme.primary,
                                  height: 1,
                                ),
                              )
                            : isActive
                            ? FadeTransition(
                                opacity: _cursorBlink,
                                child: Container(
                                  width: 2.5,
                                  height: boxHeight * 0.42,
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              )
                            : Text(
                                '·',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: scheme.onSurfaceVariant.withValues(
                                    alpha: 0.28,
                                  ),
                                  height: 1,
                                ),
                              ),
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        ),
        SizedBox(
          height: 0,
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            autofocus: false,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: widget.length,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 1, color: Colors.transparent),
            decoration: const InputDecoration(
              border: InputBorder.none,
              counterText: '',
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (value) {
              widget.onChanged?.call(value);
              if (value.length == widget.length) {
                widget.onCompleted?.call();
              }
            },
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 10),
          Text(
            widget.errorText!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
