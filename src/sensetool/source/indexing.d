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
import config;
import models;
import util.misc;

struct LibraryIndex {
    struct Document {
        string key;
        long vec_id_start_sents;
        long vec_id_count_sents;
        long vec_id_start_summ;
        long vec_id_count_summ;

        string[] sents;
        string[] summs;
    }

    Document[string] documents;
    // long vec_id_sents_counter = 0;
    // long vec_id_summ_counter = 0;
}

class LibraryIndexer {
    LibSenseConfig config;
    string base_path;
    int vector_dim;
    LibraryIndex lib_index;
    FaissIndex* sem_index = null;

    enum LIB_INDEX_FILE = "documents.idx";
    enum SEM_VECTOR_FILE = "sem_data.vec";

    this(LibSenseConfig config) {
        this.config = config;
        this.base_path = expandTilde(config.index_path);
        this.vector_dim = config.vector_dim;
    }

    ~this() {
        if (sem_index) {
            faiss_Index_free(sem_index);
        }
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
        auto sem_index_trained = faiss_Index_is_trained(sem_index);
        log.trace(format("prepared faiss index for semantic vectors, dim: %s trained: %s",
                vector_dim, sem_index_trained));
        assert(sem_index_trained, "semantic vectors index is not trained");
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

        // Some indexes can also store integer IDs corresponding to each of the vectors (but not IndexFlatL2).
        // If no IDs are provided, add just uses the vector ordinal as the id, ie. the first vector gets 0, the second 1, etc.
        // auto xid_count_sent = doc.sentence_embeddings.length;
        // auto xid_count_summ = doc.summary_embeddings.length;
        // auto xid_start_sents = ++lib_index.vec_id_sents_counter;
        // auto xid_start_summ = ++lib_index.vec_id_summ_counter;
        // lib_index.vec_id_sents_counter += xid_count_sent;
        // lib_index.vec_id_summ_counter += xid_count_summ;

        auto id_start_sents = -1;
        auto id_count_sents = 0;

        // sentence embeddings
        foreach (i, vec; doc.sentence_embeddings) {
            // idx_t[1] xid = [xid_count_sent + i];
            // faiss_Index_add_with_ids(sem_index, 1, cast(float*) vec, cast(idx_t*) xid);
            auto id = faiss_Index_add(sem_index, 1, cast(float*) vec);
            if (i == 0)
                id_start_sents = id;
            id_count_sents++;
        }

        auto id_start_summ = -1;
        auto id_count_summ = 0;

        // summary embeddings
        foreach (i, vec; doc.summary_embeddings) {
            auto id = faiss_Index_add(sem_index, 1, cast(float*) vec);
            if (i == 0)
                id_start_summ = id;
            id_count_summ++;
        }

        auto lib_doc = LibraryIndex.Document(
            doc.key,
            id_start_sents, id_count_sents, id_start_summ, id_count_summ,
            doc.sentences, doc.summaries);
        lib_index.documents[doc.key] = lib_doc;

        log.info(format("faiss stats: %s", faiss_Index_ntotal(sem_index)));
    }

    public SearchResult[] search(TEmbedding query_vec, int k = 10) {
        auto distances = new float[1 * k];
        auto labels = new idx_t[1 * k];
        auto res = faiss_Index_search(sem_index, 1, cast(float*) query_vec,
            k, cast(float*) distances, cast(idx_t*) labels);
        writefln("search result: %s, %s, %s", res, distances, labels);

        return [];
    }

    @property long num_sem_index_entries() {
        if (sem_index) {
            return faiss_Index_ntotal(sem_index);
        }
        enforce(0, "tried to read property of sem_index that was not loaded");
        assert(0);
    }

    @property long num_docs() {
        return lib_index.documents.length;
    }

    bool has_document(string doc_key) {
        return (doc_key in lib_index.documents) != null;
    }
}
