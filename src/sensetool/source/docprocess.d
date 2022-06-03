module docprocess;

import std.stdio;
import std.format;
import std.datetime;
import std.algorithm : fold;

import optional;

import global;
import models;
import util.minhttp;
import util.chunker;

class DocumentProcessor {
    string backend_url;
    this(string backend_url) {
        this.backend_url = backend_url;
    }

    Optional!ProcessedDocument process_document(FoundDocument input_doc) {
        auto client = new MinHttpClient();
        client.timeout = 600.seconds;

        // clean the document
        struct CleanReq {
            string contents;
            int max_sentence_length;
            bool discard_nonpara;
        }

        struct CleanResp {
            string[] sents;
            int num_sents;
            int num_initial_sents;
        }

        log.info(format("cleaning document: %s", input_doc.key));
        auto clean_resp = client.post!(CleanReq, CleanResp)(backend_url ~ "/clean_document.json",
            CleanReq(input_doc.raw_contents, 2000, true)
        );
        if (clean_resp == none) {
            log.err(format("failed to clean document: %s", input_doc.key));
            return no!ProcessedDocument;
        }
        auto clean_data = clean_resp.front;

        auto document_sents = clean_data.sents;

        // create summaries for the document
        // to do this, we want to chunk the document into summary input sizes
        enum SUMMARY_INPUT_SIZE = 1600;
        bool summary_chunk_boundary(string[] chunk) {
            return chunk.fold!((a, b) => a + cast(int) b.length)(0) > SUMMARY_INPUT_SIZE;
        }

        auto doc_summary_input_chunks = chunk(document_sents, &summary_chunk_boundary);

        // dump all chunks
        foreach (chunk; doc_summary_input_chunks) {
            writefln("chunk total size: %s elements -> %s chars",
                chunk.length,
                chunk.fold!((a, b) => a + cast(int) b.length)(0));
        }

        auto processed_doc = ProcessedDocument(input_doc.key, document_sents);
        return some(processed_doc);
    }
}
