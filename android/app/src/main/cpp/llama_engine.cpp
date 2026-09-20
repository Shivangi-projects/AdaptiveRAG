#include "llama_engine.h"
#include <cstring>
#include <iostream>

#if __has_include("llama.h")
#include "llama.h"
#define HAVE_LLAMA_CPP 1
#else
#define HAVE_LLAMA_CPP 0
#endif

namespace edgerag {

LlamaEngine::LlamaEngine() {
#if HAVE_LLAMA_CPP
    llama_backend_init();
#endif
}

LlamaEngine::~LlamaEngine() {
    unload_model();
#if HAVE_LLAMA_CPP
    llama_backend_free();
#endif
}

void LlamaEngine::cleanup() {
#if HAVE_LLAMA_CPP
    if (smpl_) {
        llama_sampler_free(smpl_);
        smpl_ = nullptr;
    }
    if (ctx_) {
        llama_free(ctx_);
        ctx_ = nullptr;
    }
    if (model_) {
        llama_free_model(model_);
        model_ = nullptr;
    }
#endif
    is_loaded_.store(false);
    is_generating_.store(false);
}

bool LlamaEngine::load_model(const std::string& model_path, int n_ctx, int n_threads) {
    std::lock_guard<std::mutex> lock(engine_mutex_);
    cleanup();

    model_path_ = model_path;
    n_ctx_ = (n_ctx > 0) ? n_ctx : 1024;
    n_threads_ = (n_threads > 0) ? n_threads : 4;

#if HAVE_LLAMA_CPP
    llama_model_params model_params = llama_model_default_params();
    model_params.use_mmap = true;

    model_ = llama_load_model_from_file(model_path.c_str(), model_params);
    if (!model_) {
        return false;
    }

    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = n_ctx_;
    ctx_params.n_threads = n_threads_;
    ctx_params.n_threads_batch = n_threads_;

    ctx_ = llama_new_context_with_model(model_, ctx_params);
    if (!ctx_) {
        llama_free_model(model_);
        model_ = nullptr;
        return false;
    }

    is_loaded_.store(true);
    return true;
#else
    // Simulated load for architectures where llama.h is compiled separately
    is_loaded_.store(!model_path.empty());
    return is_loaded_.load();
#endif
}

void LlamaEngine::unload_model() {
    std::lock_guard<std::mutex> lock(engine_mutex_);
    cancel_generation();
    cleanup();
    model_path_.clear();
}

bool LlamaEngine::is_loaded() const {
    return is_loaded_.load();
}

void LlamaEngine::cancel_generation() {
    cancel_requested_.store(true);
    is_generating_.store(false);
}

bool LlamaEngine::start_generation(const std::string& prompt, float temperature, int max_tokens) {
    std::lock_guard<std::mutex> lock(engine_mutex_);

    if (!is_loaded_.load()) {
        return false;
    }

    cancel_requested_.store(false);
    is_generating_.store(true);
    tokens_generated_ = 0;
    max_tokens_ = (max_tokens > 0) ? max_tokens : 512;
    current_pos_ = 0;

#if HAVE_LLAMA_CPP
    if (!ctx_ || !model_) return false;

    if (smpl_) {
        llama_sampler_free(smpl_);
    }
    smpl_ = (temperature > 0.0f) ? llama_sampler_init_temp(temperature) : llama_sampler_init_greedy();

    // Tokenize the prompt
    int n_prompt = -llama_tokenize(model_, prompt.c_str(), static_cast<int32_t>(prompt.length()), nullptr, 0, true, true);
    std::vector<llama_token> prompt_tokens(n_prompt);
    if (llama_tokenize(model_, prompt.c_str(), static_cast<int32_t>(prompt.length()), prompt_tokens.data(), static_cast<int32_t>(prompt_tokens.size()), true, true) < 0) {
        is_generating_.store(false);
        return false;
    }

    // Evaluate prompt tokens in batch
    llama_batch batch = llama_batch_get_one(prompt_tokens.data(), static_cast<int32_t>(prompt_tokens.size()));
    if (llama_decode(ctx_, batch) != 0) {
        is_generating_.store(false);
        return false;
    }

    current_pos_ = static_cast<int>(prompt_tokens.size());
    return true;
#else
    return true;
#endif
}

int LlamaEngine::get_next_token(char* out_buf, int max_len) {
    if (!is_generating_.load() || cancel_requested_.load() || out_buf == nullptr || max_len <= 1) {
        is_generating_.store(false);
        return 0; // Finished or canceled
    }

    if (tokens_generated_ >= max_tokens_) {
        is_generating_.store(false);
        return 0;
    }

#if HAVE_LLAMA_CPP
    std::lock_guard<std::mutex> lock(engine_mutex_);
    if (!ctx_ || !model_ || !smpl_) {
        is_generating_.store(false);
        return -1;
    }

    llama_token new_token_id = llama_sampler_sample(smpl_, ctx_, -1);
    llama_sampler_accept(smpl_, new_token_id);

    // Check for EOS
    if (llama_token_is_eog(model_, new_token_id)) {
        is_generating_.store(false);
        return 0;
    }

    char piece[128];
    int n_piece = llama_token_to_piece(model_, new_token_id, piece, sizeof(piece), 0, true);
    if (n_piece < 0) {
        is_generating_.store(false);
        return -1;
    }

    int copy_len = (n_piece < max_len - 1) ? n_piece : (max_len - 1);
    std::memcpy(out_buf, piece, copy_len);
    out_buf[copy_len] = '\0';

    tokens_generated_++;

    // Prepare next token decode
    llama_batch batch = llama_batch_get_one(&new_token_id, 1);
    if (llama_decode(ctx_, batch) != 0) {
        is_generating_.store(false);
        return copy_len;
    }
    current_pos_++;

    return copy_len;
#else
    // Generation placeholder when running in mock / desktop harness
    is_generating_.store(false);
    return 0;
#endif
}

} // namespace edgerag
