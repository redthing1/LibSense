module docprocess;

import std.stdio;
import std.format;
import std.datetime;
import std.algorithm : fold;
import std.array;
import mir.ndslice;
import mir.blas;

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
        log.info(format("cleaned document: %s: %d -> %d",
            input_doc.key, clean_data.num_initial_sents, clean_data.num_sents));

        auto document_sents = clean_data.sents;

        // create summaries for the document
        // to do this, we want to chunk the document into summary input sizes
        enum SUMMARY_INPUT_SIZE = 1600;
        bool summary_chunk_boundary(string[] chunk) {
            return chunk.fold!((a, b) => a + cast(int) b.length)(0) > SUMMARY_INPUT_SIZE;
        }

        auto doc_summary_input_chunks = chunk(document_sents, &summary_chunk_boundary);

        // // dump all chunks
        // foreach (chunk; doc_summary_input_chunks) {
        //     writefln("chunk total size: %s elements -> %s chars",
        //         chunk.length,
        //         chunk.fold!((a, b) => a + cast(int) b.length)(0));
        // }

        struct SummaryReq {
            string text;
            int min_length;
            int max_length;
            float typical_p;
        }

        struct SummaryResp {
            string text;
            int text_length;
        }

        // create summaries for each chunk
        string[] summaries;
        foreach (i, chunk; doc_summary_input_chunks) {
            auto chunk_text = chunk.join(" ");
            auto summary_req = SummaryReq(
                chunk_text,
                0,
                256,
                0.9
            );
            auto summary_resp = client.post!(SummaryReq, SummaryResp)(
                backend_url ~ "/gen_bart_summarizer.json", summary_req);
            if (summary_resp == none) {
                log.err(format("failed to summarize document: %s", input_doc.key));
                return no!ProcessedDocument;
            }
            auto summary_data = summary_resp.front;
            log.trace(format("summarized %s chunk #%d: %s -> %s",
                    input_doc.key, i, chunk_text.length, summary_data.text_length));
            summaries ~= summary_data.text;
        }

        // create embeddings for every sentence and every summary
        struct EmbedReq {
            string[] texts;
        }

        struct EmbedResp {
            TEmbedding[] embeds;
        }

        enum EMBED_BATCH_SIZE = 64;
        auto sent_embed_chunks = document_sents.chunk!string(x => x.length >= EMBED_BATCH_SIZE);
        auto summary_embed_chunks = summaries.chunk!string(x => x.length >= EMBED_BATCH_SIZE);

        bool accumulate_embed_chunks(ref Appender!(TEmbedding[]) embeds, ref string[][] chunks) {
            foreach (i, chunk; chunks) {
                auto embed_req = EmbedReq(chunk);
                auto embed_resp = client.post!(EmbedReq, EmbedResp)(
                    backend_url ~ "/gen_sentence_embed.json", embed_req);
                if (embed_resp == none) {
                    log.err(format("failed to embed document: %s", input_doc.key));
                    return false;
                }
                auto embed_data = embed_resp.front;
                log.trace(format("embedded %s chunk #%d",
                        input_doc.key, i));
                for (auto j = 0; j < embed_data.embeds.length; j++) {
                    auto vec = embed_data.embeds[j].sliced;
                    // writefln("vec: %s", vec);
                    // normalize the vector so we can use L2 for cosine similarity
                    // auto nrm_vec = vec / vec.nrm2();
                    vec[] = vec / vec.nrm2();
                    // writefln("nrm_vec: %s", nrm_vec);
                    auto nrm_vec_d = vec.field;
                    embeds ~= nrm_vec_d;
                }
            }
            return true;
        }

        auto sent_embeddings = appender!(TEmbedding[]);
        auto summ_embeddings = appender!(TEmbedding[]);

        if (!accumulate_embed_chunks(sent_embeddings, sent_embed_chunks)
            || !accumulate_embed_chunks(summ_embeddings, summary_embed_chunks)) {
            return no!ProcessedDocument;
        }

        auto processed_doc = ProcessedDocument(input_doc.key, document_sents,
            summaries, sent_embeddings.data, summ_embeddings.data);
        return some(processed_doc);
    }
}
