#ifndef EDGERAG_KNOWLEDGE_PACK_H
#define EDGERAG_KNOWLEDGE_PACK_H

#include <string>
#include <vector>
#include "vector_store.h"

namespace edgerag {

struct PackMetadata {
    std::string pack_id;
    std::string name;
    std::string version;
    std::string description;
    std::string created_at;
    std::string embedding_model;
    int embedding_dim = 384;
    int doc_count = 0;
    int chunk_count = 0;
};

class KnowledgePackManager {
public:
    KnowledgePackManager();
    ~KnowledgePackManager();

    // Imports a pack into the active vector store
    static bool import_pack(VectorStore& target_store,
                            const std::string& pack_db_path,
                            const std::string& metadata_json,
                            std::string& out_error);

    // Exports the active vector store into a standalone pack database
    static bool export_pack_db(VectorStore& source_store,
                               const std::string& dest_db_path,
                               const PackMetadata& meta,
                               std::string& out_error);
};

} // namespace edgerag

#endif // EDGERAG_KNOWLEDGE_PACK_H
