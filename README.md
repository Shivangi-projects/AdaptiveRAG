# EdgeRAG: Offline Intelligence

**Privacy-Preserving On-Device RAG Assistant for Android Smartphones**

EdgeRAG is an open-source, fully offline Retrieval-Augmented Generation (RAG) knowledge assistant built specifically for mobile devices running Android 10+ (API 29+). Designed for low-connectivity, air-gapped, and mission-critical environments (such as disaster response, emergency first aid, rural healthcare, maritime, mining, and field engineering), EdgeRAG performs the entire RAG pipeline—from document parsing and chunking to 384-D ONNX embeddings, vector database similarity search, and local GGUF language model inference—100% on the device CPU.

Zero data leaves the phone. No cloud AI APIs (OpenAI, Gemini, Anthropic, Firebase) are required or invoked. The application functions flawlessly with Wi-Fi disabled, mobile data disabled, and Airplane Mode engaged.

---

## Deliverables

* **`EdgeRAG.apk`**: Release Android application package optimized for `arm64-v8a` (and `x86_64`).
* **`EdgeRAG.aab`**: Google Play Store Android App Bundle.

---

## Architectural Overview

```
                          ┌─────────────────────────────┐
                          │    Flutter Mobile UI        │
                          │   (Dark Navy/Slate Theme)   │
                          └──────────────┬──────────────┘
                                         │ (Dart FFI)
                          ┌──────────────▼──────────────┐
                          │    Native AI Core (C++)     │
                          │      libedgerag.so          │
                          └───────┬───────────────┬─────┘
                                  │               │
            ┌─────────────────────▼───┐       ┌───▼─────────────────────┐
            │   ONNX Runtime Mobile   │       │     llama.cpp Core      │
            │ all-MiniLM-L6-v2 (384D) │       │ GGUF Quantized SLMs     │
            │ Mean Pooling & L2 Norm  │       │ Streaming Token Decodes │
            └─────────────┬───────────┘       └───┬─────────────────────┘
                          │                       │
                          └───────────┬───────────┘
                                      │
                          ┌───────────▼───────────┐
                          │ SQLite Vector Store   │
                          │ WAL Mode & NEON SIMD  │
                          │ Chunks & Metadata DB  │
                          └───────────────────────┘
```

### 1. Flutter Mobile UI Layer
* **Design**: Designed from the ground up for one-handed smartphone usage with Material Design and a dark navy/slate aesthetic (`#0B1325`, `#111E38`, `#1E2D4A`, `#3B82F6`, `#10B981`).
* **Status Badge**: Top-level indicator displays `🟢 LOCAL AI` or `🟢 OFFLINE RAG`.
* **Five Bottom Navigation Tabs**:
  1. **Home**: Clean dashboard with system readiness checklist, RAM and database size chips, document counts, and quick actions.
  2. **Knowledge**: Indexed document cards (page count, chunk count, file size, SHA-256 hash), Add Document picker (SAF for PDF/TXT), duplicate detection alert, and Knowledge Pack manager.
  3. **Chat**: Streaming conversation interface with user and assistant bubbles, Stop button, New Chat, and expandable **Sources** accordion under every response (showing filename, page, similarity score, and passage snippet).
  4. **Performance**: Real measured device benchmarks (Query Embedding time, Vector Search time, Retrieval latency, Time to First Token, Generation speed in tokens/sec, Total response time, RAM consumption) with dynamic latency line chart.
  5. **Settings**: GGUF Model Selector via Storage Access Framework, Load/Unload controls, RAM estimation, CPU threads (1–8), Context Length (512–2048), Max Tokens, Temperature, Top-K, Chunk Size/Overlap, Diagnostic Log Export, and Privacy manifesto.
* **Academic Demo Mode**: Special 8-step pipeline visualizer (Document Loaded → Text Chunked → 384-D Embeddings → Vectors Stored → Query Embedded → Similarity Search → Context Retrieved → Local LLM Generation) with live execution timings for machine learning demonstrations.

### 2. Native AI Core (C++ / Android NDK)
* **Embedding Engine**:
  * Runs `sentence-transformers/all-MiniLM-L6-v2` ONNX model via ONNX Runtime C API.
  * WordPiece tokenizer parsing `vocab.txt` with subword splitting (`##`).
  * Computes exact 384-dimensional dense vectors using mean pooling over active attention tokens and L2 normalization.
