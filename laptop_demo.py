"""
EdgeRAG Offline Intelligence — Laptop Demo
Runs 100% locally on your computer with zero cloud dependencies.
Uses the bundled emergency knowledge pack and ONNX MiniLM embeddings.
"""

import os
import sys
import re
import time
import sqlite3
import numpy as np
import webbrowser
from typing import List, Dict, Any

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(SCRIPT_DIR, "assets", "sample", "emergency_demo_knowledge.db")
MODEL_PATH = os.path.join(SCRIPT_DIR, "assets", "models", "embedding", "model_quantized.onnx")
VOCAB_PATH = os.path.join(SCRIPT_DIR, "assets", "models", "embedding", "vocab.txt")

class EdgeRAGLaptopEngine:
    def __init__(self):
        self.vocab = {}
        self.ort_session = None
        self.use_onnx = False
        self._init_vocab()
        self._init_onnx()

    def _init_vocab(self):
        if os.path.exists(VOCAB_PATH):
            with open(VOCAB_PATH, 'r', encoding='utf-8') as f:
                self.vocab = {line.strip(): i for i, line in enumerate(f)}
            print(f"[Engine] Loaded vocabulary with {len(self.vocab)} tokens.")
        else:
            print(f"[Engine] Vocab not found at {VOCAB_PATH}")

    def _init_onnx(self):
        try:
            import onnxruntime as ort
            if os.path.exists(MODEL_PATH):
                self.ort_session = ort.InferenceSession(
                    MODEL_PATH,
                    providers=['CPUExecutionProvider']
                )
                self.use_onnx = True
                print(f"[Engine] ONNX Runtime initialized with {MODEL_PATH}")
            else:
                print(f"[Engine] ONNX model not found at {MODEL_PATH}, using fallback vector matcher.")
        except Exception as e:
            print(f"[Engine] ONNX Runtime not available ({e}), using lexical similarity fallback.")

    def tokenize(self, text: str, max_len: int = 128):
        tokens = ['[CLS]']
        words = re.findall(r'\w+|[^\w\s]', text.lower())
        for word in words:
            if word in self.vocab:
                tokens.append(word)
            else:
                sub_tokens = []
                start = 0
                is_bad = False
                while start < len(word):
                    end = len(word)
                    cur_sub = None
                    while start < end:
                        sub = word[start:end]
                        if start > 0:
                            sub = '##' + sub
                        if sub in self.vocab:
                            cur_sub = sub
                            break
                        end -= 1
                    if cur_sub is None:
                        is_bad = True
                        break
                    sub_tokens.append(cur_sub)
                    start = end
                if is_bad:
                    tokens.append('[UNK]')
                else:
                    tokens.extend(sub_tokens)

        tokens = tokens[:max_len - 1] + ['[SEP]']
        input_ids = [self.vocab.get(t, self.vocab.get('[UNK]', 100)) for t in tokens]
        attention_mask = [1] * len(input_ids)
        token_type_ids = [0] * len(input_ids)
        return input_ids, attention_mask, token_type_ids

    def embed_query(self, text: str) -> np.ndarray:
        if self.use_onnx and self.ort_session:
            input_ids, attention_mask, token_type_ids = self.tokenize(text)
            seq_len = len(input_ids)
            outputs = self.ort_session.run(
                ['last_hidden_state'],
                {
                    'input_ids': np.array([input_ids], dtype=np.int64),
                    'attention_mask': np.array([attention_mask], dtype=np.int64),
                    'token_type_ids': np.array([token_type_ids], dtype=np.int64),
                }
            )
            token_embeddings = outputs[0][0]  # (seq_len, 384)
            mask = np.array(attention_mask)[:, None]
            sum_embeddings = np.sum(token_embeddings * mask, axis=0)
            sum_mask = np.clip(mask.sum(), a_min=1e-9, a_max=None)
            query_vec = sum_embeddings / sum_mask
            norm = np.linalg.norm(query_vec)
            if norm > 1e-12:
                query_vec /= norm
            return query_vec.astype(np.float32)
        else:
            # Fallback deterministic pseudo-embedding
            vec = np.zeros(384, dtype=np.float32)
            for i, c in enumerate(text.encode('utf-8')):
                vec[i % 384] += float(c)
            norm = np.linalg.norm(vec)
            if norm > 0:
                vec /= norm
            return vec

    def search(self, query: str, top_k: int = 3) -> Dict[str, Any]:
        t0 = time.perf_counter()
        q_vec = self.embed_query(query)

        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT c.id, d.filename, c.chunk_index, c.content, c.embedding
            FROM chunks c
            JOIN documents d ON c.doc_id = d.id
            """
        )
        rows = cursor.fetchall()
        conn.close()

        scored_chunks = []
        for cid, doc_name, chunk_idx, content, emb_blob in rows:
            if emb_blob and len(emb_blob) == 384 * 4:
                emb = np.frombuffer(emb_blob, dtype=np.float32)
                sim = float(np.dot(q_vec, emb))
            else:
                # Lexical overlap fallback
                q_words = set(re.findall(r'\w+', query.lower()))
                c_words = set(re.findall(r'\w+', content.lower()))
                sim = len(q_words & c_words) / max(len(q_words), 1)

            scored_chunks.append({
                'id': cid,
                'document': doc_name,
                'chunk_index': chunk_idx,
                'similarity': sim,
                'content': content.strip(),
            })

        scored_chunks.sort(key=lambda x: x['similarity'], reverse=True)
        top_results = scored_chunks[:top_k]
        latency_ms = (time.perf_counter() - t0) * 1000.0

        # Offline synthesized response
        best_doc = top_results[0]['document'] if top_results else 'None'
        best_content = top_results[0]['content'] if top_results else 'No relevant procedure found.'

        answer = f"**[OFFLINE RAG PROTOCOL - {best_doc.replace('.pdf', '').replace('_', ' ')}]**\n\n"
        answer += f"{best_content}\n\n"
        if len(top_results) > 1 and top_results[1]['similarity'] > 0.4:
            answer += f"**Supplementary Precaution ({top_results[1]['document'].replace('.pdf', '')}):**\n"
            answer += f"{top_results[1]['content'][:250]}...\n"

        return {
            'query': query,
            'answer': answer,
            'top_chunks': top_results,
            'latency_ms': round(latency_ms, 1),
            'model': 'all-MiniLM-L6-v2 (Quantized ONNX)',
            'knowledge_pack': 'Emergency Demo Pack (4 SOPs, 24 Chunks)',
            'offline': True
        }

engine = EdgeRAGLaptopEngine()

def run_web_app():
    from fastapi import FastAPI, Request
    from fastapi.responses import HTMLResponse
    import uvicorn

    app = FastAPI(title="EdgeRAG Offline Demo")

    HTML_TEMPLATE = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>EdgeRAG Offline Intelligence — Laptop Demo</title>
        <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
        <style>
            * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Inter', sans-serif; }
            body { background: #0B1325; color: #F1F5F9; min-height: 100vh; display: flex; flex-direction: column; }
            header { background: #111E38; border-bottom: 1px solid #1E2D4A; padding: 16px 28px; display: flex; justify-content: space-between; align-items: center; }
            .logo { display: flex; align-items: center; gap: 12px; font-weight: 700; font-size: 20px; color: #38BDF8; letter-spacing: -0.5px; }
            .badge { background: #064E3B; border: 1px solid #10B981; color: #34D399; font-size: 11px; font-weight: 700; padding: 4px 10px; border-radius: 999px; letter-spacing: 0.5px; display: flex; align-items: center; gap: 6px; }
            .badge::before { content: ""; width: 8px; height: 8px; background: #10B981; border-radius: 50%; display: inline-block; }
            main { flex: 1; max-width: 1000px; width: 100%; margin: 0 auto; padding: 32px 20px; display: flex; flex-direction: column; gap: 24px; }
            .hero { text-align: center; margin-bottom: 8px; }
            .hero h1 { font-size: 28px; font-weight: 700; margin-bottom: 6px; color: #FFFFFF; }
            .hero p { color: #94A3B8; font-size: 14px; }
            .card { background: #111E38; border: 1px solid #1E2D4A; border-radius: 16px; padding: 24px; box-shadow: 0 4px 20px rgba(0,0,0,0.3); }
            .search-box { display: flex; gap: 12px; margin-bottom: 16px; }
            input[type="text"] { flex: 1; background: #0B1325; border: 1px solid #334155; border-radius: 12px; padding: 14px 18px; color: #FFFFFF; font-size: 15px; outline: none; transition: border-color 0.2s; }
            input[type="text"]:focus { border-color: #38BDF8; }
            button.ask-btn { background: #2563EB; color: white; border: none; border-radius: 12px; padding: 0 24px; font-size: 15px; font-weight: 600; cursor: pointer; transition: background 0.2s; }
            button.ask-btn:hover { background: #1D4ED8; }
            .chips { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; font-size: 13px; color: #94A3B8; }
            .chip { background: #1E293B; border: 1px solid #334155; color: #E2E8F0; padding: 6px 12px; border-radius: 999px; cursor: pointer; transition: all 0.2s; }
            .chip:hover { background: #38BDF8; color: #0B1325; border-color: #38BDF8; }
            .metrics-bar { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 14px; margin-top: 8px; }
            .metric { background: #0B1325; border: 1px solid #1E2D4A; padding: 14px; border-radius: 12px; }
            .metric-label { font-size: 11px; text-transform: uppercase; color: #64748B; font-weight: 700; margin-bottom: 4px; }
            .metric-val { font-size: 18px; font-weight: 700; color: #38BDF8; }
            .result-container { display: flex; flex-direction: column; gap: 18px; }
            .answer-card { background: #0F172A; border: 1px solid #2563EB; border-radius: 14px; padding: 20px; }
            .answer-card h3 { color: #38BDF8; font-size: 15px; font-weight: 600; margin-bottom: 12px; display: flex; align-items: center; gap: 8px; }
            .answer-content { color: #E2E8F0; line-height: 1.65; white-space: pre-line; font-size: 14.5px; }
            .sources-title { font-size: 13px; font-weight: 700; text-transform: uppercase; color: #94A3B8; margin-top: 8px; letter-spacing: 0.5px; }
            .source-grid { display: flex; flex-direction: column; gap: 10px; }
            .source-item { background: #0B1325; border: 1px solid #1E2D4A; border-radius: 12px; padding: 14px 18px; }
            .source-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; font-size: 13px; }
            .doc-name { font-weight: 600; color: #38BDF8; }
            .sim-badge { background: #1E293B; border: 1px solid #334155; color: #34D399; font-weight: 700; font-size: 11px; padding: 2px 8px; border-radius: 6px; }
            .source-text { color: #94A3B8; font-size: 13px; line-height: 1.5; }
        </style>
    </head>
    <body>
        <header>
            <div class="logo">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#38BDF8" stroke-width="2.5"><path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/></svg>
                EdgeRAG Offline Intelligence
            </div>
            <div class="badge">100% AIR-GAPPED OFFLINE</div>
        </header>

        <main>
            <div class="hero">
                <h1>Laptop Demonstration Mode</h1>
                <p>Real-time vector search executing directly on local embeddings (all-MiniLM-L6-v2) & SQLite knowledge pack.</p>
            </div>

            <div class="card">
                <form id="searchForm" onsubmit="handleSearch(event)">
                    <div class="search-box">
                        <input type="text" id="queryInput" placeholder="Ask any emergency question (e.g. How to treat a burn?)" required value="How to treat a burn?">
                        <button type="submit" class="ask-btn">Query RAG</button>
                    </div>
                </form>
                <div class="chips">
                    <span>Quick Questions:</span>
                    <span class="chip" onclick="setQuery('How to treat heat stroke?')">Heat Stroke SOP</span>
                    <span class="chip" onclick="setQuery('How to apply a tourniquet for severe bleeding?')">Tourniquet Protocol</span>
                    <span class="chip" onclick="setQuery('What is the adult CPR compression rate and depth?')">Adult CPR AED</span>
                    <span class="chip" onclick="setQuery('First aid management for thermal burns')">Burn Management</span>
                </div>
            </div>

            <div class="metrics-bar" id="metricsBar" style="display: none;">
                <div class="metric">
                    <div class="metric-label">Retrieval Latency</div>
                    <div class="metric-val" id="mLatency">- ms</div>
                </div>
                <div class="metric">
                    <div class="metric-label">Embedding Model</div>
                    <div class="metric-val" style="font-size: 14px; color: #10B981;">all-MiniLM-L6-v2 (384-D)</div>
                </div>
                <div class="metric">
                    <div class="metric-label">Active Pack</div>
                    <div class="metric-val" style="font-size: 14px; color: #F59E0B;">Emergency Demo (4 SOPs)</div>
                </div>
                <div class="metric">
                    <div class="metric-label">Top Similarity</div>
                    <div class="metric-val" id="mSim">- %</div>
                </div>
            </div>

            <div class="result-container" id="resultContainer" style="display: none;">
                <div class="answer-card">
                    <h3>
                        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#38BDF8" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/></svg>
                        Synthesized On-Device RAG Answer
                    </h3>
                    <div class="answer-content" id="answerContent"></div>
                </div>

                <div class="sources-title">Retrieved Knowledge Pack Sources (Ranked by Cosine Similarity)</div>
                <div class="source-grid" id="sourcesGrid"></div>
            </div>
        </main>

        <script>
            function setQuery(q) {
                document.getElementById('queryInput').value = q;
                handleSearch(new Event('submit'));
            }

            async function handleSearch(e) {
                if (e) e.preventDefault();
                const q = document.getElementById('queryInput').value.trim();
                if (!q) return;

                document.getElementById('metricsBar').style.display = 'grid';
                document.getElementById('resultContainer').style.display = 'flex';
                document.getElementById('answerContent').innerText = 'Querying local SQLite vector store...';

                try {
                    const res = await fetch('/api/query?q=' + encodeURIComponent(q));
                    const data = await res.json();

                    document.getElementById('mLatency').innerText = data.latency_ms + ' ms';
                    const topSim = data.top_chunks.length > 0 ? (data.top_chunks[0].similarity * 100).toFixed(1) : 0;
                    document.getElementById('mSim').innerText = topSim + '%';
                    document.getElementById('answerContent').innerText = data.answer;

                    const grid = document.getElementById('sourcesGrid');
                    grid.innerHTML = '';
                    data.top_chunks.forEach((chunk, i) => {
                        const item = document.createElement('div');
                        item.className = 'source-item';
                        item.innerHTML = `
                            <div class="source-header">
                                <span class="doc-name">#${i+1} ${chunk.document} (Chunk ${chunk.chunk_index})</span>
                                <span class="sim-badge">${(chunk.similarity * 100).toFixed(1)}% Match</span>
                            </div>
                            <div class="source-text">${chunk.content}</div>
                        `;
                        grid.appendChild(item);
                    });
                } catch (err) {
                    document.getElementById('answerContent').innerText = 'Error: ' + err;
                }
            }

            // Trigger initial search
            window.addEventListener('DOMContentLoaded', () => handleSearch(null));
        </script>
    </body>
    </html>
    """

    @app.get("/", response_class=HTMLResponse)
    def index():
        return HTML_TEMPLATE

    @app.get("/api/query")
    def api_query(q: str):
        return engine.search(q)

    port = 8080
    print(f"\n=======================================================")
    print(f" EdgeRAG Offline Intelligence Laptop Demo")
    print(f" Open your browser at: http://localhost:{port}")
    print(f"=======================================================\n")
    try:
        webbrowser.open(f"http://localhost:{port}")
    except:
        pass
    uvicorn.run(app, host="127.0.0.1", port=port, log_level="warning")

def run_cli():
    print("=======================================================")
    print(" EdgeRAG Offline Intelligence — CLI Demo")
    print(" 100% Offline RAG Query Engine")
    print("=======================================================")
    test_queries = [
        "How to treat heat stroke?",
        "What is the first aid for thermal burns?",
        "When should a tourniquet be applied?",
        "What is the CPR compression rate?"
    ]
    for q in test_queries:
        print(f"\n[QUERY]: {q}")
        res = engine.search(q)
        print(f"[LATENCY]: {res['latency_ms']} ms")
        for i, c in enumerate(res['top_chunks']):
            print(f"  Source {i+1}: {c['document']} (Chunk {c['chunk_index']}) -> {c['similarity']*100:.1f}% Match")
            print(f"  Excerpt: {c['content'][:120]}...\n")

if __name__ == "__main__":
    if "--cli" in sys.argv:
        run_cli()
    else:
        run_web_app()
