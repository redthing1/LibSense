import time
import os
import traceback
import json
import msgpack

import lz4.frame
from bottle import run, route, request, response, abort
from loguru import logger

from doccrunch import __version__

AI_INSTANCE = None


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


def run_server(ai, host: str, port: int, debug: bool):
    global AI_INSTANCE

    AI_INSTANCE = ai

    logger.info(f"starting server on {host}:{port}")
    run(host=host, port=port, debug=debug)
