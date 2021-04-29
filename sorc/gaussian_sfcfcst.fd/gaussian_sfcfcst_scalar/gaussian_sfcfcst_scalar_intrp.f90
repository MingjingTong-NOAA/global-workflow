!------------------------------------------------------------------
! 
! Read in surface and nst data on the cubed-sphere grid,
! interpolate it to the gaussian grid, and output the result
! to a nemsio or netcdf file.  To not process nst data,
! set flag 'donst' to 'no'.  To process nst, set to 'yes'.
! To output gaussian file in netcdf, set netcdf_out=.true.
! Otherwise, nemsio format will be output.
!
! Input files:
! ------------
! weights.nc              Interpolation weights.  netcdf format
! anal.tile[1-6].nc       fv3 surface restart files
! orog.tile[1-6].nc       fv3 orography files
! fort.41 namelist        Configuration namelist
! vcoord.txt              Vertical coordinate definition file
!                         (ascii)
!
! Output files:
! -------------
! sfc.gaussian.file  surface data on gaussian grid - 
!                             nemsio or netcdf.
!
! Namelist variables:
! -------------------
! yy/mm/dd/hh             year/month/day/hour of data.
! i/jgaus                 i/j dimension of gaussian grid.
! netcdf_out              When 'true', output gaussian file in
!                         netcdf.  Otherwise output nemsio format.
!
! 2021-March-11 Tong      Initial version
!
! pwatclm, hgt_hyblev1, spfh_hyblev1, ugrd_hyblev1, vgrd_hyblev1
! tmp_hyblev1 (not required by post)
!
!------------------------------------------------------------------

 module io

 use nemsio_module

 implicit none

 integer, parameter :: num_tiles = 6

 integer :: itile, jtile, igaus, jgaus, itime, ntile
 integer :: fhzero, imp_physics
 real :: fhr, dtp, diag_fhr
 character(len=128) :: gaus_file

 integer(nemsio_intkind) :: idate(8)

 integer, parameter      :: num_noah_1=32
 character(len=30)       :: name_noah_1(num_noah_1)

 integer, parameter      :: num_noah_2=3
 character(len=30)       :: name_noah_2(num_noah_2)

! post variables
 integer, parameter      :: num_post=88
 character(len=30)       :: name_post(num_post)
 character(len=30)       :: intpl_method_post(num_post)
 character(len=30)       :: units_post(num_post)
 character(len=128)      :: desc_post(num_post)

 real, dimension(:),   allocatable      :: xlon, ylat 

 real, parameter :: pi = 3.141592653589793
 real, parameter :: todeg=180./pi

 type :: sfc_data
! surface variables
   real, allocatable :: sfc_noah_1(:,:)
   real, allocatable :: sfc_noah_2(:,:,:)
   real, allocatable :: sfc_post(:,:)
 end type sfc_data

 data name_noah_1 / "alnsf", &
                    "alnwf", &
                    "alvsf", &
                    "alvwf", &
                    "canopy", & 
                    "srflag", &
                    "f10m", &
                    "facsf", &
                    "facwf", &
                    "ffhh", &
                    "ffmm", &
                    "uustar", &
                    "fice", &
                    "hice", &
                    "slmsk", &
                    "orog", &
                    "zorl", &
                    "shdmax", &
                    "shdmin", &
                    "slope", &
                    "snoalb", &
                    "snwdph", &
                    "stype", &
                    "q2m", &
                    "tg3", &
                    "tisfc", &
                    "t2m", &
                    "tsea", &
                    "tprcp", &
                    "vfrac", &
                    "vtype", &
                    "sheleg" /

 data name_noah_2 / "slc", &
                    "smc", &
                    "stc" /

 data name_post / "acond", &
                  "cprat_ave", &
                  "cpratb_ave", &
                  "cduvb_ave", &
                  "cpofp", &
                  "csdlf", &
                  "csusf", &
                  "csusftoa", &
                  "csdsf", &
                  "csulf", &
                  "csulftoa", &
                  "cwork_aveclm", &
                  "dlwrf", &
                  "dlwrf_ave", &
                  "dswrf", &
                  "dswrf_ave", &
                  "dswrf_avetoa", &
                  "duvb_ave", &
                  "hpbl", &
                  "lhtfl", &
                  "lhtfl_ave", &
                  "nbdsf_ave", &
                  "nddsf_ave", &
                  "prateb_ave", &
                  "prate_ave", &
                  "pressfc", &
                  "pwatclm", &
                  "sfexc", &
                  "shtfl_ave", &
                  "shtfl", &
                  "sunsd_acc", &
                  "spfhmax_max2m", &
                  "spfhmin_min2m", &
                  "spfh_hyblev1", &
                  "tmax_max2m", &
                  "tmin_min2m", &
                  "tmp_hyblev1", &
                  "ulwrf", &
                  "ulwrf_ave", &
                  "ulwrf_avetoa", &
                  "uswrf_ave", &
                  "uswrf", &
                  "uswrf_avetoa", &
                  "uflx_ave", &
                  "vflx_ave", &
                  "vbdsf_ave", &
                  "vddsf_ave", &
                  "albdo_ave", &
                  "cnvprcp", &
                  "evbs_ave", &
                  "evcw_ave", &
                  "fldcp", &
                  "gflux", &
                  "gflux_ave", &
                  "hgt_hyblev1", &
                  "pevpr_ave", &
                  "pevpr", &
                  "prescnvclt", &
                  "prescnvclb", &
                  "pres_avelct", &
                  "pres_avelcb", &
                  "pres_avemct", &
                  "pres_avemcb", &
                  "pres_avehct", &
                  "pres_avehcb", &
                  "snowc_ave", &
                  "ssrun_acc", &
                  "sbsno_ave", &
                  "soilm", &
                  "snohf", &
                  "tcdc_aveclm", &
                  "tcdc_avehcl", &
                  "tcdc_avelcl", &
                  "tcdc_avemcl", &
                  "tcdccnvcl", &
                  "tcdc_avebndcl", &
                  "tmp_avelct", &
                  "tmp_avemct", &
                  "tmp_avehct", &
                  "trans_ave", &
                  "u-gwd_ave", &
                  "v-gwd_ave", &
                  "watr_acc", &
                  "wilt", &
                  "ugrd10m", &
                  "vgrd10m", &
                  "ugrd_hyblev1", &
                  "vgrd_hyblev1" / 

 type(sfc_data) :: tile_data, gaussian_data

 end module io

!------------------------------------------------------------------------------
! Main program 
!------------------------------------------------------------------------------

 program main

 use netcdf
 use io

 implicit none

 character(len=12)       :: weightfile

 integer                 :: i, j, error, ncid, id_ns, n_s, n_s2
 integer                 :: id_col, id_row, id_s, n, icoor
 integer                 :: yy, mm, dd, hh
 integer, allocatable    :: col(:), row(:), col2(:), row2(:)
 logical                 :: netcdf_out

 real(kind=8), allocatable :: s(:), s2(:)

 namelist /setup/ yy, mm, dd, hh, fhr, diag_fhr, igaus, jgaus, gaus_file, &
                  netcdf_out, fhzero, imp_physics, dtp 

 call w3tagb('GAUSSIAN_SFCFCST',2018,0179,0055,'NP20')

 print*,"- BEGIN EXECUTION"

 fhr = 0.

 netcdf_out = .true.

 print*
 print*,"- READ SETUP NAMELIST"
 open(41, file="./fort.41")
 read(41, nml=setup, iostat=error)
 if (error /= 0) then
   print*,"** FATAL ERROR READING NAMELIST. ISTAT IS: ", error
   call errexit(56)
 endif
 close (41)

 idate = 0
 idate(1) = yy
 idate(2) = mm
 idate(3) = dd
 idate(4) = hh

