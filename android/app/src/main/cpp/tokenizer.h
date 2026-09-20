#ifndef EDGERAG_TOKENIZER_H
#define EDGERAG_TOKENIZER_H

#include <string>
#include <vector>
#include <unordered_map>
#include <cstdint>

namespace edgerag {

class WordPieceTokenizer {
public:
    WordPieceTokenizer();
    ~WordPieceTokenizer();

    bool load_vocab(const std::string& vocab_path);
    bool is_loaded() const { return loaded_; }

    void tokenize(const std::string& text,
                  int max_len,
                  std::vector<int64_t>& out_input_ids,
                  std::vector<int64_t>& out_attention_mask,
                  std::vector<int64_t>& out_token_type_ids) const;

private:
    std::unordered_map<std::string, int32_t> vocab_;
    std::unordered_map<int32_t, std::string> id_to_token_;
    bool loaded_ = false;

    int32_t unk_id_ = 100;
    int32_t cls_id_ = 101;
    int32_t sep_id_ = 102;
    int32_t pad_id_ = 0;

    std::vector<std::string> basic_tokenize(const std::string& text) const;
    std::vector<int32_t> wordpiece_tokenize(const std::string& word) const;
    static std::string to_lower(const std::string& str);
    static bool is_punctuation(char c);
};

} // namespace edgerag

#endif // EDGERAG_TOKENIZER_H
