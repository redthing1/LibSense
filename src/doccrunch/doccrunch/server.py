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

AI_INSTANCE = None
GENERATOR = None


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


@route("/clean_document.<ext>", method=["GET"])
def clean_document_route(ext):
    req_json = req_as_dict(request)

    try:
        _ = req_json["contents"]
    except KeyError as ke:
        abort(400, f"missing field {ke}")

    opt_max_sentence_length: bool = get_req_opt(req_json, "max_sentence_length", 2000)
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

        global AI_INSTANCE, GENERATOR

        # standard generate
        output = GENERATOR.generate(
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
            "model": AI_INSTANCE.model_name,
        }

        return pack_bundle(resp_bundle, ext)
    except Exception as ex:
        logger.error(f"error generating: {traceback.format_exc()}")
        abort(400, f"generation failed")


def run_server(ai, host: str, port: int, debug: bool):
    global AI_INSTANCE, GENERATOR

    AI_INSTANCE = ai
    GENERATOR = EmbedGenerator(ai)

    logger.info(f"starting server on {host}:{port}")
    run(host=host, port=port, debug=debug)
