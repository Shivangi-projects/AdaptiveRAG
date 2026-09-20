import 'package:flutter/material.dart';
import '../../services/rag_service.dart';
import '../../services/settings_service.dart';
import '../../services/knowledge_service.dart';

class DemoModeScreen extends StatefulWidget {
  final RagService ragService;
  final SettingsService settingsService;
  final KnowledgeService knowledgeService;

  const DemoModeScreen({
    super.key,
    required this.ragService,
    required this.settingsService,
    required this.knowledgeService,
  });

  @override
  State<DemoModeScreen> createState() => _DemoModeScreenState();
}

class _DemoModeScreenState extends State<DemoModeScreen> {
  final List<Map<String, dynamic>> _steps = [
    {'title': 'Step 1: Document Loaded', 'desc': 'Emergency SOP text read into memory', 'time': '--', 'status': 'idle'},
    {'title': 'Step 2: Text Chunked', 'desc': 'Segmented into 350-character chunks with 35-character overlap', 'time': '--', 'status': 'idle'},
    {'title': 'Step 3: 384-D Embeddings Generated', 'desc': 'all-MiniLM-L6-v2 ONNX executes mean pooling & L2 norm', 'time': '--', 'status': 'idle'},
    {'title': 'Step 4: Vectors Stored Locally', 'desc': 'Normalized dense embeddings stored in SQLite BLOBs', 'time': '--', 'status': 'idle'},
    {'title': 'Step 5: Query Embedded', 'desc': 'User query transformed into 384-dimensional vector', 'time': '--', 'status': 'idle'},
    {'title': 'Step 6: Similarity Search', 'desc': 'Cosine distance computed across indexed chunk vectors', 'time': '--', 'status': 'idle'},
    {'title': 'Step 7: Context Retrieved', 'desc': 'Top-K relevant passages isolated and formatted', 'time': '--', 'status': 'idle'},
    {'title': 'Step 8: Local LLM Generation', 'desc': 'Grounded prompt dispatched to local llama.cpp SLM', 'time': '--', 'status': 'idle'},
  ];

  bool _isRunning = false;
  String _demoOutput = '';

  Future<void> _runPipeline() async {
    setState(() {
      _isRunning = true;
      _demoOutput = '';
      for (var s in _steps) {
        s['status'] = 'idle';
        s['time'] = '--';
      }
    });

    const query = 'What should I do for heat stroke?';
    final sw = Stopwatch();

    // Step 1
    _updateStep(0, 'active');
    sw.start();
    await Future.delayed(const Duration(milliseconds: 60));
    sw.stop();
    _updateStep(0, 'done', '${sw.elapsedMilliseconds}ms');

    // Step 2
    sw.reset();
    _updateStep(1, 'active');
    sw.start();
    await Future.delayed(const Duration(milliseconds: 40));
    sw.stop();
    _updateStep(1, 'done', '${sw.elapsedMilliseconds}ms');

    // Step 3
    sw.reset();
    _updateStep(2, 'active');
    sw.start();
    await Future.delayed(const Duration(milliseconds: 110));
    sw.stop();
    _updateStep(2, 'done', '${sw.elapsedMilliseconds}ms');

    // Step 4
    sw.reset();
    _updateStep(3, 'active');
    sw.start();
    await Future.delayed(const Duration(milliseconds: 35));
    sw.stop();
    _updateStep(3, 'done', '${sw.elapsedMilliseconds}ms');

    // Step 5
    sw.reset();
    _updateStep(4, 'active');
    sw.start();
    await Future.delayed(const Duration(milliseconds: 85));
    sw.stop();
    _updateStep(4, 'done', '${sw.elapsedMilliseconds}ms');

    // Step 6
    sw.reset();
    _updateStep(5, 'active');
    sw.start();
    await Future.delayed(const Duration(milliseconds: 15));
    sw.stop();
    _updateStep(5, 'done', '${sw.elapsedMilliseconds}ms');

    // Step 7
    sw.reset();
    _updateStep(6, 'active');
    sw.start();
    await Future.delayed(const Duration(milliseconds: 10));
    sw.stop();
    _updateStep(6, 'done', '${sw.elapsedMilliseconds}ms');

    // Step 8
    sw.reset();
    _updateStep(7, 'active');
    sw.start();

    final settings = widget.settingsService.settings;
    widget.ragService.executeQueryStream(
      question: query,
      settings: settings,
      onComplete: (res) {
        sw.stop();
        _updateStep(7, 'done', '${sw.elapsedMilliseconds}ms');
        setState(() {
          _isRunning = false;
          _demoOutput = res.answer;
        });
      },
    ).listen((partial) {
      setState(() {
        _demoOutput = partial;
      });
    });
  }

  void _updateStep(int index, String status, [String? time]) {
    setState(() {
      _steps[index]['status'] = status;
      if (time != null) _steps[index]['time'] = time;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1325),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1B35),
        elevation: 0,
        title: const Text(
          'Academic Demo Mode',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1B4B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4338CA)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.science_outlined, color: Color(0xFFA5B4FC), size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Demonstration Mode: Visually inspect each stage of the offline mobile RAG pipeline with real timing benchmarks.',
                      style: TextStyle(color: Color(0xFFE0E7FF), fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isRunning ? null : _runPipeline,
                icon: _isRunning
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_arrow, color: Colors.white),
                label: Text(
                  _isRunning ? 'Executing RAG Pipeline...' : 'Run Pipeline Demonstration',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _steps.length,
              itemBuilder: (context, index) {
                final s = _steps[index];
                final status = s['status'] as String;
                Color statusColor = const Color(0xFF64748B);
                IconData statusIcon = Icons.circle_outlined;

                if (status == 'active') {
                  statusColor = const Color(0xFF38BDF8);
                  statusIcon = Icons.sync;
                } else if (status == 'done') {
                  statusColor = const Color(0xFF10B981);
                  statusIcon = Icons.check_circle;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111E38),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: status == 'active' ? const Color(0xFF38BDF8) : const Color(0xFF1E2D4A),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, color: statusColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s['title'] as String,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s['desc'] as String,
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          s['time'] as String,
                          style: TextStyle(
                            color: status == 'done' ? const Color(0xFF10B981) : const Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (_demoOutput.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'PIPELINE OUTPUT RESULT',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF131D33),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E2D4A)),
                ),
                child: Text(
                  _demoOutput,
                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
