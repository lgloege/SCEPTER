# Start of the makefile
# Defining variables

FC            = gfortran
# FC            = ifort

CPFLAGS       = 
CPFLAGS       += -Dno_intr_findloc # need to use in cluster
# CPFLAGS       += -Dshow_PSDiter # showing iteration process during PSD calculation
# CPFLAGS       += -Dparallel_ON # testing parallelization
# CPFLAGS       += -Dnpar_in=1 # number of threads for parallelization 
# CPFLAGS       += -Dnpar_in=1 # number of threads for parallelization 
# CPFLAGS       += -Dparpsd_chk # checking parallelization results
# CPFLAGS       += -Dksld_chk # checking rate consts for sld species
CPFLAGS       += -DolddustPSD # using old PSD for dust (not user input but prescribed one)
# CPFLAGS       += -Derrmtx_printout # 
CPFLAGS       += -Dmod_basalt_cmp # using basalt composition defined in <basalt_define.h>
# CPFLAGS       += -Ddef_flx_save_alltime # flux reported each integration (costs lots of bites)
# CPFLAGS       += -Dfull_flux_report # output all cumulative flux
# CPFLAGS       += -Ddisp_lim # limiting the display of results
# CPFLAGS       += -Ddiss_only # not allowing precipitation of minerals
# CPFLAGS       += -Dlim_minsld # limiting mineral lowest conc. 
# CPFLAGS       += -Dporoiter # do iteration for porosity  
# CPFLAGS       += -Dcalcw_full # fully coupled w calcuation  
# CPFLAGS       += -Ddispiter # showing PSD flux in each iteration   
# CPFLAGS       += -DdispPSDiter # showing PSD flux in each iteration   
# CPFLAGS       += -Dcalcporo_full # fully coupled poro calcuation  
# CPFLAGS       += -Diwtypein=0 # uplift type 0--cnst w, 1-- cnst poro*w, 2-- cnst (1-poro)*w, 3--- w-flexible, if not defined 0 is taken

ifeq ($(FC),gfortran)
  # CFLAGS        = -fcheck=all -g -O3  
  # CFLAGS        = -Wall -O3 -g -fcheck=all -ffpe-trap=invalid,zero,overflow -fbacktrace
  # CFLAGS        = -Wall -O3 -g -fcheck=all -fbacktrace
  CFLAGS        = -fimplicit-none  -Wall  -Wline-truncation  -Wcharacter-truncation  -Wsurprising  \
	  -Waliasing  -Wimplicit-interface  -Wunused-parameter  -fwhole-file  -fcheck=all  -std=gnu  -pedantic  -fbacktrace -O3

endif

ifeq ($(FC),ifort)
  CFLAGS        = -O3 -heap-arrays -g -traceback -check bounds -fp-stack-check -gen-interfaces -warn interfaces -check arg_temp_created 
endif 

# LDFLAGS       = -L/usr/local/lib
LDFLAGS       = 

LIBS          = -lopenblas

ifneq (,$(findstring -Dmod_basalt_cmp,$(CPFLAGS)))
  # Found -Dmod_basalt_cmp
  INC          = -I/storage/coda1/p-creinhard3/0/ykanzaki3/PyWeath/data 
else
  # Not found
  INC          = 
endif

ifneq (,$(findstring -Dparallel_ON,$(CPFLAGS)))
  # Found -Dparallel_ON
  CFLAGS        += -fopenmp
else
  # Not found
endif

# OBJS          = pysil_dev.o 
# SRC           = pysil_dev.f90 
# OBJS          = pysil_sent.o 
# SRC           = pysil_sent.f90 
# OBJS          = pysil_dev_PSD.o 
# SRC           = pysil_dev_PSD.f90 
# OBJS          = pysil_DEV_AQ.o
# SRC           = pysil_DEV_AQ.f90
# OBJS          = pysil_DEV_NO3_ADS.o
# SRC           = pysil_DEV_NO3_ADS.f90
# OBJS          = pysil_DEV_NO3.o
# SRC           = pysil_DEV_NO3.f90
# OBJS          = pysil_DEV_AQ_ADSH_NO3H.o
# SRC           = pysil_DEV_AQ_ADSH_NO3H.f90
# OBJS          = pysil_DEV_AQ_ADSH_NO3_fert.o
# SRC           = pysil_DEV_AQ_ADSH_NO3_fert.f90
# OBJS          = pysil_DEV_AQ_ADSH_NO3_fert_DEV.o
# SRC           = pysil_DEV_AQ_ADSH_NO3_fert_DEV.f90
# OBJS          = pysil_DEV_AQ_ADSH_NO3_fert_DEVDEV.o
# SRC           = pysil_DEV_AQ_ADSH_NO3_fert_DEVDEV.f90
# OBJS          = pysil_DEV_AQ_ADSH_NO3_fert_DEVDEV_DEV.o
# SRC           = pysil_DEV_AQ_ADSH_NO3_fert_DEVDEV_DEV.f90
OBJS          = pysil.o 
SRC           = pysil.f90  
# OBJS          = pysil_DEV_AQ_ADSH_NO3.o
# SRC           = pysil_DEV_AQ_ADSH_NO3.f90
# OBJS          = pysil_DEV_AQ_ADSH.o
# SRC           = pysil_DEV_AQ_ADSH.f90
# OBJS          = pysil_DEV_AQ_ADS.o
# SRC           = pysil_DEV_AQ_ADS.f90
# OBJS          = pysil_dev_dev_PARPSD_v3.o 
# SRC           = pysil_dev_dev_PARPSD_v3.f90 
# OBJS          = pysil_dev_dev_PARPSD.o 
# SRC           = pysil_dev_dev_PARPSD.f90 
# OBJS          = pysil_dev_dev_PARPSD_v2c.o 
# SRC           = pysil_dev_dev_PARPSD_v2c.f90 
# OBJS          = pysil_dev_dev_PARPSD_v2.o 
# SRC           = pysil_dev_dev_PARPSD_v2.f90 
# OBJS          = pysil_main.o pysil_bks.o 
# SRC           = pysil_main.f90 pysil_bks.f90  
# OBJS          = pysil_dev_dev.o 
# SRC           = pysil_dev_dev.f90 
# OBJS          = pysil_dev_dev_poroiter2.o 
# SRC           = pysil_dev_dev_poroiter2.f90 
# OBJS          = pysil_dev_dev_SSV_NOT_WORKING.o 
# SRC           = pysil_dev_dev_SSV_NOT_WORKING.f90 
PROGRAM       = weathering

all:            $(PROGRAM)

$(PROGRAM):     $(OBJS)
	$(FC) $(OBJS) -o $(PROGRAM) -cpp $(CPFLAGS) $(CFLAGS) $(LIBS) $(LDFLAGS) $(INC)

$(OBJS):        $(SRC) 
	$(FC) $(SRC) -c -cpp $(CPFLAGS) $(CFLAGS) $(LIBS) $(LDFLAGS) $(INC)

clean:;         rm -f *.o  *~ $(PROGRAM)
blank:;         truncate -s 0 *.out
cleanall:;         rm -f *.o *.out *~ $(PROGRAM)

