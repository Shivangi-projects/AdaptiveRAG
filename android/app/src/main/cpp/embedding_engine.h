#ifndef EDGERAG_EMBEDDING_ENGINE_H
#define EDGERAG_EMBEDDING_ENGINE_H

#include <string>
#include <vector>
#include <memory>
#include <cstdint>
#include "tokenizer.h"

// Forward declare ONNX Runtime types
struct OrtApi;
struct OrtEnv;
struct OrtSession;
struct OrtSessionOptions;
struct OrtMemoryInfo;

namespace edgerag {

class EmbeddingEngine {
public:
    static constexpr int EMBEDDING_DIM = 384;
    static constexpr int MAX_SEQ_LEN = 128;

    EmbeddingEngine();
    ~EmbeddingEngine();

    bool init(const std::string& onnx_model_path, const std::string& vocab_path);
    bool is_initialized() const { return initialized_; }

    // Generates a 384-dimensional normalized embedding
    bool embed(const std::string& text, std::vector<float>& out_embedding);

    void release();

private:
    bool initialized_ = false;
    WordPieceTokenizer tokenizer_;

    const OrtApi* ort_ = nullptr;
    OrtEnv* env_ = nullptr;
    OrtSession* session_ = nullptr;
    OrtSessionOptions* session_options_ = nullptr;
    OrtMemoryInfo* memory_info_ = nullptr;

    void mean_pooling_and_normalize(const float* token_embeddings,
                                    const std::vector<int64_t>& attention_mask,
                                    int seq_len,
                                    std::vector<float>& out_embedding);
};

} // namespace edgerag

#endif // EDGERAG_EMBEDDING_ENGINE_H
