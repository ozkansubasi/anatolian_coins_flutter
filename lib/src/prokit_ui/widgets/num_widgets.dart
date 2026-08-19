import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../numistr_colors.dart';

/// NumisTR Common Widgets - ProKit Style
/// Reusable UI components for consistent design

// ============================================================================
// TEXT WIDGETS
// ============================================================================

/// Primary heading text
Widget numHeading(String text, {
  double size = 20,
  Color? color,
  FontWeight weight = FontWeight.w600,
  int maxLines = 2,
  TextAlign align = TextAlign.start,
}) {
  return Text(
    text,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    textAlign: align,
    style: TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color ?? numTextPrimary,
      height: 1.3,
    ),
  );
}

/// Secondary/body text
Widget numBody(String text, {
  double size = 14,
  Color? color,
  FontWeight weight = FontWeight.w400,
  int maxLines = 3,
  TextAlign align = TextAlign.start,
  bool isLongText = false,
}) {
  return Text(
    text,
    maxLines: isLongText ? null : maxLines,
    overflow: isLongText ? null : TextOverflow.ellipsis,
    textAlign: align,
    style: TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color ?? numTextSecondary,
      height: 1.5,
    ),
  );
}

/// Caption/small text
Widget numCaption(String text, {
  double size = 12,
  Color? color,
  FontWeight weight = FontWeight.w400,
}) {
  return Text(
    text,
    style: TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color ?? numTextHint,
    ),
  );
}

// ============================================================================
// IMAGE WIDGETS
// ============================================================================

/// Cached network image with placeholder
Widget numCachedImage(
  String? url, {
  double? height,
  double? width,
  BoxFit fit = BoxFit.cover,
  double borderRadius = 8,
  Widget? placeholder,
  Widget? errorWidget,
}) {
  if (url == null || url.isEmpty) {
    return _buildPlaceholder(height: height, width: width, borderRadius: borderRadius);
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: CachedNetworkImage(
      imageUrl: url,
      height: height,
      width: width,
      fit: fit,
      placeholder: (context, url) => placeholder ?? _buildShimmer(height: height, width: width),
      errorWidget: (context, url, error) => errorWidget ?? _buildErrorPlaceholder(height: height, width: width),
    ),
  );
}

/// Shimmer loading placeholder
Widget _buildShimmer({double? height, double? width}) {
  return Shimmer.fromColors(
    baseColor: numShimmerBase,
    highlightColor: numShimmerHighlight,
    child: Container(
      height: height,
      width: width,
      color: numShimmerBase,
    ),
  );
}

/// Default placeholder for missing images
Widget _buildPlaceholder({double? height, double? width, double borderRadius = 8}) {
  return Container(
    height: height,
    width: width,
    decoration: BoxDecoration(
      color: numSurfaceLight,
      borderRadius: BorderRadius.circular(borderRadius),
    ),
    child: const Icon(
      Icons.monetization_on_outlined,
      size: 40,
      color: numTextHint,
    ),
  );
}

/// Error placeholder
Widget _buildErrorPlaceholder({double? height, double? width}) {
  return Container(
    height: height,
    width: width,
    color: numSurfaceLight,
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.broken_image_outlined, size: 32, color: numTextHint),
        SizedBox(height: 4),
        Text('Resim yok', style: TextStyle(fontSize: 10, color: numTextHint)),
      ],
    ),
  );
}

// ============================================================================
// CARD WIDGETS
// ============================================================================

/// Standard card with shadow
Widget numCard({
  required Widget child,
  EdgeInsets padding = const EdgeInsets.all(16),
  EdgeInsets margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  double borderRadius = 12,
  Color? color,
  double elevation = 2,
  VoidCallback? onTap,
}) {
  final card = Container(
    margin: margin,
    decoration: BoxDecoration(
      color: color ?? numCardLight,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        BoxShadow(
          color: numShadow,
          blurRadius: elevation * 2,
          offset: Offset(0, elevation),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Padding(
        padding: padding,
        child: child,
      ),
    ),
  );

  if (onTap != null) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(borderRadius),
      child: card,
    );
  }
  return card;
}

/// List item card (horizontal layout)
Widget numListCard({
  required String title,
  String? subtitle,
  String? imageUrl,
  Widget? leading,
  Widget? trailing,
  VoidCallback? onTap,
  double imageSize = 80,
}) {
  return numCard(
    onTap: onTap,
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        // Image or leading widget
        if (imageUrl != null || leading != null) ...[
          leading ?? numCachedImage(
            imageUrl,
            height: imageSize,
            width: imageSize,
            borderRadius: 8,
          ),
          const SizedBox(width: 12),
        ],

        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              numHeading(title, size: 16, maxLines: 2),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                numBody(subtitle, size: 14, maxLines: 2),
              ],
            ],
          ),
        ),

        // Trailing
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing,
        ] else
          const Icon(Icons.chevron_right, color: numTextHint),
      ],
    ),
  );
}

