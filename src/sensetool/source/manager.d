module manager;

import std.stdio;
import std.format;

import global;
import config;
import embedding;
import indexing;
import searching;
import docread;

import optional;

class LibraryManager {
    LibSenseConfig config;

    this(LibSenseConfig config) {
        this.config = config;
    }

    public void build_index() {
        import std.file: dirEntries, SpanMode, isFile;
        import std.path: expandTilde;

        auto indexer = new LibraryIndexer();

        log.info("building library index...");

        // first, get a list of all dpcuments in all the library paths
        string[] doc_files;
        foreach (lib_path; config.library_paths) {
            log.info(format("scanning library path: %s", lib_path));
            foreach (string entry; dirEntries(expandTilde(lib_path), SpanMode.breadth)) {
                if (!isFile(entry)) {
                    continue;
                }
                log.trace(format(" found book: %s", entry));
                doc_files ~= entry;
            }
        }

        auto doc_reader = new DocumentReader();
        foreach (doc_file; doc_files) {
            log.trace(format("reading book: %s", doc_file));
            auto doc_result = doc_reader.read_document(doc_file);
            if (doc_result == none) {
                log.err(format("failed to read book: %s", doc_file));
            }
        }
    }
}
