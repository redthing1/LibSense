import std.stdio;
import std.format;
import std.file;
import std.path;
import std.array;
import std.exception : enforce;

import commandr;
import optional;

import config;
import util;

bool verbose = false;

void main(string[] raw_args) {
	// dfmt off
	enum CMD_INFO = "info";
	enum CMD_BUILD = "build";
    auto args = new Program("sensetool", "v. 0.1").summary("libsense multitool")
        .author("no")
        .add(new Flag("v", "verbose", "turns on more verbose output"))
        .add(new Command(CMD_INFO, "show library info")
		)
        .add(new Command(CMD_BUILD, "build library index")
                // .add(new Flag(null, "flag1", "flag 1").full("flag-1"))
                // .add(new Option(null, "opt1", "option 1").full("opt-1"))
		)
        .parse(raw_args);

    verbose = args.flag("verbose");
    
    args
        .on(CMD_INFO, (args) {
            cmd_info(args);
        })
        .on(CMD_BUILD, (args) {
            cmd_build(args);
        })
        ;
     // dfmt on
}

void cmd_info(ProgramArgs args) {
	auto config = get_config();
    if (config == none) {
        writefln("libsense config not found. it is expected to be at %s", get_config_file_path());
        return;
    }
    writefln("libsense config:\n%s", config.front);
}

void cmd_build(ProgramArgs args) {
}
