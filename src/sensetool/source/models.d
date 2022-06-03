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
