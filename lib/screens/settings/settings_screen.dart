import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/settings_service.dart';
import '../../services/model_service.dart';
import 'model_hub_screen.dart'; // Imports the Model Hub built in Step 3

class SettingsScreen extends StatefulWidget {
  final SettingsService settingsService;
  final ModelService modelService;

  const SettingsScreen({
    super.key,
    required this.settingsService,
    required this.modelService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;
  String _testResult = '';

  Future<void> _pickGgufModel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gguf', 'bin'],
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final path = file.path;
      if (path == null) return;

      final s = widget.settingsService.settings;
      final updated = s.copyWith(
        ggufModelPath: path,
        ggufModelName: file.name,
      );
      await widget.settingsService.saveSettings(updated);
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting model: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _loadModel() async {
  final s = widget.settingsService.settings;
  if (s.ggufModelPath.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select a GGUF model file first.')),
    );
    return;
  }

  setState(() => _isLoading = true);
  
  debugPrint("===== LOADING MODEL =====");
debugPrint("Path: ${s.ggufModelPath}");
debugPrint("Context Length: ${s.contextLength}");
debugPrint("CPU Threads: ${s.cpuThreads}");

debugPrint(
  "UI MODEL INSTANCE = ${identityHashCode(widget.modelService)}"
);

final success = await widget.modelService.loadModel(
  modelPath: s.ggufModelPath,
  contextLength: s.contextLength,
  cpuThreads: s.cpuThreads,
);

debugPrint("LOAD RESULT = $success");
debugPrint("MODEL READY = ${widget.modelService.isReady}");
debugPrint("MODEL ERROR = ${widget.modelService.errorMessage}");
  
  // Call setState HERE to trigger a re-build so `isReady` updates from false -> true
  if (mounted) {
    setState(() => _isLoading = false);
  }

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Model loaded successfully!' : 'Failed to load model: ${widget.modelService.errorMessage}'),
        backgroundColor: success ? const Color(0xFF10B981) : Colors.red,
      ),
    );
  }
}

  Future<void> _unloadModel() async {
    await widget.modelService.unloadModel();
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model unloaded. Reverted to Retrieval-Only mode.')),
      );
    }
  }

  Future<void> _testModel() async {
  if (!widget.modelService.isReady) {
    setState(() {
      _testResult = 'Error: Model is not loaded into memory.';
    });
    return;
  }

  setState(() {
    _isLoading = true;
    _testResult = 'Running test inference...';
  });

  try {
    final res = await widget.modelService.testModel();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _testResult = res.isNotEmpty ? res : 'No output generated from model.';
      });
    }
  } catch (e, stackTrace) {
    debugPrint('Model test exception: $e\n$stackTrace');
    if (mounted) {
      setState(() {
        _isLoading = false;
        _testResult = 'Inference Failed: $e';
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final s = widget.settingsService.settings;
    final isLoaded = widget.modelService.isReady;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1325),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1B35),
        elevation: 0,
        title: const Text(
          'Settings & AI Models',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Models Card
            _buildSectionHeader('AI MODELS MANAGEMENT'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111E38),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E2D4A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Embedding Engine', 'sentence-transformers/all-MiniLM-L6-v2 (384-D)'),
                  const Divider(color: Color(0xFF1E2D4A), height: 16),
                  _infoRow('Language Model', s.ggufModelName),
                  if (s.ggufModelPath.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      s.ggufModelPath,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _infoRow('Status', isLoaded ? '🟢 Loaded & Active' : '⚪ Not Loaded (Retrieval-Only)'),
                  const SizedBox(height: 16),
                  
                  // Model Hub Navigation Tile
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.cloud_download, color: Color(0xFF38BDF8)),
                      title: const Text(
                        'Download Online Models',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Get curated GGUF models directly in-app',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ModelHubScreen(
                              onModelActivated: (modelPath) async {
                                final fileName = modelPath.split('/').last;
                                final updated = s.copyWith(
                                  ggufModelPath: modelPath,
                                  ggufModelName: fileName,
                                );
                                await widget.settingsService.saveSettings(updated);
                                setState(() {});
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(color: Color(0xFF1E2D4A), height: 16),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                        onPressed: _pickGgufModel,
                        icon: const Icon(Icons.file_open, size: 16, color: Colors.white),
                        label: const Text('Select Local File', style: TextStyle(color: Colors.white)),
                      ),
                      if (!isLoaded)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                          onPressed: _isLoading ? null : _loadModel,
                          icon: const Icon(Icons.play_arrow, size: 16, color: Colors.white),
                          label: const Text('Load Model', style: TextStyle(color: Colors.white)),
                        )
                      else
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                          onPressed: _unloadModel,
                          icon: const Icon(Icons.stop, size: 16, color: Colors.white),
                          label: const Text('Unload Model', style: TextStyle(color: Colors.white)),
                        ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF38BDF8))),
                        onPressed: (_isLoading || !isLoaded) ? null : _testModel,
                        icon: const Icon(Icons.quiz_outlined, size: 16, color: Color(0xFF38BDF8)),
                        label: const Text('Test Model', style: TextStyle(color: Color(0xFF38BDF8))),
                      ),
                    ],
                  ),
                  if (_testResult.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1325),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _testResult,
                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Inference Parameters
            _buildSectionHeader('INFERENCE PARAMETERS'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111E38),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E2D4A)),
              ),
              child: Column(
                children: [
                  _buildSlider(
                    label: 'CPU Threads: ${s.cpuThreads}',
                    value: s.cpuThreads.toDouble(),
                    min: 1,
                    max: 8,
                    divisions: 7,
                    onChanged: (v) => widget.settingsService.saveSettings(s.copyWith(cpuThreads: v.toInt())),
                  ),
                  _buildSlider(
                    label: 'Top-K Retrieval: ${s.topK}',
                    value: s.topK.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    onChanged: (v) => widget.settingsService.saveSettings(s.copyWith(topK: v.toInt())),
                  ),
                  _buildSlider(
                    label: 'Context Length: ${s.contextLength}',
                    value: s.contextLength.toDouble(),
                    min: 512,
                    max: 2048,
                    divisions: 3,
                    onChanged: (v) => widget.settingsService.saveSettings(s.copyWith(contextLength: v.toInt())),
                  ),
                  _buildSlider(
                    label: 'Max Generation Tokens: ${s.maxTokens}',
                    value: s.maxTokens.toDouble(),
                    min: 64,
                    max: 512,
                    divisions: 7,
                    onChanged: (v) => widget.settingsService.saveSettings(s.copyWith(maxTokens: v.toInt())),
                  ),
                  _buildSlider(
                    label: 'Temperature: ${s.temperature.toStringAsFixed(2)}',
                    value: s.temperature,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    onChanged: (v) => widget.settingsService.saveSettings(s.copyWith(temperature: v)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Chunking Configuration
            _buildSectionHeader('CHUNKING PARAMETERS'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111E38),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E2D4A)),
              ),
              child: Column(
                children: [
                  _buildSlider(
                    label: 'Chunk Size: ${s.chunkSize} chars',
                    value: s.chunkSize.toDouble(),
                    min: 150,
                    max: 800,
                    divisions: 13,
                    onChanged: (v) => widget.settingsService.saveSettings(s.copyWith(chunkSize: v.toInt())),
                  ),
                  _buildSlider(
                    label: 'Chunk Overlap: ${s.chunkOverlap} chars',
                    value: s.chunkOverlap.toDouble(),
                    min: 10,
                    max: 100,
                    divisions: 9,
                    onChanged: (v) => widget.settingsService.saveSettings(s.copyWith(chunkOverlap: v.toInt())),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Privacy Manifesto
            _buildSectionHeader('PRIVACY & SECURITY'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1E36),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E3A8A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Your Documents Stay On Your Device',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'EdgeRAG processes documents, embeddings, vector searches, and AI generation locally. '
                    'No document content, search queries, or user responses are transmitted to any cloud service. '
                    'Full functionality is maintained in airplane mode.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 2,
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
          ),
        ),
      ),
      Expanded(
        flex: 3,
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: const Color(0xFF38BDF8),
          inactiveColor: const Color(0xFF1E2D4A),
          onChanged: (v) {
            onChanged(v);
            setState(() {});
          },
        ),
      ],
    );
  }
}