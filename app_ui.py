import os
import glob
import struct
import sqlite3
import numpy as np
import streamlit as st
import sqlite_vec
import onnxruntime as ort

st.set_page_config(
    page_title="Offline Emergency RAG",
    page_icon="🛡️",
    layout="wide",
    initial_sidebar_state="expanded"
)

st.title("🛡️ Privacy-Preserving Offline Emergency RAG")
st.caption("100% On-Device Retrieval & Inference • Zero Cloud APIs • Air-Gapped Operation")

# ---------------------------------------------------------
# 1. LOAD BACKEND ENGINES (ONNX, SQLITE-VEC, LLAMA-CPP)
# ---------------------------------------------------------
@st.cache_resource
def load_backend_engine():
    db_path = "offline_knowledge.db"
    model_path = "./onnx_model/model.onnx"
    tok_json = "./onnx_model/tokenizer.json"

    # 1. Connect to local SQLite vector database & load sqlite-vec
    db = sqlite3.connect(db_path, check_same_thread=False)
    db.enable_load_extension(True)
    sqlite_vec.load(db)
    db.enable_load_extension(False)

    # Ensure vec_documents virtual table & doc_contents view exist
    db.execute("""
        CREATE VIRTUAL TABLE IF NOT EXISTS vec_documents USING vec0(
            embedding float[384]
        )
    """)
    db.execute("""
        CREATE VIEW IF NOT EXISTS doc_contents AS
        SELECT id AS rowid, content AS text_content, source_pdf, chunk_index FROM docs
    """)

    # Populate vec_documents if needed
    cur_cnt = db.execute("SELECT count(*) FROM vec_documents").fetchone()[0]
    if cur_cnt == 0:
        docs = db.execute("SELECT id, embedding FROM docs").fetchall()
        for doc_id, emb_blob in docs:
            db.execute("INSERT INTO vec_documents(rowid, embedding) VALUES (?, ?)", (doc_id, emb_blob))
        db.commit()

    # 2. Load ONNX embedding model
    onnx_session = ort.InferenceSession(model_path, providers=['CPUExecutionProvider'])

    # 3. Load Tokenizer (fast Hugging Face Tokenizers with fallback)
    try:
        from tokenizers import Tokenizer
        tokenizer = Tokenizer.from_file(tok_json)
        tok_type = "fast"
    except Exception:
        from transformers import AutoTokenizer
        tokenizer = AutoTokenizer.from_pretrained("./onnx_model")
        tok_type = "transformers"

    # 4. Attempt to load local GGUF SLM if available
    llm = None
    llm_name = "Not Loaded (Retrieval-Only Mode)"
    gguf_files = glob.glob("./models/*.gguf")
    if gguf_files:
        try:
            from llama_cpp import Llama
            selected_gguf = gguf_files[0]
            llm = Llama(
                model_path=selected_gguf,
                n_ctx=2048,
                n_threads=4,
                verbose=False
            )
            llm_name = os.path.basename(selected_gguf)
        except Exception as e:
            llm_name = f"Failed to load: {e}"

    return db, onnx_session, tokenizer, tok_type, llm, llm_name

db, onnx_session, tokenizer, tok_type, llm, llm_name = load_backend_engine()

# Helper: Compute ONNX vector embeddings on CPU
def get_embedding(text: str) -> np.ndarray:
    if tok_type == "fast":
        encoded = tokenizer.encode(text)
        input_ids = np.array([encoded.ids], dtype=np.int64)
        attention_mask = np.array([encoded.attention_mask], dtype=np.int64)
        token_type_ids = np.array([[0] * len(encoded.ids)], dtype=np.int64)
    else:
        inputs = tokenizer(text, padding=True, truncation=True, return_tensors="np")
        input_ids = inputs["input_ids"].astype(np.int64)
        attention_mask = inputs["attention_mask"].astype(np.int64)
        token_type_ids = inputs.get("token_type_ids", np.zeros_like(input_ids)).astype(np.int64)

    onnx_inputs = {
        "input_ids": input_ids,
        "attention_mask": attention_mask,
        "token_type_ids": token_type_ids,
    }

    outputs = onnx_session.run(None, onnx_inputs)
    token_embeddings = outputs[0]  # (1, seq_len, 384)
    input_mask_expanded = np.expand_dims(attention_mask, -1)
    sum_embeddings = np.sum(token_embeddings * input_mask_expanded, axis=1)
    sum_mask = np.clip(input_mask_expanded.sum(axis=1), a_min=1e-9, a_max=None)
    embedding = sum_embeddings / sum_mask
    norm = np.linalg.norm(embedding, axis=1, keepdims=True)
    return (embedding / norm).flatten().astype(np.float32)

