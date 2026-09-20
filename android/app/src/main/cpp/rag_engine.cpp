#include "rag_engine.h"
#include "embedding_engine.h"
#include "vector_store.h"
#include "llama_engine.h"
#include "knowledge_pack.h"

#include <android/log.h>
#include <memory>
#include <sstream>
#include <cstring>
#include <iomanip>

static std::unique_ptr<edgerag::EmbeddingEngine> g_embedding;
static std::unique_ptr<edgerag::VectorStore> g_vector_store;
static std::unique_ptr<edgerag::LlamaEngine> g_llama;

static std::string escape_json(const std::string &s)
{
    std::ostringstream o;
    for (char c : s)
    {
        switch (c)
        {
        case '"':
            o << "\\\"";
            break;
        case '\\':
            o << "\\\\";
            break;
        case '\b':
            o << "\\b";
            break;
        case '\f':
            o << "\\f";
            break;
        case '\n':
            o << "\\n";
            break;
        case '\r':
            o << "\\r";
            break;
        case '\t':
            o << "\\t";
            break;
        default:
            if (static_cast<unsigned char>(c) < 0x20)
            {
                o << "\\u" << std::hex << std::setw(4) << std::setfill('0') << static_cast<int>(c);
            }
            else
            {
                o << c;
            }
        }
    }
    return o.str();
}

