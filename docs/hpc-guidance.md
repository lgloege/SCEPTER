# Running on an HPC

You will most likely be running simulations on a shared cluster or high performance computer. Here will will provide some guidance on running simulations on specific HPCs

## Yale GRACE cluster

The following [SLURM](https://slurm.schedmd.com/documentation.html) script can be used to submit a job to the cluster. Make sure to modify the SLURM directives to match your account name and resources requirements. Consult the [Grace documentation page](https://docs.ycrc.yale.edu/clusters/grace/) for more information on the different [partitions](https://docs.ycrc.yale.edu/clusters/grace/#public-partitions) and their compute nodes and job limits. YCRC also provides guidance on [running jobs with SLURM scripts](https://docs.ycrc.yale.edu/clusters-at-yale/job-scheduling/). 

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

In the code above, the lines with `#SBATCH` are called SLURM directives. These instructions tell the SLURM job scheduler how to manage and allocate resources for your job on the HPC. The directives in the code above do the following:

- `#SBATCH --job-name=scepter`: Sets the name of the job to "scepter", which is helpful for identifying it in job queues and logs.
- `#SBATCH --ntasks=1`: Requests 1 task for the job. This is often used for serial jobs.
- `#SBATCH --time=10:00`: Sets the maximum run time for the job to 10 minutes. After this time, the job will be killed if not completed.
- `#SBATCH --account=eisaman`: Charges the job's resource usage to the "eisaman" account. 
- `#SBATCH --nodes=1`: Requests 1 compute node for the job.
- `#SBATCH --mem=1G`: Requests 1 gigabyte of memory for the job.
- `#SBATCH --partition=devel`: Submits the job to the "devel" partition.

See the table [here](https://docs.ycrc.yale.edu/clusters-at-yale/job-scheduling/#common-job-request-options) for descriptions of other directives.

!!! note
    Each user can only have 1 job running in the `devel` partition. Devel is typically used for short or development jobs.
    This is also where [open-on-demand](https://docs.ycrc.yale.edu/clusters-at-yale/access/ood/) jobs run on Grace. So, if you are unable to submit to this parititon it likely means you already have something running there. Maybe try the `day` partition.

## submit your job and check the status
Once you have your submit script create you can run it with the following command:

```sh
sbatch submit.sbatch
```

This assumes you named your script `submit.sbatch`. The name can you whatever you want. If you want to be clear that this a shell script you could call it `submit.sh`.

To check the status of all your jobs in the queue you can use:

```sh
squeue --me
``` 

The latter will list the status of the job and it will also list a job ID. This job ID can be used to cancel the job if you need to. Let's say the job ID is 1234, you can use the following command to cancel the job:

```sh
scancel 1234
```

Finally you can check the effeciency of the job with:

```sh
seff 1234
```

