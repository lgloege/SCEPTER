# Start of the makefile
# Defining variables

FC            = gfortran

CPFLAGS       = 
CPFLAGS       += -Dphiter2 # attempt to do analytical solution for derivatives 
CPFLAGS       += -Dtest_anal 
# CPFLAGS       += -Dphiter1 # numerical solution 
# CPFLAGS       += -Dphiter2_chk # chk difference between two methods (both methods should be enabled)
# CPFLAGS       += -Dphv7_2  # using old routine
# CPFLAGS       += -Ddebug 
# CPFLAGS       += -Dtiming
CPFLAGS       += -Dno_intr_findloc # need to use in cluster
# CPFLAGS       += -Dfull_flux_report # output all cumulative flux

# CFLAGS        = -fcheck=all -g -O3  
CFLAGS        = -fimplicit-none  -Wall  -Wline-truncation  -Wcharacter-truncation  -Wsurprising  \
	-Waliasing  -Wimplicit-interface  -Wunused-parameter  -fwhole-file  -fcheck=all  -std=gnu  -pedantic  -fbacktrace -O3

# LDFLAGS       = -L/usr/local/lib
LDFLAGS       = 

LIBS          = -lopenblas
OBJS          = pysil.o 
SRC           = pysil.f90 
PROGRAM       = weathering

all:            $(PROGRAM)

$(PROGRAM):     $(SRC)
	$(FC) $(SRC) -o $(PROGRAM) -cpp $(CPFLAGS) $(CFLAGS) $(LIBS) $(LDFLAGS)


clean:;         rm -f *.o *~ $(PROGRAM)

