# SCEPTER

This repository contains the SCEPTER source code and Python functions to compile and run simulations.

## Directory Structure

```sh
.
├── data/          # Data used to run simulations
├── LICENSE        # License specifying code usage
├── makefile       # Used to compile source code
├── python/        # Set of python functions to run simulations
├── README.md      # Top-level documentation
└── scepter.f90    # Source code
```


# Simulations from GMD paper

## test for Sikora buffer used in in Section 3
1. in-silico field samples 
    1. modify outdir in L20 of `spinup_inert.py` 
    2. type: `python3 spinup_inert.py`
2. buffer pH for field samples in silico
    1. modify outdir in L528 and 
        undo comments-out in L849-852 of `get_soilpH_time.py`
    2. type: `python3 get_soilpH_time.py`


## cation exchange experiment in Section 3 
1. cation exchange equilibrium simulation
    1. modify outdir in L176 of test_phreeqc_ex11_init.py
    2. type: python3 test_phreeqc_ex11_init.py
2. cation exchange + advection + dispersion simulation
	1. spin-up
		1. modify outdir in L176 of `test_phreeqc_ex11.py`
		2. type: `python3 test_phreeqc_ex11.py`
	2 dynamic simulation 
		1. undo comment-out in L16,17 of `makefile`
		2. type: `make` 
		3. undo comment-out in L277-280 of `test_phreeqc_ex11.py`
		4. type: `python3 test_phreeqc_ex11.py`
	
## mesocosm experiment in Section 3 
1. field simulation
    1. modify outdir in L159 of spinup_inrt2.py 
    2. type: python3 spinup_inrt2.py

2. laboratory simulation
    1. modify outdir in L528, L888 of get_soilpH_time.py 
    2. type: python3 get_soilpH_time.py
    
## alkalinity requiremnt for ERW in Section 4 
field + laboratory simulation
1. spin/tune-up 
    1. modify outdir in L148 of tunespin_3_newton_inert_buff_v2_clean.py 
    2. type: `python3 tunespin_3_newton_inert_buff_v2_clean.py spinup_run_name 
        21.103289732688683 6.058006742238197 20.980309042371502 2.0516666666666667 
        8.222189843654622 0.282726679550165 0.35136107875550837 0.0010131311683626316 
        1.005952418781816`

> [!NOTE]  
> the runtime inputs are to specify: run ID, CEC (cmol/kg), target soil pH, 
        target exchange acidity (%CEC), target soil OM (wt%), temperature (oC),
        moisture, runoff (m/yr), erosion rate (m/yr), nitrification rate (gN/m2/yr)

2. basalt application 
    1. modify outdir in L93 of basalt_buff_tunespin_bisec_v2.py and
        option of using soil/porewater pH (phnorm_pw=False/True, L25-26)
    2. type: python3 basalt_buff_tunespin_bisec_v2.py 6.2 1 21.103289732688683 
        basalt_run_name spinup_run_name

> [!NOTE]  
> note that the runtime inputs are to specify: 
        target pH, duration of run, CEC (cmol/kg), basalt run name, spin/tune-up run name

3. calculating soil pH prodiles
    1. modify outdir in L49, L299 of get_soilpH_time_dep.py
    2. type: get_soilpH_time_dep.py basalt_run_name