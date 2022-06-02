module config;

import std.file;
import std.path;
import std.algorithm : map, filter, reduce;
import std.range;

import toml;
import util;
import optional;

string get_config_file_path() {
    enum CONFIG_DIR_NAME = "libsense";
    enum CONFIG_FILE_NAME = "config.toml";
    return buildPath(get_config_root(CONFIG_DIR_NAME), CONFIG_FILE_NAME);
}

Optional!string read_config_file() {
    auto config_file = get_config_file_path();
    if (!exists(config_file)) {
        return no!string;
    }
    return some(readText(config_file));
}

Optional!TOMLDocument parse_config_file() {
    auto config_file_text = read_config_file();
    return config_file_text.match!(
        (string text) => some(text.parseTOML()),
        () => no!TOMLDocument
    );
}

struct LibSenseConfig {
    string[] library_paths;

    string toString() {
        import std.array;
        import std.format;

        auto sb = appender!string;

        sb ~= format("library_paths: %s", library_paths);

        return sb.array;
    }
}

Optional!LibSenseConfig get_config() {
    auto doc = parse_config_file();
    if (doc == none) {
        return no!LibSenseConfig;
    }
    auto lib_paths = doc.front["library_paths"].array.map!(x => x.str).array;

    return some(LibSenseConfig(lib_paths));
}
