import std.stdio;
import std.format;
import std.file;
import std.path;
import std.array;
import std.exception : enforce;

import commandr;
import optional;

import config;
import global;
import indexing;
import searching;
import util.misc;
import util.logger;

bool verbose = false;

void main(string[] raw_args) {
    // dfmt off
	enum CMD_INFO = "info";
	enum CMD_BUILD = "build";
	enum CMD_SEARCH = "search";
    enum CMD_LIST = "list";
    enum CMD_DUMP = "dump";
    auto args = new Program("sensetool", "v. 0.1").summary("libsense multitool")
        .author("no")
        .add(new Flag("v", "verbose", "turns on more verbose output"))
        .add(new Command(CMD_INFO, "show library info")
		)
        .add(new Command(CMD_BUILD, "build library index")
                // .add(new Flag(null, "flag1", "flag 1").full("flag-1"))
                // .add(new Option(null, "opt1", "option 1").full("opt-1"))
		)
        .add(new Command(CMD_SEARCH, "search library")
            .add(new Argument("query", "query to search for"))
        )
        .add(new Command(CMD_LIST, "list library")
            .add(new Argument("filter", "filter to apply"))
        )
        .add(new Command(CMD_DUMP, "dump document")
            .add(new Argument("key", "key of document to dump"))
        )
        .parse(raw_args);

    verbose = args.flag("verbose");
    log = new Logger(Verbosity.info);
    log.sinks ~= new Logger.ConsoleSink();
    log.verbosity = verbose ? Verbosity.trace : Verbosity.info;
    
    args
        .on(CMD_INFO, (args) {
            cmd_info(args);
        })
        .on(CMD_BUILD, (args) {
            cmd_build(args);
        })
        .on(CMD_SEARCH, (args) {
            cmd_search(args);
        })
        .on(CMD_LIST, (args) {
            cmd_list(args);
        })
        .on(CMD_DUMP, (args) {
            cmd_dump(args);
        })
        ;
     // dfmt on
}

void error_no_config() {
    import core.stdc.stdlib : exit;

    writefln("libsense config not found. it is expected to be at %s", get_config_file_path());
    exit(3);
}

void cmd_info(ProgramArgs args) {
    auto maybe_config = get_config();
    if (maybe_config == none)
        error_no_config();
    auto config = maybe_config.front;
    // writefln("libsense config:\n%s", config.front);

    auto indexer = new LibraryIndexer(config);
    indexer.load();

    writefln("library stats:");
    writefln("documents: %s", indexer.num_docs);
    writefln("vectors: %s", indexer.num_sem_index_entries);
}

void cmd_build(ProgramArgs args) {
    auto maybe_config = get_config();
    if (maybe_config == none)
        error_no_config();

    import manager;

    auto mgr = new LibraryManager(maybe_config.front);
    mgr.build_index();
}

void cmd_search(ProgramArgs args) {
    auto maybe_config = get_config();
    if (maybe_config == none)
        error_no_config();
    auto config = maybe_config.front;

    auto indexer = new LibraryIndexer(config);
    indexer.load();

    auto query = args.arg("query");
    auto searcher = new LibrarySearcher(config, indexer);
    auto results = searcher.search(query);

    foreach (result; results) {
        writefln("result: %s", result);
    }
}

void cmd_list(ProgramArgs args) {
    auto maybe_config = get_config();
    if (maybe_config == none)
        error_no_config();
    auto config = maybe_config.front;

    auto indexer = new LibraryIndexer(config);
    indexer.load();

    auto filter = args.arg("filter");
    auto docs = indexer.filter_documents(filter);

    if (docs.empty) {
        writefln("no results found.");
        return;
    }

    writeln("documents:");
    foreach (doc; docs) {
        writefln("⌙ %s", doc.key);
    }
}

auto cmd_dump(ProgramArgs args) {
    auto maybe_config = get_config();
    if (maybe_config == none)
        error_no_config();
    auto config = maybe_config.front;

    auto indexer = new LibraryIndexer(config);
    indexer.load();

    auto key = args.arg("key");
    auto doc = indexer.get_document(key);

    // crunch the document nicely
    auto doc_text = doc.sents.join(" ");
    auto doc_summary = doc.summs.join(" ");
    writefln("doc key: %s\n\ntext: %s\n\nsumm: %s\n", doc.key, doc_text, doc_summary);
}
