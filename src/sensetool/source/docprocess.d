module docprocess;

import std.stdio;
import std.format;
import std.datetime;

import optional;

import global;
import models;
import util.minhttp;

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

        auto processed_doc = ProcessedDocument(input_doc.key, clean_data.sents);
        return some(processed_doc);
    }
}
