import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter_shop/main.dart';

void main() {
  testWidgets('shows setup guidance when Supabase is not configured', (
    tester,
  ) async {
    await tester.pumpWidget(const ShopApp(isConfigured: false));

    expect(find.textContaining('supabase_config.json'), findsOneWidget);
    expect(find.text('flutter run'), findsOneWidget);
  });
}