def serialize_float32(vector) -> bytes:
    return struct.pack(f"{len(vector)}f", *vector)

# ---------------------------------------------------------
# SIDEBAR STATUS & CONTROLS
# ---------------------------------------------------------
with st.sidebar:
    st.header("⚙️ System Status")
    st.success("🟢 Vector DB: `offline_knowledge.db` (12 SOP Chunks)")
    st.success("🟢 Embedding Model: `all-MiniLM-L6-v2` (ONNX 384-D)")
    st.success("🟢 Vector Search: `sqlite-vec` KNN Engine")

    if llm:
        st.success(f"🟢 SLM: `{llm_name}`")
    else:
        st.info("ℹ️ Mode: **Direct Offline Retrieval**\n\nTo enable local generation, place a `.gguf` model into `./models/`.")

    st.markdown("---")
    st.subheader("💡 Quick Test Queries")
    quick_queries = [
        "What is the CPR compression rate and depth?",
        "How to apply a Combat Application Tourniquet for severe bleeding?",
        "What are the symptoms and naloxone protocol for opioid overdose?",
        "How to treat thermal burns?",
        "What is the FAST protocol for stroke assessment?",
    ]
    for q in quick_queries:
        if st.button(q, key=f"btn_{q[:15]}", use_container_width=True):
            st.session_state["preset_query"] = q

    if st.button("🗑️ Clear Chat", use_container_width=True):
        st.session_state.messages = []
        st.rerun()

# ---------------------------------------------------------
# 2. CHAT INTERFACE & GENERATION
# ---------------------------------------------------------
if "messages" not in st.session_state:
    st.session_state.messages = []

# Display previous messages
for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.markdown(message["content"])
        if "excerpt" in message and message["excerpt"]:
            st.caption(f"📍 **Retrieved Excerpt:** {message['excerpt']}")

# Handle preset button click or user text input
preset = st.session_state.pop("preset_query", None)
user_query = preset or st.chat_input("Ask an emergency health query (e.g. CPR guidelines, tourniquet application)...")

if user_query:
    st.session_state.messages.append({"role": "user", "content": user_query})
    with st.chat_message("user"):
        st.markdown(user_query)

    # Step A: Perform vector similarity search in sqlite-vec
    query_vec = get_embedding(user_query)
    query_blob = serialize_float32(query_vec)

    matches = db.execute("""
        SELECT d.text_content, v.distance, d.source_pdf
        FROM (
            SELECT rowid, distance
            FROM vec_documents
            WHERE embedding MATCH ?
            LIMIT 2
        ) v
        JOIN doc_contents d ON v.rowid = d.rowid
        ORDER BY v.distance
    """, (query_blob,)).fetchall()

    if matches:
        context = "\n\n".join([f"[{r[2]}]: {r[0]}" for r in matches])
        primary_excerpt = matches[0][0][:200]
        top_distance = matches[0][1]
    else:
        context = "No relevant SOP found in local database."
        primary_excerpt = "None"
        top_distance = 1.0

    # Step B: Pass context and prompt to local SLM or offline synthesis
    if llm:
        prompt_messages = [
            {
                "role": "system",
                "content": "You are an offline emergency medical assistant. Answer concisely using strictly the provided context."
            },
            {
                "role": "user",
                "content": f"Context:\n{context}\n\nQuestion: {user_query}"
            }
        ]
        with st.chat_message("assistant"):
            with st.spinner("Generating offline answer with local SLM..."):
                response = llm.create_chat_completion(messages=prompt_messages, max_tokens=200, temperature=0.1)
                answer = response['choices'][0]['message']['content']
                st.markdown(answer)
                st.caption(f"📍 **Retrieved Excerpt:** {primary_excerpt}...")
    else:
        # High-Fidelity Grounded Retrieval Mode
        with st.chat_message("assistant"):
            best_chunk = matches[0][0] if matches else "No relevant medical protocol found."
            best_source = matches[0][2] if matches else "Knowledge Base"

            answer = f"**[OFFLINE PROTOCOL: {best_source.replace('.pdf', '').upper()}]**\n\n{best_chunk}"
            if len(matches) > 1:
                answer += f"\n\n**Supplementary Protocol ({matches[1][2]}):**\n{matches[1][0][:220]}..."

            st.markdown(answer)
            st.caption(f"📍 **Ranked Evidence (Distance: {top_distance:.3f}):** {primary_excerpt}...")

    st.session_state.messages.append({
        "role": "assistant",
        "content": answer,
        "excerpt": primary_excerpt
    })
