@echo off
:: To bundle your high-performance Odin functions into a library for Python, 
:: you must use the @export attribute and the "c" calling convention. 
:: This ensures that the Odin compiler generates symbols that the Python ctypes library can discover and call correctly. 

REM Step#1. The Odin Library (vol_3D_surface_lib.odin) : here you wrap your logic into exported procedures. Note that we use f64 (equivalent to c_double in Python).

REM Step#2. Compiling to a Shared Library : Use the -build-mode:shared (or dll on Windows) flag to generate the library file. 
odin build vol_3D_surface_lib.odin -file -build-mode:dll

REM Step#3. Calling from Python (bridge.py)
:: Use the Python ctypes library to load the library and define the argument/return types.
python bridge_vol_3D_surface.py

@echo off

PAUSE 