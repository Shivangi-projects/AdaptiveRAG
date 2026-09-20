#include "tokenizer.h"
#include <fstream>
#include <sstream>
#include <algorithm>
#include <cctype>

namespace edgerag {

WordPieceTokenizer::WordPieceTokenizer() = default;
WordPieceTokenizer::~WordPieceTokenizer() = default;

bool WordPieceTokenizer::load_vocab(const std::string& vocab_path) {
    std::ifstream file(vocab_path);
    if (!file.is_open()) {
        return false;
    }

    vocab_.clear();
    id_to_token_.clear();

    std::string line;
    int32_t id = 0;
    while (std::getline(file, line)) {
        // Strip trailing \r / \n
        while (!line.empty() && (line.back() == '\r' || line.back() == '\n')) {
            line.pop_back();
        }
        if (!line.empty()) {
            vocab_[line] = id;
            id_to_token_[id] = line;
            if (line == "[UNK]") unk_id_ = id;
            else if (line == "[CLS]") cls_id_ = id;
            else if (line == "[SEP]") sep_id_ = id;
            else if (line == "[PAD]") pad_id_ = id;
            id++;
        }
    }

    loaded_ = (!vocab_.empty());
    return loaded_;
}

std::string WordPieceTokenizer::to_lower(const std::string& str) {
    std::string res = str;
    std::transform(res.begin(), res.end(), res.begin(), [](unsigned char c) {
        return std::tolower(c);
    });
    return res;
}

bool WordPieceTokenizer::is_punctuation(char c) {
    return (c >= 33 && c <= 47) ||
           (c >= 58 && c <= 64) ||
           (c >= 91 && c <= 96) ||
           (c >= 123 && c <= 126);
}

std::vector<std::string> WordPieceTokenizer::basic_tokenize(const std::string& text) const {
    std::string lower = to_lower(text);
    std::vector<std::string> tokens;
    std::string current;

    for (size_t i = 0; i < lower.size(); ++i) {
        char c = lower[i];
        if (std::isspace(static_cast<unsigned char>(c))) {
            if (!current.empty()) {
                tokens.push_back(current);
                current.clear();
            }
        } else if (is_punctuation(c)) {
            if (!current.empty()) {
                tokens.push_back(current);
                current.clear();
            }
            tokens.push_back(std::string(1, c));
        } else {
            current += c;
        }
    }
    if (!current.empty()) {
        tokens.push_back(current);
    }
    return tokens;
}

std::vector<int32_t> WordPieceTokenizer::wordpiece_tokenize(const std::string& word) const {
    std::vector<int32_t> subword_ids;
    if (word.length() > 100) {
        subword_ids.push_back(unk_id_);
        return subword_ids;
    }

    size_t start = 0;
    while (start < word.length()) {
        size_t end = word.length();
        int32_t cur_id = -1;

        while (start < end) {
            std::string sub = word.substr(start, end - start);
            if (start > 0) {
                sub = "##" + sub;
            }
            auto it = vocab_.find(sub);
            if (it != vocab_.end()) {
                cur_id = it->second;
                break;
            }
            end--;
        }

        if (cur_id == -1) {
            subword_ids.clear();
            subword_ids.push_back(unk_id_);
            return subword_ids;
        }

        subword_ids.push_back(cur_id);
        start = end;
    }

    return subword_ids;
}

void WordPieceTokenizer::tokenize(const std::string& text,
                                   int max_len,
                                   std::vector<int64_t>& out_input_ids,
                                   std::vector<int64_t>& out_attention_mask,
                                   std::vector<int64_t>& out_token_type_ids) const {
    out_input_ids.clear();
    out_attention_mask.clear();
    out_token_type_ids.clear();

    if (!loaded_) {
        return;
    }

    // [CLS]
    out_input_ids.push_back(cls_id_);
    out_attention_mask.push_back(1);
    out_token_type_ids.push_back(0);

    std::vector<std::string> words = basic_tokenize(text);
    for (const auto& word : words) {
        std::vector<int32_t> piece_ids = wordpiece_tokenize(word);
        for (int32_t pid : piece_ids) {
            if (static_cast<int>(out_input_ids.size()) >= max_len - 1) {
                break; // Leave room for [SEP]
            }
            out_input_ids.push_back(pid);
            out_attention_mask.push_back(1);
            out_token_type_ids.push_back(0);
        }
        if (static_cast<int>(out_input_ids.size()) >= max_len - 1) {
            break;
        }
    }

    // [SEP]
    out_input_ids.push_back(sep_id_);
    out_attention_mask.push_back(1);
    out_token_type_ids.push_back(0);

    // Pad to max_len
    while (static_cast<int>(out_input_ids.size()) < max_len) {
        out_input_ids.push_back(pad_id_);
        out_attention_mask.push_back(0);
        out_token_type_ids.push_back(0);
    }
}

} // namespace edgerag
