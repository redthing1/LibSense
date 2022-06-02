import time
import os
import sys
import typer
from loguru import logger

from doccrunch.server import run_server

from aitg.model import load_sentence_embed_model
from aitg.model import load_bart_summarizer_model


def cli(
    embed_model_path: str,
    summarizer_model_path: str,
    host: str = "localhost",
    port: int = 12789,
    debug: bool = False,
):
    # load the models
    logger.info(f"loading sentence embed model from {embed_model_path}")
    embed_ai = load_sentence_embed_model(embed_model_path)

    logger.info(f"loading summarizer model from {summarizer_model_path}")
    summarizer_ai = load_bart_summarizer_model(summarizer_model_path)

    run_server(
        embed_ai=embed_ai,
        summarizer_ai=summarizer_ai,
        host=host,
        port=port,
        debug=debug,
    )


def main():
    typer.run(cli)


if __name__ == "__main__":
    main()