/// Grid item card (vertical layout)
Widget numGridCard({
  required String title,
  String? subtitle,
  String? imageUrl,
  Widget? badge,
  VoidCallback? onTap,
  double imageHeight = 120,
}) {
  return numCard(
    onTap: onTap,
    padding: EdgeInsets.zero,
    margin: const EdgeInsets.all(4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image with badge
        Stack(
          children: [
            numCachedImage(
              imageUrl,
              height: imageHeight,
              width: double.infinity,
              borderRadius: 0,
            ),
            if (badge != null)
              Positioned(
                top: 8,
                right: 8,
                child: badge,
              ),
          ],
        ),

        // Content
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              numHeading(title, size: 14, maxLines: 2),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                numBody(subtitle, size: 12, maxLines: 1),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

// ============================================================================
// CHIP / BADGE WIDGETS
// ============================================================================

/// Material badge (AU, AR, AE)
Widget numMaterialBadge(String material, {double fontSize = 11}) {
  final color = getMaterialColor(material);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withAlpha(30),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withAlpha(100), width: 1),
    ),
    child: Text(
      material.toUpperCase(),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: color.withAlpha(200),
      ),
    ),
  );
}

/// Region badge
Widget numRegionBadge(String regionCode, String regionName, {double fontSize = 11}) {
  final color = getRegionColor(regionCode);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withAlpha(25),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      regionName,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );
}

/// Simple status badge
Widget numBadge(String text, {
  Color? backgroundColor,
  Color? textColor,
  double fontSize = 11,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: backgroundColor ?? numPrimary.withAlpha(30),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: textColor ?? numPrimary,
      ),
    ),
  );
}

// ============================================================================
// BUTTON WIDGETS
// ============================================================================

/// Primary button
Widget numPrimaryButton(
  String text, {
  required VoidCallback onPressed,
  bool isLoading = false,
  bool isFullWidth = true,
  double height = 52,
  IconData? icon,
}) {
  return SizedBox(
    width: isFullWidth ? double.infinity : null,
    height: height,
    child: ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: numTextOnPrimary,
              ),
            )
          : Row(
              mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(text),
              ],
            ),
    ),
  );
}

/// Secondary/outlined button
Widget numOutlinedButton(
  String text, {
  required VoidCallback onPressed,
  bool isFullWidth = true,
  double height = 52,
  IconData? icon,
}) {
  return SizedBox(
    width: isFullWidth ? double.infinity : null,
    height: height,
    child: OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: 8),
          ],
          Text(text),
        ],
      ),
    ),
  );
}

// ============================================================================
// LOADING / EMPTY WIDGETS
// ============================================================================

/// Loading indicator
Widget numLoading({String? message}) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: numPrimary),
        if (message != null) ...[
          const SizedBox(height: 16),
          numBody(message, align: TextAlign.center),
        ],
      ],
    ),
  );
}

/// Empty state widget
Widget numEmptyState({
  required String title,
  String? subtitle,
  IconData icon = Icons.inbox_outlined,
  Widget? action,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: numTextHint.withAlpha(100)),
          const SizedBox(height: 16),
          numHeading(title, align: TextAlign.center, color: numTextSecondary),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            numBody(subtitle, align: TextAlign.center, isLongText: true),
          ],
          if (action != null) ...[
            const SizedBox(height: 24),
            action,
          ],
        ],
      ),
    ),
  );
}

/// Error state widget
Widget numErrorState({
  required String title,
  String? subtitle,
  VoidCallback? onRetry,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: numError.withAlpha(150)),
          const SizedBox(height: 16),
          numHeading(title, align: TextAlign.center, color: numError),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            numBody(subtitle, align: TextAlign.center),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            numOutlinedButton('Tekrar Dene', onPressed: onRetry, isFullWidth: false),
          ],
        ],
      ),
    ),
  );
}

// ============================================================================
// DIVIDER / SPACING
// ============================================================================

/// Horizontal divider
Widget numHorizontalDivider({double height = 1, double indent = 0}) {
  return Divider(
    height: height,
    thickness: height,
    color: numDividerColor,
    indent: indent,
    endIndent: indent,
  );
}

/// Spacing widget
Widget numSpace({double height = 16, double width = 0}) {
  return SizedBox(height: height, width: width);
}

// ============================================================================
// SECTION HEADER
// ============================================================================

/// Section header with optional action
Widget numSectionHeader({
  required String title,
  String? actionText,
  VoidCallback? onAction,
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
}) {
  return Padding(
    padding: padding,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        numHeading(title, size: 18),
        if (actionText != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionText),
          ),
      ],
    ),
  );
}
