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
import embed;

class DocumentProcessor {
    string backend_url;
    this(string backend_url) {
        this.backend_url = backend_url;
    }

    Optional!ProcessedDocument process_document(FoundDocument input_doc) {
        auto client = new MinHttpClient();
        client.timeout = 600.seconds;

        // clean the document

        log.info(format("cleaning document: %s", input_doc.key));
        auto clean_resp = client.post!(CleanReq, CleanResp)(backend_url ~ "/clean_document.json",
            CleanReq(input_doc.raw_contents, 2000, true)
        );
        if (clean_resp == none) {
            log.err(format("failed to clean document: %s", input_doc.key));
            return no!ProcessedDocument;
        }
        auto clean_data = clean_resp.front;
        log.info(format("cleaned document: %s: %d s -> %d s",
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
            log.trace(format("summarized %s chunk #%d/%d: %s c -> %s c",
                    input_doc.key, i + 1, doc_summary_input_chunks.length, chunk_text.length, summary_data
                    .text_length));
            summaries ~= summary_data.text;
        }

        // create embeddings for every sentence and every summary

        enum EMBED_BATCH_SIZE = 64;
        auto sent_embed_chunks = document_sents.chunk!string(x => x.length >= EMBED_BATCH_SIZE);
        auto summary_embed_chunks = summaries.chunk!string(x => x.length >= EMBED_BATCH_SIZE);
        auto embedder = SentenceEmbed(backend_url);

        bool accumulate_embed_chunks(ref Appender!(TEmbedding[]) embeds, ref string[][] chunks) {
            foreach (i, chunk; chunks) {
                auto maybe_embed_data = embedder.embed(chunk);
                if (maybe_embed_data == none) {
                    log.err(format("failed to embed document: %s", input_doc.key));
                    return false;
                }
                auto embed_data = maybe_embed_data.front;
                log.trace(format("embedded %s chunk #%d/%d", input_doc.key, i + 1, chunks.length));
                embeds ~= embed_data;
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
