module indexing;

import std.stdio;
import std.file;
import std.format;
import std.path;
import mir.ser.msgpack : serializeMsgpack;
import mir.deser.msgpack : deserializeMsgpack;
import std.exception : enforce;

import faiss;
import faiss.index;
import faiss.index_factory;
import faiss.index_io;

import global;
import models;

struct LibraryIndex {

}

class LibraryIndexer {
    string base_path;
    int vector_dim;
    LibraryIndex lib_index;
    FaissIndex* sem_index = null;

    enum LIB_INDEX_FILE = "documents.idx";
    enum SEM_VECTOR_FILE = "sem_data.vec";

    this(string base_path, int vector_dim) {
        this.base_path = expandTilde(base_path);
        this.vector_dim = vector_dim;
    }

    public void load() {
        // check if base_path exists and create it if not
        if (!exists(base_path)) {
            mkdirRecurse(base_path);
        }

        log.info(format("loading library lib_index data from %s", base_path));

        // load the various files

        // 1. library lib_index
        auto lib_index_path = buildPath(base_path, LIB_INDEX_FILE);
        if (exists(lib_index_path)) {
            // load the lib_index
            auto file_data = cast(ubyte[]) std.file.read(lib_index_path);
            lib_index = file_data.deserializeMsgpack!LibraryIndex();
        } else {
            // create the lib_index
            log.warn(format("existing library lib_index not found, creating new one in %s", lib_index_path));
            lib_index = LibraryIndex();
        }

        // 2. semantic vector data
        auto sem_vector_path = buildPath(base_path, SEM_VECTOR_FILE);
        // https://github.com/facebookresearch/faiss/issues/593 - for cosine similarity, pre-normalize vectors and just use L2
        // use the IndexFlatL2 for now
        if (faiss_index_factory(&sem_index, vector_dim, "Flat", FaissMetricType.METRIC_L2)) {
            // failed to create FAISS index
            log.err(format("failed to create FAISS index for semantic vectors"));
            enforce(0, format("failed to create FAISS index for semantic vectors"));
        }
        if (exists(sem_vector_path)) {
            // load the vector data
            faiss_read_index_fname(cast(char*) sem_vector_path, 0, &sem_index);
        }
        log.trace(format("prepared faiss index for semantic vectors, trained: %s", faiss_Index_is_trained(
                sem_index)));
    }

    public void save() {
        log.info(format("saving library index data to %s", base_path));

        // save the lib index
        auto lib_index_path = buildPath(base_path, LIB_INDEX_FILE);
        log.info(format("saving library lib_index data to %s", lib_index_path));
        auto lib_index_data = lib_index.serializeMsgpack();
        std.file.write(lib_index_path, lib_index_data);

        // save the semantic vector data
        auto sem_vector_path = buildPath(base_path, SEM_VECTOR_FILE);
        log.info(format("saving semantic vector data to %s", sem_vector_path));
        faiss_write_index_fname(sem_index, cast(char*) sem_vector_path);
    }

    public void add_document(ProcessedDocument doc) {
        log.info(format("adding to library lib_index: %s", doc.key));
        // TODO: add document to lib_index
    }
}
