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
        Document[] doc_files;
        foreach (lib_path; config.library_paths) {
            log.info(format("scanning library path: %s", lib_path));
            foreach (string entry; dirEntries(expandTilde(lib_path), SpanMode.breadth)) {
                if (!isFile(entry)) {
                    continue;
                }
                log.trace(format(" found document: %s", entry));
                auto doc_key = get_doc_key_from_filename(entry);
                auto doc_file_path = entry;
                doc_files ~= Document(doc_key, doc_file_path);
            }
        }

        auto doc_reader = new DocumentReader();
        foreach (doc; doc_files) {
            log.trace(format("reading document: %s", doc));
            auto doc_result = doc_reader.read_document(doc.file_name);
            if (doc_result == none) {
                log.err(format("failed to read document: %s", doc));
            }
        }
    }

    string get_doc_key_from_filename(string doc_filename) {
        import std.path: baseName, stripExtension;
        import std.string;
        import std.regex;

        auto fn = doc_filename.baseName.stripExtension;

        // clean up the file name by stripping all non-alphanumeric characters
        fn = fn.strip.toLower;
        auto re_remove_non_alpha = regex(r"[^a-zA-Z\d\s]");
        auto re_condense_space = regex(r"\s\s+");
        fn = fn.replaceAll(re_remove_non_alpha, " ");
        fn = fn.replaceAll(re_condense_space, " ");

        return fn;
    }
}
