import os
import ctypes
import numpy as np
from scipy.stats import norm

# Notepad++'s execution environment might be defaulting to a non-interactive backend like agg, which only renders to files rather than displaying windows. 
# You can explicitly set an interactive backend like TkAgg or Qt5Agg at the very top of your script
import matplotlib
matplotlib.use('TkAgg')  # Must be called before importing pyplot
import matplotlib.pyplot as plt
from matplotlib import cm


# Load Library
lib = ctypes.CDLL(os.path.abspath("vol_3D_surface_lib.dll"))
lib.calculate_3d_surface.argtypes = [
    ctypes.POINTER(ctypes.c_double), # prices
    ctypes.POINTER(ctypes.c_double), # strikes
    ctypes.POINTER(ctypes.c_double), # times
    ctypes.POINTER(ctypes.c_double), # results
    ctypes.c_longlong,               # count
    ctypes.c_double, ctypes.c_double # S, r
]

def generate_mock_market_data(S, K, T, r):
    # Create a synthetic "Vol Surface" model: Smile + Term Structure
    vol = 0.2 + 0.4 * ((K - S)/S)**2 + 0.1 * np.exp(-T)
    d1 = (np.log(S/K) + (r + 0.5*vol**2)*T) / (vol*np.sqrt(T))
    d2 = d1 - vol*np.sqrt(T)
    price = S * norm.cdf(d1) - K * np.exp(-r*T) * norm.cdf(d2)
    return price.astype(np.float64)

# 1. Grid Parameters
S, r = 100.0, 0.05
strikes = np.linspace(70, 130, 50)
tenors = np.linspace(0.1, 2.0, 50)
K_grid, T_grid = np.meshgrid(strikes, tenors)

# 2. Flatten for Odin (C-style contiguous)
K_flat = K_grid.flatten().astype(np.float64)
T_flat = T_grid.flatten().astype(np.float64)
P_flat = generate_mock_market_data(S, K_flat, T_flat, r)
IV_flat = np.zeros_like(K_flat)

# 3. Call Odin Parallel Library
lib.calculate_3d_surface(
    P_flat.ctypes.data_as(ctypes.POINTER(ctypes.c_double)),
    K_flat.ctypes.data_as(ctypes.POINTER(ctypes.c_double)),
    T_flat.ctypes.data_as(ctypes.POINTER(ctypes.c_double)),
    IV_flat.ctypes.data_as(ctypes.POINTER(ctypes.c_double)),
    len(K_flat), S, r
)

# 4. Reshape Results for 3D Plot
IV_grid = IV_flat.reshape(K_grid.shape)
# Optional: Cap IV in Python for cleaner plotting
IV_grid = np.clip(IV_grid, 0, 2.0) # Cap at 200% for visualization


# 5. Plotting
fig = plt.figure(figsize=(12, 8))
ax = fig.add_subplot(111, projection='3d')

surf = ax.plot_surface(K_grid, T_grid, IV_grid * 100, cmap=cm.viridis,
                       linewidth=0, antialiased=True, alpha=0.8)

ax.set_xlabel('Strike Price (K)')
ax.set_ylabel('Time to Maturity (T)')
ax.set_zlabel('Implied Volatility (%)')
ax.set_title('3D Volatility Surface Computed via Parallel Odin')

fig.colorbar(surf, shrink=0.5, aspect=5)
plt.show()
