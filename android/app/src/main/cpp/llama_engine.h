#ifndef EDGERAG_LLAMA_ENGINE_H
#define EDGERAG_LLAMA_ENGINE_H

#include <string>
#include <vector>
#include <atomic>
#include <mutex>
#include <cstdint>

struct llama_model;
struct llama_context;
struct llama_sampler;

namespace edgerag {

class LlamaEngine {
public:
    LlamaEngine();
    ~LlamaEngine();

    bool load_model(const std::string& model_path, int n_ctx = 1024, int n_threads = 4);
    void unload_model();
    bool is_loaded() const;

    // Start generation session with prompt
    bool start_generation(const std::string& prompt, float temperature = 0.7f, int max_tokens = 512);

    // Fetch the next generated token piece (returns number of bytes written, 0 if done, -1 on error/cancel)
    int get_next_token(char* out_buf, int max_len);

    // Cancel ongoing generation
    void cancel_generation();

    bool is_generating() const { return is_generating_.load(); }
    std::string get_model_path() const { return model_path_; }

private:
    std::string model_path_;
    int n_ctx_ = 1024;
    int n_threads_ = 4;

    llama_model* model_ = nullptr;
    llama_context* ctx_ = nullptr;
    llama_sampler* smpl_ = nullptr;

    std::atomic<bool> is_loaded_{false};
    std::atomic<bool> is_generating_{false};
    std::atomic<bool> cancel_requested_{false};
    std::mutex engine_mutex_;

    int current_pos_ = 0;
    int max_tokens_ = 512;
    int tokens_generated_ = 0;
    int32_t last_token_ = 0;

    void cleanup();
};

} // namespace edgerag

#endif // EDGERAG_LLAMA_ENGINE_H
