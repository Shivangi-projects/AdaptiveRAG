import 'package:flutter/material.dart';
import '../../services/model_downloader_service.dart';

class ModelInfo {
  final String name;
  final String size;
  final String url;
  final String fileName;

  ModelInfo({
    required this.name,
    required this.size,
    required this.url,
    required this.fileName,
  });
}

class ModelHubScreen extends StatefulWidget {
  final Function(String path) onModelActivated;

  const ModelHubScreen({super.key, required this.onModelActivated});

  @override
  State<ModelHubScreen> createState() => _ModelHubScreenState();
}

class _ModelHubScreenState extends State<ModelHubScreen> {
  final ModelDownloaderService _downloader = ModelDownloaderService();

  final List<ModelInfo> _models = [
    ModelInfo(
      name: 'Qwen 2.5 0.5B Instruct (Ultra Light)',
      size: '390 MB',
      url: 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
      fileName: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
    ),
    ModelInfo(
      name: 'Llama 3.2 1B Instruct (Recommended)',
      size: '800 MB',
      url: 'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
      fileName: 'Llama-3.2-1B-Instruct-Q4_K_M.gguf',
    ),
  ];

  Map<String, double> _downloadProgress = {};
  Map<String, bool> _downloadedState = {};

  @override
  void initState() {
    super.initState();
    _checkDownloadedModels();
  }

  Future<void> _checkDownloadedModels() async {
    for (var model in _models) {
      bool exists = await _downloader.isModelDownloaded(model.fileName);
      setState(() {
        _downloadedState[model.fileName] = exists;
      });
    }
  }

  Future<void> _startDownload(ModelInfo model) async {
    setState(() {
      _downloadProgress[model.fileName] = 0.001;
    });

    try {
      final file = await _downloader.downloadModel(
        url: model.url,
        fileName: model.fileName,
        onProgress: (received, total) {
  print('Received: $received  Total: $total');

  if (total > 0) {
    setState(() {
      _downloadProgress[model.fileName] = received / total;
    });
  }
},
      );

      setState(() {
        _downloadedState[model.fileName] = true;
        _downloadProgress.remove(model.fileName);
      });

      widget.onModelActivated(file.path);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${model.name} downloaded & activated!')),
      );
    } catch (e) {
      setState(() {
        _downloadProgress.remove(model.fileName);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download model: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Local Model Hub')),
      body: ListView.builder(
        itemCount: _models.length,
        itemBuilder: (context, index) {
          final model = _models[index];
          final isDownloaded = _downloadedState[model.fileName] ?? false;
          final progress = _downloadProgress[model.fileName];

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(model.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Size: ${model.size}'),
                  if (progress != null) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress),
                    Text(
  '${(progress * 100).toStringAsFixed(1)}% downloaded',
  style: const TextStyle(fontWeight: FontWeight.w500),
),
                  ],
                ],
              ),
              trailing: isDownloaded
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : progress != null
    ? SizedBox(
        width: 50,
        height: 50,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 4,
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      )
    : ElevatedButton(
        onPressed: () => _startDownload(model),
        child: const Text('Download'),
      ),
            ),
          );
        },
      ),
    );
  }
}