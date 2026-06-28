package adbc

import "core:dynlib"
import "core:os"      // NEW: Import the OS package to read environment variables
import "core:strings" // NEW: Import strings to combine paths
import "core:fmt"
import "core:c"

// --- Native Handle & Structure Mappings ---
Database   :: struct { _internal: rawptr }
Connection :: struct { _internal: rawptr }

Result :: struct {
    _deprecated_column_count: c.uint64_t,
    _deprecated_row_count:    c.uint64_t,
    _deprecated_rows_changed: c.uint64_t,
    _columns:                 rawptr,
    Error_Message:           cstring,
    _internal_data:           rawptr,
}

State :: enum c.int {
    Success = 0,
    Error   = 1,
}

// --- Internal Procedure Layouts ---
open_proc           :: proc "c" (path: cstring, out_database: ^Database) -> State
connect_proc        :: proc "c" (database: Database, out_connection: ^Connection) -> State
disconnect_proc     :: proc "c" (connection: ^Connection)
close_proc          :: proc "c" (database: ^Database)
query_proc          :: proc "c" (connection: Connection, query: cstring, out_result: ^Result) -> State
destroy_result_proc :: proc "c" (result: ^Result)
row_count_proc      :: proc "c" (result: ^Result) -> c.uint64_t
column_text_proc    :: proc "c" (result: ^Result, col: c.uint64_t, row: c.uint64_t) -> cstring
column_double_proc  :: proc "c" (result: ^Result, col: c.uint64_t, row: c.uint64_t) -> f64
column_int64_proc   :: proc "c" (result: ^Result, col: c.uint64_t, row: c.uint64_t) -> i64

// --- Hidden Global Function Table ---
@(private="file") lib_handle:       dynlib.Library
@(private="file") _open:            open_proc
@(private="file") _connect:         connect_proc
@(private="file") _disconnect:      disconnect_proc
@(private="file") _close:           close_proc
@(private="file") _query:           query_proc
@(private="file") _destroy_result:  destroy_result_proc

// --- Public Function Table (Exposed to main.odin) ---
row_count:      row_count_proc
column_text:    column_text_proc
column_double:  column_double_proc
column_int64:   column_int64_proc

// Bootstraps the DLL and initialises the engine
init :: proc(db_path: cstring, out_db: ^Database) -> bool {
    // 1. Fetch the "%APPDATA%" directory path safely by explicitly providing the context allocator
    appdata_path := os.get_env("APPDATA", context.allocator)
    if len(appdata_path) == 0 {
        fmt.eprintln("Error: Could not locate the Windows %APPDATA% environment directory.")
        return false
    }
    defer delete(appdata_path) // Clean up the string memory when exiting init context

    // 2. Build the absolute path to your specific driver version
    full_path_str := strings.concatenate({
        appdata_path, 
        "/ADBC/Drivers/duckdb_windows_amd64_v1.5.4/duckdb.dll",
    })
    defer delete(full_path_str) // Clean up the combined string memory

    // 3. Load the library using the dynamically resolved runtime path string
    ok: bool
    lib_handle, ok = dynlib.load_library(full_path_str)
    if !ok {
        fmt.eprintln("Error: Failed to load duckdb.dll from AppData path.")
        return false
   }

    ok_all := true
    addr: rawptr

    addr, ok = dynlib.symbol_address(lib_handle, "duckdb_open");           _open = transmute(open_proc)addr; ok_all = ok_all && ok
    addr, ok = dynlib.symbol_address(lib_handle, "duckdb_connect");        _connect = transmute(connect_proc)addr; ok_all = ok_all && ok
    addr, ok = dynlib.symbol_address(lib_handle, "duckdb_disconnect");     _disconnect = transmute(disconnect_proc)addr; ok_all = ok_all && ok
    addr, ok = dynlib.symbol_address(lib_handle, "duckdb_close");          _close = transmute(close_proc)addr; ok_all = ok_all && ok
    addr, ok = dynlib.symbol_address(lib_handle, "duckdb_query");          _query = transmute(query_proc)addr; ok_all = ok_all && ok
    addr, ok = dynlib.symbol_address(lib_handle, "duckdb_destroy_result"); _destroy_result = transmute(destroy_result_proc)addr; ok_all = ok_all && ok
    
    addr, ok = dynlib.symbol_address(lib_handle, "duckdb_row_count");      row_count = transmute(row_count_proc)addr; ok_all = ok_all && ok
    addr, ok = dynlib.symbol_address(lib_handle, "duckdb_value_varchar");  column_text = transmute(column_text_proc)addr; ok_all = ok_all && ok
    addr, ok = dynlib.symbol_address(lib_handle, "duckdb_value_double");   column_double = transmute(column_double_proc)addr; ok_all = ok_all && ok
    addr, ok = dynlib.symbol_address(lib_handle, "duckdb_value_int64");    column_int64 = transmute(column_int64_proc)addr; ok_all = ok_all && ok

    if !ok_all do return false
    return _open(db_path, out_db) == .Success
}

connect :: proc(db: Database, out_conn: ^Connection) -> bool {
    return _connect(db, out_conn) == .Success
}

execute :: proc(conn: Connection, sql: cstring, out_res: ^Result) -> bool {
    return _query(conn, sql, out_res) == .Success
}

clear_result :: proc(res: ^Result) {
    _destroy_result(res)
}

shutdown :: proc(db: ^Database, conn: ^Connection) {
    if conn._internal != nil do _disconnect(conn)
    if db._internal != nil do _close(db)
    dynlib.unload_library(lib_handle)
}
