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
import util.misc;

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
            faiss_read_index_fname(sem_vector_path.c_str(), 0, &sem_index);
        }
        log.trace(format("prepared faiss index for semantic vectors, dim: %s trained: %s",
                vector_dim, faiss_Index_is_trained(sem_index)));
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
        faiss_write_index_fname(sem_index, sem_vector_path.c_str());
    }

    public void add_document(ProcessedDocument doc) {
        // add document to lib_index
        log.info(format("adding to library index: %s", doc.key));

        // sentence embeddings
        import core.stdc.stdlib : malloc;
        import core.stdc.string : memcpy;

        // auto doc_sent_vecs = cast(float*) malloc(
        //     vector_dim * float.sizeof * doc.sentence_embeddings.length);
        // for (auto i = 0; i < doc.sentence_embeddings.length; i++) {
        //     auto vec = doc.sentence_embeddings[i];
        //     memcpy(doc_sent_vecs, vec.ptr, vector_dim * float.sizeof);
        // }
        // faiss_Index_add(sem_index, doc.sentence_embeddings.length, doc_sent_vecs);


        foreach (i, vec; doc.sentence_embeddings) {
            auto vec_ptr = vec.ptr;
            faiss_Index_add(sem_index, 1, cast(float*) vec);
        }
        writefln("faiss stats: %s", faiss_Index_ntotal(sem_index));
    }

    ~this() {
        if (sem_index) {
            faiss_Index_free(sem_index);
        }
    }
}
