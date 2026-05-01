import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:strawhut/app/app.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const StrawHutApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
