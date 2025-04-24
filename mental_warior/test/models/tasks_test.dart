import 'package:flutter_test/flutter_test.dart';
import 'package:mental_warior/models/task.dart';

void main() {
  test('Task model should create a task with given properties', () {
    final task = Task(id: 1, title: 'Test Task', completed: false);
    expect(task.id, 1);
    expect(task.title, 'Test Task');
    expect(task.completed, false);
  });

  test('Task model should toggle completion status', () {
    final task = Task(id: 1, title: 'Test Task', completed: false);
    task.toggleCompletion();
    expect(task.completed, true);
  });
}