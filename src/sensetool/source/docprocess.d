module docprocess;

import std.stdio;
import std.format;
import std.datetime;

import requests;
import mir.ser.json : serializeJson;
import mir.deser.json : deserializeJson;
import optional;

import global;
import models;

class DocumentProcessor {
    string backend_url;
    this(string backend_url) {
        this.backend_url = backend_url;
    }

    Optional!ProcessedDocument process_document(FoundDocument input_doc) {
        // clean the document
        auto clean_req = Request();
        clean_req.timeout = 600.seconds;
        struct CleanReq {
            string contents;
            int max_sentence_length;
            bool discard_nonpara;
        }

        auto clean_req_json = CleanReq(input_doc.raw_contents, 2000, true).serializeJson();

        log.info(format("cleaning document: %s", input_doc.key));
        auto clean_resp = clean_req.post(backend_url ~ "/clean_document.json",
            clean_req_json,
            "application/json"
        );
        if (clean_resp.code != 200) {
            return no!ProcessedDocument;
        }
        struct CleanResp {
            string[] sents;
            int num_sents;
            int num_initial_sents;
        }
        auto clean_resp_data = clean_resp.responseBody.data!string.deserializeJson!CleanResp();
        writefln("clean_resp_data: %s", clean_resp_data);
        writefln("num sents: %s", clean_resp_data.num_sents);

        auto processed_doc = ProcessedDocument(input_doc.key, clean_resp_data.sents);
        return some(processed_doc);
    }
}
