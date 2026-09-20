#include "knowledge_pack.h"
#include <sstream>
#include <iostream>

namespace edgerag {

KnowledgePackManager::KnowledgePackManager() = default;
KnowledgePackManager::~KnowledgePackManager() = default;

bool KnowledgePackManager::import_pack(VectorStore& target_store,
                                      const std::string& pack_db_path,
                                      const std::string& /*metadata_json*/,
                                      std::string& out_error) {
    sqlite3* db = target_store.get_db_handle();
    if (!db) {
        out_error = "Target database is not open";
        return false;
    }

    // Attach the pack database
    std::string attach_sql = "ATTACH DATABASE '" + pack_db_path + "' AS pack_source;";
    char* err_msg = nullptr;
    int rc = sqlite3_exec(db, attach_sql.c_str(), nullptr, nullptr, &err_msg);
    if (rc != SQLITE_OK) {
        out_error = err_msg ? err_msg : "Failed to attach pack database";
        if (err_msg) sqlite3_free(err_msg);
        return false;
    }

    // Copy documents (maintaining unique file_hash)
    const char* merge_docs_sql =
        "INSERT OR IGNORE INTO documents (filename, file_hash, file_type, page_count, chunk_count, date_added, file_size) "
        "SELECT filename, file_hash, file_type, page_count, chunk_count, date_added, file_size FROM pack_source.documents;";
    sqlite3_exec(db, merge_docs_sql, nullptr, nullptr, nullptr);

    // Copy chunks with updated doc_id
    const char* merge_chunks_sql =
        "INSERT INTO chunks (doc_id, chunk_index, page_num, content, embedding) "
        "SELECT d.id, c.chunk_index, c.page_num, c.content, c.embedding "
        "FROM pack_source.chunks c "
        "JOIN pack_source.documents sd ON c.doc_id = sd.id "
        "JOIN documents d ON sd.file_hash = d.file_hash;";
    sqlite3_exec(db, merge_chunks_sql, nullptr, nullptr, nullptr);

    // Detach pack database
    sqlite3_exec(db, "DETACH DATABASE pack_source;", nullptr, nullptr, nullptr);
    return true;
}

bool KnowledgePackManager::export_pack_db(VectorStore& source_store,
                                         const std::string& dest_db_path,
                                         const PackMetadata& /*meta*/,
                                         std::string& out_error) {
    sqlite3* src_db = source_store.get_db_handle();
    if (!src_db) {
        out_error = "Source database is not open";
        return false;
    }

    std::string attach_sql = "ATTACH DATABASE '" + dest_db_path + "' AS pack_dest;";
    char* err_msg = nullptr;
    int rc = sqlite3_exec(src_db, attach_sql.c_str(), nullptr, nullptr, &err_msg);
    if (rc != SQLITE_OK) {
        out_error = err_msg ? err_msg : "Failed to create/attach export database";
        if (err_msg) sqlite3_free(err_msg);
        return false;
    }

    // Create tables in pack_dest
    const char* create_sql =
        "CREATE TABLE IF NOT EXISTS pack_dest.documents ("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  filename TEXT NOT NULL,"
        "  file_hash TEXT NOT NULL UNIQUE,"
        "  file_type TEXT,"
        "  page_count INTEGER DEFAULT 1,"
        "  chunk_count INTEGER DEFAULT 0,"
        "  date_added TEXT,"
        "  file_size INTEGER DEFAULT 0"
        ");"
        "CREATE TABLE IF NOT EXISTS pack_dest.chunks ("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  doc_id INTEGER NOT NULL,"
        "  chunk_index INTEGER NOT NULL,"
        "  page_num INTEGER DEFAULT 1,"
        "  content TEXT NOT NULL,"
        "  embedding BLOB"
        ");";
    sqlite3_exec(src_db, create_sql, nullptr, nullptr, nullptr);

    // Copy records
    sqlite3_exec(src_db, "INSERT INTO pack_dest.documents SELECT * FROM documents;", nullptr, nullptr, nullptr);
    sqlite3_exec(src_db, "INSERT INTO pack_dest.chunks SELECT * FROM chunks;", nullptr, nullptr, nullptr);

    sqlite3_exec(src_db, "DETACH DATABASE pack_dest;", nullptr, nullptr, nullptr);
    return true;
}

} // namespace edgerag
