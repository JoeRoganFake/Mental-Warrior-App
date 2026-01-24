

import 'package:flutter/material.dart';
import 'dart:math';


class UserXP {
  final int id;
  final int totalXP;
  final int level;
  final String rank;
  final DateTime lastUpdated;

  UserXP({
    required this.id,
    required this.totalXP,
    required this.level,
    required this.rank,
    required this.lastUpdated,
  });

  // Calculate level from XP (exponential curve)
  static int calculateLevel(int xp) {
    // Level 1: 0-99 XP
    // Level 2: 100-399 XP (need 100 XP)
    // Level 3: 400-899 XP (need 300 more XP)
    // Level 4: 900-1599 XP (need 500 more XP)
    // Formula: XP needed = (level-1)^2 * 100
    return sqrt(xp / 100).floor() + 1;
  }

  // Calculate XP needed to START a given level (0-indexed internally)
  static int xpForLevel(int level) {
    // Level 1 starts at 0 XP
    // Level 2 starts at 100 XP: (2-1)^2 * 100 = 100
    // Level 3 starts at 400 XP: (3-1)^2 * 100 = 400
    return ((level - 1) * (level - 1) * 100);
  }

  // Calculate XP needed to reach next level
  int get xpToNextLevel {
    int currentLevelXP = xpForLevel(level);
    int nextLevelXP = xpForLevel(level + 1);
    return nextLevelXP - totalXP;
  }

  // Calculate progress to next level (0.0 to 1.0)
  double get progressToNextLevel {
    int currentLevelXP = xpForLevel(level);
    int nextLevelXP = xpForLevel(level + 1);
    int xpInCurrentLevel = totalXP - currentLevelXP;
    int xpNeededInLevel = nextLevelXP - currentLevelXP;
    return (xpInCurrentLevel / xpNeededInLevel).clamp(0.0, 1.0);
  }

  // Determine rank based on level
  static String calculateRank(int level) {
    if (level < 10) return "Novice";
    if (level < 20) return "Apprentice";
    if (level < 30) return "Adept";
    if (level < 40) return "Expert";
    if (level < 50) return "Master";
    if (level < 75) return "Grandmaster";
    if (level < 100) return "Legend";
    return "Immortal";
  }

  // Get rank color
  static Color getRankColor(String rank) {
    switch (rank) {
      case "Novice":
        return Colors.grey;
      case "Apprentice":
        return Colors.green;
      case "Adept":
        return Colors.blue;
      case "Expert":
        return Colors.purple;
      case "Master":
        return Colors.orange;
      case "Grandmaster":
        return Colors.red;
      case "Legend":
        return Colors.amber;
      case "Immortal":
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'totalXP': totalXP,
      'level': level,
      'rank': rank,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory UserXP.fromMap(Map<String, dynamic> map) {
    return UserXP(
      id: map['id'],
      totalXP: map['totalXP'],
      level: map['level'],
      rank: map['rank'],
      lastUpdated: DateTime.parse(map['lastUpdated']),
    );
  }

  UserXP copyWith({
    int? id,
    int? totalXP,
    int? level,
    String? rank,
    DateTime? lastUpdated,
  }) {
    return UserXP(
      id: id ?? this.id,
      totalXP: totalXP ?? this.totalXP,
      level: level ?? this.level,
      rank: rank ?? this.rank,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
