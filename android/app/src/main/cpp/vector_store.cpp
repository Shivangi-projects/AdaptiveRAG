#include <android/log.h>
#include "vector_store.h"
#include <algorithm>
#include <cmath>
#include <cstring>
#include <sys/stat.h>

namespace edgerag
{

    VectorStore::VectorStore() = default;

    VectorStore::~VectorStore()
    {
        close();
    }

    bool VectorStore::open(const std::string &db_path)
    {
        close();
        db_path_ = db_path;

        int rc = sqlite3_open(db_path_.c_str(), &db_);
        if (rc != SQLITE_OK)
        {
            close();
            return false;
        }

        // Enable WAL mode for high concurrency
        sqlite3_exec(db_, "PRAGMA journal_mode=WAL;", nullptr, nullptr, nullptr);
        sqlite3_exec(db_, "PRAGMA synchronous=NORMAL;", nullptr, nullptr, nullptr);
        sqlite3_exec(db_, "PRAGMA foreign_keys=ON;", nullptr, nullptr, nullptr);

        return create_tables();
    }

    void VectorStore::close()
    {
        if (db_)
        {
            sqlite3_close(db_);
            db_ = nullptr;
        }
    }

    bool VectorStore::create_tables()
    {
        if (!db_)
            return false;

        const char *sql =
            "CREATE TABLE IF NOT EXISTS documents ("
            "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
            "  filename TEXT NOT NULL,"
            "  file_hash TEXT NOT NULL UNIQUE,"
            "  file_type TEXT,"
            "  page_count INTEGER DEFAULT 1,"
            "  chunk_count INTEGER DEFAULT 0,"
            "  date_added TEXT,"
            "  file_size INTEGER DEFAULT 0"
            ");"
            "CREATE TABLE IF NOT EXISTS chunks ("
            "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
            "  doc_id INTEGER NOT NULL,"
            "  chunk_index INTEGER NOT NULL,"
            "  page_num INTEGER DEFAULT 1,"
            "  content TEXT NOT NULL,"
            "  embedding BLOB,"
            "  FOREIGN KEY(doc_id) REFERENCES documents(id) ON DELETE CASCADE"
            ");"
            "CREATE TABLE IF NOT EXISTS knowledge_packs ("
            "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
            "  pack_id TEXT NOT NULL UNIQUE,"
            "  name TEXT NOT NULL,"
            "  version TEXT,"
            "  description TEXT,"
            "  doc_count INTEGER DEFAULT 0,"
            "  chunk_count INTEGER DEFAULT 0,"
            "  is_active INTEGER DEFAULT 0"
            ");"
            "CREATE INDEX IF NOT EXISTS idx_chunks_doc_id ON chunks(doc_id);"
            "CREATE INDEX IF NOT EXISTS idx_documents_hash ON documents(file_hash);";

        char *err_msg = nullptr;
        int rc = sqlite3_exec(db_, sql, nullptr, nullptr, &err_msg);
        if (rc != SQLITE_OK)
        {
            if (err_msg)
                sqlite3_free(err_msg);
            return false;
        }
        return true;
    }

