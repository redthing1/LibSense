module util.minhttp;

import std.format;
import std.datetime;

import requests;
import mir.ser.json : serializeJson;
import mir.deser.json : deserializeJson;

import optional;

private Optional!TResp decode_response(TResp)(Response resp) {
    if (resp.code < 200 || resp.code >= 300) {
        return no!TResp;
    }

    auto resp_data = resp.responseBody
        .data!string
        .deserializeJson!TResp;

    return some!TResp(resp_data);
}

class MinHttpClient {
    public Duration timeout = 60.seconds;

    this() {
    }

    private Request create_request() {
        auto req = Request();
        req.timeout = timeout;
        return req;
    }

    private string encode_request_body(TReq)(TReq req) {
        return req.serializeJson();
    }

    public Optional!TResp get(TResp)(string url) {
        return create_request
            .get(url)
            .decode_response!TResp;
    }

    public Optional!TResp post(TReq, TResp)(string url, TReq req_data) {
        return create_request
            .post(url, encode_request_body(req_data), "application/json")
            .decode_response!TResp;
    }

    public Optional!TResp put(TReq, TResp)(string url, TReq req_data) {
        return create_request
            .put(url, encode_request_body(req_data), "application/json")
            .decode_response!TResp;
    }

    public Optional!TResp patch(TReq, TResp)(string url, TReq req_data) {
        return create_request
            .patch(url, encode_request_body(req_data), "application/json")
            .decode_response!TResp;
    }

    public Optional!TResp del(TResp)(string url) {
        return create_request
            .deleteRequest(url)
            .decode_response!TResp;
    }
}
