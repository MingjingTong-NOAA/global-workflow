help([[
Build environment for workflow utilities on Hera
]])

prepend_path("MODULEPATH", "/scratch1/NCEPDEV/nems/role.epic/spack-stack/spack-stack-1.6.0/envs/gsi-addon-dev-rocky8/install/modulefiles/Core")

stack_intel_ver=os.getenv("stack_intel_ver") or "2021.5.0"
load(pathJoin("stack-intel", stack_intel_ver))

stack_impi_ver=os.getenv("stack_impi_ver") or "2021.5.1"
load(pathJoin("stack-intel-oneapi-mpi", stack_impi_ver))

cmake_ver=os.getenv("cmake_ver") or "3.23.1"
load(pathJoin("cmake", cmake_ver))

load(pathJoin("jasper", "2.0.32"))
load(pathJoin("zlib", "1.2.13"))
load(pathJoin("libpng", "1.6.37"))

load(pathJoin("hdf5", "1.14.0"))
load(pathJoin("netcdf-c", "4.9.2"))
load(pathJoin("netcdf-fortran", "4.6.1"))

load(pathJoin("bacio", "2.4.1"))
load(pathJoin("g2", "3.4.5"))
load(pathJoin("ip", "4.3.0"))
load(pathJoin("nemsio", "2.5.4"))
load(pathJoin("sp", "2.5.0"))
load(pathJoin("w3emc", "2.10.0"))
load(pathJoin("w3nco", "2.4.1"))
load(pathJoin("nemsiogfs", "2.5.3"))
load(pathJoin("ncio", "1.1.2"))
load(pathJoin("landsfcutil", "2.4.1"))
load(pathJoin("sigio", "2.3.2"))
load(pathJoin("bufr", "11.7.0"))

local wgrib2_ver=os.getenv("wgrib2_ver") or "2.0.8"
load(pathJoin("wgrib2", wgrib2_ver))
setenv("WGRIB2","wgrib2")
