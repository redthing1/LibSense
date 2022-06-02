module docprocess;

import std.format;
import requests;
import mir.ser.json : serializeJson;

import models;

class DocumentProcessor {
    string backend_url;
    this(string backend_url) {
        this.backend_url = backend_url;
    }

    ProcessedDocument process_document(FoundDocument input_doc) {
        // clean the document
        auto clean_req = Request();
        struct CleanReq {
            string contents;
            int max_sentence_length;
            bool discard_nonpara;
        }

        auto clean_req_json = CleanReq(input_doc.raw_contents, 2000, true).serializeJson();

        auto clean_resp = clean_req.post(backend_url ~ "/clean_document.json",
            clean_req_json,
            "application/json"
        );

        import std.stdio;

        writefln("clean_resp: %s", clean_resp);

        auto processed_doc = ProcessedDocument(input_doc.key, []);
        return processed_doc;
    }
}
