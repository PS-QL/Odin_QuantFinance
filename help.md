# High-Performance Local Quant Sandbox (Odin + DuckDB)

An institutional-grade, zero-cost quantitative backtesting and analytical sandbox environment. This platform bypasses heavy client-server database architecture and slow interpreted language overhead (like Python serialization bottlenecks) by combining the raw machine execution speed of **Odin** with the in-memory, vectorized analytical power of **DuckDB**.

---

## 📌 System Architecture Blueprint

Your local workspace is completely self-contained, portable across Windows environments, and operates directly against the native drivers downloaded by your system package layers.

### 🗂️ Workspace Directory Blueprint
```text
C:\Dev\scripts\odin\dbc\
├── adbc\
│   └── adbc.odin          # Custom module wrapping %APPDATA% path resolutions & dynamic C-API bindings
├── duckdb\
│   ├── market_historical_data.db   # Your permanent, high-performance embedded relational dataset repo
│   └── quant_results.csv  # Blazing-fast structured CSV output sheet containing computed signals
└── main.odin              # Lean execution script containing strategy configurations & risk metrics
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

## 🚀 Summary of the Odin Implementation

The core platform architecture is built around clean segregation of concerns: **`adbc.odin`** acts as a technical infrastructure layer executing system tasks invisibly, while **`main.odin`** serves as your pure quantitative sandbox.

### 1. Dynamic In-Process Loading (`adbc.odin`)
* **Zero Missing-Symbol Errors:** Bypasses standard link-time MSVC compiler issues (`LNK1181`/`LNK1107`) by leveraging Odin's cross-platform dynamic loader (`core:dynlib`).
* **Environment Agnostic:** Natively leverages `os.get_env("APPDATA", context.allocator)` to cleanly map the dynamic library path on any Windows system, making your GitHub repository instantly portable for deployment.
* **C-API Mapping:** Exposes native database contexts as clean, type-safe structures (`adbc.Database`, `adbc.Connection`, `adbc.Result`) while transmuting low-level handles into idiomatic Odin procedures.

### 2. Time-Series Price Simulation & Ledger Ingestion (`main.odin`)
* **Portfolio Ledger:** Generates a permanent relational schema block (`portfolio_ledger`) with an independent identification sequence to securely track simulated transaction fills, execution metrics, and share counts over time.
* **Sequenced Random Walk:** Generates a clean chronological tracking timeline (`time_idx`) for 10,000 synthetic rows, modeling structured price-drift patterns that simulate real asset movements rather than jagged, erratic noise.

### 3. Isolated Multi-Asset Signal Generation
* **True Ticker Segregation:** Utilizing database window functions paired with `PARTITION BY ticker`, the code ensures `AAPL` metrics only consider `AAPL` records, and `MSFT` metrics only consider `MSFT` records.
* **Technical Signal Pipeline:** Computes a full vector matrix simultaneously over the asset partitions directly in memory without manual loops or formatting layers:
  * **SMA_20 & Rolling Volatility:** Captures baseline moving boundaries and asset standard deviations.
  * **Recursive EMA_20:** Executes a custom mathematical recursion loop (`WITH RECURSIVE`) to model exponential trend momentum.
  * **RSI_14:** Maps rolling gain and loss dynamics to identify market entry zones.
  * **Automated Action Tags:** Evaluates indicator boundaries to cleanly label rows as **`BUY`**, **`SELL`**, or **`HOLD`**.

### 4. Terse, High-Performance File Export
* **Bypasses Console Latency:** Completely eliminates tedious row-by-row code loops and slow string rendering on the terminal.
* **Direct Streaming:** Uses DuckDB's native `COPY ... TO ... (HEADER, DELIMITER ',')` engine to stream computed data sets directly into `quant_results.csv`, maximizing disk-write speeds.

### 5. Institutional-Grade Performance Benchmarking
* **Predictive Peeking:** Uses the `LEAD()` window function to match active entry signals against tomorrow's actual price state.
* **Equity Curve Evaluation:** Compounds trading metrics into a simulated wealth curve to extract professional risk parameters:
  * **Win/Loss Metrics:** Tracks exact win counts and strategy percent ratios.
  * **Maximum Strategy Drawdown:** Calculates the single largest peak-to-trough drop your simulated balance suffered.
  * **Sharpe & Sortino Ratios:** Measures excess returns relative to risk, with the Sortino ratio penalizing the strategy strictly for downside volatility.

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
Total Executed Trade Signals : 2341
Hypothetical Win Count       : 1162 ✅
Hypothetical Loss Count      : 1179 ❌
Strategy Win Ratio           : 49.64%
--------------------------------------------
Maximum Strategy Drawdown    : -18.43%
Automated Sharpe Ratio       : -0.0124
Automated Sortino Ratio      : -0.0178
============================================
```

## 🛠️ Getting Started
1. Install DuckDB or the ADBC Driver via the `dbc` tool.
2. Ensure `duckdb.dll` exists in your `%APPDATA%/ADBC/Drivers/duckdb_windows_amd64_v1.5.4/` folder.
3. Open your terminal inside your repository folder and run:
   ```cmd
   odin run .
   ```
