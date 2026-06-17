import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_em_dashboard/main.dart';

void main() {
  testWidgets('App shows fleet dashboard title', (WidgetTester tester) async {
    await tester.pumpWidget(const FleetEmApp());
    await tester.pump();

    expect(find.text('Fleet EM — MTD / YTD vs target'), findsOneWidget);
    expect(find.textContaining('Dashboard_EM'), findsWidgets);
  });
}
