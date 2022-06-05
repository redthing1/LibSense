module manager;

import std.stdio;
import std.format;

import global;
import config;
import models;
import docprocess;
import indexing;
import searching;
import docread;

import optional;

class LibraryManager {
    LibSenseConfig config;

    this(LibSenseConfig config) {
        this.config = config;
    }

    public void build_index(bool save_often = false) {
        import std.file : dirEntries, SpanMode, isFile;
        import std.path : expandTilde;

        auto indexer = new LibraryIndexer(config, false);
        indexer.load();

        log.info("building library index...");

        // first, get a list of all dpcuments in all the library paths
        FoundDocument[] doc_files;
        foreach (lib_path; config.library_paths) {
            log.info(format("scanning library path: %s", lib_path));
            foreach (string entry; dirEntries(expandTilde(lib_path), SpanMode.breadth)) {
                if (!isFile(entry)) {
                    continue;
                }
                log.trace(format(" found document: %s", entry));
                auto doc_key = get_doc_key_from_filename(entry);
                auto doc_file_path = entry;
                doc_files ~= FoundDocument(doc_key, doc_file_path);
            }
        }

        auto doc_reader = new DocumentReader();
        auto doc_processor = new DocumentProcessor(config.server_endpoint);
        foreach (doc; doc_files) {
            // check if we already know about this document
            if (indexer.has_document(doc.key)) {
                log.trace(format("skipping document %s, already indexed", doc.key));
                continue;
            }

            log.trace(format("reading document: %s", doc));
            auto doc_raw_contents = doc_reader.read_document(doc.file_name);
            if (doc_raw_contents == none) {
                log.err(format("failed to read document: %s", doc));
            }

            // we have the raw contents of the document, now we need to process it
            doc.raw_contents = doc_raw_contents.front;
            auto maybe_processed_document = doc_processor.process_document(doc);
            if (maybe_processed_document == none) {
                log.err(format("failed to process document: %s", doc));
                continue;
            }

            auto processed_document = maybe_processed_document.front;
            // the document is now fully processed, so we can add it to the index
            indexer.add_document(processed_document);

            if (save_often) {
                log.trace(format("saving index (save often enabled)..."));
                indexer.save();
            }
        }

        // save the library index
        indexer.save();
    }

    string get_doc_key_from_filename(string doc_filename) {
        import std.path : baseName, stripExtension;
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
