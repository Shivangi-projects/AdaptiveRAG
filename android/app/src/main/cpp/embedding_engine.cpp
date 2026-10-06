#include <android/log.h>
#include "embedding_engine.h"
#include <cmath>
#include <cstring>
#include <iostream>

#if __has_include(<onnxruntime_c_api.h>)
#include <onnxruntime_c_api.h>
#include <dlfcn.h>
#define HAVE_ONNX_RUNTIME 1
#else
#define HAVE_ONNX_RUNTIME 0
#endif

namespace edgerag
{

    EmbeddingEngine::EmbeddingEngine() = default;

    EmbeddingEngine::~EmbeddingEngine()
    {
        release();
    }

    void EmbeddingEngine::release()
    {
#if HAVE_ONNX_RUNTIME
        if (ort_)
        {
            if (session_)
            {
                ort_->ReleaseSession(session_);
                session_ = nullptr;
            }
            if (session_options_)
            {
                ort_->ReleaseSessionOptions(session_options_);
                session_options_ = nullptr;
            }
            if (memory_info_)
            {
                ort_->ReleaseMemoryInfo(memory_info_);
                memory_info_ = nullptr;
            }
            if (env_)
            {
                ort_->ReleaseEnv(env_);
                env_ = nullptr;
            }
        }
#endif
        initialized_ = false;
    }

    bool EmbeddingEngine::init(const std::string &onnx_model_path, const std::string &vocab_path)
    {
        release();

        if (!tokenizer_.load_vocab(vocab_path))
        {
            return false;
        }

#if HAVE_ONNX_RUNTIME
        typedef const OrtApiBase *(*OrtGetApiBaseFn)(void);
        OrtGetApiBaseFn get_api_base = nullptr;

        void *ort_lib = dlopen("libonnxruntime.so", RTLD_NOW | RTLD_GLOBAL);
        if (ort_lib)
        {
            get_api_base = (OrtGetApiBaseFn)dlsym(ort_lib, "OrtGetApiBase");
        }
        if (!get_api_base)
        {
            get_api_base = (OrtGetApiBaseFn)dlsym(RTLD_DEFAULT, "OrtGetApiBase");
        }
        if (!get_api_base)
        {
            return false;
        }

        const OrtApiBase *api_base = get_api_base();
        if (!api_base)
        {
            return false;
        }

        ort_ = api_base->GetApi(ORT_API_VERSION);
        if (!ort_)
        {
            return false;
        }

        OrtStatus *status = ort_->CreateEnv(ORT_LOGGING_LEVEL_WARNING, "EdgeRAG_Embeddings", &env_);
        if (status != nullptr)
        {
            ort_->ReleaseStatus(status);
            return false;
        }

        status = ort_->CreateSessionOptions(&session_options_);
        if (status != nullptr)
        {
            ort_->ReleaseStatus(status);
            return false;
        }

        ort_->SetIntraOpNumThreads(session_options_, 2);
        ort_->SetSessionGraphOptimizationLevel(session_options_, ORT_ENABLE_ALL);

        status = ort_->CreateCpuMemoryInfo(OrtArenaAllocator, OrtMemTypeDefault, &memory_info_);
        if (status != nullptr)
        {
            ort_->ReleaseStatus(status);
            return false;
        }

        status = ort_->CreateSession(
            env_,
            onnx_model_path.c_str(),
            session_options_,
            &session_);

        if (status != nullptr)
        {
            ort_->ReleaseStatus(status);
            return false;
        }

        __android_log_print(
            ANDROID_LOG_ERROR,
            "EMBED",
            "ONNX INIT SUCCESS");

        initialized_ = true;
        return true;
#else
        // Fallback stub if ONNX runtime is compiled without header (test environments)
        initialized_ = true;
        return true;
#endif
    }

    void EmbeddingEngine::mean_pooling_and_normalize(const float *token_embeddings,
                                                     const std::vector<int64_t> &attention_mask,
                                                     int seq_len,
                                                     std::vector<float> &out_embedding)
    {
        out_embedding.assign(EMBEDDING_DIM, 0.0f);
        int active_tokens = 0;

        for (int t = 0; t < seq_len; ++t)
        {
            if (attention_mask[t] == 1)
            {
                active_tokens++;
                for (int d = 0; d < EMBEDDING_DIM; ++d)
                {
                    out_embedding[d] += token_embeddings[t * EMBEDDING_DIM + d];
                }
            }
        }

        if (active_tokens > 0)
        {
            for (int d = 0; d < EMBEDDING_DIM; ++d)
            {
                out_embedding[d] /= static_cast<float>(active_tokens);
            }
        }

        // L2 normalize
        float sum_sq = 0.0f;
        for (int d = 0; d < EMBEDDING_DIM; ++d)
        {
            sum_sq += out_embedding[d] * out_embedding[d];
        }
        float norm = std::sqrt(sum_sq);
        if (norm > 1e-12f)
        {
            for (int d = 0; d < EMBEDDING_DIM; ++d)
            {
                out_embedding[d] /= norm;
            }
        }
    }

