class Workout {
  final int id;
  final String name;
  final String date;
  final int duration; // Duration in seconds
  final List<Exercise> exercises;

  Workout({
    required this.id,
    required this.name,
    required this.date,
    required this.duration,
    required this.exercises,
  });

  factory Workout.fromMap(Map<String, dynamic> map, List<Exercise> exercises) {
    return Workout(
      id: map['id'] as int,
      name: map['name'] as String,
      date: map['date'] as String,
      duration: map['duration'] as int,
      exercises: exercises,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'date': date,
      'duration': duration,
    };
  }

  Workout copyWith({
    int? id,
    String? name,
    String? date,
    int? duration,
    List<Exercise>? exercises,
  }) {
    return Workout(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      duration: duration ?? this.duration,
      exercises: exercises ?? this.exercises,
    );
  }
}

class Exercise {
  final int id;
  final int workoutId;
  final String name;
  final String equipment; // e.g., "Machine", "Barbell", "Cable"
  final List<ExerciseSet> sets;

  Exercise({
    required this.id,
    required this.workoutId,
    required this.name,
    required this.equipment,
    required this.sets,
  });

  factory Exercise.fromMap(Map<String, dynamic> map, List<ExerciseSet> sets) {
    return Exercise(
      id: map['id'] as int,
      workoutId: map['workoutId'] as int,
      name: map['name'] as String,
      equipment: map['equipment'] as String,
      sets: sets,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workoutId': workoutId,
      'name': name,
      'equipment': equipment,
    };
  }
}

class ExerciseSet {
  final int id;
  final int exerciseId;
  late final int setNumber;
  double weight;
  int reps;
  int restTime; // Rest time in seconds
  bool completed;

  ExerciseSet({
    required this.id,
    required this.exerciseId,
    required this.setNumber,
    required this.weight,
    required this.reps,
    required this.restTime,
    required this.completed,
  });

  factory ExerciseSet.fromMap(Map<String, dynamic> map) {
    return ExerciseSet(
      id: map['id'] as int,
      exerciseId: map['exerciseId'] as int,
      setNumber: map['setNumber'] as int,
      weight: map['weight'] as double,
      reps: map['reps'] as int,
      restTime: map['restTime'] as int,
      completed: map['completed'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exerciseId': exerciseId,
      'setNumber': setNumber,
      'weight': weight,
      'reps': reps,
      'restTime': restTime,
      'completed': completed ? 1 : 0,
    };
  }

  ExerciseSet copyWith({
    int? id,
    int? exerciseId,
    int? setNumber,
    double? weight,
    int? reps,
    int? restTime,
    bool? completed,
  }) {
    return ExerciseSet(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      setNumber: setNumber ?? this.setNumber,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      restTime: restTime ?? this.restTime,
      completed: completed ?? this.completed,
    );
  }
}