extern "C"
{

    int32_t edgerag_init(const char *db_path, const char *onnx_path, const char *vocab_path)
    {
        if (!g_vector_store)
        {
            g_vector_store = std::make_unique<edgerag::VectorStore>();
        }
        if (db_path && !g_vector_store->open(db_path))
        {
            return 0;
        }

        if (!g_embedding)
        {
            g_embedding = std::make_unique<edgerag::EmbeddingEngine>();
        }
        if (onnx_path && vocab_path)
        {
            g_embedding->init(onnx_path, vocab_path);
        }

        if (!g_llama)
        {
            g_llama = std::make_unique<edgerag::LlamaEngine>();
        }

        return 1;
    }

    int32_t edgerag_embed_text(const char *text, float *out_embedding)
    {
        __android_log_print(
            ANDROID_LOG_ERROR,
            "EDGERAG",
            "REAL EMBEDDING CALLED");
        std::vector<float> vec;

        if (!g_embedding || !text || !out_embedding)
            return 0;

        if (!g_embedding->embed(text, vec))
            return 0;

        printf("EMBEDDING GENERATED\n");

        for (int i = 0; i < 10 && i < (int)vec.size(); i++)
        {
            printf("%f ", vec[i]);
        }

        printf("\n");

        if (vec.size() != edgerag::EmbeddingEngine::EMBEDDING_DIM)
            return 0;

        std::memcpy(
            out_embedding,
            vec.data(),
            edgerag::EmbeddingEngine::EMBEDDING_DIM * sizeof(float));

        return 1;
    }

    int64_t edgerag_add_document(const char *filename,
                                 const char *file_hash,
                                 const char *file_type,
                                 int32_t page_count,
                                 int64_t file_size,
                                 const char *date_added)
    {
        if (!g_vector_store || !filename || !file_hash)
            return -1;
        return g_vector_store->insert_document(
            filename,
            file_hash,
            file_type ? file_type : "txt",
            page_count,
            file_size,
            date_added ? date_added : "");
    }

    int64_t edgerag_add_chunk(int64_t doc_id,
                              int32_t chunk_index,
                              int32_t page_num,
                              const char *content,
                              const float *embedding_data)
    {
        if (!g_vector_store || !content)
            return -1;
        return g_vector_store->insert_chunk(
            doc_id,
            chunk_index,
            page_num,
            content,
            embedding_data,
            edgerag::EmbeddingEngine::EMBEDDING_DIM);
    }

    int32_t edgerag_search(
        const float *query_vector,
        int32_t top_k,
        char *out_json,
        int32_t max_out_len)
    {
        if (!g_vector_store ||
            !query_vector ||
            !out_json)
        {
            return 0;
        }

        auto results =
            g_vector_store->search(
                query_vector,
                edgerag::EmbeddingEngine::EMBEDDING_DIM,
                top_k);

        std::ostringstream ss;
        ss << "[";

        for (size_t i = 0; i < results.size(); i++)
        {
            if (i > 0)
                ss << ",";

            const auto &r = results[i];

            ss << "{"
               << "\"chunk_id\":" << r.chunk_id << ","
               << "\"doc_id\":" << r.doc_id << ","
               << "\"chunk_index\":" << r.chunk_index << ","
               << "\"page_num\":" << r.page_num << ","
               << "\"score\":" << r.score << ","
               << "\"filename\":\""
               << escape_json(r.filename)
               << "\","
               << "\"content\":\""
               << escape_json(r.content)
               << "\"}";
        }

        ss << "]";

        std::string json = ss.str();

        if ((int)json.size() >= max_out_len)
            return 0;

        strcpy(out_json, json.c_str());

        return (int32_t)results.size();
    }

    int32_t edgerag_check_duplicate(const char *file_hash, int64_t *out_doc_id)
    {
        if (!g_vector_store || !file_hash || !out_doc_id)
            return 0;
        int64_t doc_id = -1;
        bool exists = g_vector_store->check_duplicate_hash(file_hash, doc_id);
        *out_doc_id = doc_id;
        return exists ? 1 : 0;
    }

    int32_t edgerag_list_documents(char *out_json, int32_t max_out_len)
    {
        if (!g_vector_store || !out_json || max_out_len <= 2)
        {
            if (out_json && max_out_len >= 3)
                std::strcpy(out_json, "[]");
            return 0;
        }

        auto docs = g_vector_store->get_all_documents();
        std::ostringstream ss;
        ss << "[";
        for (size_t i = 0; i < docs.size(); ++i)
        {
            const auto &d = docs[i];
            if (i > 0)
                ss << ",";
            ss << "{"
               << "\"id\":" << d.id << ","
               << "\"filename\":\"" << escape_json(d.filename) << "\","
               << "\"file_hash\":\"" << escape_json(d.file_hash) << "\","
               << "\"file_type\":\"" << escape_json(d.file_type) << "\","
               << "\"page_count\":" << d.page_count << ","
               << "\"chunk_count\":" << d.chunk_count << ","
               << "\"date_added\":\"" << escape_json(d.date_added) << "\","
               << "\"file_size\":" << d.file_size
               << "}";
        }
        ss << "]";

        std::string str = ss.str();
        if (static_cast<int>(str.length()) >= max_out_len)
            return 0;
        std::memcpy(out_json, str.c_str(), str.length() + 1);
        return static_cast<int32_t>(docs.size());
    }

    int32_t edgerag_delete_document(int64_t doc_id)
    {
        if (!g_vector_store)
            return 0;
        return g_vector_store->delete_document(doc_id) ? 1 : 0;
    }

    int32_t edgerag_get_stats(int64_t *out_doc_count, int64_t *out_chunk_count, int64_t *out_db_size)
    {
        printf("GET_STATS CALLED\n");
        if (!g_vector_store || !out_doc_count || !out_chunk_count || !out_db_size)
            return 0;
        g_vector_store->get_stats(*out_doc_count, *out_chunk_count, *out_db_size);
        return 1;
    }

    int32_t edgerag_load_llm(const char *gguf_path, int32_t n_ctx, int32_t n_threads)
    {
        if (!g_llama || !gguf_path)
            return 0;
        return g_llama->load_model(gguf_path, n_ctx, n_threads) ? 1 : 0;
    }

    int32_t edgerag_unload_llm()
    {
        if (!g_llama)
            return 0;
        g_llama->unload_model();
        return 1;
    }

    int32_t edgerag_is_llm_loaded()
    {
        if (!g_llama)
            return 0;
        return g_llama->is_loaded() ? 1 : 0;
    }

    int32_t edgerag_generate_start(const char *prompt, float temperature, int32_t max_tokens)
    {
        if (!g_llama || !prompt)
            return 0;
        return g_llama->start_generation(prompt, temperature, max_tokens) ? 1 : 0;
    }

    int32_t edgerag_generate_next_token(char *out_token_buf, int32_t max_len)
    {
        if (!g_llama || !out_token_buf)
            return -1;
        return g_llama->get_next_token(out_token_buf, max_len);
    }

    void edgerag_generate_stop()
    {
        if (g_llama)
        {
            g_llama->cancel_generation();
        }
    }

    int32_t edgerag_import_pack_db(const char *pack_db_path, char *out_error_buf, int32_t max_error_len)
    {
        if (!g_vector_store || !pack_db_path)
            return 0;
        std::string err;
        bool success = edgerag::KnowledgePackManager::import_pack(*g_vector_store, pack_db_path, "{}", err);
        if (!success && out_error_buf && max_error_len > 0)
        {
            std::strncpy(out_error_buf, err.c_str(), max_error_len - 1);
            out_error_buf[max_error_len - 1] = '\0';
        }
        return success ? 1 : 0;
    }

    int32_t edgerag_export_pack_db(const char *dest_db_path, char *out_error_buf, int32_t max_error_len)
    {
        if (!g_vector_store || !dest_db_path)
            return 0;
        edgerag::PackMetadata meta;
        std::string err;
        bool success = edgerag::KnowledgePackManager::export_pack_db(*g_vector_store, dest_db_path, meta, err);
        if (!success && out_error_buf && max_error_len > 0)
        {
            std::strncpy(out_error_buf, err.c_str(), max_error_len - 1);
            out_error_buf[max_error_len - 1] = '\0';
        }
        return success ? 1 : 0;
    }

    void edgerag_dispose()
    {
        if (g_llama)
        {
            g_llama->unload_model();
            g_llama.reset();
        }
        if (g_embedding)
        {
            g_embedding->release();
            g_embedding.reset();
        }
        if (g_vector_store)
        {
            g_vector_store->close();
            g_vector_store.reset();
        }
    }

} // extern "C"
