#ifndef EDGERAG_VECTOR_STORE_H
#define EDGERAG_VECTOR_STORE_H

#include <string>
#include <vector>
#include <cstdint>
#include <sqlite3.h>

namespace edgerag
{

    struct SearchResult
    {
        int64_t chunk_id = 0;
        int64_t doc_id = 0;
        int32_t chunk_index = 0;
        int32_t page_num = 0;
        float score = 0.0f;
        std::string filename;
        std::string content;
    };

    struct DocumentRecord
    {
        int64_t id = 0;
        std::string filename;
        std::string file_hash;
        std::string file_type;
        int32_t page_count = 0;
        int32_t chunk_count = 0;
        std::string date_added;
        int64_t file_size = 0;
    };

    struct KnowledgePackRecord
    {
        int64_t id = 0;
        std::string pack_id;
        std::string name;
        std::string version;
        std::string description;
        int32_t doc_count = 0;
        int32_t chunk_count = 0;
        bool is_active = false;
    };

    class VectorStore
    {
    public:
        VectorStore();
        ~VectorStore();

        bool open(const std::string &db_path);
        void close();
        bool is_open() const { return db_ != nullptr; }

        int64_t insert_document(const std::string &filename,
                                const std::string &file_hash,
                                const std::string &file_type,
                                int32_t page_count,
                                int64_t file_size,
                                const std::string &date_added);

        bool check_duplicate_hash(const std::string &file_hash, int64_t &out_doc_id);

        int64_t insert_chunk(int64_t doc_id,
                             int32_t chunk_index,
                             int32_t page_num,
                             const std::string &content,
                             const float *embedding_data,
                             int embedding_dim = 384);

        std::vector<SearchResult> search(const float *query_vector, int embedding_dim, int top_k);

        bool delete_document(int64_t doc_id);

        std::vector<DocumentRecord> get_all_documents();

        void get_stats(int64_t &out_doc_count, int64_t &out_chunk_count, int64_t &out_db_size);

        std::string get_db_path() const { return db_path_; }
        sqlite3 *get_db_handle() { return db_; }

    private:
        sqlite3 *db_ = nullptr;
        std::string db_path_;

        bool create_tables();
        static float compute_cosine_similarity(const float *a, const float *b, int dim);
    };

} // namespace edgerag

#endif // EDGERAG_VECTOR_STORE_H
