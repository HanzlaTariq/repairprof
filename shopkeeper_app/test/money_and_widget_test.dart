import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repairproof/models/repair.dart';
import 'package:repairproof/core/theme.dart';
import 'package:repairproof/widgets/common.dart';

void main() {
  test('currency uses exact integer minor units', () {
    expect(minor('120.50'), 12050);
    expect(minor('0.01'), 1);
    expect(() => minor('1.234'), throwsFormatException);
    expect(() => minor('-5'), throwsFormatException);
  });
  testWidgets('ticket card is usable on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: repairTheme(),
        home: Scaffold(
          body: TicketTile({
            'customerName': 'A customer with a very long name',
            'device': 'A long device brand and model description',
            'number': 'RP-1001',
            'status': 'Awaiting Approval',
          }, onTap: () => opened = true),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('RP-1001'));
    expect(opened, true);
  });
}
