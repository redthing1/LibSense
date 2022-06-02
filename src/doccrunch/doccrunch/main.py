import time
import os
import sys
import typer
from loguru import logger

from doccrunch.server import run_server

from aitg.model import load_sentence_embed_model

def cli(
    model_path: str,
    host: str = "localhost",
    port: int = 12789,
    debug: bool = False,
):
    # load the model
    logger.info(f"loading model from {model_path}")
    ai = load_sentence_embed_model(model_path)
    run_server(ai, host, port, debug)


def main():
    typer.run(cli)


if __name__ == "__main__":
    main()
