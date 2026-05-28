package vol_surface_3d

import "core:math"
import "core:thread"
import "core:os"
import "base:runtime"
import "core:simd"
import "core:sys/info"

// 4-lane 64-bit float vector
Simd4f64 :: #simd [4]f64 

// Statistics helper functions
cdf :: proc(x: f64) -> f64 { return 0.5 * (1.0 + math.erf_f64(x / math.sqrt_f64(2.0))) }
pdf :: proc(x: f64) -> f64 { return math.exp_f64(-0.5 * x * x) / math.sqrt_f64(2.0 * math.PI) }

SurfaceTask :: struct {
	prices, strikes, times, results: [^]f64,
	S, r: f64,
	start, end: int,
}

solve_iv :: proc(market_price, S, K, T, r: f64) -> f64 {
	// 1. Check for intrinsic value floor. If market_price is below intrinsic, IV is mathematically impossible.
	intrinsic := max(S - K * math.exp_f64(-r * T), 0.0)
	if market_price <= intrinsic + 0.0001 do return 0.0

	sigma := 0.5 // Start with higher initial guess for better stability
	
	for _ in 0..<100 {
		sqrt_t := math.sqrt_f64(T)
		d1 := (math.ln(S / K) + (r + 0.5 * sigma * sigma) * T) / (sigma * sqrt_t)
		d2 := d1 - sigma * sqrt_t
		
		price := S * cdf(d1) - K * math.exp_f64(-r * T) * cdf(d2)
		vega  := S * sqrt_t * pdf(d1)
		
		diff := price - market_price
		
		// Convergence check
		if math.abs(diff) < 1e-7 do return sigma
		
		// 2. Numerical Guard: If Vega is near zero, Newton-Raphson fails. 
		// Use a small step or exit to prevent division by zero.
		if vega < 1e-8 {
			// Fallback: simple step toward the target price
			sigma += diff > 0 ? -0.01 : 0.01
		} else {
			// 3. Capped Newton Step: Prevent sigma from jumping by more than 50% per iteration
			step := diff / vega
			step = math.clamp(step, -0.5, 0.5) 
			sigma -= step
		}

		// 4. Physical Boundary: Clamp sigma between 0.0001 (0.01%) and 5.0 (500%)
		sigma = math.clamp(sigma, 0.0001, 5.0)
	}
	
	return sigma
}

// Thread based concurrent execution via arena temp allocator context
worker_proc :: proc(task: thread.Task) {
	p := cast(^SurfaceTask)task.data
	context = runtime.default_context()

	for i in p.start..<p.end {
		// Each index i represents a (Strike, Time) pair in the flattened grid
		p.results[i] = solve_iv(p.prices[i], p.S, p.strikes[i], p.times[i], p.r)
	}
}

// only this function gets exported thus you can call this fuction in python script via ctype and odin built dll library file 
// You can pass a Numpy array directly into an Odin Monte Carlo function using this DLL bridge for zero-copy performance.
// To pass a NumPy array directly into an Odin function for zero-copy performance, you must use a multi-pointer [^]f64 in the Odin signature. 
// This allows Odin to treat the incoming memory address as an array that can be indexed, while Python’s ctypes handles the underlying memory pointer from NumPy.

@export
calculate_3d_surface :: proc "c" (prices, strikes, times, results: [^]f64, count: int, S, r: f64) {
	context = runtime.default_context()
	
	_, num_cores, ok := info.cpu_core_count()
	pool: thread.Pool
	thread.pool_init(&pool, context.allocator, num_cores)
	thread.pool_start(&pool)
	defer thread.pool_destroy(&pool)

	tasks := make([]SurfaceTask, num_cores)
	defer delete(tasks)

	chunk_size := count / num_cores
	for i in 0..<num_cores {
		tasks[i] = {
			prices = prices, strikes = strikes, times = times, results = results,
			S = S, r = r,
			start = i * chunk_size,
			end = (i == num_cores - 1) ? count : (i + 1) * chunk_size,
		}
		thread.pool_add_task(&pool, context.allocator, worker_proc, &tasks[i])
	}
	thread.pool_finish(&pool)
}
