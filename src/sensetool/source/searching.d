module searching;

import global;
import config;

struct SearchResult {
}

class LibrarySearcher {
    LibSenseConfig config;

    this(LibSenseConfig config) {
        this.config = config;
    }

    public SearchResult[] search() {
        return [SearchResult()];
    }
}
