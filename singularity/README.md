
# POD Singularity Examples

Official Singularity Documentation: http://singularity.lbl.gov/

## Bootstrap Example

From a remote system, with root access:

```
sudo singularity create --size 1512 ./pod-centos7-ompi2.img
sudo singularity bootstrap ./pod-centos7-ompi2.img ./pod-centos7-ompi2.def
rsync -azvH ./pod-centos7-ompi2.img <pod_username>@<loginnode_ip>:~/
```

## Running Singularity Images on POD

The following examples use interactive qsub sessions on B30 class nodes, but an interactive session is not required to use singularity.  Singularity can be used inside a standard job submission script.

### pod-centos7-ompi2.def

```
qsub -I -q B30 -l nodes=2:ppn=28,walltime=00:15:00
module load singularity
module load openmpi/2.0.1/gcc.4.8.5
mpirun singularity exec pod-centos7-ompi2.img /usr/bin/mpi_ring
```

### pod-ubuntu16-ompi2.def

```
qsub -I -q B30 -l nodes=2:ppn=28,walltime=00:15:00
module load singularity
module load openmpi/2.0.1/gcc.6.2.0
mpirun -mca btl_tcp_if_include ib0 -mca btl tcp,sm,self singularity exec pod-centos7-ompi2.img /usr/bin/mpi_ring
```

### pod-ubuntu17-ompi2.def

```
qsub -I -q B30 -l nodes=2:ppn=28,walltime=00:15:00
module load singularity
module load openmpi/2.0.1/gcc.6.2.0
mpirun singularity exec pod-centos7-ompi2.img /usr/bin/mpi_ring
```

### pod-pod-centos7-R-openblas-lapack.def

```
qsub -I -q B30 -l nodes=1:ppn=28,walltime=00:15:00
module load singularity
singularity exec pod-centos7-R-openblas-lapack.img R --version
singularity exec pod-centos7-R-openblas-lapack.img R CMD BATCH myscript.R
```
