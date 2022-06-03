module indexing;

import std.stdio;
import std.file;
import std.format;
import std.path;
import mir.ser.msgpack : serializeMsgpack;
import mir.deser.msgpack : deserializeMsgpack;

import global;
import models;

struct LibraryIndex {

}

class LibraryIndexer {
    string base_path;
    LibraryIndex index;

    enum LIB_INDEX_FILE = "documents.idx";

    this(string base_path) {
        this.base_path = base_path;
    }

    public void load() {
        // check if base_path exists and create it if not
        if (!exists(base_path)) {
            mkdirRecurse(base_path);
        }

        log.info(format("loading library index data from %s", base_path));

        // load the index files
        auto lib_index_path = buildPath(base_path, LIB_INDEX_FILE);
        if (exists(lib_index_path)) {
            // load the index
            auto file_data = cast(ubyte[]) std.file.read(lib_index_path);
            index = file_data.deserializeMsgpack!LibraryIndex();
        } else {
            // create the index
            log.warn(format("existing library index not found, creating new one in %s", lib_index_path));
            index = LibraryIndex();
        }
    }

    public void add_document(ProcessedDocument doc) {
        log.info(format("adding to library index: %s", doc.key));
        // TODO: add document to index
    }

    public void save() {
        log.info(format("saving library index data to %s", base_path));
        auto lib_index_path = buildPath(base_path, LIB_INDEX_FILE);
        auto lib_index_data = index.serializeMsgpack();
        std.file.write(lib_index_path, lib_index_data);
    }
}
