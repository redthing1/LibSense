import time
import os
import traceback
import json
import msgpack
from typing import List

import lz4.frame
from bottle import run, route, request, response, abort
from doccrunch.document_processor import clean_document_for_indexing
from loguru import logger

from doccrunch import __version__

from aitg.gens.embed_generator import EmbedGenerator
from aitg.gens.bart_summary_generator import BartSummaryGenerator

AI_EMBED_INSTANCE = None
EMBED_GENERATOR = None
AI_SUMMARIZER_INSTANCE = None
SUMMARY_GENERATOR = None


def req_as_dict(req):
    try:
        if request.json:
            return request.json
        elif request.params:
            return request.params
        else:
            return None
    except:
        abort(400, f"invalid request json")


def get_req_opt(req, name, default):
    if name in req:
        return req[name]
    else:
        return default


def pack_bundle(bundle, ext):
    if ext == "json":
        response.headers["Content-Type"] = "application/json"
        return json.dumps(bundle)
    elif ext == "mp":
        response.headers["Content-Type"] = "application/x-msgpack"
        return msgpack.dumps(bundle)
    elif ext == "mpz":
        response.headers["Content-Type"] = "application/octet-stream"
        return lz4.frame.compress(msgpack.dumps(bundle))
    else:  # default
        return None


@route("/info.<ext>", method=["GET"])
def info_route(ext):
    req_json = req_as_dict(request)

    bundle = {
        "server": "doccrunch",
        "version": __version__,
    }

    return pack_bundle(bundle, ext)


@route("/clean_document.<ext>", method=["GET", "POST"])
def clean_document_route(ext):
    req_json = req_as_dict(request)

    try:
        _ = req_json["contents"]
    except KeyError as ke:
        abort(400, f"missing field {ke}")

    opt_max_sentence_length: int = get_req_opt(req_json, "max_sentence_length", 2000)
    opt_contents: str = get_req_opt(req_json, "contents", "")
    opt_discard_nonparagraph_sentences: bool = get_req_opt(
        req_json, "discard_nonpara", False
    )

    cleaned_doc = clean_document_for_indexing(
        contents=opt_contents,
        max_sentence_length=opt_max_sentence_length,
        discard_nonparagraph_sentences=opt_discard_nonparagraph_sentences,
    )

    bundle = {
        "sents": cleaned_doc.sentences,
        "num_sents": cleaned_doc.num_sents,
        "num_initial_sents": cleaned_doc.num_initial_sents,
    }

    if not opt_discard_nonparagraph_sentences:
        bundle["nonparagraph_sentences"] = cleaned_doc.nonparagraph_sentences

    return pack_bundle(bundle, ext)


@route("/gen_sentence_embed.<ext>", method=["GET", "POST"])
def gen_bart_classifier_route(ext):
    req_json = req_as_dict(request)
    try:
        _ = req_json["texts"]
    except KeyError as ke:
        abort(400, f"missing field {ke}")

    # mode params
    # option params
    opt_texts: List[str] = get_req_opt(req_json, "texts", None)

    logger.debug(f"requesting sentence embeds for texts: {opt_texts}")

    # generate
    try:
        start = time.time()

        global AI_EMBED_INSTANCE, EMBED_GENERATOR

        # standard generate
        output = EMBED_GENERATOR.generate(
            texts=opt_texts,
        )

        embeds = output.embeddings
        num_embeds = len(embeds)
        logger.debug(f"model output: embeds[{len(embeds)}]")
        generation_time = time.time() - start
        gen_vecps = num_embeds / generation_time
        logger.info(
            f"generated [{num_embeds} vec] ({generation_time:.2f}s/{gen_vecps:.2f} vps)"
        )

        resp_bundle = {
            "similarity": output.similarity,
            "num_embeds": num_embeds,
            "embeds": embeds,
            "gen_time": generation_time,
            "model": AI_EMBED_INSTANCE.model_name,
        }

        return pack_bundle(resp_bundle, ext)
    except Exception as ex:
        logger.error(f"error generating: {traceback.format_exc()}")
        abort(400, f"generation fembed_ailed")


@route("/gen_bart_summarizer.<ext>", method=["GET", "POST"])
def gen_bart_summarizer_route(ext):
    req_json = req_as_dict(request)
    try:
        _ = req_json["text"]
    except KeyError as ke:
        abort(400, f"missing field {ke}")

    # mode params
    # option params
    opt_text: str = get_req_opt(req_json, "text", "")
    opt_max_length: int = get_req_opt(req_json, "max_length", 256)
    opt_min_length: int = get_req_opt(req_json, "min_length", 0)
    opt_typical_p: float = get_req_opt(req_json, "typical_p", 0.9)
    opt_repetition_penalty: float = get_req_opt(req_json, "repetition_penalty", 1.0)
    opt_length_penalty: float = get_req_opt(req_json, "length_penalty", 1.0)
    opt_max_time: float = get_req_opt(req_json, "opt_max_time", None)
    opt_no_repeat_ngram_size: int = get_req_opt(req_json, "no_repeat_ngram_size", 3)

    logger.debug(f"requesting generation for text: {opt_text}")

    # generate
    try:
        start = time.time()

        global AI_SUMMARIZER_INSTANCE, SUMMARY_GENERATOR

        # standard generate
        output = SUMMARY_GENERATOR.generate(
            article=opt_text,
            max_length=opt_max_length,
            min_length=opt_min_length,
            typical_p=opt_typical_p,
            num_beams=1,  # disable beam search
            do_sample=False,
            repetition_penalty=opt_repetition_penalty,
            length_penalty=opt_length_penalty,
            max_time=opt_max_time,
            no_repeat_ngram_size=opt_no_repeat_ngram_size,
        )

        gen_txt = AI_SUMMARIZER_INSTANCE.filter_text(output.text)
        gen_txt_size = len(gen_txt)
        prompt_token_count = len(output.prompt_ids)
        logger.debug(f"model output: {gen_txt}")
        generation_time = time.time() - start
        total_gen_num = len(output.tokens)
        gen_tps = output.num_new / generation_time
        logger.info(
            f"generated [{prompt_token_count}->{output.num_new}] ({generation_time:.2f}s/{(gen_tps):.2f}tps)"
        )

        # done generating, now return the results over http

        # create base response bundle
        resp_bundle = {
            "text": gen_txt,
            "text_length": gen_txt_size,
            "prompt_token_count": prompt_token_count,
            "tokens": output.tokens,
            "token_count": total_gen_num,
            "num_new": output.num_new,
            "num_total": total_gen_num,
            "gen_time": generation_time,
            "gen_tps": gen_tps,
            "model": AI_SUMMARIZER_INSTANCE.model_name,
        }

        return pack_bundle(resp_bundle, ext)
    except Exception as ex:
        logger.error(f"error generating: {traceback.format_exc()}")
        abort(400, f"generation failed")


def run_server(embed_ai, summarizer_ai, host: str, port: int, debug: bool):
    global AI_EMBED_INSTANCE, EMBED_GENERATOR, AI_SUMMARIZER_INSTANCE, SUMMARY_GENERATOR

    AI_EMBED_INSTANCE = embed_ai
    EMBED_GENERATOR = EmbedGenerator(embed_ai)

    AI_SUMMARIZER_INSTANCE = summarizer_ai
    SUMMARY_GENERATOR = BartSummaryGenerator(summarizer_ai)

    logger.info(f"starting server on {host}:{port}")
    run(host=host, port=port, debug=debug)
