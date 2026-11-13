import 'package:cine_catalogo/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('La bienvenida ofrece registro e inicio de sesión', (
    tester,
  ) async {
    await tester.pumpWidget(const Cinema());

    expect(find.text('Bienvenido a Cine Catálogo'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
  });
}
