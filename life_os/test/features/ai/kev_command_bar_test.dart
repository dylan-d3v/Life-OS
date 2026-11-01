import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/ai/data/kev_action_dispatcher.dart';
import 'package:life_os/features/ai/data/kev_llm_service.dart';
import 'package:life_os/features/ai/domain/kev_action.dart';
import 'package:life_os/features/ai/presentation/ai_providers.dart';
import 'package:life_os/features/ai/presentation/kev_command_bar_controller.dart';
import 'package:life_os/features/ai/presentation/kev_command_bar_dialog.dart';
import 'package:life_os/features/shell/presentation/desktop_scaffold.dart';

// =============================================================================
// Mocks para pruebas de UI
// =============================================================================

class MockLlmServiceForUi implements KevLlmService {
  KevAction nextAction;

  MockLlmServiceForUi({
    this.nextAction = const CreateTaskAction(title: 'Tarea de prueba'),
  });

  @override
  Future<KevAction> parseUserIntent(
    String userInput, {
    DateTime? referenceDateTime,
  }) async {
    return nextAction;
  }
}

class MockDispatcherForUi implements KevActionDispatcher {
  KevExecutionResult nextResult;
  KevAction? lastDispatchedAction;

  MockDispatcherForUi({
    this.nextResult = const KevExecutionResult(
      success: true,
      userMessage: 'Tarea agregada: "Tarea de prueba".',
      actionType: 'create_task',
      entityId: 'task-123',
    ),
  });

  @override
  Future<KevExecutionResult> dispatch(KevAction action) async {
    lastDispatchedAction = action;
    return nextResult;
  }

  // Stubs no utilizados en este test pero requeridos por la interfaz
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  testWidgets('DesktopScaffold muestra el botón de Kev y abre el diálogo al pulsarlo',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DesktopScaffold(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verificamos que el botón de Kev Asistente esté presente en la barra superior
    final shortcutBtn = find.byKey(const Key('kev_assistant_shortcut_button'));
    expect(shortcutBtn, findsOneWidget);
    expect(find.text('Kev Asistente'), findsOneWidget);
    expect(find.text('Ctrl + K'), findsOneWidget);

    // Pulsamos el botón para abrir la barra de comandos
    await tester.tap(shortcutBtn);
    await tester.pumpAndSettle();

    // Verificamos que el diálogo modal se abrió
    expect(find.text('Kev AI Assistant'), findsOneWidget);
    expect(find.text('TypeSafe E2EE'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('KevCommandBarDialog muestra sugerencias iniciales y atajos de pie',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: KevCommandBarDialog(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verificamos encabezado y sugerencias
    expect(find.text('Kev AI Assistant'), findsOneWidget);
    expect(find.text('Sugerencias de órdenes:'), findsOneWidget);
    expect(find.text('Anotar tarea estudiar matemáticas para mañana'), findsOneWidget);
    expect(find.text('Gasté \$15 en almuerzo'), findsOneWidget);

    // Verificamos pie con atajos
    expect(find.text('Enter'), findsOneWidget);
    expect(find.text('Esc'), findsOneWidget);
    expect(find.text('Zero-Knowledge AES-256-GCM'), findsOneWidget);

    // Pulsar una sugerencia debe colocarla en el TextField
    await tester.tap(find.text('Gasté \$15 en almuerzo'));
    await tester.pumpAndSettle();

    expect(find.text('Gasté \$15 en almuerzo'), findsWidgets);
  });

  testWidgets('KevCommandBarDialog ejecuta una orden y muestra la tarjeta de resultado exitoso',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockLlm = MockLlmServiceForUi(
      nextAction: const CreateTaskAction(title: 'Comprar café tostado'),
    );
    final mockDispatcher = MockDispatcherForUi(
      nextResult: const KevExecutionResult(
        success: true,
        userMessage: 'Tarea agregada: "Comprar café tostado".',
        actionType: 'create_task',
        entityId: 't-123',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kevLlmServiceProvider.overrideWithValue(mockLlm),
          kevActionDispatcherProvider.overrideWithValue(mockDispatcher),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: KevCommandBarDialog(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Escribimos una orden en el campo de texto
    await tester.enterText(find.byType(TextField), 'Anotar tarea comprar café');
    await tester.pumpAndSettle();

    // Pulsamos el botón de enviar
    await tester.tap(find.byKey(const Key('kev_submit_button')));
    await tester.pumpAndSettle();

    // Verificamos que se renderice la tarjeta de resultado con el badge correspondiente
    expect(find.text('Tarea Creada'), findsOneWidget);
    expect(find.text('Tarea agregada: "Comprar café tostado".'), findsOneWidget);

    // Verificamos que el comando aparezca en el historial reciente
    expect(find.text('Comandos recientes de la sesión:'), findsOneWidget);
    expect(find.text('Anotar tarea comprar café'), findsOneWidget);
  });

  testWidgets('KevCommandBarDialog muestra feedback de error si el despachador falla',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockLlm = MockLlmServiceForUi();
    final mockDispatcher = MockDispatcherForUi(
      nextResult: const KevExecutionResult(
        success: false,
        userMessage: 'La bóveda de seguridad está bloqueada.',
        actionType: 'create_task',
        error: 'KeyVault locked',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kevLlmServiceProvider.overrideWithValue(mockLlm),
          kevActionDispatcherProvider.overrideWithValue(mockDispatcher),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: KevCommandBarDialog(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Enviamos una orden
    await tester.enterText(find.byType(TextField), 'Nueva tarea urgente');
    await tester.tap(find.byKey(const Key('kev_submit_button')));
    await tester.pumpAndSettle();

    // Verificamos que se muestre el badge de Error
    expect(find.text('Error'), findsOneWidget);
    expect(find.text('La bóveda de seguridad está bloqueada.'), findsOneWidget);
  });

  testWidgets('KevCommandBarController valida entrada vacía', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(kevCommandBarProvider.notifier);
    final result = await notifier.executePrompt('   ');

    expect(result.success, isFalse);
    expect(result.userMessage, 'Por favor, escribe una instrucción para Kev.');

    final state = container.read(kevCommandBarProvider);
    expect(state.errorMessage, contains('Por favor, escribe una instrucción'));
  });
}