!------------------------------------------------------------------------------
! Read interpolation weight file (Nearest).
!------------------------------------------------------------------------------

 print*
 print*,"- READ INTERPOLATION WEIGHT FILE"

 weightfile = "./weights.nc"

 error=nf90_open(trim(weightfile),nf90_nowrite,ncid)
 call netcdf_err(error, 'OPENING weights.nc' )

 error=nf90_inq_dimid(ncid, 'n_s', id_ns)
 call netcdf_err(error, 'READING n_s id' )
 error=nf90_inquire_dimension(ncid,id_ns,len=n_s)
 call netcdf_err(error, 'READING n_s' )

 allocate(col(n_s))
 error=nf90_inq_varid(ncid, 'col', id_col)
 call netcdf_err(error, 'READING col id' )
 error=nf90_get_var(ncid, id_col, col)
 call netcdf_err(error, 'READING col' )

 allocate(row(n_s))
 error=nf90_inq_varid(ncid, 'row', id_row)
 call netcdf_err(error, 'READING row id' )
 error=nf90_get_var(ncid, id_row, row)
 call netcdf_err(error, 'READING row' )

 allocate(s(n_s))
 error=nf90_inq_varid(ncid, 'S', id_s)
 call netcdf_err(error, 'READING s id' )
 error=nf90_get_var(ncid, id_s, s)
 call netcdf_err(error, 'READING s' )

 error = nf90_close(ncid)

!------------------------------------------------------------------------------
! Read interpolation weight file (Bilinear).
!------------------------------------------------------------------------------

 intpl_method_post(1:47)='bilinear'
 intpl_method_post(48:84)='nearest_stod'
! winds from GFS physics are defined on the lat-lon grid, 
! need to do a vector interpolation
 intpl_method_post(85:88)='bilinear'

 print*
 print*,"- READ INTERPOLATION WEIGHT FILE"

 weightfile = "./weightb.nc"

 error=nf90_open(trim(weightfile),nf90_nowrite,ncid)
 call netcdf_err(error, 'OPENING weights.nc' )

 error=nf90_inq_dimid(ncid, 'n_s', id_ns)
 call netcdf_err(error, 'READING n_s id' )
 error=nf90_inquire_dimension(ncid,id_ns,len=n_s2)
 call netcdf_err(error, 'READING n_s' )

 allocate(col2(n_s2))
 error=nf90_inq_varid(ncid, 'col', id_col)
 call netcdf_err(error, 'READING col id' )
 error=nf90_get_var(ncid, id_col, col2)
 call netcdf_err(error, 'READING col' )

 allocate(row2(n_s2))
 error=nf90_inq_varid(ncid, 'row', id_row)
 call netcdf_err(error, 'READING row id' )
 error=nf90_get_var(ncid, id_row, row2)
 call netcdf_err(error, 'READING row' )

 allocate(s2(n_s2))
 error=nf90_inq_varid(ncid, 'S', id_s)
 call netcdf_err(error, 'READING s id' )
 error=nf90_get_var(ncid, id_s, s2)
 call netcdf_err(error, 'READING s' )

 error = nf90_close(ncid)

!------------------------------------------------------------------------------
! Read the tiled forecast data.
!------------------------------------------------------------------------------

 call read_data_nc

!------------------------------------------------------------------------------
! Interpolate tiled data to gaussian grid.
!------------------------------------------------------------------------------

 allocate(gaussian_data%sfc_noah_1(igaus*jgaus,num_noah_1))    ! sfc
 allocate(gaussian_data%sfc_noah_2(igaus*jgaus,4,num_noah_2))
 allocate(gaussian_data%sfc_post(igaus*jgaus,num_post))

 gaussian_data%sfc_noah_1=0.0 
 gaussian_data%sfc_noah_2=0.0
 gaussian_data%sfc_post=0.0

!------------------------------------------------------------------------------
! interpolation (Bilinear or Nearest).
!------------------------------------------------------------------------------
 do j = 1, num_noah_1
   if (trim(name_noah_1(j)) == "t2m" .or. trim(name_noah_1(j)) == "q2m") then
     do i = 1, n_s2
       gaussian_data%sfc_noah_1(row2(i),j) = gaussian_data%sfc_noah_1(row2(i),j) &
                                           + s2(i)*tile_data%sfc_noah_1(col2(i),j)
     enddo
   else
     do i = 1, n_s
       gaussian_data%sfc_noah_1(row(i),j) = gaussian_data%sfc_noah_1(row(i),j) &
                                          + s(i)*tile_data%sfc_noah_1(col(i),j)
     enddo
   endif
 enddo
 
 do j = 1, num_noah_2
   do n = 1, 4
     do i = 1, n_s
       gaussian_data%sfc_noah_2(row(i),n,j) = gaussian_data%sfc_noah_2(row(i),n,j) &
                                            + s(i)*tile_data%sfc_noah_2(col(i),n,j)
     enddo
   enddo
 enddo

 do j = 1, num_post
   if (intpl_method_post(j) == 'bilinear') then
     do i = 1, n_s2
       gaussian_data%sfc_post(row2(i),j) = gaussian_data%sfc_post(row2(i),j) &
                                           + s2(i)*tile_data%sfc_post(col2(i),j)
     enddo
   else if (intpl_method_post(j) == 'nearest_stod') then
     do i = 1, n_s
       gaussian_data%sfc_post(row(i),j) = gaussian_data%sfc_post(row(i),j) &
                                          + s(i)*tile_data%sfc_post(col(i),j)
     enddo
   endif
 enddo

 deallocate(col, row, s)
 deallocate(col2, row2, s2)

 deallocate(tile_data%sfc_noah_1)
 deallocate(tile_data%sfc_noah_2)
 deallocate(tile_data%sfc_post)

!------------------------------------------------------------------------------
! Write gaussian data to either netcdf or nemsio file.
!------------------------------------------------------------------------------

 if (netcdf_out) then
   call write_sfc_data_netcdf
 else
   call write_sfc_data_nemsio
 endif

 deallocate(gaussian_data%sfc_noah_1)
 deallocate(gaussian_data%sfc_noah_2)
 deallocate(gaussian_data%sfc_post)

 print*
 print*,'- NORMAL TERMINATION'

 call w3tage('GAUSSIAN_SFCFCST')

 end program main

!-------------------------------------------------------------------------------------------
! Write gaussian surface data to netcdf file.
!-------------------------------------------------------------------------------------------

 subroutine write_sfc_data_netcdf

 use netcdf
 use io

 implicit none

 character(len=50)       :: outfile
 character(len=31)       :: date_string
 character(len=4)        :: year
 character(len=2)        :: mon, day, hour

 integer                 :: header_buffer_val = 16384
 integer                 :: i, j, error, ncid, dim_xt, dim_yt, dim_time
 integer                 :: id_xt, id_yt, id_lon, id_lat, id_time
 integer                 :: n

