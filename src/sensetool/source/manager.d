module manager;

import std.stdio;
import std.format;

import global;
import config;
import embedding;
import indexing;
import searching;

class LibraryManager {
    LibSenseConfig config;

    this(LibSenseConfig config) {
        this.config = config;
    }

    public void build_index() {
        import std.file: dirEntries, SpanMode;
        import std.path: expandTilde;

        auto indexer = new LibraryIndexer();

        log.info("building library index...");

        // first, get a list of all books in all the library paths
        foreach (lib_path; config.library_paths) {
            log.info(format("scanning library path: %s", lib_path));
            foreach (string name; dirEntries(expandTilde(lib_path), SpanMode.breadth)) {
                log.trace(format(" found book: %s", name));
            }
        }
    }
}
