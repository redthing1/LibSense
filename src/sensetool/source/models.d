module models;

struct FoundDocument {
    string key;
    string file_name;
    string raw_contents;
}

struct ProcessedDocument {
    string key;
    
    string[] sentences;
    string[] summaries;
}