! noah variables
 integer, parameter      :: num_noah=44
 character(len=30)       :: noah_var(num_noah)
 character(len=70)       :: noah_name(num_noah)
 character(len=30)       :: noah_units(num_noah)

! variables to be output
 integer                              :: num_vars
 character(len=30), allocatable       :: var(:)
 character(len=70), allocatable       :: name(:)
 character(len=30), allocatable       :: units(:)
 integer, allocatable                 :: id_var(:)

 real, parameter         :: missing = 9.99e20
 real(kind=4), parameter :: fillvalue = 9.99e20

 real(kind=4), allocatable :: dummy(:,:)
 real :: dlon, dlat
 real, dimension(:,:), allocatable :: lon2d, lat2d

! define noah fields

 data noah_var /"alnsf", &
                "alnwf", &
                "alvsf", &
                "alvwf", &
                "cnwat", &
                "crain",&
                "f10m", &
                "facsf", &
                "facwf", &
                "ffhh", &
                "ffmm", &
                "fricv", &
                "icec", &
                "icetk", &
                "land", &
                "orog", &
                "sfcr", &
                "shdmax", &
                "shdmin", &
                "sltyp", &
                "snoalb", &
                "snod", &
                "sotyp", &
                "spfh2m", &
                "tg3" , &
                "tisfc", &
                "tmp2m", &
                "tmpsfc", &
                "tprcp", &
                "veg", &
                "vtype", &
                "weasd", &
                "soill1", &
                "soill2", &
                "soill3", &
                "soill4", &
                "soilt1", &
                "soilt2", &
                "soilt3", &
                "soilt4", &
                "soilw1", &
                "soilw2", &
                "soilw3", &
                "soilw4" /

 data noah_name /"mean nir albedo with strong cosz dependency", &
                 "mean nir albedo with weak cosz dependency", &
                 "mean vis albedo with strong cosz dependency", &
                 "mean vis albedo with weak cosz dependency", &
                 "canopy water (cnwat in gfs data)" , &
                 "instantaneous categorical rain", &
                 "10-meter wind speed divided by lowest model wind speed", &
                 "fractional coverage with strong cosz dependency", &
                 "fractional coverage with weak cosz dependency", &
                 "fh parameter from PBL scheme" , &
                 "fm parameter from PBL scheme" , &
                 "uustar surface frictional wind", &
                 "surface ice concentration (ice=1; no ice=0)", &
                 "sea ice thickness (icetk in gfs_data)", &
                 "sea-land-ice mask (0-sea, 1-land, 2-ice)", &
                 "surface geopotential height", &
                 "surface roughness", &
                 "maximum fractional coverage of green vegetation", &
                 "minimum fractional coverage of green vegetation", &
                 "surface slope type" , &
                 "maximum snow albedo in fraction", &
                 "surface snow depth", &
                 "soil type in integer", &
                 "2m specific humidity" , &
                 "deep soil temperature" , &
                 "surface temperature over ice fraction", &
                 "2m temperature", &
                 "surface temperature", &
                 "total precipitation" , &
                 "vegetation fraction", &
                 "vegetation type in integer", &
                 "surface snow water equivalent", &
                 "liquid soil moisture at layer-1", &
                 "liquid soil moisture at layer-2", &
                 "liquid soil moisture at layer-3", &
                 "liquid soil moisture at layer-4", &
                 "soil temperature 0-10cm", &
                 "soil temperature 10-40cm", &
                 "soil temperature 40-100cm", &
                 "soil temperature 100-200cm", &
                 "volumetric soil moisture 0-10cm", &
                 "volumetric soil moisture 10-40cm", &
                 "volumetric soil moisture 40-100cm", &
                 "volumetric soil moisture 100-200cm" /

 data noah_units /"%", &
                  "%", &
                  "%", &
                  "%", &
                  "XXX", &
                  "number", &
                  "N/A", &
                  "XXX", &
                  "XXX", &
                  "XXX", &
                  "XXX", &
                  "XXX", &
                  "fraction", &
                  "XXX", &
                  "numerical", &
                  "gpm", &
                  "m", &
                  "XXX", &
                  "XXX", &
                  "XXX", &
                  "XXX", &
                  "m", &
                  "number", &
                  "kg/kg", &
                  "K", &
                  "K", &
                  "K", &
                  "K", &
                  "kg/m**2", &
                  "fraction", &
                  "number" , &
                  "kg/m**2", &
                  "XXX", &
                  "XXX", &
                  "XXX", &
                  "XXX", &
                  "K", &
                  "K", &
                  "K", &
                  "K", &
                  "fraction", &
                  "fraction", &
                  "fraction", &
                  "fraction" /

 outfile = "./sfc.gaussian.nc"

 print*,"- WRITE SURFACE DATA TO NETCDF FILE: ", trim(outfile)

 error = nf90_create(outfile, cmode=IOR(IOR(NF90_CLOBBER,NF90_NETCDF4),NF90_CLASSIC_MODEL), ncid=ncid)
 call netcdf_err(error, 'CREATING NETCDF FILE')

! dimensions

 error = nf90_def_dim(ncid, 'grid_xt', igaus, dim_xt)
 call netcdf_err(error, 'DEFINING GRID_XT DIMENSION')

 error = nf90_def_dim(ncid, 'grid_yt', jgaus, dim_yt)
 call netcdf_err(error, 'DEFINING GRID_YT DIMENSION')

 error = nf90_def_dim(ncid, 'time', 1, dim_time)
 call netcdf_err(error, 'DEFINING TIME DIMENSION')

! global attributes
 if(fhr > 0.) then
   error = nf90_put_att(ncid, nf90_global, 'fhzero', fhzero)
   call netcdf_err(error, 'DEFINING FHZERO ATTRIBUTE')
 end if

 error = nf90_put_att(ncid, nf90_global, 'ncld', 5)
 call netcdf_err(error, 'DEFINING NCLD ATTRIBUTE')

 error = nf90_put_att(ncid, nf90_global, 'nsoil', 4)
 call netcdf_err(error, 'DEFINING NSOIL ATTRIBUTE')

 if(fhr > 0.) then
   error = nf90_put_att(ncid, nf90_global, 'imp_physics', imp_physics)
   call netcdf_err(error, 'DEFINING IMP_PHYSICS ATTRIBUTE')

   error = nf90_put_att(ncid, nf90_global, 'dtp', dtp)
   call netcdf_err(error, 'DEFINING DTP ATTRIBUTE')
 end if

 error = nf90_put_att(ncid, nf90_global, 'source', "FV3GFS")
 call netcdf_err(error, 'DEFINING SOURCE ATTRIBUTE')

 error = nf90_put_att(ncid, nf90_global, 'grid', "gaussian")
 call netcdf_err(error, 'DEFINING GRID ATTRIBUTE')

 error = nf90_put_att(ncid, nf90_global, 'im', igaus)
 call netcdf_err(error, 'DEFINING IM ATTRIBUTE')

 error = nf90_put_att(ncid, nf90_global, 'jm', jgaus)
 call netcdf_err(error, 'DEFINING JM ATTRIBUTE')

