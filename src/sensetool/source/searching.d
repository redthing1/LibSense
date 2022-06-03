module searching;

import global;
import config;
import indexing;

struct SearchResult {
}

class LibrarySearcher {
    LibSenseConfig config;
    LibraryIndexer indexer;

    this(LibSenseConfig config, LibraryIndexer indexer) {
        this.config = config;
        this.indexer = indexer;
    }

    public SearchResult[] search(string query) {
        return [SearchResult()];
    }
}
