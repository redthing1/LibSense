module models;

struct FoundDocument {
    string key;
    string file_name;
    string raw_contents;

    string toString() {
        import std.format;

        return format("FoundDocument(key: %s, file_name: %s)", key, file_name);
    }
}

alias TEmbedding = float[];

struct ProcessedDocument {
    string key;

    string[] sentences;
    string[] summaries;

    TEmbedding[] sentence_embeddings;
    TEmbedding[] summary_embeddings;
}

struct CleanReq {
    string contents;
    int max_sentence_length;
    bool discard_nonpara;
}

struct CleanResp {
    string[] sents;
    int num_sents;
    int num_initial_sents;
}

struct SummaryReq {
    string text;
    int min_length;
    int max_length;
    float typical_p;
}

struct SummaryResp {
    string text;
    int text_length;
}

struct EmbedReq {
    string[] texts;
}

struct EmbedResp {
    TEmbedding[] embeds;
}

struct SearchResult {
    string document_key;
    string match_text;

    Type match_type;

    float vec_distance;
    long vec_label;

    enum Type {
        Unknown,
        Sentence,
        Summary,
    }

    @property string type_label() const {
        // dfmt off
        switch (match_type) {
            case Type.Unknown: return "unk";
            case Type.Sentence: return "snt";
            case Type.Summary: return "sum";
            default: assert(0);
        }
        // dfmt on
    }

    string toString() const {
        import std.format;

        return format("(%.3f) [%s] %s: %s", vec_distance, type_label, document_key, match_text);
    }
}