! variables

! grid_xt

 error = nf90_def_var(ncid, 'grid_xt', NF90_DOUBLE, dim_xt, id_xt)
 call netcdf_err(error, 'DEFINING GRID_XT')

 error = nf90_put_att(ncid, id_xt, "cartesian_axis", "X")
 call netcdf_err(error, 'DEFINING GRID_XT ATTRIBUTE')

 error = nf90_put_att(ncid, id_xt, "long_name", "T-cell longitude")
 call netcdf_err(error, 'DEFINING GRID_XT ATTRIBUTE')

 error = nf90_put_att(ncid, id_xt, "units", "degrees_E")
 call netcdf_err(error, 'DEFINING GRID_XT ATTRIBUTE')

! lon

 error = nf90_def_var(ncid, 'lon', NF90_DOUBLE, (/dim_xt,dim_yt/), id_lon)
 call netcdf_err(error, 'DEFINING LON')

 error = nf90_put_att(ncid, id_lon, "long_name", "T-cell longitude")
 call netcdf_err(error, 'DEFINING LON ATTRIBUTE')

 error = nf90_put_att(ncid, id_lon, "units", "degrees_E")
 call netcdf_err(error, 'DEFINING LON ATTRIBUTE')

! grid_yt

 error = nf90_def_var(ncid, 'grid_yt', NF90_DOUBLE, dim_yt, id_yt)
 call netcdf_err(error, 'DEFINING GRID_YT')

 error = nf90_put_att(ncid, id_yt, "cartesian_axis", "Y")
 call netcdf_err(error, 'DEFINING GRID_YT ATTRIBUTE')

 error = nf90_put_att(ncid, id_yt, "long_name", "T-cell latitude")
 call netcdf_err(error, 'DEFINING GRID_YT ATTRIBUTE')

 error = nf90_put_att(ncid, id_yt, "units", "degrees_N")
 call netcdf_err(error, 'DEFINING GRID_YT ATTRIBUTE')

! lat

 error = nf90_def_var(ncid, 'lat', NF90_DOUBLE, (/dim_xt,dim_yt/), id_lat)
 call netcdf_err(error, 'DEFINING LAT')

 error = nf90_put_att(ncid, id_lat, "long_name", "T-cell latitude")
 call netcdf_err(error, 'DEFINING LAT ATTRIBUTE')

 error = nf90_put_att(ncid, id_lat, "units", "degrees_N")
 call netcdf_err(error, 'DEFINING LAT ATTRIBUTE')

! time

 error = nf90_def_var(ncid, 'time', NF90_DOUBLE, dim_time, id_time)
 call netcdf_err(error, 'DEFINING TIME')

 error = nf90_put_att(ncid, id_time, "long_name", "time")
 call netcdf_err(error, 'DEFINING TIME ATTRIBUTE')

 write(year, "(i4)") idate(1)
 write(mon, "(i2.2)") idate(2)
 write(day, "(i2.2)") idate(3)
 write(hour, "(i2.2)") idate(4)

 date_string="hours since " // year // "-" // mon // "-" // day // " " // hour // ":00:00"

 error = nf90_put_att(ncid, id_time, "units", date_string)
 call netcdf_err(error, 'DEFINING TIME ATTRIBUTE')

 error = nf90_put_att(ncid, id_time, "cartesian_axis", "T")
 call netcdf_err(error, 'DEFINING TIME ATTRIBUTE')

 error = nf90_put_att(ncid, id_time, "calendar_type", "JULIAN")
 call netcdf_err(error, 'DEFINING TIME ATTRIBUTE')

 error = nf90_put_att(ncid, id_time, "calendar", "JULIAN")
 call netcdf_err(error, 'DEFINING TIME ATTRIBUTE')

!-------------------------------------------------------------------------------------------
! Determine what variables to output (noah, or noah plus nst).
!-------------------------------------------------------------------------------------------
 
 num_vars = num_noah + num_post
   
 allocate(var(num_vars))
 allocate(name(num_vars))
 allocate(units(num_vars))
 allocate(id_var(num_vars))

 var(1:num_noah) = noah_var
 name(1:num_noah) = noah_name
 units(1:num_noah) = noah_units

 do n = 1, num_post
   var(n+num_noah) = name_post(n)
   name(n+num_noah) = desc_post(n)
   units(n+num_noah) = units_post(n)
 enddo

!-------------------------------------------------------------------------------------------
! Define variables in netcdf file.
!-------------------------------------------------------------------------------------------

 do n = 1, num_vars

   print*,'- DEFINE VARIABLE ',trim(var(n))
   error = nf90_def_var(ncid, trim(var(n)), NF90_FLOAT, (/dim_xt,dim_yt,dim_time/), id_var(n))
   call netcdf_err(error, 'DEFINING variable')
   error = nf90_def_var_deflate(ncid, id_var(n), 1, 1, 1)
   call netcdf_err(error, 'DEFINING variable with compression')

   error = nf90_put_att(ncid, id_var(n), "long_name", trim(name(n)))
   call netcdf_err(error, 'DEFINING name ATTRIBUTE')

   error = nf90_put_att(ncid, id_var(n), "units", trim(units(n)))
   call netcdf_err(error, 'DEFINING units ATTRIBUTE')

   error = nf90_put_att(ncid, id_var(n), "missing_value", missing)
   call netcdf_err(error, 'DEFINING missing ATTRIBUTE')

   error = nf90_put_att(ncid, id_var(n), "_FillValue", fillvalue)
   call netcdf_err(error, 'DEFINING filling ATTRIBUTE')

   error = nf90_put_att(ncid, id_var(n), "cell_methods", "time: point")
   call netcdf_err(error, 'DEFINING cell method ATTRIBUTE')

   error = nf90_put_att(ncid, id_var(n), "output_file", "sfc")
   call netcdf_err(error, 'DEFINING out file ATTRIBUTE')

 enddo

! end variable defs

 error = nf90_enddef(ncid, header_buffer_val,4,0,4)
 call netcdf_err(error, 'DEFINING HEADER')

!-------------------------------------------------------------------------------------------
! Write variables to netcdf file.
!-------------------------------------------------------------------------------------------

 allocate(dummy(igaus,jgaus))
 allocate(xlon(igaus), ylat(jgaus))
 allocate(lon2d(igaus,jgaus),lat2d(igaus,jgaus))

