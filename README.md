# 📈 High-Performance Local Quant Sandbox (Odin + DuckDB)

[[Language] ](https://odin-lang.org)
[[Database]](https://duckdb.org)
[[Database Driver]](https://columnar.tech/dbc)


An institutional-grade, zero-cost quantitative backtesting and analytical sandbox environment. This platform bypasses heavy client-server database architecture and slow interpreted language overhead (like Python serialization bottlenecks) by combining the raw machine execution speed of **Odin** with the in-memory, vectorized analytical power of **DuckDB**.

---

## 🎯 Core Features

* **True Zero-Copy Architecture:** Streams C-pointers directly to hardware registers, bypassing Python memory wrapping.
* **Multi-Asset Segregation:** Uses mathematical partitioning to compute vector data across parallel ticker channels concurrently.
* **Recursive Signal Synthesis:** Implements in-memory relational mathematical recursion loops for advanced momentum filters.
* **Risk Engine Auto-Benchmarking:** Tracks live compounding portfolio equity curves to calculate Drawdown, Sharpe, and Sortino statistics instantly.


---

## 📌 System Architecture Blueprint

Your local workspace is completely self-contained, portable across Windows environments, and operates directly against the native drivers downloaded by your system package layers.

### 🗂️ Workspace Directory Blueprint
```text
C:\Dev\scripts\odin\dbc\
├── adbc\
│   └── adbc.odin          # Custom module wrapping %APPDATA% path resolutions & dynamic C-API bindings
├── duckdb\
│   ├── market_historical_data.db   # Permanent, high-performance embedded relational database file
│   └── quant_results.csv  # Vectorized flat CSV output sheet containing computed signal matrices
├── .gitignore             # Strict exclusion filter protecting repository storage boundaries
└── main.odin              # Main execution script containing strategy parameters & risk metrics
```


### ⚙️ Engine Infrastructure Flow
Rather than forcing a hardcoded local copy of `duckdb.dll` inside the code folder, the application automatically maps your system's centralized AppData runtime profile via environment variables:

```text
[main.odin] 
    │
    ▼ (Initializes Context)
[adbc.odin] ───► Reads %APPDATA% ───► Maps Target Native Path:
                                       "C:/Users/<User>/AppData/Roaming/ADBC/Drivers/duckdb_windows_amd64_v1.5.4/duckdb.dll"
                                       │
                                       ▼ (Loads Procedures via Core Runtime Injection)
                             [duckdb.dll Core Engine]
                                       │
                                       ▼ (Vectorized Calculations)
                        [./duckdb/market_historical_data.db]
```

---

## 🛠️ Summary of the Odin Implementation

The core software framework segregates low-level systems engineering from core trading script configurations:

### 1. Dynamic In-Process Loading (`adbc.odin`)
* **Bypasses Linker Flags:** Avoids static library compilation failures (`LNK1181`/`LNK1107`) by leveraging Odin's cross-platform dynamic loader (`core:dynlib`).
* **Environment Agnostic:** Automatically calls `os.get_env("APPDATA", context.allocator)` to cleanly map the dynamic library path on any Windows system, ensuring total repository portability.

### 2. Time-Series Price Simulation & Ledger Ingestion (`main.odin`)
* **Portfolio Ledger Table:** Establishes a permanent transaction framework (`portfolio_ledger`) paired with an auto-incrementing identity sequence to securely log simulated execution fills, transaction sizing, and share states.
* **Chronological Random Walk:** Populates a sequential tracking index (`time_idx`) for 10,000 synthetic rows, modeling realistic market drift vectors rather than jagged, erratic layout noise.

### 3. Isolated Multi-Asset Signal Generation
* **Ticker Partitioning:** Paired with `PARTITION BY ticker`, window functions isolate `AAPL` and `MSFT` arrays into independent memory tracks, preventing data bleed or tracking contamination.
* **Vectorized Mathematical Pipeline:** Computes your technical analytics suite simultaneously across database blocks:
  * **SMA_20 & Rolling Volatility:** Tracks moving boundaries and moving standard deviations.
  * **Recursive EMA_20:** Executes a custom mathematical recursion loop to calculate precise exponential trend curves.
  * **RSI_14:** Maps rolling gain and loss velocity to evaluate directional momentum.
  * **Automated Action Tags:** Evaluates boundaries to stamp rows as **`BUY`**, **`SELL`**, or **`HOLD`**.

### 4. Terse, High-Performance File Export
* **Bypasses Console Latency:** Drops slow, row-by-row code loops and text formatting routines.
* **Direct Streaming:** Utilizes DuckDB's high-speed `COPY ... TO ... (HEADER, DELIMITER ',')` engine to stream computed matrices straight onto your hard drive into `quant_results.csv`.

### 5. Institutional Risk Benchmarking
* **Predictive Peeking:** Employs the `LEAD()` window function to evaluate execution entry triggers against tomorrow's actual market price state.
* **Advanced Risk Diagnostics:** Measures your strategy's alpha profile via trailing metrics:
  * **Maximum Strategy Drawdown:** Tracks the largest peak-to-trough percentage equity drop your portfolio encountered.
  * **Sharpe & Sortino Ratios:** Measures excess returns relative to volatility, with the Sortino ratio isolating downside-only deviations.

---

## 📊 Sample Performance Output
Upon execution via `odin run .`, the system bypasses compilation limits and outputs a clean strategy report directly to the terminal:

```text
Successfully launched the dynamic DuckDB workspace natively from Odin!
Successfully generated 10,000 randomized synthetic asset metrics rows!
Successfully generated execution signals and exported to ./duckdb/quant_results.csv!

============================================
   STRATEGY PERFORMANCE BENCHMARK METRICS   
============================================
Total Executed Trade Signals : 2908
Hypothetical Win Count       : 2379 ✅
Hypothetical Loss Count      : 529 ❌
Strategy Win Ratio           : 81.81%
--------------------------------------------
Maximum Strategy Drawdown    : -5.19%
Automated Sharpe Ratio       : 0.9669
Automated Sortino Ratio      : 4.0397
============================================
```

## 💻 Quick Start Guide

### Prerequisites
* Ensure you have the [Odin Compiler](https://odin-lang.org) installed and mapped to your system path environment.
* Ensure you have downloaded the core DuckDB driver via your `dbc` setup tool so that `duckdb.dll` exists in your centralized AppData system profile folder.

### Running the Engine
Clone this repository to your local machine, open your Command Prompt (`cmd`) inside the project root folder, and type:

```cmd
odin run .
```
The application will automatically initialize the workspace, generate the synthetic market datasets, compute your entire quantitative feature script matrix, update your local ledger tracking tables, and export your final spreadsheet analytics instantly.
