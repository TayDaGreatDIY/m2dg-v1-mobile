import 'package:flutter/material.dart';

class CourtCardData {
  final String title;
  final String subtitle;

  final String? distanceText; // e.g. "330 m"
  final bool inRange;
  final bool active;
  final String? radiusText; // e.g. "100 m radius"

  final VoidCallback onTap;
  final VoidCallback? onCheckIn; // null disables the button

  const CourtCardData({
    required this.title,
    required this.subtitle,
    required this.distanceText,
    required this.inRange,
    required this.active,
    required this.radiusText,
    required this.onTap,
    required this.onCheckIn,
  });
}

class CourtCard extends StatelessWidget {
  final CourtCardData data;

  const CourtCard({
    super.key,
    required this.data,
  });

  String _initial(String s) {
    final t = s.trim();
    if (t.isEmpty) return '?';
    return t.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = theme.textTheme;

    final chips = <Widget>[
      if (data.active)
        _pill(
          context,
          label: 'Active',
          icon: Icons.verified_rounded,
          emphasis: true,
        ),
      if (data.inRange)
        _pill(
          context,
          label: 'In range',
          icon: Icons.my_location_rounded,
          emphasis: true,
        ),
      if (data.distanceText != null)
        _pill(
          context,
          label: data.distanceText!,
          icon: Icons.straighten_rounded,
        ),
      if (data.radiusText != null)
        _pill(
          context,
          label: data.radiusText!,
          icon: Icons.radar_rounded,
        ),
    ];

    return Material(
      color: cs.surface,
      elevation: 1.5,
      shadowColor: cs.shadow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: cs.outlineVariant,
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(
                letter: _initial(data.title),
              ),
              const SizedBox(width: 12),

              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title.isEmpty ? 'Court' : data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      data.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: chips,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    height: 36,
                    child: FilledButton(
                      onPressed: data.onCheckIn,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Check in'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(
    BuildContext context, {
    required String label,
    IconData? icon,
    bool emphasis = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final bg = emphasis ? cs.primaryContainer : cs.surfaceContainerHighest;
    final fg = emphasis ? cs.onPrimaryContainer : cs.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: t.labelMedium?.copyWith(
              color: fg,
              fontWeight: emphasis ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String letter;

  const _Avatar({
    required this.letter,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: cs.onSecondaryContainer,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
    );
  }
}
