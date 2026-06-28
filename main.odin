package main

import "core:fmt"
import "adbc" // Import your simplified custom database module

main :: proc() {
    db:  adbc.Database
    con: adbc.Connection
    res: adbc.Result

    // 1. Initialize the background runtime engine and point to your specific db name
    if !adbc.init("./duckdb/market_historical_data.db", &db) {
        fmt.println("Error: Failed to load library or build target DuckDB file path!")
        return
    }
    defer adbc.shutdown(&db, &con)

    // 2. Establish a data pipeline execution stream
    if !adbc.connect(db, &con) {
        fmt.println("Error: Failed to open a functional execution query pipeline stream!")
        return
    }

    fmt.println("Successfully launched the dynamic DuckDB workspace natively from Odin!")

    // 3. Setup the permanent Portfolio Tracker table to store simulated execution trade logs
    portfolio_setup_sql := `
        CREATE TABLE IF NOT EXISTS portfolio_ledger (
            trade_id INTEGER PRIMARY KEY DEFAULT nextval('id_seq'),
            ticker VARCHAR,
            action VARCHAR,     -- 'BUY' or 'SELL'
            execution_price DOUBLE,
            shares INT,
            trade_volume BIGINT,
            timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    `
    adbc.execute(con, "CREATE SEQUENCE IF NOT EXISTS id_seq;", &res); adbc.clear_result(&res)
    adbc.execute(con, cstring(raw_data(portfolio_setup_sql)), &res);  adbc.clear_result(&res)

    // 4. Reset our historical market data environment and generate a sequenced time-series table
    adbc.execute(con, "DROP TABLE IF EXISTS running_stats;", &res); adbc.clear_result(&res)
    
    generate_series_sql := `
        CREATE TABLE running_stats AS 
        WITH RECURSIVE time_steps AS (
            SELECT 1 as step_id
            UNION ALL
            SELECT step_id + 1 FROM time_steps WHERE step_id < 10000
        ),
        random_assignments AS (
            SELECT 
                CASE WHEN random() > 0.5 THEN 'AAPL' ELSE 'MSFT' END as ticker,
                150.0 + (random() * 20.0) as price, 
                CAST(1000000 + (random() * 9000000) AS BIGINT) as volume 
            FROM time_steps
        )
        SELECT 
            ticker,
            ROW_NUMBER() OVER (PARTITION BY ticker) as time_idx, 
            price,
            volume
        FROM random_assignments;
    `
    adbc.execute(con, cstring(raw_data(generate_series_sql)), &res); adbc.clear_result(&res)
    fmt.println("Successfully generated 10,000 randomized synthetic asset metrics rows!")

    // 5. Compute Quantitative Metrics AND generate automated BUY/SELL/HOLD execution labels
    adbc.execute(con, "DROP TABLE IF EXISTS analyzed_data;", &res); adbc.clear_result(&res)
    
    create_view_sql := `
        CREATE TABLE analyzed_data AS 
        WITH RECURSIVE sequential_data AS (
            SELECT 
                ticker, price, volume, time_idx,
                ROW_NUMBER() OVER (PARTITION BY ticker ORDER BY time_idx ASC) as row_seq,
                AVG(price) OVER (PARTITION BY ticker ORDER BY time_idx ASC ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) as sma_20,
                STDDEV(price) OVER (PARTITION BY ticker ORDER BY time_idx ASC ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) as rolling_vol,
                price - LAG(price, 1) OVER (PARTITION BY ticker ORDER BY time_idx ASC) as change
            FROM running_stats
        ),
        split_gains_losses AS (
            SELECT *,
                CASE WHEN change > 0 THEN change ELSE 0 END as gain,
                CASE WHEN change < 0 THEN -change ELSE 0 END as loss,
                AVG(CASE WHEN change > 0 THEN change ELSE 0 END) OVER (PARTITION BY ticker ORDER BY time_idx ASC ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) as avg_gain,
                AVG(CASE WHEN change < 0 THEN -change ELSE 0 END) OVER (PARTITION BY ticker ORDER BY time_idx ASC ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) as avg_loss
            FROM sequential_data
        ),
        ema_recursion AS (
            SELECT ticker, row_seq, price as ema_20 FROM split_gains_losses WHERE row_seq = 1
            UNION ALL
            SELECT 
                curr.ticker, curr.row_seq, 
                (curr.price * 0.095) + (prev.ema_20 * (1.0 - 0.095)) as ema_20
            FROM split_gains_losses curr
            JOIN ema_recursion prev ON curr.ticker = prev.ticker AND curr.row_seq = prev.row_seq + 1
        )
        SELECT 
            d.ticker, d.price, d.volume, d.time_idx, d.sma_20, d.rolling_vol, ROUND(e.ema_20, 2) as ema_20,
            CASE WHEN d.avg_loss = 0 THEN 100.0 ELSE ROUND(100.0 - (100.0 / (1.0 + (d.avg_gain / d.avg_loss))), 2) END as rsi_14,
            CASE WHEN (CASE WHEN d.avg_loss = 0 THEN 100.0 ELSE ROUND(100.0 - (100.0 / (1.0 + (d.avg_gain / d.avg_loss))), 2) END) < 45.0 THEN 'BUY'
                 WHEN (CASE WHEN d.avg_loss = 0 THEN 100.0 ELSE ROUND(100.0 - (100.0 / (1.0 + (d.avg_gain / d.avg_loss))), 2) END) > 55.0 THEN 'SELL'
                 ELSE 'HOLD' END as signal
        FROM split_gains_losses d
        JOIN ema_recursion e ON d.ticker = e.ticker AND d.row_seq = e.row_seq;
    `
    adbc.execute(con, cstring(raw_data(create_view_sql)), &res); adbc.clear_result(&res)

    adbc.execute(con, "COPY (SELECT * FROM analyzed_data ORDER BY ticker, time_idx ASC) TO './duckdb/quant_results.csv' (HEADER, DELIMITER ',');", &res); adbc.clear_result(&res)
    fmt.println("Successfully generated execution signals and exported to ./duckdb/quant_results.csv!")

    // 6. ADVANCED PERFORMANCE BENCHMARKING & RISK RATIOS
    // Combines basic counts with compounding Equity Curve drift, peak tracking for Max Drawdown,
    // and mathematical standard deviation matrices for Sharpe and Sortino ratios.
    benchmark_sql := `
        WITH signal_forward_look AS (
            SELECT 
                ticker, price, time_idx, signal,
                LEAD(price, 1) OVER (PARTITION BY ticker ORDER BY time_idx ASC) as next_price
            FROM analyzed_data
        ),
        trade_returns AS (
            SELECT *,
                -- Calculate percent return of this specific trade entry snapshot
                CASE 
                    WHEN signal = 'BUY'  THEN (next_price - price) / price
                    WHEN signal = 'SELL' THEN (price - next_price) / price
                    ELSE 0.0
                END as trade_return
            FROM signal_forward_look
            WHERE signal IN ('BUY', 'SELL') AND next_price IS NOT NULL
        ),
        equity_curve AS (
            SELECT *,
                -- Calculate a chronological rank across combined transactions to chart cumulative growth
                ROW_NUMBER() OVER (ORDER BY time_idx ASC) as trade_seq,
                -- Compounding equity log return addition to trace portfolio state changes
                SUM(log(1.0 + trade_return)) OVER (ORDER BY time_idx ASC) as cumulative_log_return
            FROM trade_returns
        ),
        portfolio_trajectory AS (
            SELECT *,
                -- Convert log returns back to standard compound equity multiplier (Starting at $1.0)
                exp(cumulative_log_return) as equity_value,
                -- Track the peak historical wealth achieved up to this point in the timeline
                MAX(exp(cumulative_log_return)) OVER (ORDER BY trade_seq ASC) as peak_equity
            FROM equity_curve
        ),
        drawdowns_and_ratios AS (
            SELECT *,
                -- Drawdown formula: (Current Equity - Peak Equity) / Peak Equity
                (equity_value - peak_equity) / peak_equity as drawdown,
                -- Excess returns assuming a 0% baseline risk-free floor rate
                trade_return as excess_return,
                -- Capture downside-only deviations (Zeroing out positive trade distributions)
                CASE WHEN trade_return < 0.0 THEN trade_return ELSE 0.0 END as downside_return
            FROM portfolio_trajectory
        ),
        risk_aggregations AS (
            SELECT 
                COUNT(*) as total_trades,
                COUNT(CASE WHEN excess_return > 0.0 THEN 1 END) as win_count,
                COUNT(CASE WHEN excess_return <= 0.0 THEN 1 END) as loss_count,
                MIN(drawdown) as max_drawdown,
                AVG(excess_return) as avg_return,
                STDDEV(excess_return) as std_dev,
                STDDEV(downside_return) as downside_std_dev
            FROM drawdowns_and_ratios
        )
        SELECT 
            total_trades,
            win_count,
            loss_count,
            COALESCE(ROUND((win_count * 100.0) / NULLIF(total_trades, 0), 2), 0.0) as win_ratio_pct,
            ROUND(max_drawdown * 100.0, 2) as max_drawdown_pct,
            -- Sharpe Ratio = Mean Excess Return / Standard Deviation
            COALESCE(ROUND(avg_return / NULLIF(std_dev, 0.0), 4), 0.0) as sharpe_ratio,
            -- Sortino Ratio = Mean Excess Return / Downside Standard Deviation
            COALESCE(ROUND(avg_return / NULLIF(downside_std_dev, 0.0), 4), 0.0) as sortino_ratio
        FROM risk_aggregations;
    `

    if !adbc.execute(con, cstring(raw_data(benchmark_sql)), &res) {
        fmt.printf("SQL Error running analytical risk parameters: %s\n", res.Error_Message)
        adbc.clear_result(&res)
        return
    }
    defer adbc.clear_result(&res)

    // Parse the extended data array directly from the memory blocks
    total_trades := adbc.column_int64(&res, 0, 0)
    wins         := adbc.column_int64(&res, 1, 0)
    losses       := adbc.column_int64(&res, 2, 0)
    win_ratio    := adbc.column_double(&res, 3, 0)
    max_dd       := adbc.column_double(&res, 4, 0)
    sharpe       := adbc.column_double(&res, 5, 0)
    sortino      := adbc.column_double(&res, 6, 0)

    fmt.printf("\n============================================\n")
    fmt.printf("   STRATEGY PERFORMANCE BENCHMARK METRICS   \n")
    fmt.printf("=============================================\n")
    fmt.printf("Total Executed Trade Signals : %d\n", total_trades)
    fmt.printf("Hypothetical Win Count       : %d ✅\n", wins)
    fmt.printf("Hypothetical Loss Count      : %d ❌\n", losses)
    fmt.printf("Strategy Win Ratio           : %.2f%%\n", win_ratio)
	fmt.printf("----------------------------------------------------------------------------\n")
	fmt.printf("Maximum Strategy Drawdown    : %.2f%%\n", max_dd)
	fmt.printf("Automated Sharpe Ratio       : %.4f\n", sharpe)
	fmt.printf("Automated Sortino Ratio      : %.4f\n", sortino)
    fmt.printf("=============================================\n")
}
	