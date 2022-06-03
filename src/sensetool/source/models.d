module models;

struct FoundDocument {
    string key;
    string file_name;
    string raw_contents;
}

alias TEmbedding = float[];

struct ProcessedDocument {
    string key;

    string[] sentences;
    string[] summaries;

    TEmbedding[] sentence_embeddings;
    TEmbedding[] summary_embeddings;
}
