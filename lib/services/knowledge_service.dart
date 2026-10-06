import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/document.dart';
import '../models/knowledge_pack.dart';
import 'native_bridge.dart';
import 'dart:math' as math;

class KnowledgeService {
  final NativeBridge _bridge = NativeBridge();

  List<DocumentItem> _documents = [];
  List<KnowledgePack> _packs = [];
  KnowledgePack? _activePack;

  List<DocumentItem> get documents => _documents;
  List<KnowledgePack> get packs => _packs;
  KnowledgePack? get activePack => _activePack;

  Future<void> refreshDocuments() async {
  _documents = _bridge.listDocuments();

  print("========== DOCUMENTS IN DB ==========");

  for (final doc in _documents) {
    
    print(
      "ID=${doc.id} FILE=${doc.filename} PAGES=${doc.pageCount}"
    );
  }

  print("TOTAL DOCS = ${_documents.length}");
}

  // SHA-256 duplicate check
  String computeHash(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }

  bool isDuplicate(String hash) {
    return _bridge.checkDuplicate(hash);
  }

  // Text chunker with overlap
  List<String> chunkText(String text, int chunkSize, int chunkOverlap) {
    final List<String> chunks = [];
    if (text.isEmpty) return chunks;

    // Clean text whitespace
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= chunkSize) {
      chunks.add(cleaned);
      return chunks;
    }

    int start = 0;
    while (start < cleaned.length) {
      int end = start + chunkSize;
      if (end >= cleaned.length) {
        chunks.add(cleaned.substring(start).trim());
        break;
      }

      // Try to break at sentence or word boundary
      int breakIndex = cleaned.lastIndexOf(RegExp(r'[.!?\n]'), end);
      if (breakIndex > start + (chunkSize / 2)) {
        end = breakIndex + 1;
      } else {
        int spaceIndex = cleaned.lastIndexOf(' ', end);
        if (spaceIndex > start + (chunkSize / 2)) {
          end = spaceIndex;
        }
      }

      chunks.add(cleaned.substring(start, end).trim());
      start = end - chunkOverlap;
      if (start < 0) start = 0;
    }

