import 'package:flutter_test/flutter_test.dart';
import 'package:mental_warior/services/database_services.dart';

void main() {
  test('Database service should return expected data', () async {
    final databaseService = DatabaseService();
    final result = await databaseService.getData();
    expect(result, isNotNull);
    expect(result, equals(expectedData));
  });
}