    bool EmbeddingEngine::embed(const std::string &text, std::vector<float> &out_embedding)
    {
        if (!initialized_)
        {
            return false;
        }

        std::vector<int64_t> input_ids;
        std::vector<int64_t> attention_mask;
        std::vector<int64_t> token_type_ids;

        tokenizer_.tokenize(text, MAX_SEQ_LEN, input_ids, attention_mask, token_type_ids);
        int seq_len = static_cast<int>(input_ids.size());

#if HAVE_ONNX_RUNTIME
        if (!ort_ || !session_ || !memory_info_)
        {
            return false;
        }

        int64_t input_shape[2] = {1, seq_len};
        size_t input_tensor_size = seq_len * sizeof(int64_t);

        OrtValue *in_tensors[3] = {nullptr, nullptr, nullptr};

        OrtStatus *s1 = ort_->CreateTensorWithDataAsOrtValue(
            memory_info_, input_ids.data(), input_tensor_size, input_shape, 2, ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64, &in_tensors[0]);
        OrtStatus *s2 = ort_->CreateTensorWithDataAsOrtValue(
            memory_info_, attention_mask.data(), input_tensor_size, input_shape, 2, ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64, &in_tensors[1]);
        OrtStatus *s3 = ort_->CreateTensorWithDataAsOrtValue(
            memory_info_, token_type_ids.data(), input_tensor_size, input_shape, 2, ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64, &in_tensors[2]);

        if (s1 != nullptr || s2 != nullptr || s3 != nullptr)
        {
            if (s1)
                ort_->ReleaseStatus(s1);
            if (s2)
                ort_->ReleaseStatus(s2);
            if (s3)
                ort_->ReleaseStatus(s3);
            for (int i = 0; i < 3; ++i)
            {
                if (in_tensors[i])
                    ort_->ReleaseValue(in_tensors[i]);
            }
            return false;
        }

        const char *input_names[] = {"input_ids", "attention_mask", "token_type_ids"};
        const char *output_names[] = {"last_hidden_state"};
        OrtValue *out_tensor = nullptr;

        OrtStatus *run_status = ort_->Run(session_, nullptr, input_names, in_tensors, 3, output_names, 1, &out_tensor);

        for (int i = 0; i < 3; ++i)
        {
            if (in_tensors[i])
                ort_->ReleaseValue(in_tensors[i]);
        }

        if (run_status != nullptr || out_tensor == nullptr)
        {
            if (run_status)
                ort_->ReleaseStatus(run_status);
            if (out_tensor)
                ort_->ReleaseValue(out_tensor);
            return false;
        }

        float *raw_output = nullptr;
        ort_->GetTensorMutableData(out_tensor, reinterpret_cast<void **>(&raw_output));

        if (raw_output)
        {
            __android_log_print(
                ANDROID_LOG_ERROR,
                "EMBED",
                "RAW=%f %f %f %f %f",
                raw_output[0],
                raw_output[1],
                raw_output[2],
                raw_output[3],
                raw_output[4]);
            mean_pooling_and_normalize(
                raw_output,
                attention_mask,
                seq_len,
                out_embedding);

            if (out_embedding.size() >= 5)
            {
                __android_log_print(
                    ANDROID_LOG_ERROR,
                    "EMBED",
                    "FIRST=%f %f %f %f %f",
                    out_embedding[0],
                    out_embedding[1],
                    out_embedding[2],
                    out_embedding[3],
                    out_embedding[4]);
            }
        }

        ort_->ReleaseValue(out_tensor);
        return (raw_output != nullptr);
#else
        // Deterministic embedding fallback for test harness
        out_embedding.assign(EMBEDDING_DIM, 0.0f);
        for (size_t i = 0; i < text.size(); ++i)
        {
            out_embedding[i % EMBEDDING_DIM] += static_cast<float>(text[i]);
        }
        float sum_sq = 0.0f;
        for (float v : out_embedding)
            sum_sq += v * v;
        float norm = std::sqrt(sum_sq);
        if (norm > 0)
        {
            for (float &v : out_embedding)
                v /= norm;
        }
        return true;
#endif
    }

} // namespace edgerag
