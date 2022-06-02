module util;

string get_config_root(string app_name) {
    import std.process;
    import std.path: expandTilde, buildPath;
    auto config_dir = expandTilde(environment.get("XDG_CONFIG_HOME", "~/.config"));

    return buildPath(config_dir, app_name);
}