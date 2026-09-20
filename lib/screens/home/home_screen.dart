import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/native_bridge.dart';
import '../../services/knowledge_service.dart';
import '../../services/model_service.dart';
import '../../services/benchmark_service.dart';
import '../../services/settings_service.dart';

class HomeScreen extends StatefulWidget {
  final KnowledgeService knowledgeService;
  final ModelService modelService;
  final BenchmarkService benchmarkService;
  final SettingsService settingsService;
  final NativeBridge nativeBridge;
  final Function(int) onNavigate;

  const HomeScreen({
    super.key,
    required this.knowledgeService,
    required this.modelService,
    required this.benchmarkService,
    required this.settingsService,
    required this.nativeBridge,
    required this.onNavigate,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      bootstrapEdgeRag(widget.nativeBridge, widget.knowledgeService);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EdgeRAG Home'),
        backgroundColor: const Color(0xFF0F1B35),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bolt,
              size: 64,
              color: Color(0xFF38BDF8),
            ),
            const SizedBox(height: 16),
            const Text(
              'EdgeRAG Ready',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () => widget.onNavigate(2), // Navigate to Chat screen
              child: const Text(
                'Open Chat',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}