! read gaussian grid

 call read_gaus_grid(gaus_file, xlon, ylat, igaus, jgaus)

 do j=1,jgaus
   lon2d(:,j)=xlon(:)
 end do

 error = nf90_put_var(ncid, id_xt, lon2d(:,1))
 call netcdf_err(error, 'WRITING GRID_XT')

 error = nf90_put_var(ncid, id_lon, lon2d)
 call netcdf_err(error, 'WRITING LON')

 do i=1, igaus
   do j=1,jgaus
     lat2d(i,j)=ylat(jgaus-j+1)
   end do
 end do

 error = nf90_put_var(ncid, id_yt, lat2d(1,:))
 call netcdf_err(error, 'WRITING GRID_YT')

 error = nf90_put_var(ncid, id_lat, lat2d)
 call netcdf_err(error, 'WRITING LAT')

 error = nf90_put_var(ncid, id_time, fhr)
 call netcdf_err(error, 'WRITING TIME')

 deallocate(lon2d,lat2d)

 do n = 1, num_vars
   print*,'- WRITE VARIABLE ',trim(var(n))
   if (n <= num_noah) then
     call get_netcdf_var(n, var(n), dummy)
     error = nf90_put_var(ncid, id_var(n), dummy, start=(/1,1,1/), count=(/igaus,jgaus,1/))
   else
     j=n-num_noah
     dummy = reshape(gaussian_data%sfc_post(:,j), (/igaus,jgaus/))
     error = nf90_put_var(ncid, id_var(n), dummy, start=(/1,1,1/), count=(/igaus,jgaus,1/))
   end if
   call netcdf_err(error, 'WRITING variable')
 enddo

 deallocate (dummy)

 error = nf90_close(ncid)

 end subroutine write_sfc_data_netcdf

 subroutine read_gaus_grid(gaus_file, xlon, ylat, nlon, nlat)

 use netcdf

 implicit none

 character(len=128), intent(in) :: gaus_file
 integer, intent(in)  :: nlon, nlat
 real,    intent(out) :: xlon(nlon), ylat(nlat)
 !------------------------------------------------------------------!
 ! local variables                                                  !
 !------------------------------------------------------------------!
 integer :: ncid, lon_id, lat_id, ndims, dimids(1), error
 character(len=120) :: filename
 logical :: exists

 ! form file name and check existance
 write(filename,100) trim(gaus_file)
100 format(a,'.nc')
 inquire(file=filename, exist=exists)
 if (.not. exists) then
   print 110, trim(filename)
110    format(/,"Gaussian grid file ",a," doesn't exist",/)
   stop
 endif

 ! open nc file
 error=nf90_open(trim(filename), 0, ncid)
 call netcdf_err(error, 'OPENING gaus_file' )

 ! get nlon
 error=nf90_inq_varid(ncid, "lon", lon_id)
 error=nf90_get_var(ncid, lon_id, xlon)
 call netcdf_err(error, 'READING lon' )

 ! get nlat
 error=nf90_inq_varid(ncid, "lat", lat_id)
 error=nf90_get_var(ncid, lat_id, ylat)
 call netcdf_err(error, 'READING lat' )

 ! close nc file
 error=nf90_close(ncid)

 end subroutine read_gaus_grid

!-------------------------------------------------------------------------------------------
! Retrieve variable based on its netcdf identifier.
!-------------------------------------------------------------------------------------------

 subroutine get_netcdf_var(n, var, dummy)

 use io

 implicit none
 
 integer :: n
 character(len=*), intent(in) :: var

 real(kind=4), intent(out) :: dummy(igaus,jgaus)

 if (n <= 32) then
   if (trim(var) == 'sfcr') then
     dummy = reshape(gaussian_data%sfc_noah_1(:,n), (/igaus,jgaus/)) * 0.01
   else if (trim(var) == 'snod') then
     dummy = reshape(gaussian_data%sfc_noah_1(:,n), (/igaus,jgaus/)) * 0.001
   else if (trim(var) == 'veg') then
     dummy = reshape(gaussian_data%sfc_noah_1(:,n), (/igaus,jgaus/)) * 100.0
   else
     dummy = reshape(gaussian_data%sfc_noah_1(:,n), (/igaus,jgaus/))
   endif 
 else
   select case (var)
     case ('soill1')
       dummy = reshape(gaussian_data%sfc_noah_2(:,1,1), (/igaus,jgaus/))
       if(fhr == 0.) then
        where (dummy > 0.99) dummy = 0.0  ! replace flag value at water/landice
       endif
     case ('soill2')
       dummy = reshape(gaussian_data%sfc_noah_2(:,2,1), (/igaus,jgaus/))
       if(fhr == 0.) then
          where (dummy > 0.99) dummy = 0.0  ! replace flag value at water/landice
       endif
     case ('soill3')
       dummy = reshape(gaussian_data%sfc_noah_2(:,3,1), (/igaus,jgaus/))
       if(fhr == 0.) then
          where (dummy > 0.99) dummy = 0.0  ! replace flag value at water/landice
       endif
     case ('soill4')
       dummy = reshape(gaussian_data%sfc_noah_2(:,4,1), (/igaus,jgaus/))
       if(fhr == 0.) then
          where (dummy > 0.99) dummy = 0.0  ! replace flag value at water/landice
       endif
     case ('soilt1')
       dummy = reshape(gaussian_data%sfc_noah_2(:,1,3), (/igaus,jgaus/))
     case ('soilt2')
       dummy = reshape(gaussian_data%sfc_noah_2(:,2,3), (/igaus,jgaus/))
     case ('soilt3')
       dummy = reshape(gaussian_data%sfc_noah_2(:,3,3), (/igaus,jgaus/))
     case ('soilt4')
       dummy = reshape(gaussian_data%sfc_noah_2(:,4,3), (/igaus,jgaus/))
     case ('soilw1')
       dummy = reshape(gaussian_data%sfc_noah_2(:,1,2), (/igaus,jgaus/))
     case ('soilw2')
       dummy = reshape(gaussian_data%sfc_noah_2(:,2,2), (/igaus,jgaus/))
     case ('soilw3')
       dummy = reshape(gaussian_data%sfc_noah_2(:,3,2), (/igaus,jgaus/))
     case ('soilw4')
       dummy = reshape(gaussian_data%sfc_noah_2(:,4,2), (/igaus,jgaus/))
     case default
       print*,'- FATAL ERROR: UNKNOWN VAR IN GET_VAR: ', var
       call errexit(67)
   end select
 end if

 end subroutine get_netcdf_var

