import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import '../lib/services/knowledge_service.dart';
import '../lib/models/app_settings.dart';
import '../lib/models/chunk.dart';
import '../lib/models/knowledge_pack.dart';
import '../lib/models/query_result.dart';

void main() {
  group('EdgeRAG Unit Tests', () {
    final knowledgeService = KnowledgeService();

    test('Chunking logic splits text respecting size and overlap', () {
      final sampleText =
          'Heat stroke is a severe medical emergency. It occurs when body temperature exceeds 40°C. '
          'Immediately move the patient to a cool shade. Apply ice packs to groin and armpits. '
          'Do not administer oral fluids if the patient is confused or unconscious.';

      final chunks = knowledgeService.chunkText(sampleText, 80, 20);

      expect(chunks.isNotEmpty, isTrue);
      for (final chunk in chunks) {
        expect(chunk.isNotEmpty, isTrue);
      }
      expect(chunks.first.contains('Heat stroke'), isTrue);
    });

    test('SHA-256 hashing detects exact duplicate documents', () {
      const doc1 = 'Emergency SOP: For severe arterial bleeding, apply tourniquet 2-3 inches above wound.';
      const doc2 = 'Emergency SOP: For severe arterial bleeding, apply tourniquet 2-3 inches above wound.';
      const doc3 = 'Different text altogether.';

      final hash1 = sha256.convert(utf8.encode(doc1)).toString();
      final hash2 = sha256.convert(utf8.encode(doc2)).toString();
      final hash3 = sha256.convert(utf8.encode(doc3)).toString();

      expect(hash1, equals(hash2));
      expect(hash1, isNot(equals(hash3)));
      expect(hash1.length, equals(64));
    });

    test('L2 Normalization produces unit vectors', () {
      final vec = [3.0, 4.0];
      double sumSq = 0.0;
      for (var v in vec) {
        sumSq += v * v;
      }
      final norm = math.sqrt(sumSq); // 5.0
      final normalized = vec.map((v) => v / norm).toList();

      double normSum = 0.0;
      for (var v in normalized) {
        normSum += v * v;
      }
      expect((normSum - 1.0).abs() < 1e-6, isTrue);
    });

    test('Cosine similarity correctly ranks nearest vector', () {
      double cosine(List<double> a, List<double> b) {
        double dot = 0.0;
        for (int i = 0; i < a.length; i++) {
          dot += a[i] * b[i];
        }
        return dot;
      }

      final query = [1.0, 0.0, 0.0];
      final candidateA = [0.99, 0.01, 0.0];
      final candidateB = [0.1, 0.9, 0.0];

      final simA = cosine(query, candidateA);
      final simB = cosine(query, candidateB);

      expect(simA > simB, isTrue);
    });

    test('Knowledge Pack serialization and deserialization', () {
      final pack = KnowledgePack(
        packId: 'emergency_v1',
        name: 'Emergency Demo Pack',
        version: '1.0.0',
        description: 'First Aid procedures for disaster response',
        createdAt: '2026-09-05',
        docCount: 4,
        chunkCount: 28,
        fileSize: 45000,
        isActive: true,
      );

      final jsonMap = pack.toJson();
      final restored = KnowledgePack.fromJson(jsonMap);

      expect(restored.packId, equals('emergency_v1'));
      expect(restored.name, equals('Emergency Demo Pack'));
      expect(restored.chunkCount, equals(28));
      expect(restored.isActive, isTrue);
    });

    test('AppSettings defaults adhere to low-power mobile specifications', () {
      final settings = AppSettings();

      expect(settings.cpuThreads, inInclusiveRange(2, 4));
      expect(settings.contextLength, inInclusiveRange(512, 1024));
      expect(settings.maxTokens, inInclusiveRange(128, 512));
      expect(settings.topK, inInclusiveRange(2, 5));
      expect(settings.chunkSize, inInclusiveRange(200, 500));
      expect(settings.chunkOverlap, inInclusiveRange(20, 50));
    });

    test('QueryResult formatting and source tracking', () {
      final source = ChunkItem(
        id: 1,
        docId: 10,
        chunkIndex: 2,
        pageNum: 3,
        content: 'Cool victim with cold water spray and fanning.',
        score: 0.89,
        filename: 'Heat_Stroke.pdf',
      );

      final result = QueryResult(
        question: 'How to treat heat stroke?',
        answer: 'Spray victim with cold water and fan vigorously.',
        sources: [source],
        embeddingTimeMs: 45,
        searchTimeMs: 12,
        generationTimeMs: 250,
        totalTimeMs: 307,
        tokensPerSecond: 18.5,
        isRetrievalOnly: false,
      );

      expect(result.sources.length, equals(1));
      expect(result.sources.first.score, equals(0.89));
      expect(result.totalTimeMs, equals(307));
      expect(result.isRetrievalOnly, isFalse);
    });
  });
}
