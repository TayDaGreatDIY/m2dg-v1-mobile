import 'package:flutter/material.dart';

class ChallengeCard extends StatelessWidget {
  final String title;
  final String? subtitle; // e.g. "by BallinMike"
  final String? imageUrl; // Challenge thumbnail or video thumbnail
  final String? prizeAmount; // e.g. "$50 Cash"
  final String? badgeLabel; // e.g. "Golden Badge"
  final int participantCount; // Number of players who participated
  final bool isFeatured; // Show fire animation indicator
  final VoidCallback? onTap;

  const ChallengeCard({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.prizeAmount,
    this.badgeLabel,
    this.participantCount = 0,
    this.isFeatured = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: const Color(0xFF3A3A3C),
      elevation: 4,
      shadowColor: const Color(0x0000000040),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF2C2C2E),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail image
              if (imageUrl != null)
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                    ),
                    color: const Color(0xFF2C2C2E),
                    image: DecorationImage(
                      image: NetworkImage(imageUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Fire indicator for featured challenges
                      if (isFeatured)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF2D55),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '🔥',
                                  style: TextStyle(fontSize: 12),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Hot',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Prize badge
                      if (prizeAmount != null)
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '🏆',
                                  style: TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'WIN ${prizeAmount!}',
                                  style: const TextStyle(
                                    color: Color(0xFF1F1F1F),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                    ),
                    color: const Color(0xFF2C2C2E),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: const Color(0xFFC7C7CC),
                      size: 48,
                    ),
                  ),
                ),
              // Content section
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Challenge title
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Subtitle (creator)
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFFC7C7CC),
                        ),
                      ),
                    ],
                    // Participant count
                    if (participantCount > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.people_outline,
                            color: Color(0xFFC7C7CC),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$participantCount players',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: const Color(0xFFC7C7CC),
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Badge info
                    if (badgeLabel != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badgeLabel!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF1F1F1F),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
