import 'package:flutter_test/flutter_test.dart';
import 'package:smart_presensi/main.dart';
import 'package:smart_presensi/pages/login_page.dart';

void main() {
  testWidgets('App menampilkan halaman login saat pertama dibuka',
      (tester) async {
    await tester.pumpWidget(const SmartPresensiApp());

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Smart Presensi'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
  });
}