    return chunks;
  }

  // Import TXT document
  Future<bool> importTextFile({
    required String filename,
    required String content,
    required int chunkSize,
    required int chunkOverlap,
    Function(double progress)? onProgress,
  }) async {
    final bytes = utf8.encode(content);
    final hash = computeHash(bytes);

    if (_bridge.checkDuplicate(hash)) {
      return false; // Duplicate
    }

    final dateStr = DateTime.now().toIso8601String().substring(0, 10);
    final docId = _bridge.addDocument(filename, hash, 'txt', 1, bytes.length, dateStr);
    if (docId <= 0) return false;

    final chunks = chunkText(content, chunkSize, chunkOverlap);
    print("FILE = $filename");
print("TOTAL CHUNKS = ${chunks.length}");
if (filename.contains("Heat_Stroke")) {
  print("================================");
  print("HEAT STROKE IMPORT STARTED");
  print("CHUNKS CREATED = ${chunks.length}");
  print("================================");
}
for (int i = 0; i < math.min(5, chunks.length) ;i++) {
  print(chunks[i]);
}
    for (int i = 0; i < chunks.length; i++) {
      final chunkText = chunks[i];
      final embedding = _bridge.embedText(chunkText);
      if (chunkText.toLowerCase().contains("aed") ||
    chunkText.toLowerCase().contains("defibrillator"))
{
  print("AED CHUNK FOUND");
  print(chunkText);
  print("EMBED LEN = ${embedding?.length}");
}
      if (i == 0 && embedding != null) {
  print("FIRST CHUNK EMBEDDING:");
  print(embedding.take(20).toList());
}
if (embedding != null) {
  print("EMBED LEN = ${embedding.length}");

  print(
    "FIRST 10 = "
    "${embedding.take(10).toList()}"
  );
}
      if (filename.contains("Heat_Stroke")) {
  print("========== HEAT STROKE CHUNK ==========");
  print(chunkText.substring(
      0,
      chunkText.length > 100 ? 100 : chunkText.length));

  print("EMBED NULL = ${embedding == null}");

  if (embedding != null) {
    print("EMBED LEN = ${embedding.length}");
    print("EMBED SAMPLE = ${embedding.take(5).toList()}");
  }
  print(chunkText);
  print("EMBED NULL = ${embedding == null}");
  print("EMBED LEN = ${embedding?.length}");
}
      if (i == 0 && embedding != null) {
  double norm = 0;
  for (final v in embedding) {
    norm += v * v;
  }
  print("EMBED NORM = ${math.sqrt(norm)}");
  print("EMBED SIZE = ${embedding.length}");
}
print("ADDING CHUNK $i");
if (chunkText.toLowerCase().contains("burn")) {
  print("FOUND BURN CHUNK");
  print(chunkText);
}
      _bridge.addChunk(docId, i, 1, chunkText, embedding);

      if (onProgress != null) {
        onProgress((i + 1) / chunks.length);
      }
    }

    await refreshDocuments();
    return true;
  }

  // Delete document
  Future<bool> deleteDocument(int docId) async {
    final res = _bridge.deleteDocument(docId);
    if (res) {
      await refreshDocuments();
    }
    return res;
  }

  // Load sample Emergency Demo Pack from assets safely
  Future<bool> loadSamplePack() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final sampleDir = Directory('${appDir.path}/packs');
      if (!await sampleDir.exists()) {
        await sampleDir.create(recursive: true);
      }

      final targetDbPath = '${sampleDir.path}/emergency_demo_knowledge.db';
      final packFile = '${sampleDir.path}/emergency_demo.edgepack';

      // Check if emergency_demo.edgepack exists in assets
      try {
        final data = await rootBundle.load('assets/sample/emergency_demo.edgepack');
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        final file = File(packFile);
        await file.writeAsBytes(bytes, flush: true);

        // Extract ZIP
        final archive = ZipDecoder().decodeBytes(bytes);
        for (final file in archive) {
          if (file.isFile) {
            final outFile = File('${sampleDir.path}/${file.name}');
            await outFile.create(recursive: true);
            final content = file.content as List<int>;
            await outFile.writeAsBytes(content, flush: true);
          }
        }
      } catch (e) {
        debugPrint('Sample pack extraction bypass: $e');
      }

      if (await File(targetDbPath).exists()) {
        _bridge.importPackDb(targetDbPath);
        await refreshDocuments();

print("AFTER IMPORT:");
print("DOC COUNT = ${_documents.length}");

// final stats = _bridge.getDbStats();
// print("DB STATS AFTER IMPORT = $stats");
      }

      _activePack = KnowledgePack(
        packId: 'emergency_demo_v1',
        name: 'Emergency Demo Pack',
        version: '1.0.0',
        description: 'First aid and emergency SOPs (heat stroke, burns, CPR, bleeding)',
        createdAt: '2026-09-05',
        docCount: 4,
        chunkCount: 28,
        isActive: true,
      );

      await refreshDocuments();
      return true;
    } catch (e) {
      debugPrint('Load sample pack error: $e');
      return false;
    }
  }

  // Export active knowledge base to .edgepack
  Future<String?> exportActivePack(String packName, String description) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${appDir.path}/exports');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempDb = '${exportDir.path}/knowledge_$timestamp.db';
      final packFile = '${exportDir.path}/${packName.replaceAll(' ', '_')}.edgepack';

      final success = _bridge.exportPackDb(tempDb);
      if (!success) return null;

      final meta = {
        'pack_id': 'pack_$timestamp',
        'name': packName,
        'version': '1.0.0',
        'description': description,
        'created_at': DateTime.now().toIso8601String(),
        'embedding_model': 'all-MiniLM-L6-v2',
        'embedding_dim': 384,
      };

      final archive = Archive();
      final metaBytes = utf8.encode(jsonEncode(meta));
      archive.addFile(ArchiveFile('metadata.json', metaBytes.length, metaBytes));

      final dbBytes = await File(tempDb).readAsBytes();
      archive.addFile(ArchiveFile('knowledge.db', dbBytes.length, dbBytes));

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes != null) {
        await File(packFile).writeAsBytes(zipBytes, flush: true);
        final tempDbFile = File(tempDb);
        if (await tempDbFile.exists()) {
          await tempDbFile.delete();
        }
        return packFile;
      }
      return null;
    } catch (e) {
      debugPrint('Export active pack error: $e');
      return null;
    }
  }
}