!-------------------------------------------------------------------------------------------
! Write gaussian surface data to nemsio file.
!-------------------------------------------------------------------------------------------

 subroutine write_sfc_data_nemsio

 use nemsio_module
 use io

 implicit none

 integer(nemsio_intkind), parameter :: nrec_all=126
 integer(nemsio_intkind), parameter :: nmetaaryi=1
 integer(nemsio_intkind), parameter :: nmetavari=4
 integer(nemsio_intkind), parameter :: nmetavarr=1
 integer(nemsio_intkind), parameter :: nmetavarc=2

 character(nemsio_charkind)         :: recname_all(nrec_all)
 character(nemsio_charkind)         :: reclevtyp_all(nrec_all)
 character(nemsio_charkind)         :: aryiname(nmetaaryi)
 character(nemsio_charkind)         :: variname(nmetavari)
 character(nemsio_charkind)         :: varrname(nmetavarr)
 character(nemsio_charkind)         :: varcname(nmetavarc)
 character(nemsio_charkind)         :: varcval(nmetavarc)

 integer(nemsio_intkind)            :: iret, version, nrec
 integer(nemsio_intkind)            :: reclev_all(nrec_all)
 integer(nemsio_intkind)            :: aryival(jgaus,nmetaaryi)
 integer(nemsio_intkind)            :: aryilen(nmetaaryi)
 integer(nemsio_intkind)            :: varival(nmetavari)
 integer                            :: i, j, k, n, nvcoord, levs_vcoord
 
 real(nemsio_realkind), allocatable :: the_data(:)
 real(nemsio_realkind)              :: varrval(nmetavarr)
 real(nemsio_realkind), allocatable :: lat(:), lon(:)
 real, allocatable                  :: dummy(:,:)
 real(nemsio_realkind), allocatable :: vcoord(:,:,:)

 type(nemsio_gfile)                 :: gfileo

 data recname_all /'alnsf', 'alnwf', 'alvsf', 'alvwf', &
               'cnwat', 'crain', 'f10m',  'facsf', &
               'facwf', 'ffhh',  'ffmm',  'fricv', &
               'icec',  'icetk', 'land',  'orog', &
               'sfcr',  'shdmax', 'shdmin', 'sltyp', &
               'snoalb', 'snod',  'sotyp',  'spfh', & 
               'tg3',   'ti', 'tmp', 'tmp',  &
               'tprcp', 'veg',   'vtype',  'weasd', &
               'soill',   'soill',   'soill',    'soill',  &
               'tmp',   'tmp',   'tmp',  'tmp',  &
               'soilw',   'soilw',    'soilw', 'soilw', &
               'acond', 'cprat_ave', 'cpratb_ave', 'cduvb_ave', &
               'cpofp', 'csdlf', 'csusf', 'csusftoa', &
               'csdsf', 'csulf', 'csulftoa', 'cwork_aveclm', &
               'cnvprcp', 'dlwrf', 'dlwrf_ave', 'dswrf', &
               'dswrf_ave', 'dswrf_avetoa', 'duvb_ave', 'hpbl', &
               'lhtfl', 'lhtfl_ave', 'nbdsf_ave', 'nddsf_ave', &
               'prateb_ave', 'prate_ave', 'pressfc', 'sfexc', &
               'shtfl_ave', 'shtfl', 'sunsd_acc', 'spfhmax_max2m', &
               'spfhmin_min2m', 'tmax_max2m', 'tmin_min2m', 'ulwrf', &
               'ulwrf_ave', 'ulwrf_avetoa', 'uswrf_ave', 'uswrf', &
               'uswrf_avetoa', 'uflx_ave', 'vflx_ave', 'vbdsf_ave', &
               'vddsf_ave', 'albdo_ave', 'evbs_ave', 'evcw_ave', &
               'fldcp', 'gflux', 'gflux_ave', 'pevpr_ave', &
               'pevpr', 'prescnvclt', 'prescnvclb', 'pres_avelct', &
               'pres_avelcb', 'pres_avemct', 'pres_avemcb', 'pres_avehct', &
               'pres_avehcb', 'snowc_ave', 'ssrun_acc', 'sbsno_ave', &
               'soilm', 'snohf', 'tcdc_aveclm', 'tcdc_avehcl', &
               'tcdc_avelcl', 'tcdc_avemcl', 'tcdccnvcl', 'tcdc_avebndcl', &
               'tmp_avelct', 'tmp_avemct', 'tmp_avehct', 'trans_ave', &
               'u-gwd_ave', 'v-gwd_ave', 'watr_acc', 'wilt', &
               'ugrd10m', 'vgrd10m' /

 data reclevtyp_all /'sfc',   'sfc',   'sfc',   'sfc', &
                 'sfc',   'sfc', '10 m above gnd',   'sfc', &
                 'sfc',   'sfc',   'sfc',   'sfc', &
                 'sfc',   'sfc',   'sfc',   'sfc', &
                 'sfc',   'sfc',   'sfc',   'sfc', &
                 'sfc',   'sfc',   'sfc',   '2 m above gnd', &
                 'sfc',   'sfc',   '2 m above gnd',   'sfc', &
                 'sfc',   'sfc',   'sfc',   'sfc', &
                 '0-10 cm down', '10-40 cm down', '40-100 cm down', '100-200 cm down', &
                 '0-10 cm down', '10-40 cm down', '40-100 cm down', '100-200 cm down', &
                 '0-10 cm down', '10-40 cm down', '40-100 cm down', '100-200 cm down', &
                 'sfc',   'sfc',   'sfc',   'sfc', &
                 'sfc',   'sfc',   'sfc',   'nom. top', &
                 'sfc',   'sfc',   'nom. top',   'atmos col', &
                 'sfc',   'sfc',   'sfc',   'sfc', &
                 'sfc',   'nom. top',   'sfc',   'sfc', &
                 'sfc',   'sfc',   'sfc',   'sfc', &
                 'sfc',   'sfc',   'sfc',   'sfc', &
                 'sfc',   'sfc',   'sfc',   '2 m above gnd', &
                 '2 m above gnd', '2 m above gnd', '2 m above gnd', 'sfc', &
                 'sfc',   'nom. top',   'sfc',   'sfc', &
                 'nom. top',   'sfc',   'sfc',   'sfc', &
                 'sfc',   'sfc',   'sfc',   'sfc', &
                 'sfc',   'sfc',   'sfc',   'sfc', &
                 'sfc',   'convect-cld top', 'convect-cld bot', 'low cld top', &
                 'low cld bot', 'mid cld top', 'mid cld bot', 'high cld top', &
                 'high cld bot',   'sfc',   'sfc',   'sfc', &
                 'sfc',   'sfc',   'atmos col', 'high cld lay', &
                 'low cld lay', 'mid cld lay', 'convect-cld laye', 'bndary-layer cld', &
                 'low cld top', 'mid cld top', 'high cld top', 'sfc', &
                 'sfc',   'sfc',   'sfc',   'sfc', &
                 '10 m above gnd', '10 m above gnd'/

 data reclev_all /1, 1, 1, 1, &
                  1, 1, 1, 1, &
                  1, 1, 1, 1, &
                  1, 1, 1, 1, &
                  1, 1, 1, 1, &
                  1, 1, 1, 1, &
                  1, 1, 1, 1, &
                  1, 1, 1, 1, &
                  1, 1, 1, 1, &
                  1, 1, 1, 1, &
                  1, 1, 1, 1, &
                  1, 1, 1, 1, & 
                  1, 1, 1, 1, & 
                  1, 1, 1, 1, & 
                  1, 1, 1, 1, & 
                  1, 1, 1, 1, & 
                  1, 1, 1, 1, & 
                  1, 1, 1, 1, & 
                  1, 1, 1, 1, & 
                  1, 1, 1, 1, & 
                  1, 1, 1, 1, &
                  1, 1, 1, 1, & 
                  1, 1, 1, 1, & 
                  1, 1, 1, 1, & 
                  1, 1, 1, 1, & 
                  1, 1, 1, 1, & 
                  1, 1, 1, 1, & 
                  1, 1, 1, 1, & 
                  1, 1, 1, 1, & 
                  1, 1, 1, 1, & 
                  1, 1, 1, 1, &
                  1, 1/
        
 data aryiname /'lpl'/

 data variname /'fhzero', 'ncld', 'nsoil', 'imp_physics'/

 data varrname /'dtp'/

 data varcname /"y-direction", "z-direction"/

 data varcval /"north2south", "bottom2top"/

 version  = 200809

 varival(1) = fhzero
 varival(2) = 5
 varival(3) = 4
 varival(4) = imp_physics
 varrval(1) = dtp

 aryival = igaus    ! reduced grid definition
 aryilen = jgaus

 allocate(dummy(igaus,jgaus))

 do j=1,jgaus
   dummy(:,j)=xlon(:)
 end do

 allocate(lon(igaus*jgaus))
 lon = reshape (dummy, (/igaus*jgaus/) )

 do i=1, igaus
   dummy(i,:)=ylat(:)
 end do

 allocate(lat(igaus*jgaus))
 lat = reshape (dummy, (/igaus*jgaus/) )

 deallocate(dummy)

 print*
 print*, "- OPEN VCOORD FILE."
 open(14, file="vcoord.txt", form='formatted', iostat=iret)
 if (iret /= 0) goto 43

 print*, "- READ VCOORD FILE."
 read(14, *, iostat=iret) nvcoord, levs_vcoord
 if (iret /= 0) goto 43

 allocate(vcoord(levs_vcoord,3,2))
 vcoord = 0.0
 read(14, *, iostat=iret) ((vcoord(n,k,1), k=1,nvcoord), n=1,levs_vcoord)
 if (iret /= 0) goto 43

 close (14)

 call nemsio_init(iret=iret)

 print*
 print*,"- OPEN GAUSSIAN NEMSIO SURFACE FILE"

 call nemsio_open(gfileo, "sfc.gaussian.file", 'write',   &
                  modelname="FV3GFS", gdatatype="bin4", version=version,  &
                  nmeta=8, nrec=nrec_all, dimx=igaus, dimy=jgaus, &
                  dimz=(levs_vcoord-1),     &
                  nframe=0, nsoil=4, ntrac=8, jcap=-9999,  &
                  ncldt=5, idvc=-9999, idsl=-9999, idvm=-9999, &
                  idrt=4, lat=lat, lon=lon, vcoord=vcoord, &
                  nfhour=int(fhr), nfminute=0, nfsecondn=0,  &
                  nfsecondd=1, nfday=0, idate=idate, &
                  recname=recname_all, reclevtyp=reclevtyp_all, &
                  reclev=reclev_all, extrameta=.true., &
                  nmetavari=nmetavari, variname=variname, varival=varival, &
                  nmetavarr=nmetavarr, varrname=varrname, varrval=varrval, &
                  nmetavarc=nmetavarc, varcname=varcname, varcval=varcval, &
                  nmetaaryi=nmetaaryi, aryiname=aryiname, &
                  aryival=aryival, aryilen=aryilen, iret=iret)
 if (iret /= 0) goto 44

 deallocate (lat, lon, vcoord)

 allocate(the_data(igaus*jgaus))

 print*,"- WRITE GAUSSIAN NEMSIO SURFACE FILE"

 print*,"- WRITE ALNSF"
 do j=1, nrec_all
   if (j <= num_noah_1) then
     if (recname_all(j) == "zorl") then
       the_data = gaussian_data%sfc_noah_1(:,j) * 0.01 ! meters
     else if (recname_all(j) == "snwdph") then 
       the_data = gaussian_data%sfc_noah_1(:,j) * 0.001 ! meters
     else if (recname_all(j) == "vfrac") then
       the_data = gaussian_data%sfc_noah_1(:,j) * 100.0
     else
       the_data = gaussian_data%sfc_noah_1(:,j)
     end if
   else if (j <= num_noah_2) then
      if (recname_all(j) == "soill") then
        if(reclevtyp_all(j) == '0-10 cm down') then
          the_data = gaussian_data%sfc_noah_2(:,1,1)
        else if (reclevtyp_all(j) == '10-40 cm down') then
          the_data = gaussian_data%sfc_noah_2(:,2,1)
        else if (reclevtyp_all(j) == '40-100 cm down') then
          the_data = gaussian_data%sfc_noah_2(:,3,1)
        else
          the_data = gaussian_data%sfc_noah_2(:,4,1)
        end if
      else if (recname_all(j) == "tmp") then
        if(reclevtyp_all(j) == '0-10 cm down') then
          the_data = gaussian_data%sfc_noah_2(:,1,2)
        else if (reclevtyp_all(j) == '10-40 cm down') then
          the_data = gaussian_data%sfc_noah_2(:,2,2)
        else if (reclevtyp_all(j) == '40-100 cm down') then
          the_data = gaussian_data%sfc_noah_2(:,3,2)
        else
          the_data = gaussian_data%sfc_noah_2(:,4,2)
        end if
      else if (recname_all(j) == "soilw") then
        if(reclevtyp_all(j) == '0-10 cm down') then
          the_data = gaussian_data%sfc_noah_2(:,1,3)
        else if (reclevtyp_all(j) == '10-40 cm down') then
          the_data = gaussian_data%sfc_noah_2(:,2,3)
        else if (reclevtyp_all(j) == '40-100 cm down') then
          the_data = gaussian_data%sfc_noah_2(:,3,3)
        else
          the_data = gaussian_data%sfc_noah_2(:,4,3)
        end if
      end if
   else 
      the_data = gaussian_data%sfc_post(:,j)
   endif
   call nemsio_writerec(gfileo, j, the_data, iret=iret)
   if (iret /= 0) goto 44
 end do

 call nemsio_close(gfileo,iret=iret)

 call nemsio_finalize()

 deallocate(the_data)

 return

 43 continue
 print*,"- ** FATAL ERROR OPENING/READING VCOORD FILE."
 print*,"- IRET IS: ", iret
 call errexit(17)
 stop

 44 continue
 print*,"- ** FATAL ERROR WRITING GAUSSIAN NEMSIO FILE."
 print*,"- IRET IS: ", iret
 call errexit(15)
 stop

 end subroutine write_sfc_data_nemsio

