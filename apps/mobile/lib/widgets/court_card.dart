import 'package:flutter/material.dart';

class CourtCardData {
  final String title;
  final String subtitle;

  final String? distanceText; // e.g. "330 m"
  final bool inRange;
  final bool active;
  final String? radiusText; // e.g. "100 m radius"
  final int? waitingCount; // Number of players waiting
  final VoidCallback? onNextUp; // Callback for "Call Next" button
  final VoidCallback? onJoinQueue; // Callback for "Join Queue" button

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
    this.waitingCount,
    this.onNextUp,
    this.onJoinQueue,
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
      color: Color(0xFF3A3A3C),
      elevation: 4,
      shadowColor: Color(0x00000040),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Color(0xFF2C2C2E),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(
                letter: _initial(data.title),
              ),
              const SizedBox(width: 16),

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
                        color: Color(0xFFFFFFFF),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall?.copyWith(
                        color: Color(0xFFC7C7CC),
                      ),
                    ),
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: chips,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Waiting queue badge
                  if (data.waitingCount != null && data.waitingCount! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFFFF2D55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${data.waitingCount} waiting',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Color(0xFFFFFFFF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Join Queue button
                  if (data.onJoinQueue != null)
                    SizedBox(
                      height: 38,
                      child: FilledButton(
                        onPressed: data.onJoinQueue,
                        style: FilledButton.styleFrom(
                          backgroundColor: Color(0xFF32D74B),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'Join Queue',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Color(0xFF1F1F1F),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Call Next button
                  if (data.onNextUp != null)
                    SizedBox(
                      height: 38,
                      child: FilledButton(
                        onPressed: data.onNextUp,
                        style: FilledButton.styleFrom(
                          backgroundColor: Color(0xFFFFD700),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'Call Next',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Color(0xFF1F1F1F),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Check in button
                  SizedBox(
                    height: 38,
                    child: FilledButton(
                      onPressed: data.onCheckIn,
                      style: FilledButton.styleFrom(
                        backgroundColor: Color(0xFFFF2D55),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'Check in',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Color(0xFFFFFFFF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFC7C7CC),
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
    final t = Theme.of(context).textTheme;

    final bg = emphasis ? Color(0xFFFF2D55) : Color(0xFF2C2C2E);
    final fg = emphasis ? Color(0xFFFFFFFF) : Color(0xFFC7C7CC);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: emphasis ? Color(0xFFFF2D55) : Color(0xFF3A3A3C),
          width: 1,
        ),
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
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Color(0xFFFF2D55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFF2C2C2E), width: 1),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFF2D55).withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: Color(0xFFFFFFFF),
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
    );
  }
}
