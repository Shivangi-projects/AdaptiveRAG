import 'dart:math';
import 'dart:async';
import '../models/query_result.dart';
import '../models/app_settings.dart';
import 'native_bridge.dart';
import 'model_service.dart';
import 'benchmark_service.dart';

class RagService {
  final NativeBridge _bridge = NativeBridge();
  final ModelService _modelService;
  final BenchmarkService _benchmarkService;

  RagService(this._modelService, this._benchmarkService);

  bool _isCancelled = false;

  void stopGeneration() {
    _isCancelled = true;
  }

  Stream<String> executeQueryStream({
    required String question,
    required AppSettings settings,
    required Function(QueryResult result) onComplete,
  }) async* {
    _isCancelled = false;
    final totalSw = Stopwatch()..start();

    // 1. Embed query locally with safety guard
    final embedSw = Stopwatch()..start();
    List<double>? queryVector;
    
    try {
      print("EMBEDDER AVAILABLE = ${_bridge.isAvailable}");
      print("ABOUT TO EMBED QUESTION");
print(question);
      queryVector = _bridge.embedText(question);
      print("========== QUERY VECTOR ==========");

print("QUESTION = $question");

print("LENGTH = ${queryVector?.length}");

if (queryVector != null) {
  print(queryVector.take(10).toList());

  double norm = 0;

  for (final v in queryVector) {
    norm += v * v;
  }

  print("NORM = $norm");
}

print("==================================");

print("EMBED RESULT NULL = ${queryVector == null}");
      if (queryVector != null) {
        print("================================");
  print("QUESTION = $question");
  print("EMBEDDING LENGTH = ${queryVector.length}");
  print("VECTOR SAMPLE:");
  print(queryVector.take(10).toList());
  print("================================");
  final norm = queryVector.fold(
      0.0,
      (sum, v) => sum + v * v);

  print("VECTOR NORM = ${norm}");
}

if (queryVector != null) {
  print("QUESTION = $question");
  print("EMBEDDING LENGTH = ${queryVector.length}");
  print("FIRST 20 VALUES:");
  print(queryVector.take(20).toList());
}
      print("FIRST 20 VALUES:");
print(queryVector?.take(20).toList());
    } catch (e) {
      print('DEBUG: Native embedding crashed: $e');
    }
    embedSw.stop();

    if (queryVector == null || queryVector.isEmpty) {
      const errMsg = 'Error: Failed to generate query embedding locally.';
      yield errMsg;
      onComplete(QueryResult(
        question: question,
        answer: errMsg,
        sources: [],
        totalTimeMs: totalSw.elapsedMilliseconds,
      ));
      return;
    }

    // 2. Search local vector storage with safety guard
    final searchSw = Stopwatch()..start();
    List<dynamic> rawSources = [];
    
    try {
      print('DEBUG: Requested topK = ${settings.topK}');
print("DB STATS = ${_bridge.getStats()}");
print("QUESTION = $question");
print("EMBEDDING DIM = ${queryVector.length}");
final docs = _bridge.listDocuments();

print("========== DOCUMENTS IN DB ==========");

for (final d in docs) {
  print("DOC = ${d.filename}");
}

print("====================================");
print("====================================");
print("SETTINGS.TOPK = ${settings.topK}");
print("QUERY = $question");
print("====================================");
      rawSources = _bridge.search(queryVector, settings.topK);
      print("========== QUERY TEST ==========");
print("QUESTION = $question");

for (final s in rawSources) {
  print("FILE=${s.filename}");
  print("PAGE=${s.pageNum}");
  print("SCORE=${s.score}");
  print("TEXT=${s.content}");
  print("--------------------------------");
}
      print("RAW SOURCE COUNT = ${rawSources.length}");

for (final s in rawSources) {
  print(
      "RAW -> FILE=${s.filename} PAGE=${s.pageNum} SCORE=${s.score}");
}
      print('DEBUG: rawSources count = ${rawSources.length}');
      
      for (var s in rawSources) {
    print("=================================");
    print("FILE: ${s.filename}");
    print("PAGE: ${s.pageNum}");
    print("SCORE: ${s.score}");

    final preview = s.content.length > 200
        ? s.content.substring(0, 200)
        : s.content;

    print("TEXT: $preview");
    print("=================================");
  }
    } catch (e) {
      print('DEBUG: Native vector search crashed: $e');
    }

    // CUTOFF THRESHOLD: Filter out low-similarity noise (< 10% or 0.10)
    const double minSimilarityThreshold = 0.40;
const double dynamicThreshold = 0.30;
final sources = rawSources;
print("RAW COUNT = ${rawSources.length}");

for(final s in rawSources){
  if(s.content.toLowerCase().contains(question.toLowerCase())) {
   print("KEYWORD MATCH FOUND");
}
  print("RAW SCORE = ${s.score}");
}
for(final s in rawSources){
  print(
    "CHECKING -> score=${s.score} "
    "contains=${s.content.toLowerCase().contains(question.toLowerCase())}"
  );
}
print("FILTERED COUNT = ${sources.length}");

for(final s in sources){
  print("FILTERED SCORE = ${s.score}");
}
if (sources.isNotEmpty) {
  print("BEST SCORE = ${sources.first.score}");
}
const minScore = 0.10;

print(
  "BEST SCORE=${sources.first.score} "
  "MIN REQUIRED=$minScore"
);

if (sources.isNotEmpty &&
    sources.first.score < minScore) {
  print("TOP SCORE TOO LOW = ${sources.first.score}");

  yield "Information not found in the indexed SOPs.";

  onComplete(
    QueryResult(
      question: question,
      answer: "Information not found in the indexed SOPs.",
      sources: [],
    ),
  );

  return;
}
    if (sources.isEmpty) {
    print("NO SOURCES FOUND -> RETURNING FALLBACK");

  yield "Information not found in the indexed SOPs.";

  onComplete(
    QueryResult(
      question: question,
      answer: "Information not found in the indexed SOPs.",
      sources: [],
    ),
  );

  return;
}
    print("FILTERED SOURCE COUNT = ${sources.length}");

for (final s in sources) {
  print(
      "FILTERED -> FILE=${s.filename} PAGE=${s.pageNum} SCORE=${s.score}");
}
    
    searchSw.stop();

    // 3. Check if LLM is loaded (Retrieval-Only Mode)
    print("========== QUERY ==========");
print(
  "RAG MODEL INSTANCE = ${identityHashCode(_modelService)}"
);
print(
  "Model ready = ${_modelService.isReady}"
);
print(
  "Error = ${_modelService.errorMessage}"
);
    if (!_modelService.isReady) {
      print("========== QUERY ==========");
print("Model ready = ${_modelService.isReady}");
print("Error = ${_modelService.errorMessage}");
      final answerBuffer = StringBuffer();
      answerBuffer.writeln('⚠️ Local language model not configured.');
      answerBuffer.writeln('Showing the most relevant information retrieved from your local knowledge base:\n');

      if (sources.isEmpty) {
        answerBuffer.writeln('⚠️ **No relevant medical SOPs found** for this query in the offline knowledge base.');
        answerBuffer.writeln('Please verify your input or consult emergency medical personnel immediately.');
      } else {
        for (int i = 0; i < sources.length; i++) {
          final s = sources[i];
          answerBuffer.writeln('📌 **Source ${i + 1} (${s.filename}, Page ${s.pageNum})** [Similarity: ${(s.score * 100).toStringAsFixed(1)}%]:');
          answerBuffer.writeln('> ${s.content}\n');
        }
      }

      totalSw.stop();
      final finalAnswer = answerBuffer.toString();
      yield finalAnswer;

      final res = QueryResult(
        question: question,
        answer: finalAnswer,
        sources: sources.cast(),
        embeddingTimeMs: embedSw.elapsedMilliseconds,
        searchTimeMs: searchSw.elapsedMilliseconds,
        generationTimeMs: 0,
        totalTimeMs: totalSw.elapsedMilliseconds,
        tokensPerSecond: 0.0,
        isRetrievalOnly: true,
      );
      _benchmarkService.recordQuery(res);
      onComplete(res);
      return;
    }

    // 4. Build grounded prompt
    final contextBuffer = StringBuffer();
final seen = <String>{};

final dedupedSources = sources.where((s) {
  final key = "${s.docId}_${s.chunkIndex}";
  if (seen.contains(key)) {
    return false;
  }

  seen.add(key);
  return true;
}).toList();
for (final source in dedupedSources) {
  contextBuffer.writeln(source.content);
  contextBuffer.writeln();
}
print("========== CONTEXT BUFFER ==========");
print(contextBuffer.toString());
print("====================================");
    print("========== RETRIEVED CONTEXT ==========");
    print("============== SOURCES ==============");
for (final s in sources) {
  print(
      "FILE=${s.filename} PAGE=${s.pageNum} SCORE=${s.score}");
      print("=====================================");
  print(s.content);
  print("--------------------------------");
}
final systemPrompt = '''
You are a retrieval-based assistant.

Answer ONLY from Context.

If the answer is not explicitly present in Context,
reply exactly:

Information not found in the indexed SOPs.

Context:
${contextBuffer.toString()}

Question:
$question

Answer:
''';
print("========== RETRIEVED SOURCES ==========");

for (final s in sources) {
  print("FILE: ${s.filename}");
  print("PAGE: ${s.pageNum}");
  print("SCORE: ${s.score}");
  print(s.content);
  print("--------------------------------");
}

    // 5. Run local GGUF model via llama.cpp
    final genSw = Stopwatch()..start();

String answer = '';

try {
  print("=========== FULL PROMPT ===========");
print(systemPrompt);
print("===================================");
  answer = await _modelService.generateResponse(
  prompt: systemPrompt,
  query: question,
  temperature: settings.temperature,
  maxTokens: settings.maxTokens,
);

  print("========== GENERATED ANSWER ==========");
  print("ANSWER LENGTH = ${answer.length}");
  print(answer);
  print("====================================");

} catch (e) {
  answer = 'Generation failed: $e';
}

genSw.stop();
totalSw.stop();
print("YIELDING ANSWER");
yield answer;

final result = QueryResult(
  question: question,
  answer: answer,
  sources: sources.cast(),
  embeddingTimeMs: embedSw.elapsedMilliseconds,
  searchTimeMs: searchSw.elapsedMilliseconds,
  generationTimeMs: genSw.elapsedMilliseconds,
  totalTimeMs: totalSw.elapsedMilliseconds,
  tokensPerSecond: 0,
  isRetrievalOnly: false,
);

_benchmarkService.recordQuery(result);
print("ON COMPLETE");
onComplete(result); 
  }
}