!-------------------------------------------------------------------------------------------
! Read tile data.
!-------------------------------------------------------------------------------------------

 subroutine read_data_nc

 use netcdf
 use io

 implicit none

 integer             :: i, j, ii, ijtile, id_dim, id_var, ith
 integer             :: error, tile, ncid, icoor
 integer             :: istart, iend

 real(kind=8), allocatable  :: dummy(:,:), dummy3d(:,:,:)
 real(kind=8), allocatable  :: timeh(:), dummy3t(:,:,:)

!-------------------------------------------------------------------------------------------
! Get tile dimensions from the first forecast file.
!-------------------------------------------------------------------------------------------

 error=nf90_open("./fcst.tile1.nc",nf90_nowrite,ncid)
 error=nf90_inq_dimid(ncid, 'xaxis_1', id_dim)
 call netcdf_err(error, 'READING xaxis_1' )
 error=nf90_inquire_dimension(ncid,id_dim,len=itile)
 call netcdf_err(error, 'READING xaxis_1' )

 error=nf90_inq_dimid(ncid, 'yaxis_1', id_dim)
 call netcdf_err(error, 'READING yaxis_1' )
 error=nf90_inquire_dimension(ncid,id_dim,len=jtile)
 call netcdf_err(error, 'READING yaxis_1' )

 error = nf90_close(ncid)

 ijtile = itile*jtile

 allocate(dummy(itile,jtile))
 allocate(dummy3d(itile,jtile,4))

 allocate(tile_data%sfc_noah_1(ijtile*num_tiles,num_noah_1))
 allocate(tile_data%sfc_noah_2(ijtile*num_tiles,4,num_noah_2))
 allocate(tile_data%sfc_post(ijtile*num_tiles,num_post))

 error=nf90_open("./gfs_surface.tile1.nc",nf90_nowrite,ncid)
 error=nf90_inq_dimid(ncid, 'time', id_dim)
 call netcdf_err(error, 'READING time')
 error=nf90_inquire_dimension(ncid,id_dim,len=itime)
 call netcdf_err(error, 'READING time' )
 allocate(timeh(itime))
 allocate(dummy3t(itile,jtile,itime))
 error=nf90_get_var(ncid, id_dim, timeh) 
 call netcdf_err(error, 'READING time')
 error = nf90_close(ncid)

 if (itime == 1 .and. int(diag_fhr) == 0) then
    ith=1
 else
    ith=0
    do i=1,itime
       if (timeh(i) == diag_fhr) then
          ith=i
          EXIT
       endif
    end do
    if (ith == 0) then 
       print*,'** FATAL ERROR: diag hour', diag_fhr, 'not found'
       print*,'STOP.'
       call errexit(23)
    endif
 endif
 print *,'diag_fhr, ith ', diag_fhr, ith

 do tile = 1, num_tiles

   print*
   print*, "- READ INPUT SFC DATA FOR TILE: ", tile

   istart = (ijtile) * (tile-1) + 1
   iend   = istart + ijtile - 1

   if (tile==1) error=nf90_open("./fcst.tile1.nc",nf90_nowrite,ncid)
   if (tile==2) error=nf90_open("./fcst.tile2.nc",nf90_nowrite,ncid)
   if (tile==3) error=nf90_open("./fcst.tile3.nc",nf90_nowrite,ncid)
   if (tile==4) error=nf90_open("./fcst.tile4.nc",nf90_nowrite,ncid)
   if (tile==5) error=nf90_open("./fcst.tile5.nc",nf90_nowrite,ncid)
   if (tile==6) error=nf90_open("./fcst.tile6.nc",nf90_nowrite,ncid)

   call netcdf_err(error, 'OPENING FILE' )

   do i=1,num_noah_1
      if (trim(name_noah_1(i)) == "orog") then
         ii=i
      else
         error=nf90_inq_varid(ncid, trim(name_noah_1(i)), id_var)
         call netcdf_err(error, 'READING '//trim(name_noah_1(i))//' ID' )
         error=nf90_get_var(ncid, id_var, dummy)
         call netcdf_err(error, 'READING '//trim(name_noah_1(i)))
         print*,'- '//trim(name_noah_1(i))//': ',maxval(dummy),minval(dummy)
         tile_data%sfc_noah_1(istart:iend,i) = reshape(dummy, (/ijtile/))
      end if
   end do

   do i=1,num_noah_2
      error=nf90_inq_varid(ncid, trim(name_noah_2(i)), id_var)
      call netcdf_err(error, 'READING '//trim(name_noah_2(i))//' ID' )
      error=nf90_get_var(ncid, id_var, dummy3d)
      call netcdf_err(error, 'READING '//trim(name_noah_2(i)) )
      print*,'- SMC: ',maxval(dummy3d),minval(dummy3d)
      tile_data%sfc_noah_2(istart:iend,1:4,i) = reshape(dummy3d, (/ijtile,4/))
   end do

   error = nf90_close(ncid)

   print*
   print*, "- READ INPUT OROG DATA FOR TILE: ",tile

   if (tile==1) error=nf90_open("./orog.tile1.nc",nf90_nowrite,ncid)
   if (tile==2) error=nf90_open("./orog.tile2.nc",nf90_nowrite,ncid)
   if (tile==3) error=nf90_open("./orog.tile3.nc",nf90_nowrite,ncid)
   if (tile==4) error=nf90_open("./orog.tile4.nc",nf90_nowrite,ncid)
   if (tile==5) error=nf90_open("./orog.tile5.nc",nf90_nowrite,ncid)
   if (tile==6) error=nf90_open("./orog.tile6.nc",nf90_nowrite,ncid)

   call netcdf_err(error, 'OPENING FILE' )

   if (fhr > 0.) then
      ! use filtered orog
      error=nf90_inq_varid(ncid, "orog_filt", id_var)
      call netcdf_err(error, 'READING orog_filt ID' )
      error=nf90_get_var(ncid, id_var, dummy)
      call netcdf_err(error, 'READING orog_filt' )
   else
      error=nf90_inq_varid(ncid, "orog_raw", id_var)
      call netcdf_err(error, 'READING orog_raw ID' )
      error=nf90_get_var(ncid, id_var, dummy)
      call netcdf_err(error, 'READING orog_raw' )
   endif
   print*,'- OROG: ',maxval(dummy),minval(dummy)
   tile_data%sfc_noah_1(istart:iend,ii) = reshape(dummy, (/ijtile/))

   error = nf90_close(ncid)

   print*
   print*, "- READ INPUT GFS_SURFACE DATA FOR TILE: ",tile

   if (tile==1) error=nf90_open("./gfs_surface.tile1.nc",nf90_nowrite,ncid)
   if (tile==2) error=nf90_open("./gfs_surface.tile2.nc",nf90_nowrite,ncid)
   if (tile==3) error=nf90_open("./gfs_surface.tile3.nc",nf90_nowrite,ncid)
   if (tile==4) error=nf90_open("./gfs_surface.tile4.nc",nf90_nowrite,ncid)
   if (tile==5) error=nf90_open("./gfs_surface.tile5.nc",nf90_nowrite,ncid)
   if (tile==6) error=nf90_open("./gfs_surface.tile6.nc",nf90_nowrite,ncid)

   call netcdf_err(error, 'OPENING FILE' )

   do i=1,num_post
      error=nf90_inq_varid(ncid, trim(name_post(i)), id_var)
      call netcdf_err(error, 'READING '//trim(name_post(i))//' ID' )
      error=nf90_get_var(ncid, id_var, dummy3t)
      dummy=dummy3t(:,:,ith)
      call netcdf_err(error, 'READING '//trim(name_post(i)))
      print*,'- '//trim(name_post(i))//': ',maxval(dummy),minval(dummy)
      tile_data%sfc_post(istart:iend,i) = reshape(dummy, (/ijtile/))
      if (tile == 1) then
         error=nf90_get_att(ncid, id_var, 'units', units_post(i))
         error=nf90_get_att(ncid, id_var, 'long_name', desc_post(i))
      endif
   end do

   error = nf90_close(ncid)

 enddo

 deallocate (dummy, dummy3d, dummy3t, timeh)

 end subroutine read_data_nc

!-------------------------------------------------------------------------------------------
! Netcdf error routine.
!-------------------------------------------------------------------------------------------

 subroutine netcdf_err(err, string)

 use netcdf

 implicit none

 character(len=*), intent(in) :: string
 integer, intent(in)          :: err

 character(len=256)           :: errmsg

 if( err.eq.nf90_noerr )return

 errmsg = nf90_strerror(err)
 print*,''
 print*,'** FATAL ERROR: ', trim(string), ': ', trim(errmsg)
 print*,'STOP.'
 call errexit(22)

 return
 end subroutine netcdf_err