    int64_t VectorStore::insert_document(const std::string &filename,
                                         const std::string &file_hash,
                                         const std::string &file_type,
                                         int32_t page_count,
                                         int64_t file_size,
                                         const std::string &date_added)
    {
        if (!db_)
            return -1;

        const char *sql = "INSERT INTO documents (filename, file_hash, file_type, page_count, chunk_count, date_added, file_size) "
                          "VALUES (?, ?, ?, ?, 0, ?, ?) "
                          "ON CONFLICT(file_hash) DO UPDATE SET filename=excluded.filename RETURNING id;";

        sqlite3_stmt *stmt = nullptr;
        if (sqlite3_prepare_v2(db_, sql, -1, &stmt, nullptr) != SQLITE_OK)
        {
            return -1;
        }

        sqlite3_bind_text(stmt, 1, filename.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 2, file_hash.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 3, file_type.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_int(stmt, 4, page_count);
        sqlite3_bind_text(stmt, 5, date_added.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64(stmt, 6, file_size);

        int64_t doc_id = -1;
        if (sqlite3_step(stmt) == SQLITE_ROW)
        {
            doc_id = sqlite3_column_int64(stmt, 0);
        }
        sqlite3_finalize(stmt);
        return doc_id;
    }

    bool VectorStore::check_duplicate_hash(const std::string &file_hash, int64_t &out_doc_id)
    {
        if (!db_)
            return false;

        const char *sql = "SELECT id FROM documents WHERE file_hash = ? LIMIT 1;";
        sqlite3_stmt *stmt = nullptr;
        if (sqlite3_prepare_v2(db_, sql, -1, &stmt, nullptr) != SQLITE_OK)
        {
            return false;
        }

        sqlite3_bind_text(stmt, 1, file_hash.c_str(), -1, SQLITE_TRANSIENT);
        bool found = false;
        if (sqlite3_step(stmt) == SQLITE_ROW)
        {
            out_doc_id = sqlite3_column_int64(stmt, 0);
            found = true;
        }
        sqlite3_finalize(stmt);
        return found;
    }

    int64_t VectorStore::insert_chunk(int64_t doc_id,
                                      int32_t chunk_index,
                                      int32_t page_num,
                                      const std::string &content,
                                      const float *embedding_data,
                                      int embedding_dim)
    {
        __android_log_print(
            ANDROID_LOG_ERROR,
            "EDGERAG",
            "INSERTING CHUNK doc=%ld",
            doc_id);
        if (embedding_data == nullptr)
        {
            __android_log_print(
                ANDROID_LOG_ERROR,
                "EDGERAG",
                "embedding_data is NULL");
        }
        else
        {
            __android_log_print(
                ANDROID_LOG_ERROR,
                "EDGERAG",
                "embedding_dim=%d",
                embedding_dim);
        }
        for (int i = 0; i < 10; i++)
        {
            __android_log_print(
                ANDROID_LOG_ERROR,
                "EDGERAG",
                "EMB[%d] = %f",
                i,
                embedding_data[i]);
        }
        printf("DOC=%lld\n", doc_id);

        for (int i = 0; i < 5; i++)
        {
            printf("%f ", embedding_data[i]);
        }

        printf("\n");
        if (!db_)
            return -1;

        const char *sql = "INSERT INTO chunks (doc_id, chunk_index, page_num, content, embedding) VALUES (?, ?, ?, ?, ?);";
        sqlite3_stmt *stmt = nullptr;
        if (sqlite3_prepare_v2(db_, sql, -1, &stmt, nullptr) != SQLITE_OK)
        {
            return -1;
        }

        sqlite3_bind_int64(stmt, 1, doc_id);
        sqlite3_bind_int(stmt, 2, chunk_index);
        sqlite3_bind_int(stmt, 3, page_num);
        sqlite3_bind_text(stmt, 4, content.c_str(), -1, SQLITE_TRANSIENT);
        if (embedding_data != nullptr && embedding_dim > 0)
        {
            sqlite3_bind_blob(stmt, 5, embedding_data, embedding_dim * sizeof(float), SQLITE_TRANSIENT);
        }
        else
        {
            sqlite3_bind_null(stmt, 5);
        }

        int64_t chunk_id = -1;
        if (sqlite3_step(stmt) == SQLITE_DONE)
        {
            chunk_id = sqlite3_last_insert_rowid(db_);
            // Update document chunk count
            const char *upd_sql = "UPDATE documents SET chunk_count = chunk_count + 1 WHERE id = ?;";
            sqlite3_stmt *upd_stmt = nullptr;
            if (sqlite3_prepare_v2(db_, upd_sql, -1, &upd_stmt, nullptr) == SQLITE_OK)
            {
                sqlite3_bind_int64(upd_stmt, 1, doc_id);
                sqlite3_step(upd_stmt);
                sqlite3_finalize(upd_stmt);
            }
        }
        sqlite3_finalize(stmt);
        return chunk_id;
    }

    float VectorStore::compute_cosine_similarity(
        const float *a,
        const float *b,
        int dim)
    {

        float dot = 0.0f;
        float normA = 0.0f;
        float normB = 0.0f;

        for (int i = 0; i < dim; ++i)
        {
            dot += a[i] * b[i];
            normA += a[i] * a[i];
            normB += b[i] * b[i];
        }

        if (normA == 0.0f || normB == 0.0f)
        {
            return 0.0f;
        }

        return dot / (sqrtf(normA) * sqrtf(normB));
    }

    std::vector<SearchResult> VectorStore::search(const float *query_vector, int embedding_dim, int top_k)
    {

        printf("SEARCH CALLED\n");
        printf("DB OPEN = %p\n", db_);
        std::vector<SearchResult> results;
        if (!db_ || query_vector == nullptr || embedding_dim <= 0 || top_k <= 0)
        {
            return results;
        }
        float queryNorm = 0.0f;

        for (int i = 0; i < embedding_dim; i++)
        {
            queryNorm += query_vector[i] * query_vector[i];
        }

        queryNorm = sqrtf(queryNorm);

        __android_log_print(
            ANDROID_LOG_ERROR,
            "EDGERAG",
            "QUERY_NORM=%f",
            queryNorm);

        const char *sql =
            "SELECT c.id, c.doc_id, c.chunk_index, c.page_num, c.content, c.embedding, d.filename "
            "FROM chunks c "
            "JOIN documents d ON c.doc_id = d.id;";

        sqlite3_stmt *stmt = nullptr;
        if (sqlite3_prepare_v2(db_, sql, -1, &stmt, nullptr) != SQLITE_OK)
        {
            return results;
        }

        struct Candidate
        {
            SearchResult res;
            float score;
        };
        std::vector<Candidate> candidates;
        __android_log_print(
            ANDROID_LOG_ERROR,
            "EDGERAG",
            "ROW FOUND");
        while (sqlite3_step(stmt) == SQLITE_ROW)
        {
            printf("CHUNK FOUND IN DB\n");
            printf("ROW FOUND\n");
            int64_t chunk_id = sqlite3_column_int64(stmt, 0);
            int64_t doc_id = sqlite3_column_int64(stmt, 1);
            int32_t chunk_index = sqlite3_column_int(stmt, 2);
            int32_t page_num = sqlite3_column_int(stmt, 3);
            const char *content = reinterpret_cast<const char *>(sqlite3_column_text(stmt, 4));
            const void *blob = sqlite3_column_blob(stmt, 5);
            int blob_bytes = sqlite3_column_bytes(stmt, 5);
            __android_log_print(
                ANDROID_LOG_ERROR,
                "EDGERAG",
                "chunk=%lld blob_bytes=%d expected=%d",
                sqlite3_column_int64(stmt, 0),
                blob_bytes,
                embedding_dim * (int)sizeof(float));
            const char *filename = reinterpret_cast<const char *>(sqlite3_column_text(stmt, 6));
            printf("blob_bytes=%d\n", blob_bytes);
            printf("expected=%zu\n", embedding_dim * sizeof(float));
            if (blob_bytes > 0)
            {
                const float *v = static_cast<const float *>(blob);

                printf("FIRST 5 VALUES: ");
                for (int i = 0; i < 5; i++)
                {
                    printf("%f ", v[i]);
                }
                printf("\n");
            }
            printf(
                "blob_bytes=%d expected=%d\n",
                blob_bytes,
                embedding_dim * (int)sizeof(float));
            if (blob && blob_bytes == embedding_dim * static_cast<int>(sizeof(float)))
            {
                const float *chunk_vec = static_cast<const float *>(blob);

                float queryNorm = 0.0f;
                float chunkNorm = 0.0f;

                for (int i = 0; i < embedding_dim; i++)
                {
                    queryNorm += query_vector[i] * query_vector[i];
                    chunkNorm += chunk_vec[i] * chunk_vec[i];
                }

                __android_log_print(
                    ANDROID_LOG_ERROR,
                    "EDGERAG",
                    "queryNorm=%f chunkNorm=%f",
                    sqrtf(queryNorm),
                    sqrtf(chunkNorm));

                float score = compute_cosine_similarity(
                    query_vector,
                    chunk_vec,
                    embedding_dim);

                __android_log_print(
                    ANDROID_LOG_ERROR,
                    "EDGERAG",
                    "chunk=%ld score=%f",
                    chunk_id,
                    score);

                SearchResult sr;
                sr.chunk_id = chunk_id;
                sr.doc_id = doc_id;
                sr.chunk_index = chunk_index;
                sr.page_num = page_num;
                sr.score = score;
                sr.content = content ? content : "";
                sr.filename = filename ? filename : "";

                candidates.push_back({sr, score});
            }
        }
        sqlite3_finalize(stmt);

        // Sort candidates descending by score
        std::sort(candidates.begin(), candidates.end(), [](const Candidate &a, const Candidate &b)
                  { return a.score > b.score; });

        int count = std::min(top_k, static_cast<int>(candidates.size()));
        results.reserve(count);
        for (int i = 0; i < count; ++i)
        {
            results.push_back(candidates[i].res);
        }

        return results;
    }

    bool VectorStore::delete_document(int64_t doc_id)
    {
        if (!db_)
            return false;

        // Delete chunks first (or cascaded)
        const char *sql1 = "DELETE FROM chunks WHERE doc_id = ?;";
        sqlite3_stmt *stmt1 = nullptr;
        if (sqlite3_prepare_v2(db_, sql1, -1, &stmt1, nullptr) == SQLITE_OK)
        {
            sqlite3_bind_int64(stmt1, 1, doc_id);
            sqlite3_step(stmt1);
            sqlite3_finalize(stmt1);
        }

        const char *sql2 = "DELETE FROM documents WHERE id = ?;";
        sqlite3_stmt *stmt2 = nullptr;
        bool success = false;
        if (sqlite3_prepare_v2(db_, sql2, -1, &stmt2, nullptr) == SQLITE_OK)
        {
            sqlite3_bind_int64(stmt2, 1, doc_id);
            success = (sqlite3_step(stmt2) == SQLITE_DONE);
            sqlite3_finalize(stmt2);
        }

        return success;
    }

    std::vector<DocumentRecord> VectorStore::get_all_documents()
    {
        std::vector<DocumentRecord> docs;
        if (!db_)
            return docs;

        const char *sql = "SELECT id, filename, file_hash, file_type, page_count, chunk_count, date_added, file_size FROM documents ORDER BY id DESC;";
        sqlite3_stmt *stmt = nullptr;
        if (sqlite3_prepare_v2(db_, sql, -1, &stmt, nullptr) != SQLITE_OK)
        {
            return docs;
        }

        while (sqlite3_step(stmt) == SQLITE_ROW)
        {
            DocumentRecord doc;
            doc.id = sqlite3_column_int64(stmt, 0);
            const char *fn = reinterpret_cast<const char *>(sqlite3_column_text(stmt, 1));
            const char *fh = reinterpret_cast<const char *>(sqlite3_column_text(stmt, 2));
            const char *ft = reinterpret_cast<const char *>(sqlite3_column_text(stmt, 3));
            doc.filename = fn ? fn : "";
            doc.file_hash = fh ? fh : "";
            doc.file_type = ft ? ft : "";
            doc.page_count = sqlite3_column_int(stmt, 4);
            doc.chunk_count = sqlite3_column_int(stmt, 5);
            const char *da = reinterpret_cast<const char *>(sqlite3_column_text(stmt, 6));
            doc.date_added = da ? da : "";
            doc.file_size = sqlite3_column_int64(stmt, 7);
            docs.push_back(doc);
        }
        sqlite3_finalize(stmt);
        return docs;
    }

    void VectorStore::get_stats(int64_t &out_doc_count, int64_t &out_chunk_count, int64_t &out_db_size)
    {
        out_doc_count = 0;
        out_chunk_count = 0;
        out_db_size = 0;

        if (!db_)
            return;

        const char *sql1 = "SELECT COUNT(*) FROM documents;";
        sqlite3_stmt *s1 = nullptr;
        if (sqlite3_prepare_v2(db_, sql1, -1, &s1, nullptr) == SQLITE_OK)
        {
            if (sqlite3_step(s1) == SQLITE_ROW)
                out_doc_count = sqlite3_column_int64(s1, 0);
            sqlite3_finalize(s1);
        }

        const char *sql2 = "SELECT COUNT(*) FROM chunks;";
        sqlite3_stmt *s2 = nullptr;
        if (sqlite3_prepare_v2(db_, sql2, -1, &s2, nullptr) == SQLITE_OK)
        {
            if (sqlite3_step(s2) == SQLITE_ROW)
                out_chunk_count = sqlite3_column_int64(s2, 0);
            sqlite3_finalize(s2);
        }

        struct stat st;
        if (stat(db_path_.c_str(), &st) == 0)
        {
            out_db_size = st.st_size;
        }
    }

} // namespace edgerag
