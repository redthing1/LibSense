module searching;

import global;
import config;
import indexing;
import embed;

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
        auto embedder = SentenceEmbed(config.server_endpoint);

        // embed the query
        auto query_vecs = embedder.embed([query]);
        auto query_vec = query_vecs[0];

        return [SearchResult()];
    }
}
