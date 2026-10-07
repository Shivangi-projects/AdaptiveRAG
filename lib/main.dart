import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'services/native_bridge.dart';
import 'services/settings_service.dart';
import 'services/knowledge_service.dart';
import 'services/model_service.dart';
import 'services/benchmark_service.dart';
import 'services/rag_service.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/knowledge/knowledge_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/performance/performance_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/demo/demo_mode_screen.dart';

Future<void> bootstrapEdgeRag(NativeBridge bridge, KnowledgeService knowledgeService) async {
  try {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    final dbPath = '${appDir.path}/knowledge.db';
    final onnxPath = '${modelsDir.path}/model_quantized.onnx';
    final vocabPath = '${modelsDir.path}/vocab.txt';

    // 1. Unpack ONNX model
    final onnxFile = File(onnxPath);
    if (!await onnxFile.exists() || await onnxFile.length() < 20 * 1024 * 1024) {
      try {
        final data = await rootBundle.load('assets/models/embedding/model_quantized.onnx');
        await onnxFile.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
      } catch (e) {
        debugPrint('ONNX asset extract note: $e');
      }
    }

    // 2. Unpack vocab.txt
    final vocabFile = File(vocabPath);
    if (!await vocabFile.exists()) {
      try {
        final data = await rootBundle.load('assets/models/embedding/vocab.txt');
        await vocabFile.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
      } catch (e) {
        debugPrint('Vocab asset extract note: $e');
      }
    }

    // 3. Unpack initial SQLite knowledge database
    final dbFile = File(dbPath);

if (await dbFile.exists()) {
  print("DELETING OLD DB");
  await dbFile.delete();
}


    // 4. Initialize Native C++ Core
    final ok = bridge.initEngine(
  dbPath,
  onnxPath,
  vocabPath,
);

print("EDGE RAG INIT RESULT = $ok");
print("DB PATH = $dbPath");
print("ONNX PATH = $onnxPath");
print("VOCAB PATH = $vocabPath");

    // 5. Load sample pack if knowledge base is empty
    await knowledgeService.refreshDocuments();
    if (knowledgeService.documents.isEmpty) {
      await knowledgeService.loadSamplePack();
    }
  } catch (e) {
    debugPrint('Bootstrap error: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final nativeBridge = NativeBridge()..initialize();
  final settingsService = SettingsService();
  await settingsService.loadSettings();

 final knowledgeService = KnowledgeService();
final modelService = ModelService();
final benchmarkService = BenchmarkService();
final ragService = RagService(modelService, benchmarkService);

await bootstrapEdgeRag(
  nativeBridge,
  knowledgeService,
);

runApp(EdgeRagApp(
    settingsService: settingsService,
    knowledgeService: knowledgeService,
    modelService: modelService,
    benchmarkService: benchmarkService,
    ragService: ragService,
    nativeBridge: nativeBridge,
  ));
}

class EdgeRagApp extends StatefulWidget {
  final SettingsService settingsService;
  final KnowledgeService knowledgeService;
  final ModelService modelService;
  final BenchmarkService benchmarkService;
  final RagService ragService;
  final NativeBridge nativeBridge;

  const EdgeRagApp({
    super.key,
    required this.settingsService,
    required this.knowledgeService,
    required this.modelService,
    required this.benchmarkService,
    required this.ragService,
    required this.nativeBridge,
  });

  @override
  State<EdgeRagApp> createState() => _EdgeRagAppState();
}

class _EdgeRagAppState extends State<EdgeRagApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EdgeRAG Offline Intelligence',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B1325),
        primaryColor: const Color(0xFF2563EB),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2563EB),
          secondary: Color(0xFF38BDF8),
          surface: Color(0xFF111E38),
        ),
      ),
      home: widget.settingsService.settings.isFirstRun
          ? OnboardingScreen(
              settingsService: widget.settingsService,
              onFinished: () {
                setState(() {});
              },
            )
          : MainNavigationScreen(
              settingsService: widget.settingsService,
              knowledgeService: widget.knowledgeService,
              modelService: widget.modelService,
              benchmarkService: widget.benchmarkService,
              ragService: widget.ragService,
              nativeBridge: widget.nativeBridge,
            ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final SettingsService settingsService;
  final KnowledgeService knowledgeService;
  final ModelService modelService;
  final BenchmarkService benchmarkService;
  final RagService ragService;
  final NativeBridge nativeBridge;

  const MainNavigationScreen({
    super.key,
    required this.settingsService,
    required this.knowledgeService,
    required this.modelService,
    required this.benchmarkService,
    required this.ragService,
    required this.nativeBridge,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(
        knowledgeService: widget.knowledgeService,
        modelService: widget.modelService,
        benchmarkService: widget.benchmarkService,
        settingsService: widget.settingsService,
        nativeBridge: widget.nativeBridge,
        onNavigate: (idx) {
          if (idx == 5) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DemoModeScreen(
                  ragService: widget.ragService,
                  settingsService: widget.settingsService,
                  knowledgeService: widget.knowledgeService,
                ),
              ),
            );
          } else {
            setState(() => _currentIndex = idx);
          }
        },
      ),
      KnowledgeScreen(
        knowledgeService: widget.knowledgeService,
        settingsService: widget.settingsService,
      ),
      ChatScreen(
        ragService: widget.ragService,
        settingsService: widget.settingsService,
        modelService: widget.modelService,
      ),
      PerformanceScreen(
        benchmarkService: widget.benchmarkService,
        knowledgeService: widget.knowledgeService,
      ),
      SettingsScreen(
        settingsService: widget.settingsService,
        modelService: widget.modelService,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0F1B35),
          indicatorColor: const Color(0x4D2563EB),
          labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
            (states) => states.contains(WidgetState.selected)
                ? const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)
                : const TextStyle(color: Color(0xFF64748B), fontSize: 11),
          ),
          iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
            (states) => states.contains(WidgetState.selected)
                ? const IconThemeData(color: Color(0xFF38BDF8), size: 22)
                : const IconThemeData(color: Color(0xFF64748B), size: 22),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.library_books_outlined), selectedIcon: Icon(Icons.library_books), label: 'Knowledge'),
            NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chat'),
            NavigationDestination(icon: Icon(Icons.speed_outlined), selectedIcon: Icon(Icons.speed), label: 'Performance'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}