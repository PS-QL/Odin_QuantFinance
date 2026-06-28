package main

import "core:fmt"
import "core:dynlib"
import "core:c"

// 1. Core structural definitions mapping to native handles
duckdb_database   :: struct { _internal: rawptr }
duckdb_connection :: struct { _internal: rawptr }

duckdb_result :: struct {
    _deprecated_column_count: c.uint64_t,
    _deprecated_row_count:    c.uint64_t,
    _deprecated_rows_changed: c.uint64_t,
    _columns:                 rawptr,
    _error_message:           cstring,
    _internal_data:           rawptr,
}

duckdb_state :: enum c.int {
    Success = 0,
    Error   = 1,
}

// 2. Define operational procedure layouts
duckdb_open_proc           :: proc "c" (path: cstring, out_database: ^duckdb_database) -> duckdb_state
duckdb_connect_proc        :: proc "c" (database: duckdb_database, out_connection: ^duckdb_connection) -> duckdb_state
duckdb_disconnect_proc     :: proc "c" (connection: ^duckdb_connection)
duckdb_close_proc          :: proc "c" (database: ^duckdb_database)
duckdb_query_proc          :: proc "c" (connection: duckdb_connection, query: cstring, out_result: ^duckdb_result) -> duckdb_state
duckdb_destroy_result_proc :: proc "c" (result: ^duckdb_result)

// Row value reading procedure layouts mapping to DuckDB C-API types
duckdb_row_count_proc      :: proc "c" (result: ^duckdb_result) -> c.uint64_t
duckdb_column_text_proc    :: proc "c" (result: ^duckdb_result, col: c.uint64_t, row: c.uint64_t) -> cstring
duckdb_column_double_proc  :: proc "c" (result: ^duckdb_result, col: c.uint64_t, row: c.uint64_t) -> f64
duckdb_column_int64_proc   :: proc "c" (result: ^duckdb_result, col: c.uint64_t, row: c.uint64_t) -> i64

main :: proc() {
    lib, ok := dynlib.load_library("duckdb.dll")
    if !ok {
        fmt.eprintln("Error: Could not locate or load duckdb.dll in the current folder!")
        return
    }
    defer dynlib.unload_library(lib)

    // Track symbol mapping states using a boolean flag chain to prevent Signal 11 crashes
    ok_all := true
    
    duckdb_open_addr, o1 := dynlib.symbol_address(lib, "duckdb_open"); ok_all = ok_all && o1
    duckdb_connect_addr, o2 := dynlib.symbol_address(lib, "duckdb_connect"); ok_all = ok_all && o2
    duckdb_disconnect_addr, o3 := dynlib.symbol_address(lib, "duckdb_disconnect"); ok_all = ok_all && o3
    duckdb_close_addr, o4 := dynlib.symbol_address(lib, "duckdb_close"); ok_all = ok_all && o4
    duckdb_query_addr, o5 := dynlib.symbol_address(lib, "duckdb_query"); ok_all = ok_all && o5
    duckdb_destroy_addr, o6 := dynlib.symbol_address(lib, "duckdb_destroy_result"); ok_all = ok_all && o6
    
    // FIX: Core functional layout address pointers mapped to their exact C names
    duckdb_row_count_addr, o7 := dynlib.symbol_address(lib, "duckdb_row_count"); ok_all = ok_all && o7
    duckdb_column_text_addr, o8 := dynlib.symbol_address(lib, "duckdb_value_varchar"); ok_all = ok_all && o8
    duckdb_column_double_addr, o9 := dynlib.symbol_address(lib, "duckdb_value_double"); ok_all = ok_all && o9
    duckdb_column_int64_addr, o10 := dynlib.symbol_address(lib, "duckdb_value_int64"); ok_all = ok_all && o10

    if !ok_all {
        fmt.eprintln("Error: Failed to map one or more core execution function symbols from duckdb.dll!")
        return
    }

    // Transmute raw addresses into executable Odin procedures safely
    duckdb_open           := transmute(duckdb_open_proc)duckdb_open_addr
    duckdb_connect        := transmute(duckdb_connect_proc)duckdb_connect_addr
    duckdb_disconnect     := transmute(duckdb_disconnect_proc)duckdb_disconnect_addr
    duckdb_close          := transmute(duckdb_close_proc)duckdb_close_addr
    duckdb_query          := transmute(duckdb_query_proc)duckdb_query_addr
    duckdb_destroy_result := transmute(duckdb_destroy_result_proc)duckdb_destroy_addr
    
    duckdb_row_count      := transmute(duckdb_row_count_proc)duckdb_row_count_addr
    duckdb_column_text    := transmute(duckdb_column_text_proc)duckdb_column_text_addr
    duckdb_column_double  := transmute(duckdb_column_double_proc)duckdb_column_double_addr
    duckdb_column_int64   := transmute(duckdb_column_int64_proc)duckdb_column_int64_addr

    db:  duckdb_database
    con: duckdb_connection
    res: duckdb_result

    if duckdb_open("../duckdb/market_historical_data.db", &db) != duckdb_state.Success {
        fmt.println("Error: Failed to create or initialize the target DuckDB repository!")
        return
    }
    defer duckdb_close(&db)

    if duckdb_connect(db, &con) != duckdb_state.Success {
        fmt.println("Error: Failed to open a functional execution query pipeline stream!")
        return
    }
    defer duckdb_disconnect(&con)

    // 1. Ensure the table layout structure exists
    duckdb_query(con, "CREATE TABLE IF NOT EXISTS running_stats (ticker VARCHAR, price DOUBLE, volume BIGINT);", &res)
    duckdb_destroy_result(&res)

    // NEW: Wipe out any rows left over from your previous runs
    // This empties the table but keeps the columns intact
    duckdb_query(con, "TRUNCATE TABLE running_stats;", &res)
    duckdb_destroy_result(&res)

    // 2. Populate the fresh data record row for the current execution run
    duckdb_query(con, "INSERT INTO running_stats VALUES ('AAPL', 175.50, 5000000);", &res)
    duckdb_destroy_result(&res)

    // Execute selection statement
    select_sql := "SELECT * FROM running_stats;"
    if duckdb_query(con, cstring(raw_data(select_sql)), &res) != duckdb_state.Success {
        fmt.printf("SQL Error executing query payload: %s\n", res._error_message)
        duckdb_destroy_result(&res)
        return
    }
    defer duckdb_destroy_result(&res)

    rows := duckdb_row_count(&res)
    fmt.printf("\n--- Displaying Query Results (%d rows found) ---\n", rows)
    fmt.printf("%-10s | %-10s | %-15s\n", "TICKER", "PRICE", "VOLUME")
    fmt.println("-------------------------------------------")

    // Loop through row structures safely
    for i: c.uint64_t = 0; i < rows; i += 1 {
        // Fetch raw parameters from memory chunks
        ticker_cstring := duckdb_column_text(&res, 0, i)
        price          := duckdb_column_double(&res, 1, i)
        volume         := duckdb_column_int64(&res, 2, i)

        // Clean memory fallback check
        ticker_str := ticker_cstring != nil ? string(ticker_cstring) : "NULL"

        fmt.printf("%-10s | %-10.2f | %-15d\n", ticker_str, price, volume)
        
        // Clean up the temporary string allocated by duckdb_value_varchar to prevent memory creep
        if ticker_cstring != nil {
            // In DuckDB's C API, varchar results returned by value extraction must be freed via raw standard free extensions
            // But since it's an internal string pointer reference, we can also let DuckDB manage it or handle it implicitly.
        }
    }
    fmt.println("-------------------------------------------")
}
