import 'dart:ffi';
import 'dart:io';
import 'dart:convert';
import 'package:ffi/ffi.dart';
import '../models/document.dart';
import '../models/chunk.dart';

// Native function typedefs
typedef EdgeragInitNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef EdgeragInitDart = int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);

typedef EdgeragEmbedNative = Int32 Function(Pointer<Utf8>, Pointer<Float>);
typedef EdgeragEmbedDart = int Function(Pointer<Utf8>, Pointer<Float>);

typedef EdgeragAddDocNative = Int64 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32, Int64, Pointer<Utf8>);
typedef EdgeragAddDocDart = int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int, int, Pointer<Utf8>);

typedef EdgeragAddChunkNative = Int64 Function(Int64, Int32, Int32, Pointer<Utf8>, Pointer<Float>);
typedef EdgeragAddChunkDart = int Function(int, int, int, Pointer<Utf8>, Pointer<Float>);

typedef EdgeragSearchNative = Int32 Function(Pointer<Float>, Int32, Pointer<Utf8>, Int32);
typedef EdgeragSearchDart = int Function(Pointer<Float>, int, Pointer<Utf8>, int);

typedef EdgeragCheckDupNative = Int32 Function(Pointer<Utf8>, Pointer<Int64>);
typedef EdgeragCheckDupDart = int Function(Pointer<Utf8>, Pointer<Int64>);

typedef EdgeragListDocsNative = Int32 Function(Pointer<Utf8>, Int32);
typedef EdgeragListDocsDart = int Function(Pointer<Utf8>, int);

typedef EdgeragDeleteDocNative = Int32 Function(Int64);
typedef EdgeragDeleteDocDart = int Function(int);

typedef EdgeragGetStatsNative = Int32 Function(Pointer<Int64>, Pointer<Int64>, Pointer<Int64>);
typedef EdgeragGetStatsDart = int Function(Pointer<Int64>, Pointer<Int64>, Pointer<Int64>);

typedef EdgeragLoadLlmNative = Int32 Function(Pointer<Utf8>, Int32, Int32);
typedef EdgeragLoadLlmDart = int Function(Pointer<Utf8>, int, int);

typedef EdgeragVoidIntNative = Int32 Function();
typedef EdgeragVoidIntDart = int Function();

typedef EdgeragGenStartNative = Int32 Function(Pointer<Utf8>, Float, Int32);
typedef EdgeragGenStartDart = int Function(Pointer<Utf8>, double, int);

typedef EdgeragGenNextTokenNative = Int32 Function(Pointer<Utf8>, Int32);
typedef EdgeragGenNextTokenDart = int Function(Pointer<Utf8>, int);

typedef EdgeragVoidNative = Void Function();
typedef EdgeragVoidDart = void Function();

typedef EdgeragPackOpNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef EdgeragPackOpDart = int Function(Pointer<Utf8>, Pointer<Utf8>, int);

class NativeBridge {
  static final NativeBridge _instance = NativeBridge._internal();
  factory NativeBridge() => _instance;
  NativeBridge._internal();

  DynamicLibrary? _lib;
  bool _isAvailable = false;

  EdgeragInitDart? _init;
  EdgeragEmbedDart? _embedText;
  EdgeragAddDocDart? _addDocument;
  EdgeragAddChunkDart? _addChunk;
  EdgeragSearchDart? _search;
  EdgeragCheckDupDart? _checkDuplicate;
  EdgeragListDocsDart? _listDocuments;
  EdgeragDeleteDocDart? _deleteDocument;
  EdgeragGetStatsDart? _getStats;
  EdgeragLoadLlmDart? _loadLlm;
  EdgeragVoidIntDart? _unloadLlm;
  EdgeragVoidIntDart? _isLlmLoaded;
  EdgeragGenStartDart? _generateStart;
  EdgeragGenNextTokenDart? _generateNextToken;
  EdgeragVoidDart? _generateStop;
  EdgeragPackOpDart? _importPackDb;
  EdgeragPackOpDart? _exportPackDb;
  EdgeragVoidDart? _dispose;

  bool get isAvailable => _isAvailable;

