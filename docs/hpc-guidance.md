# Running on an HPC

You will most likely be running simulations on a shared cluster or high performance computer. Here will will provide some guidance on running simulations on specific HPCs

## Yale GRACE cluster

The following [SLURM](https://slurm.schedmd.com/documentation.html) script can be used to submit a job to the cluster. Make sure to modify the SLURM directives to match your account name and resources requirements. Consult the [Grace documentation page](https://docs.ycrc.yale.edu/clusters/grace/) for more information on the different partitions and their compute nodes and job limits. 

```sh
#!/bin/bash

#SBATCH --job-name=scepter
#SBATCH --ntasks=1
#SBATCH --time=10:00
#SBATCH --account eisaman
#SBATCH --nodes 1
#SBATCH --mem 1G
#SBATCH --partition devel

module load netCDF-Fortran/4.6.0-iompi-2022b
module load OpenBLAS/0.3.27-GCC-13.3.0

make
```

