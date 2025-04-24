import 'package:flutter_test/flutter_test.dart';
import 'package:your_project/models/category.dart';

void main() {
  test('Category model should create an instance with given properties', () {
    final category = Category(id: 1, name: 'Test Category');
    expect(category.id, 1);
    expect(category.name, 'Test Category');
  });

  test('Category model should have a default name if not provided', () {
    final category = Category(id: 2);
    expect(category.name, 'Default Name');
  });
}