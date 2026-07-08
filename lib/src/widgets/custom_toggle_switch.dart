import 'package:flutter/material.dart';

/// Custom toggle switch widget inspired by iOS design
/// Shows ON (green) / OFF (gray) states clearly
class CustomToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? activeText;
  final String? inactiveText;
  final Color? activeColor;
  final Color? inactiveColor;
  final double width;
  final double height;

  const CustomToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeText,
    this.inactiveText,
    this.activeColor,
    this.inactiveColor,
    this.width = 60,
    this.height = 32,
  });

  @override
  Widget build(BuildContext context) {
    final activeCol = activeColor ?? Colors.green;
    final inactiveCol = inactiveColor ?? Colors.grey[400]!;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: value ? activeCol : inactiveCol,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: Stack(
          children: [
            // ON/OFF text
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              left: value ? 8 : null,
              right: value ? null : 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Text(
                  value ? (activeText ?? 'ON') : (inactiveText ?? 'OFF'),
                  style: TextStyle(
                    color: value ? Colors.white : Colors.grey[600],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // Sliding circle
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              left: value ? width - height + 4 : 4,
              top: 4,
              child: Container(
                width: height - 8,
                height: height - 8,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
