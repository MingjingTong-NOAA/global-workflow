#! /usr/bin/env bash

#####
## "parsing_namelist_shield.sh"
## This script writes namelist for shield model
##
## This is the child script of ex-global forecast,
## writing namelist for FV3
## This script is a direct execution.
#####

shield_namelists(){

# setup the tables
DIAG_TABLE=${DIAG_TABLE:-$PARM_FV3DIAG/diag_table_shield}
DATA_TABLE=${DATA_TABLE:-$PARM_FV3DIAG/data_table}
FIELD_TABLE=${FIELD_TABLE:-$PARM_FV3DIAG/field_table}

# ensure non-prognostic tracers are set
dnats=${dnats:-1}

# build the diag_table with the experiment name and date stamp
if [ "$DOIAU" == "YES" ]; then
cat > diag_table << EOF
FV3 Forecast
${gPDY:0:4} ${gPDY:4:2} ${gPDY:6:2} ${gcyc} 0 0
EOF
cat $DIAG_TABLE >> diag_table
if [ $FHOUT -gt 1 ]; then
   sed -i "s/IH/3/g" diag_table
else
   sed -i "s/IH/1/g" diag_table
fi
else
cat > diag_table << EOF
FV3 Forecast
${sPDY:0:4} ${sPDY:4:2} ${sPDY:6:2} ${scyc} 0 0
EOF
cat $DIAG_TABLE >> diag_table
sed -i "s/YYYY MM DD HH/${PDY:0:4} ${PDY:4:2} ${PDY:6:2} ${cyc}/g" diag_table
sed -i "s/IH/$FHOUT/g" diag_table
sed -i "s/DELTIM/$DELTIM/g" diag_table
fi

# copy data table
$NCP $DATA_TABLE  data_table
$NCP $FIELD_TABLE field_table

cat > input.nml <<EOF
&amip_interp_nml
  interp_oi_sst = .true.
  use_ncep_sst = .true.
  use_ncep_ice = .false.
  no_anom_sst = .false.
  data_set = 'reynolds_oi'
  date_out_of_range = 'climo'
  ${amip_interp_nml:-}
/

&atmos_model_nml
  blocksize = $blocksize
  chksum_debug = $chksum_debug
  dycore_only = $dycore_only
  fdiag = $FDIAG
  first_time_step = $first_time_step
  fprint = .false.
  ${atmos_model_nml:-}
/

&diag_manager_nml
  prepend_date = .false.
  ${diag_manager_nml:-}
/

&fms_io_nml
  checksum_required = .false.
  max_files_r = 100
  max_files_w = 100
  ${fms_io_nml:-}
/

&fms_nml
  clock_grain = 'ROUTINE'
  domains_stack_size = ${domains_stack_size:-3000000}
  print_memory_usage = ${print_memory_usage:-".false."}
  ${fms_nml:-}
/

&fv_core_nml
  layout = $layout_x,$layout_y
  io_layout = $io_layout
  npx = $npx
  npy = $npy
  ntiles = $ntiles
  npz = $npz
  grid_type = -1
  make_nh = $make_nh
  fv_debug = ${fv_debug:-".false."}
  range_warn = ${range_warn:-".true."}
  reset_eta = .false.
  n_sponge = ${n_sponge:-"30"}
  nudge_qv = ${nudge_qv}
  nudge_dz = ${nudge_dz:-".false."}
  rf_fast = .false.
  tau = ${tau:-5.}
  rf_cutoff = ${rf_cutoff:-"7.5e2"}
  d2_bg_k1 = ${d2_bg_k1:-"0.15"}
  d2_bg_k2 = ${d2_bg_k2:-"0.02"}
  kord_tm = ${kord_tm:-"-9"}
  kord_mt = ${kord_mt:-"9"}
  kord_wz = ${kord_wz:-"9"}
  kord_tr = ${kord_tr:-"9"}
  hydrostatic = $hydrostatic
  phys_hydrostatic = $phys_hydrostatic
  use_hydro_pressure = $use_hydro_pressure
  beta = 0.
  a_imp = 1.
  p_fac = 0.1
  k_split = $k_split
  n_split = $n_split
  nwat = ${nwat:-6}
  na_init = $na_init
  d_ext = 0.
  dnats = ${dnats:-1}
  fv_sg_adj = ${fv_sg_adj:-"450"}
  d2_bg = 0.
  nord = ${nord:-3}
  dddmp = ${dddmp:-0.2}
  d4_bg = ${d4_bg:-0.12}
  vtdm4 = $vtdm4
  delt_max = ${delt_max:-"0.002"}
  ke_bg = 0.
  do_vort_damp = $do_vort_damp
  external_ic = $external_ic
  gfs_phil = ${gfs_phil:-".false."}
  nggps_ic = $nggps_ic
  ecmwf_ic = ${ecmwf_ic:-".false."}
  mountain = $mountain
  ncep_ic = $ncep_ic
  d_con = $d_con
  hord_mt = $hord_mt
  hord_vt = $hord_xx
  hord_tm = $hord_xx
  hord_dp = -$hord_xx
  hord_tr = ${hord_tr:-"-5"}
  adjust_dry_mass = ${adjust_dry_mass:-".false."}
  dry_mass=${dry_mass:-98320.0}
  consv_te = $consv_te
  do_sat_adj = ${do_sat_adj:-".false."}
  consv_am = .false.
  fill = .true.
  dwind_2d = .false.
  print_freq = $print_freq
  warm_start = $warm_start
  no_dycore = $no_dycore
  z_tracer = .true.
  do_inline_mp = .true.
  agrid_vel_rst = ${agrid_vel_rst:-".true."}
  read_increment = $read_increment
  res_latlon_dynamics = $res_latlon_dynamics
EOF

if [ $replay -gt 0 ]; then
  cat >> input.nml << EOF
  replay = $replay
  nrestartbg = ${nrestartbg:-1}
  write_replay_ic = ${write_replay_ic:-".true."}
EOF
fi

cat >> input.nml << EOF
  ${fv_core_nml:-}
/

&coupler_nml
  months = ${months:-0}
  days = ${days:-$((FHMAX/24))}
  hours = ${hours:-$((FHMAX-24*(FHMAX/24)))}
  dt_atmos = $DELTIM
  dt_ocean = $DELTIM
  current_date = $curr_date
  calendar = 'julian'
  memuse_verbose = .false.
  atmos_nthreads = $NTHREADS_FV3
  use_hyper_thread = ${hyperthread:-".false."}
  restart_secs = ${restart_secs:-3600}
  restart_start_secs = ${restart_start_secs:-10800}
EOF

if [ $restart_secs_aux -gt 0 ]; then
  cat >> input.nml << EOF
  restart_secs_aux = ${restart_secs_aux:-0}
  restart_start_secs_aux = ${restart_start_secs_aux:-0}
  restart_duration_secs_aux = ${restart_duration_secs_aux:-0}
EOF
fi

cat >> input.nml << EOF
  iau_offset   = ${IAU_OFFSET}
  ${coupler_nml:-}
/

&external_ic_nml
  filtered_terrain = $filtered_terrain
  levp = ${ncep_levs:-128}
  gfs_dwinds = $gfs_dwinds
  checker_tr = .false.
  nt_checker = 0
  ${external_ic_nml:-}
/

&gfs_physics_nml
  fhzero       = $FHZER
  ldiag3d      = ${ldiag3d:-".false."}
  fhcyc        = $FHCYC
  nst_anl      = $nst_anl
  use_ufo      = ${use_ufo:-".true."}
  pre_rad      = ${pre_rad:-".false."}
  ncld         = ${ncld:-5}
  zhao_mic     = .false.
  pdfcld       = ${pdfcld:-".true."}
  fhswr        = ${FHSWR:-"3600."}
  fhlwr        = ${FHLWR:-"3600."}
  ialb         = ${IALB:-"1"}
  iems         = ${IEMS:-"1"}
  iaer         = $IAER
  ico2         = $ICO2
  isubc_sw     = ${isubc_sw:-"2"}
  isubc_lw     = ${isubc_lw:-"2"}
  isol         = ${ISOL:-"2"}
  lwhtr        = ${lwhtr:-".true."}
  swhtr        = ${swhtr:-".true."}
  cnvgwd       = ${cnvgwd:-".true."}
  do_deep      = ${do_deep:-".true."}
  shal_cnv     = ${shal_cnv:-".true."}
  cal_pre      = ${cal_pre:-".false."}
  redrag       = ${redrag:-".true."}
  dspheat      = ${dspheat:-".true."}
  hybedmf      = ${hybedmf:-".false."}
  random_clds  = ${random_clds:-".false."}
  trans_trac   = ${trans_trac:-".true."}
  cnvcld       = ${cnvcld:-".false."}
  imfshalcnv   = ${imfshalcnv:-"1"}
  imfdeepcnv   = ${imfdeepcnv:-"1"}
  cdmbgwd      = ${cdmbgwd:-"3.5,0.25"}
  prslrd0      = ${prslrd0:-"0."}
  ivegsrc      = ${ivegsrc:-"1"}
  isot         = ${isot:-"1"}
  ysupbl       = ${ysupbl:-".false."}
  satmedmf     = ${satmedmf:-".true."}
  isatmedmf    = ${isatmedmf:-"0"}
  do_dk_hb19   = .false.
  xkzminv      = 0.0
  xkzm_m       = 1.5
  xkzm_h       = 1.5
  xkzm_ml        = 1.0
  xkzm_hl        = 1.0
  xkzm_mi        = 1.5
  xkzm_hi        = 1.5
  cap_k0_land    = .false.
  cloud_gfdl   = .true.
  do_inline_mp = .true.
  do_ocean     = ${do_ocean:-".true."}
  do_z0_hwrf17_hwonly = .true.
  debug        = ${gfs_phys_debug:-".false."}
  nstf_name    = $nstf_name
  do_sppt      = ${do_sppt:-".false."}
  do_shum      = ${do_shum:-".false."}
  do_skeb      = ${do_skeb:-".false."}
EOF

if [[ "$DOIAU" == "YES" && "$fcst_wo_da" == "NO" ]]; then
  cat >> input.nml << EOF
  iaufhrs      = ${IAUFHRS}
  iau_delthrs  = ${IAU_DELTHRS}
  iau_inc_files= ${IAU_INC_FILES}
  iau_drymassfixer = .false.
  iau_filter_increments=${IAU_FILTER_INCREMENTS:-".false."}
EOF
fi

if [ $replay -eq 1 ]; then
  cat >> input.nml << EOF
  iau_forcing_var = ${IAU_FORCING_VAR}
EOF
fi

cat >> input.nml << EOF
  ${gfs_physics_nml:-}
/
EOF

echo "" >> input.nml

cat >> input.nml << EOF
&ocean_nml
  mld_option       = "obs"
  ocean_option     = "MLM"
  restore_method   = 2
  mld_obs_ratio    = 1.
  use_rain_flux    = .true.
  sst_restore_tscale = 2.
  start_lat        = -30.
  end_lat          = 30.
  Gam              = 0.2
  use_old_mlm      = .true.
  do_mld_restore   = .true.
  mld_restore_tscale = 2.
  stress_ratio     = 1.
  eps_day          = 10.
  ${ocean_nml:-}
/

&gfdl_mp_nml
  do_sedi_heat = .false.
  vi_max = 1.
  vs_max = 2.
  vg_max = 12.
  vr_max = 12.
  tau_l2v = 225.
  dw_land = 0.16
  dw_ocean = 0.10
  ql_mlt = 1.0e-3
  qi0_crt = 8.0e-5
  rh_inc = 0.30
  rh_inr = 0.30
  rh_ins = 0.30
  c_paut = 0.5
  rthresh = 8.0e-6
  do_cld_adj = .true.
  use_rhc_revap = .true.
  f_dq_p = 3.0
  rewmax = 10.0
  rermin = 10.0
  ${gfdl_mp_nml:-}
/

&interpolator_nml
  interp_method = 'conserve_great_circle'
  ${interpolator_nml:-}
/

&namsfc
  FNGLAC   = '${FNGLAC}'
  FNMXIC   = '${FNMXIC}'
  FNTSFC   = '${FNTSFC}'
  FNMLDC   = '${FNMLDC}'
  FNSNOC   = '${FNSNOC}'
  FNZORC   = '${FNZORC}'
  FNALBC   = '${FNALBC}'
  FNALBC2  = '${FNALBC2}'
  FNAISC   = '${FNAISC}'
  FNTG3C   = '${FNTG3C}'
  FNVEGC   = '${FNVEGC}'
  FNVETC   = '${FNVETC}'
  FNSOTC   = '${FNSOTC}'
  FNSMCC   = '${FNSMCC}'
  FNMSKH   = '${FNMSKH}'
  FNTSFA   = '${FNTSFA:-}'
  FNACNA   = '${FNACNA:-}'
  FNSNOA   = '${FNSNOA:-}'
  FNVMNC   = '${FNVMNC}'
  FNVMXC   = '${FNVMXC}'
  FNSLPC   = '${FNSLPC}'
  FNABSC   = '${FNABSC}'
  LDEBUG = ${LDEBUG:-".false."}
  FSMCL(2) = ${FSMCL2:-99999}
  FSMCL(3) = ${FSMCL3:-99999}
  FSMCL(4) = ${FSMCL4:-99999}
  FTSFS = ${FTSFS:-90}
  FAISL = ${FAISL:-99999}
  FAISS = ${FAISS:-99999}
  FSNOL = ${FSNOL:-99999}
  FSNOS = ${FSNOS:-99999}
  FSICL = 99999
  FSICS = 99999
  FTSFL = 99999
  FVETL = 99999
  FSOTL = 99999
  FvmnL = 99999
  FvmxL = 99999
  FSLPL = 99999
  FABSL = 99999
  ${namsfc_nml:-}
/

&fv_grid_nml
  grid_file = 'INPUT/grid_spec.nc'
  ${fv_grid_nml:-}
/
EOF

# Add namelist for stochastic physics options
echo "" >> input.nml
if [ "$DO_SPPT" == "YES" -o "$DO_SHUM" == "YES" -o "$DO_SKEB" == "YES" -o "$DO_LAND_PERT" == "YES" ]; then

    cat >> input.nml << EOF
&nam_stochy
EOF

  if [ $DO_SKEB = "YES" ]; then
    cat >> input.nml << EOF
  skeb = $SKEB
  iseed_skeb = ${ISEED_SKEB:-$ISEED}
  skeb_tau = ${SKEB_TAU:-"-999."}
  skeb_lscale = ${SKEB_LSCALE:-"-999."}
  skebnorm = ${SKEBNORM:-"1"}
  skeb_npass = ${SKEB_nPASS:-"30"}
  skeb_vdof = ${SKEB_VDOF:-"5"}
EOF
  fi

  if [ $DO_SHUM = "YES" ]; then
    cat >> input.nml << EOF
  shum = $SHUM
  iseed_shum = ${ISEED_SHUM:-$ISEED}
  shum_tau = ${SHUM_TAU:-"-999."}
  shum_lscale = ${SHUM_LSCALE:-"-999."}
EOF
  fi

  if [ $DO_SPPT = "YES" ]; then
    cat >> input.nml << EOF
  sppt = $SPPT
  iseed_sppt = ${ISEED_SPPT:-$ISEED}
  sppt_tau = ${SPPT_TAU:-"-999."}
  sppt_lscale = ${SPPT_LSCALE:-"-999."}
  sppt_logit = ${SPPT_LOGIT:-".true."}
  sppt_sfclimit = ${SPPT_SFCLIMIT:-".true."}
  use_zmtnblck = ${use_zmtnblck:-".true."}
EOF
  fi

  cat >> input.nml << EOF
  ${nam_stochy_nml:-}
/
EOF

  if [ ${DO_LAND_PERT:-"NO"} = "YES" ]; then
    cat >> input.nml << EOF
&nam_sfcperts
  lndp_type = ${lndp_type}
  LNDP_TAU = ${LNDP_TAU}
  LNDP_SCALE = ${LNDP_SCALE}
  ISEED_LNDP = ${ISEED_LNDP:-$ISEED}
  lndp_var_list = ${lndp_var_list}
  lndp_prt_list = ${lndp_prt_list}
  ${nam_sfcperts_nml:-}
/
EOF
  else
    cat >> input.nml << EOF
&nam_sfcperts
  ${nam_sfcperts_nml:-}
/
EOF
  fi

else

  cat >> input.nml << EOF
&nam_stochy
/
&nam_sfcperts
/
EOF

fi

echo "$(cat input.nml)"
}
