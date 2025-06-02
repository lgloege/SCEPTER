# Python Scripts
This directory contains a collection of Python scripts used to run SCEPTER

* `get_int_prof.py`: contain functions to get output data 
* `get_int_prof_time.py`: same as `get_int_prof.py`, but with specifing the model time  
* `get_int_prof_time_dep.py`: same as `get_int_prof_time.py`, but with specifing the model depth 
* `get_soilpH_time.py`: contain functions to calculate soil pH 
* `get_soilpH_time_dep.py`: same above but with specifing the model depth
* `get_inputs.py`: contain functions to retrieve input data
* `make_inputs.py`: contain functions to make input data
* `tunespin_3_newton_inert_buff_v2_clean.py`: conduct 3 variable field-run iterations (output dir needs to be specified)
* `basalt_buff_tunespin_bisec_v2.py`: conduct field-run iteration to get to a target soil/pw pH (output dir needs to be specified)
* `spinup.py`: run a spin-up run
* `spinup_inert.py`: run series of run with bulk speces varying CECs
* `spinup_inrt2.py`: run series of run with bulk and OM speces varying CECs etc.
* `test_phreeqc_ex11.py`: run series of run with an exchanger bulk species 