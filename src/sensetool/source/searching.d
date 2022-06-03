module searching;

import optional;

import global;
import config;
import indexing;
import embed;
import models;

class LibrarySearcher {
    LibSenseConfig config;
    LibraryIndexer indexer;

    this(LibSenseConfig config, LibraryIndexer indexer) {
        this.config = config;
        this.indexer = indexer;
    }

    public SearchResult[] search(string query, int k) {
        auto embedder = SentenceEmbed(config.server_endpoint);

        // embed the query
        auto maybe_query_vecs = embedder.embed([query]);
        if (maybe_query_vecs == none) {
            return [];
        }
        auto query_vecs = maybe_query_vecs.front;
        auto query_vec = query_vecs[0];

        // search the index
        auto results = indexer.search(query_vec, k);

        return results;
    }
}