* **Vector Database**:
  * Embedded SQLite database in Write-Ahead Logging (`WAL`) mode with foreign key cascade support.
  * Cosine similarity ranking accelerated via ARM NEON SIMD vector dot products.
  * SHA-256 document hashing for instantaneous duplicate detection.
* **Local Language Model (`llama.cpp`)**:
  * Memory-mapped (`mmap`) loading of GGUF quantized models (Q4_K_M recommended).
  * Token-by-token progressive streaming to the Flutter UI thread.
  * Atomic cancellation support via the "Stop" button.
  * Safe memory management with out-of-memory guards and unload routines.
* **Retrieval-Only Mode**:
  * Guarantees full operation even when no GGUF model is loaded or configured.
  * Performs query embedding, retrieves Top-K chunks, and displays the exact grounded evidence passages.

### 3. Portable Knowledge Packs (`.edgepack`)
* Portable format containing pre-indexed domain databases (`metadata.json` + `knowledge.db`).
* Bundled sample pack: `emergency_demo.edgepack` (contains emergency first-aid protocols for heat stroke, severe burns, active bleeding, adult CPR, hypothermia, and choking).
* Eliminates the need for low-power smartphones to spend battery and CPU re-embedding standard operating procedures.

---

## Target Hardware & Minimum Requirements

| Parameter | Minimum Requirement | Recommended |
| :--- | :--- | :--- |
| **Operating System** | Android 10 (API 29) | Android 12+ (API 31+) |
| **Architecture** | `arm64-v8a` (ARM64) | `arm64-v8a` (ARM64) |
| **System RAM** | 4 GB | 6 GB to 8 GB+ |
| **Dedicated GPU** | Not required (CPU only) | Optional device acceleration |
| **Storage Space** | ~100 MB for app + model | 1.5 GB for GGUF model storage |

---

## Recommended GGUF Models

Download from Hugging Face and place in your phone's storage:
* **Qwen2.5 0.5B Instruct** (`Qwen2.5-0.5B-Instruct-Q4_K_M.gguf`, ~390 MB) — Fast and responsive on 4GB RAM devices.
* **Qwen2.5 1.5B Instruct** (`Qwen2.5-1.5B-Instruct-Q4_K_M.gguf`, ~980 MB) — Outstanding reasoning and concise answers.
* **Llama 3.2 1B Instruct** (`Llama-3.2-1B-Instruct-Q4_K_M.gguf`, ~800 MB) — High quality mobile assistant.

---

## Building from Source

### Prerequisites
* JDK 17
* Android SDK (API 34, Build Tools 34.0.0, NDK 26.1.10909125, CMake 3.22.1)
* Flutter SDK 3.24.x+

### Commands
```bash
# 1. Fetch dependencies
flutter pub get

# 2. Run automated test suite
flutter test

# 3. Build release APK
flutter build apk --release

# 4. Build Android App Bundle (AAB)
flutter build appbundle --release
```

---

## Offline & Airplane Mode Verification Procedure

1. Install `EdgeRAG.apk` onto an Android smartphone using ADB:
   ```bash
   adb install -r EdgeRAG.apk
   ```
2. Turn OFF Wi-Fi and Mobile Data. Enable **Airplane Mode**.
3. Open **EdgeRAG**. Complete the 5-step onboarding walkthrough.
4. On the Home screen, tap **Sample Pack** to activate the `Emergency Demo Pack`.
5. Navigate to **Knowledge** to inspect the 4 pre-indexed documents and 24 chunks.
6. Open **Chat** and ask:
   > *"What should I do for heat stroke?"*
7. Verify that:
   * Query is embedded locally in milliseconds.
   * Matching chunks from `Heat_Stroke_Emergency_SOP.pdf` are retrieved.
   * Expandable **Sources** accordion displays page numbers, similarity scores, and excerpt snippets.
   * Grounded answer is streamed or displayed via Retrieval-Only mode.
8. Open **Performance** to observe measured latencies, memory footprint, and latency charts.
9. Close and kill the application from recent apps. Re-open to confirm persistent database state.

---

## Privacy Notice
EdgeRAG does not contain code to communicate with remote AI inference servers. No tracking, telemetry, or analytics libraries are bundled. All document contents, embeddings, and chat histories remain strictly inside the device's local application sandbox.