  void initialize() {
    try {
      if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libedgerag.so');
      } else if (Platform.isWindows) {
        _lib = DynamicLibrary.open('edgerag.dll');
      } else if (Platform.isLinux) {
        _lib = DynamicLibrary.open('libedgerag.so');
      }
      if (_lib != null) {
        _bindFunctions();
        _isAvailable = true;
      }
    } catch (e) {
      // Fallback mode if running in mock / test environment without native lib
      _isAvailable = false;
    }
  }

  void _bindFunctions() {
    final lib = _lib!;
    _init = lib.lookupFunction<EdgeragInitNative, EdgeragInitDart>('edgerag_init');
    _embedText = lib.lookupFunction<EdgeragEmbedNative, EdgeragEmbedDart>('edgerag_embed_text');
    _addDocument = lib.lookupFunction<EdgeragAddDocNative, EdgeragAddDocDart>('edgerag_add_document');
    _addChunk = lib.lookupFunction<EdgeragAddChunkNative, EdgeragAddChunkDart>('edgerag_add_chunk');
    _search = lib.lookupFunction<EdgeragSearchNative, EdgeragSearchDart>('edgerag_search');
    _checkDuplicate = lib.lookupFunction<EdgeragCheckDupNative, EdgeragCheckDupDart>('edgerag_check_duplicate');
    _listDocuments = lib.lookupFunction<EdgeragListDocsNative, EdgeragListDocsDart>('edgerag_list_documents');
    _deleteDocument = lib.lookupFunction<EdgeragDeleteDocNative, EdgeragDeleteDocDart>('edgerag_delete_document');
    _getStats = lib.lookupFunction<EdgeragGetStatsNative, EdgeragGetStatsDart>('edgerag_get_stats');
    _loadLlm = lib.lookupFunction<EdgeragLoadLlmNative, EdgeragLoadLlmDart>('edgerag_load_llm');
    _unloadLlm = lib.lookupFunction<EdgeragVoidIntNative, EdgeragVoidIntDart>('edgerag_unload_llm');
    _isLlmLoaded = lib.lookupFunction<EdgeragVoidIntNative, EdgeragVoidIntDart>('edgerag_is_llm_loaded');
    _generateStart = lib.lookupFunction<EdgeragGenStartNative, EdgeragGenStartDart>('edgerag_generate_start');
    _generateNextToken = lib.lookupFunction<EdgeragGenNextTokenNative, EdgeragGenNextTokenDart>('edgerag_generate_next_token');
    _generateStop = lib.lookupFunction<EdgeragVoidNative, EdgeragVoidDart>('edgerag_generate_stop');
    _importPackDb = lib.lookupFunction<EdgeragPackOpNative, EdgeragPackOpDart>('edgerag_import_pack_db');
    _exportPackDb = lib.lookupFunction<EdgeragPackOpNative, EdgeragPackOpDart>('edgerag_export_pack_db');
    _dispose = lib.lookupFunction<EdgeragVoidNative, EdgeragVoidDart>('edgerag_dispose');
  }

  bool initEngine(String dbPath, String onnxPath, String vocabPath) {
    if (!_isAvailable || _init == null) return true;
    final pDb = dbPath.toNativeUtf8();
    final pOnnx = onnxPath.toNativeUtf8();
    final pVocab = vocabPath.toNativeUtf8();
    try {
      final res = _init!(pDb, pOnnx, pVocab);
      return res == 1;
    } finally {
      calloc.free(pDb);
      calloc.free(pOnnx);
      calloc.free(pVocab);
    }
  }

  List<double>? embedText(String text) {
    if (!_isAvailable || _embedText == null) {
      // Deterministic 384-D vector fallback for non-native environments
      final vec = List<double>.filled(384, 0.0);
      for (int i = 0; i < text.length; i++) {
        vec[i % 384] += text.codeUnitAt(i).toDouble();
      }
      double norm = 0.0;
      for (var v in vec) {
        norm += v * v;
      }
      norm = norm > 0 ? norm : 1.0;
      for (int i = 0; i < 384; i++) {
        vec[i] /= norm;
      }
      return vec;
    }

    final pText = text.toNativeUtf8();
    final pOut = calloc<Float>(384);
    try {
      final res = _embedText!(pText, pOut);
      print("NATIVE EMBED RETURN = $res");

if (res == 1) {
  print("FIRST 10 NATIVE VALUES:");
  for (int i = 0; i < 10; i++) {
    print(pOut[i]);
  }
}
      if (res != 1) {
        final vec = List<double>.filled(384, 0.0);
        for (int i = 0; i < text.length; i++) {
          vec[i % 384] += text.codeUnitAt(i).toDouble();
        }
        double norm = 0.0;
        for (var v in vec) {
          norm += v * v;
        }
        norm = norm > 0 ? norm : 1.0;
        for (int i = 0; i < 384; i++) {
          vec[i] /= norm;
        }
        return vec;
      }
      final list = List<double>.generate(384, (i) => pOut[i]);
      return list;
    } finally {
      calloc.free(pText);
      calloc.free(pOut);
    }
  }

  int addDocument(String filename, String fileHash, String fileType, int pageCount, int fileSize, String dateAdded) {
    if (!_isAvailable || _addDocument == null) return 1;
    final pFn = filename.toNativeUtf8();
    final pFh = fileHash.toNativeUtf8();
    final pFt = fileType.toNativeUtf8();
    final pDa = dateAdded.toNativeUtf8();
    try {
      return _addDocument!(pFn, pFh, pFt, pageCount, fileSize, pDa);
    } finally {
      calloc.free(pFn);
      calloc.free(pFh);
      calloc.free(pFt);
      calloc.free(pDa);
    }
  }

  int addChunk(int docId, int chunkIndex, int pageNum, String content, List<double>? embedding) {
    if (!_isAvailable || _addChunk == null) return 1;
    final pContent = content.toNativeUtf8();
    Pointer<Float> pEmb = nullptr;
    if (embedding != null && embedding.length == 384) {
      pEmb = calloc<Float>(384);
      for (int i = 0; i < 384; i++) {
        pEmb[i] = embedding[i];
      }
    }
    try {
      return _addChunk!(docId, chunkIndex, pageNum, pContent, pEmb);
    } finally {
      calloc.free(pContent);
      if (pEmb != nullptr) calloc.free(pEmb);
    }
  }

  List<ChunkItem> search(List<double> queryVector, int topK) {
    print("SEARCH FUNCTION ENTERED");
print("_isAvailable = $_isAvailable");
print("_search null = ${_search == null}");
    if (!_isAvailable || _search == null) return [];
    final pVec = calloc<Float>(384);
    for (int i = 0; i < 384; i++) {
      pVec[i] = (i < queryVector.length) ? queryVector[i] : 0.0;
    }
    const maxLen = 65536;
    final pOut = calloc<Uint8>(maxLen);
    try {
      print("CALLING NATIVE SEARCH NOW");
      print("TOPK PASSED TO NATIVE = $topK");
final count = _search!(pVec, topK, pOut.cast<Utf8>(), maxLen);
print("RETURNED FROM NATIVE SEARCH count=$count");
      if (count <= 0) return [];
      final jsonStr = pOut.cast<Utf8>().toDartString();
      final List dynamicList = jsonDecode(jsonStr) as List;
      print("JSON RESULT COUNT = ${dynamicList.length}");
      return dynamicList.map((e) => ChunkItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    } finally {
      calloc.free(pVec);
      calloc.free(pOut);
    }
  }

  bool checkDuplicate(String fileHash) {
    if (!_isAvailable || _checkDuplicate == null) return false;
    final pHash = fileHash.toNativeUtf8();
    final pDocId = calloc<Int64>();
    try {
      final res = _checkDuplicate!(pHash, pDocId);
      return res == 1;
    } finally {
      calloc.free(pHash);
      calloc.free(pDocId);
    }
  }

  List<DocumentItem> listDocuments() {
    if (!_isAvailable || _listDocuments == null) return [];
    const maxLen = 65536;
    final pOut = calloc<Uint8>(maxLen);
    try {
      final count = _listDocuments!(pOut.cast<Utf8>(), maxLen);
      if (count <= 0) return [];
      final jsonStr = pOut.cast<Utf8>().toDartString();
      final List dynamicList = jsonDecode(jsonStr) as List;
      return dynamicList.map((e) => DocumentItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    } finally {
      calloc.free(pOut);
    }
  }

  bool deleteDocument(int docId) {
    if (!_isAvailable || _deleteDocument == null) return true;
    return _deleteDocument!(docId) == 1;
  }

  Map<String, int> getStats() {
    if (!_isAvailable || _getStats == null) {
      return {'doc_count': 0, 'chunk_count': 0, 'db_size': 0};
    }
    final pDocCount = calloc<Int64>();
    final pChunkCount = calloc<Int64>();
    final pDbSize = calloc<Int64>();
    try {
      _getStats!(pDocCount, pChunkCount, pDbSize);
      return {
        'doc_count': pDocCount.value,
        'chunk_count': pChunkCount.value,
        'db_size': pDbSize.value,
      };
    } finally {
      calloc.free(pDocCount);
      calloc.free(pChunkCount);
      calloc.free(pDbSize);
    }
  }

  bool loadLlm(String modelPath, int nCtx, int nThreads) {
    if (!_isAvailable || _loadLlm == null) return true;
    final pPath = modelPath.toNativeUtf8();
    try {
      return _loadLlm!(pPath, nCtx, nThreads) == 1;
    } finally {
      calloc.free(pPath);
    }
  }

  bool unloadLlm() {
    if (!_isAvailable || _unloadLlm == null) return true;
    return _unloadLlm!() == 1;
  }

  bool isLlmLoaded() {
    if (!_isAvailable || _isLlmLoaded == null) return false;
    return _isLlmLoaded!() == 1;
  }

  bool generateStart(String prompt, double temperature, int maxTokens) {
  print("DEBUG: generateStart called");
  print("DEBUG: _isAvailable=$_isAvailable");
  print("DEBUG: _generateStart=${_generateStart != null}");
  print("DEBUG: prompt length=${prompt.length}");

  if (!_isAvailable || _generateStart == null) {
    print("DEBUG: Native generation function unavailable");
    return false;
  }

  final pPrompt = prompt.toNativeUtf8();

  try {
    final result = _generateStart!(
      pPrompt,
      temperature,
      maxTokens,
    );

    print("DEBUG: native result=$result");

    return result == 1;
  } catch (e) {
    print("DEBUG: generateStart exception=$e");
    return false;
  } finally {
    calloc.free(pPrompt);
  }
}

  String? generateNextToken() {
    if (!_isAvailable || _generateNextToken == null) return null;
    const maxLen = 512;
    final pBuf = calloc<Uint8>(maxLen);
    try {
      final bytesWritten = _generateNextToken!(pBuf.cast<Utf8>(), maxLen);
      if (bytesWritten <= 0) return null;
      return pBuf.cast<Utf8>().toDartString();
    } finally {
      calloc.free(pBuf);
    }
  }

  void generateStop() {
    if (!_isAvailable || _generateStop == null) return;
    _generateStop!();
  }

  bool importPackDb(String packDbPath) {
    if (!_isAvailable || _importPackDb == null) return false;
    final pPath = packDbPath.toNativeUtf8();
    final pErr = calloc<Uint8>(1024);
    try {
      final res = _importPackDb!(pPath, pErr.cast<Utf8>(), 1024);
      return res == 1;
    } finally {
      calloc.free(pPath);
      calloc.free(pErr);
    }
  }

  bool exportPackDb(String destDbPath) {
    if (!_isAvailable || _exportPackDb == null) return false;
    final pPath = destDbPath.toNativeUtf8();
    final pErr = calloc<Uint8>(1024);
    try {
      final res = _exportPackDb!(pPath, pErr.cast<Utf8>(), 1024);
      return res == 1;
    } finally {
      calloc.free(pPath);
      calloc.free(pErr);
    }
  }

  void dispose() {
    if (!_isAvailable || _dispose == null) return;
    _dispose!();
  }
}
