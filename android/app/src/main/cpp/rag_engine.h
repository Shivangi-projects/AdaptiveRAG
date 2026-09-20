#ifndef EDGERAG_RAG_ENGINE_H
#define EDGERAG_RAG_ENGINE_H

#include <cstdint>

#ifdef __cplusplus
extern "C"
{
#endif

    // Returns 1 on success, 0 on failure
    int32_t edgerag_init(const char *db_path, const char *onnx_path, const char *vocab_path);

    // Generates 384-D embedding into out_embedding float array
    int32_t edgerag_embed_text(const char *text, float *out_embedding);

    // Document indexing
    int64_t edgerag_add_document(const char *filename,
                                 const char *file_hash,
                                 const char *file_type,
                                 int32_t page_count,
                                 int64_t file_size,
                                 const char *date_added);

    // Chunk indexing
    int64_t edgerag_add_chunk(int64_t doc_id,
                              int32_t chunk_index,
                              int32_t page_num,
                              const char *content,
                              const float *embedding_data);

    // Vector search: writes JSON array to out_json
    int32_t edgerag_search(const float *query_vector, int32_t top_k, char *out_json, int32_t max_out_len);

    // Duplicate check
    int32_t edgerag_check_duplicate(const char *file_hash, int64_t *out_doc_id);

    // List documents JSON
    int32_t edgerag_list_documents(char *out_json, int32_t max_out_len);

    // Delete document
    int32_t edgerag_delete_document(int64_t doc_id);

    // Stats
    int32_t edgerag_get_stats(int64_t *out_doc_count, int64_t *out_chunk_count, int64_t *out_db_size);

    // LLM management
    int32_t edgerag_load_llm(const char *gguf_path, int32_t n_ctx, int32_t n_threads);
    int32_t edgerag_unload_llm();
    int32_t edgerag_is_llm_loaded();

    // LLM generation
    int32_t edgerag_generate_start(const char *prompt, float temperature, int32_t max_tokens);
    int32_t edgerag_generate_next_token(char *out_token_buf, int32_t max_len);
    void edgerag_generate_stop();

    // Knowledge pack DB operations
    int32_t edgerag_import_pack_db(const char *pack_db_path, char *out_error_buf, int32_t max_error_len);
    int32_t edgerag_export_pack_db(const char *dest_db_path, char *out_error_buf, int32_t max_error_len);

    // Cleanup
    void edgerag_dispose();

#ifdef __cplusplus
}
#endif

#endif // EDGERAG_RAG_ENGINE_H
