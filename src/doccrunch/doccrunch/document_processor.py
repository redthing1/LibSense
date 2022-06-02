from aitg_doctools.clean import ParagraphCleaner
from types import SimpleNamespace

def clean_document_for_indexing(contents, max_sentence_length=2000, discard_nonparagraph_sentences=False):
    # split the text into sentences
    cleaner = ParagraphCleaner()
    contents = cleaner.clean_space(contents)
    sentences = cleaner.sentencize(contents)
    num_initial_sents = len(sentences)
    cleaned_sentences = list(map(lambda x: x.strip(), sentences))
    cleaned_sentences = cleaner.drop_longer_than(cleaned_sentences, max_sentence_length)
    cleaned_sentences, nonparagraph_sentences = cleaner.filter_non_paragraph_sentences(cleaned_sentences)

    num_sents = len(cleaned_sentences)

    if discard_nonparagraph_sentences:
        # just throw away the non-paragraph sentences
        nonparagraph_sentences = []

    return SimpleNamespace(
        sentences=cleaned_sentences,
        num_initial_sents=num_initial_sents,
        num_sents=num_sents,
        nonparagraph_sentences=nonparagraph_sentences
    )