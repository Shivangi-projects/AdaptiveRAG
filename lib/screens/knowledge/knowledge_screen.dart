import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/document.dart';
import '../../services/knowledge_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/status_badge.dart';

class KnowledgeScreen extends StatefulWidget {
  final KnowledgeService knowledgeService;
  final SettingsService settingsService;

  const KnowledgeScreen({
    super.key,
    required this.knowledgeService,
    required this.settingsService,
  });

  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isImporting = false;
  double _importProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    widget.knowledgeService.refreshDocuments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickAndImportDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'pdf'],
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final path = file.path;
      if (path == null) return;

      final ioFile = File(path);
      final bytes = await ioFile.readAsBytes();
      final hash = widget.knowledgeService.computeHash(bytes);

      if (widget.knowledgeService.isDuplicate(hash)) {
        if (!mounted) return;
        _showDuplicateDialog(file.name, ioFile);
        return;
      }

      await _processImport(file.name, ioFile);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _processImport(String filename, File file) async {
    setState(() {
      _isImporting = true;
      _importProgress = 0.0;
    });

    try {
      String content = '';
      if (filename.toLowerCase().endsWith('.txt')) {
        content = await file.readAsString();
      } else {
        // PDF text extraction or byte text parsing
        final bytes = await file.readAsBytes();
        content = String.fromCharCodes(bytes.where((b) => b >= 32 && b <= 126));
      }

      final settings = widget.settingsService.settings;
      final success = await widget.knowledgeService.importTextFile(
        filename: filename,
        content: content,
        chunkSize: settings.chunkSize,
        chunkOverlap: settings.chunkOverlap,
        onProgress: (p) => setState(() => _importProgress = p),
      );

      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Indexed $filename successfully!' : 'Failed to index document.'),
            backgroundColor: success ? const Color(0xFF10B981) : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDuplicateDialog(String filename, File file) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111E38),
        title: const Text('Duplicate Document', style: TextStyle(color: Colors.white)),
        content: Text(
          'This document ($filename) is already indexed with the same SHA-256 hash.',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () {
              Navigator.pop(ctx);
              _processImport(filename, file);
            },
            child: const Text('Re-index'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(DocumentItem doc) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111E38),
        title: const Text('Confirm Deletion', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to remove "${doc.filename}" and all its vector chunks from the database?',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.knowledgeService.deleteDocument(doc.id);
              setState(() {});
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = widget.knowledgeService.documents;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1325),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1B35),
        elevation: 0,
        title: const Text(
          'Knowledge Hub',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          tabs: const [
            Tab(text: 'Indexed Documents'),
            Tab(text: 'Knowledge Packs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Documents tab
          Column(
            children: [
              if (_isImporting)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFF1E3A8A),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chunking & Generating Embeddings... ${(_importProgress * 100).toInt()}%',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: _importProgress,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation(Color(0xFF38BDF8)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${docs.length} Documents Indexed',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isImporting ? null : _pickAndImportDocument,
                      icon: const Icon(Icons.add, size: 18, color: Colors.white),
                      label: const Text('Add Document', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: docs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.folder_open_outlined, size: 48, color: Color(0xFF475569)),
                            SizedBox(height: 12),
                            Text(
                              'No documents indexed yet',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Import a PDF/TXT or activate a Knowledge Pack',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          return Card(
                            color: const Color(0xFF111E38),
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFF1E2D4A)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF38BDF8).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.description, color: Color(0xFF38BDF8), size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              doc.filename,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${doc.formattedSize} • ${doc.dateAdded}',
                                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, color: Color(0xFF94A3B8)),
                                        color: const Color(0xFF1E293B),
                                        onSelected: (val) {
                                          if (val == 'delete') _confirmDelete(doc);
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Remove Document', style: TextStyle(color: Colors.redAccent)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      _buildBadge('Pages: ${doc.pageCount}'),
                                      const SizedBox(width: 8),
                                      _buildBadge('Chunks: ${doc.chunkCount}'),
                                      const SizedBox(width: 8),
                                      _buildBadge('SHA-256: ${doc.fileHash.substring(0, 8)}...'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),

          // Knowledge Packs tab
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'Emergency Demo Pack',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          StatusBadge(label: 'ACTIVE'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Pre-indexed SOPs for heat stroke, burns, severe bleeding, and adult CPR.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildBadge('4 Documents'),
                          const SizedBox(width: 8),
                          _buildBadge('28 Chunks'),
                          const SizedBox(width: 8),
                          _buildBadge('MiniLM-L6-v2'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'PORTABLE KNOWLEDGE PACKS (.edgepack)',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Knowledge packs contain pre-indexed domain databases that can be opened instantly on low-power devices without re-embedding.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
    );
  }
}
