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
