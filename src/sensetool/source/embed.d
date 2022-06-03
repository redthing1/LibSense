module embed;

import mir.ndslice;
import mir.blas;
import std.array;
import mir.ndslice;
import mir.blas;

import util.minhttp;
import models;

import optional;

struct SentenceEmbed {
    string backend_url;

    this(string backend_url) {
        this.backend_url = backend_url;
    }

    Optional!(TEmbedding[]) embed(string[] sentences) {
        auto client = new MinHttpClient();

        auto embed_req = EmbedReq(sentences);
        auto embed_resp = client.post!(EmbedReq, EmbedResp)(
            backend_url ~ "/gen_sentence_embed.json", embed_req);
        if (embed_resp == none) {
            return no!(TEmbedding[]);
        }
        auto embed_data = embed_resp.front;
        TEmbedding[] embeds;
        for (auto j = 0; j < embed_data.embeds.length; j++) {
            auto vec = embed_data.embeds[j].sliced;
            vec[] = vec / vec.nrm2();
            embeds ~= vec.field;
        }
        return some(embeds);
    }
}
