import 'package:flutter/material.dart';
import 'package:mental_warior/models/user_xp.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/utils/app_theme.dart';

class XPBar extends StatelessWidget {
  final bool compact;

  const XPBar({Key? key, this.compact = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserXP?>(
      valueListenable: XPService.xpNotifier,
      builder: (context, userXP, child) {
        if (userXP == null) {
          return FutureBuilder<UserXP>(
            future: XPService().getUserXP(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }
              return _buildXPBar(context, snapshot.data!);
            },
          );
        }
        return _buildXPBar(context, userXP);
      },
    );
  }

  Widget _buildXPBar(BuildContext context, UserXP userXP) {
    if (compact) {
      return _buildCompactBar(context, userXP);
    }
    return _buildFullBar(context, userXP);
  }

  Widget _buildFullBar(BuildContext context, UserXP userXP) {
    final progress = userXP.progressToNextLevel;
    final currentLevelXP = UserXP.xpForLevel(userXP.level);
    final xpInCurrentLevel = userXP.totalXP - currentLevelXP;
    final xpNeededInLevel = UserXP.xpForLevel(userXP.level + 1) - currentLevelXP;
    final rankColor = UserXP.getRankColor(userXP.rank);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey[900]!,
            Colors.grey[850]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rankColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: rankColor.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Level and Rank
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Level badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [rankColor, rankColor.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: rankColor.withOpacity(0.3),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Level ${userXP.level}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Rank badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: rankColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: rankColor.withOpacity(0.5), width: 1.5),
                ),
                child: Text(
                  userXP.rank,
                  style: TextStyle(
                    color: rankColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // XP progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // XP text
              Text(
                '${xpInCurrentLevel} / ${xpNeededInLevel} XP',
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              // Progress bar
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(rankColor),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // XP to next level
              Text(
                '${userXP.xpToNextLevel} XP to level ${userXP.level + 1}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBar(BuildContext context, UserXP userXP) {
    final progress = userXP.progressToNextLevel;
    final rankColor = UserXP.getRankColor(userXP.rank);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rankColor.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          // Level badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [rankColor, rankColor.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Lv ${userXP.level}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Progress bar
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(rankColor),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Rank text
          Text(
            userXP.rank,
            style: TextStyle(
              color: rankColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
