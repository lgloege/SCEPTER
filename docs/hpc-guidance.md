# Yale Grace Cluster

Yale Grace cluster is a shared high performance computer (HPC) maintained by the Yale Center for Research and Computing (YCRC). The YCRC maintains an [excellent documentation page](https://docs.ycrc.yale.edu/clusters/grace/), but I will provide an abbreviated version on this page. However, for more details on any topic please see the YCRC documentation.

## Steps to Get Setup and Log Into Grace

1. [Request an account](https://research.computing.yale.edu/support/hpc/account-request) if you do not already have one
2. Send us your public SSH key with the YCRC's [SSH key uploader](https://sshkeys.ycrc.yale.edu/). Allow up to ten minutes for it to propagate. See the box below if you need help finding or generating an SSH key. SSH is the Secure SHell protocol and it allows you to connect to remote (or cloud) computers, such as Grace. 
3. Once YCRC has your public key then you can connect to Grace with the following terminal command:
```
ssh netid@clustername.ycrc.yale.edu
```
If you are off campus you will need to first connect to [Yale's VPN](https://docs.ycrc.yale.edu/clusters-at-yale/access/vpn/)

!!! Note "Creating an SSH Key"
    First see if you have any SSH keys on your computer by copying the following command into the terminal 
    
    ```
    ls ~/.ssh/*.pub
    ```
    
    If you anything is displayed, then you have you have an SSH key. If you do, then you use this command to copy the key (the name may be different depending on the encryption algorithm used):
     ```
     pbcopy < ~/.ssh/id_ed25519.pub
     ``` 
    
    Alternatively, you can just print the key to the screen and then copy it:

    ```
    more ~/.ssh/id_ed25519.pub
    ```
    
    Finally, if you do not have a key, then use the following command to generate one (make sure to change the email address):

    ```
    ssh-keygen -t ed25519 -C "your_email@example.com"
    ```

## Creating a Python Environment on Grace
Use the following steps to create a conda Python environment on Grace. These steps are an abbreviated version of [YCRC's more detailed instructions](https://docs.ycrc.yale.edu/clusters-at-yale/guides/conda/#setup-your-environment).

1. Log into grace with the `ssh netid@clustername.ycrc.yale.edu`
2. Start an interactice session of the devel partion by copying the following command into the terminal (need to be on Grace): 
```
salloc --partition=devel --mem=15G --time=2:00:00 --cpus-per-task=2
```
This puts you into a compute node for two hours and gives you 15G of memory
3. Now we need to load miniconda. This can done with the following command:
```
module load miniconda
```
4. Once miniconda is loaded, you can create a new environment like this:
```
conda create -n scepter python numpy pandas matplotlib jupyter jupyterlab
```
Here I named the environment scepter and installed relevant packages into it. We only really need `numpy`, but the others may be useful for analysis later
5. Now let's load the environment into OOD so we can use in a Jupyter notebook --- if you decide to JupyterLab. First, reset the modules:
```
module reset
```
Then run the following command to load it into the OOD:
```
ycrc_conda_env.sh update
```
6. That's it! Now you have a conda environment and can use it a Jupyter notebook.


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

