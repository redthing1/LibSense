module docread;

import std.stdio;
import std.file;
import std.path : extension;
import std.format;
import std.process;
import std.exception : enforce;

import optional;

import global;

class DocumentReader {
    public Optional!string read_document(string file_path) {
        // get file extension
        auto file_ext = extension(file_path);

        switch (file_ext) {
        case ".md":
            return read_markdown(file_path);
        case ".html":
            return read_html(file_path);
        case ".txt":
            return some(read_text(file_path));
        case ".pdf":
            return read_pdf(file_path);
        default:
            return no!string;
        }
    }

    string read_text(string file_path) {
        return readText(file_path);
    }

    Optional!string read_markdown(string file_path) {
        return pandoc_convert(file_path, "markdown", "plain");
    }

    Optional!string read_html(string file_path) {
        return pandoc_convert(file_path, "html", "plain");
    }

    Optional!string read_pdf(string file_path) {
        return pdftotext_convert(file_path);
    }

    Optional!string pandoc_convert(string file_path, string from_format, string to_format) {
        auto command = format("pandoc -i '%s' -f %s -t %s", file_path, from_format, to_format);
        auto pandoc = executeShell(command);

        if (pandoc.status != 0) {
            log.err(format("pandoc failed: %s", command));
            return no!string;
        }

        return some(pandoc.output);
    }

    Optional!string pdftotext_convert(string file_path) {
        auto command = format("pdftotext -layout '%s' -", file_path);
        auto pdftotext = executeShell(command);

        if (pdftotext.status != 0) {
            log.err(format("pdftotext failed: %s", command));
            return no!string;
        }

        return some(pdftotext.output);
    }
}
