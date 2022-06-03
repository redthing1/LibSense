module util.chunker;

T[][] chunk(T)(T[] arr, bool delegate(T[]) chunk_boundary_func) {
    // chunk an array into an array of chunks, splitting when the boundary function returns true

    T[][] chunks = [];
    T[] current_chunk = [];

    foreach (i, item; arr) {
        if (chunk_boundary_func(current_chunk)) {
            // chunk boundary returned true, so we should save this chunk
            chunks ~= current_chunk;
            // and start a new one
            current_chunk = [];
        }
        // add the item to the current chunk
        current_chunk ~= item;
    }

    // add the last chunk
    chunks ~= current_chunk;

    return chunks;
}
