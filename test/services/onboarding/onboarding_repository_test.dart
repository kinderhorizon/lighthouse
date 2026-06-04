import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/services/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('initial read returns completed=false and homeLabel=null', () async {
    final repo = OnboardingRepository();
    final state = await repo.read();
    expect(state.completed, isFalse);
    expect(state.homeLabel, isNull);
  });

  test('markComplete persists across new repository instances', () async {
    await OnboardingRepository().markComplete();
    final state = await OnboardingRepository().read();
    expect(state.completed, isTrue);
  });

  test('setHomeLabel persists the enum and round-trips by name', () async {
    final repo = OnboardingRepository();
    await repo.setHomeLabel(OnboardingHomeLabel.school);
    final state = await OnboardingRepository().read();
    expect(state.homeLabel, OnboardingHomeLabel.school);
  });

  test('setHomeLabel(null) clears the persisted value', () async {
    final repo = OnboardingRepository();
    await repo.setHomeLabel(OnboardingHomeLabel.both);
    await repo.setHomeLabel(null);
    final state = await OnboardingRepository().read();
    expect(state.homeLabel, isNull);
  });

  test('reset clears completed and homeLabel together', () async {
    final repo = OnboardingRepository();
    await repo.setHomeLabel(OnboardingHomeLabel.home);
    await repo.markComplete();
    await repo.reset();
    final state = await OnboardingRepository().read();
    expect(state.completed, isFalse);
    expect(state.homeLabel, isNull);
  });

  test('tryParse handles unknown enum strings as null', () {
    expect(OnboardingHomeLabel.tryParse(null), isNull);
    expect(OnboardingHomeLabel.tryParse(''), isNull);
    expect(OnboardingHomeLabel.tryParse('Hogwarts'), isNull);
    expect(OnboardingHomeLabel.tryParse('home'), OnboardingHomeLabel.home);
  });
}
