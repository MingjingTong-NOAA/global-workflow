#! /usr/bin/env bash

################################################################################
####  UNIX Script Documentation Block
#                      .                                             .
# Script name:         exgdas_enkf_update.sh
# Script description:  Make global_enkf update
#
# Author:        Rahul Mahajan      Org: NCEP/EMC     Date: 2017-03-02
#
# Abstract: This script runs the global_enkf update
#
# $Id$
#
# Attributes:
#   Language: POSIX shell
#
################################################################################

source "$HOMEgfs/ush/preamble.sh"

# Directories.
pwd=$(pwd)

# Utilities
NCLEN=${NCLEN:-$HOMEgfs/ush/getncdimlen}
USE_CFP=${USE_CFP:-"NO"}
CFP_MP=${CFP_MP:-"NO"}
nm=""
if [ $CFP_MP = "YES" ]; then
    nm=0
fi
APRUNCFP=${APRUNCFP:-""}
APRUN_ENKF=${APRUN_ENKF:-${APRUN:-""}}
NTHREADS_ENKF=${NTHREADS_ENKF:-${NTHREADS:-1}}

# Executables
ENKFEXEC=${ENKFEXEC:-$HOMEgfs/exec/enkf.x}

# Cycling and forecast hour specific parameters
CDATE=${CDATE:-"2001010100"}

# Filenames.
GPREFIX=${GPREFIX:-""}
APREFIX=${APREFIX:-""}

SMOOTH_ENKF=${SMOOTH_ENKF:-"YES"}

GBIASe=${GBIASe:-${APREFIX}abias_int.ensmean}
CNVSTAT=${CNVSTAT:-${APREFIX}cnvstat}
OZNSTAT=${OZNSTAT:-${APREFIX}oznstat}
RADSTAT=${RADSTAT:-${APREFIX}radstat}
ENKFSTAT=${ENKFSTAT:-${APREFIX}enkfstat}

# Namelist parameters
USE_CORRELATED_OBERRS=${USE_CORRELATED_OBERRS:-"NO"}
NMEM_ENKF=${NMEM_ENKF:-80}
NAM_ENKF=${NAM_ENKF:-""}
SATOBS_ENKF=${SATOBS_ENKF:-""}
OZOBS_ENKF=${OZOBS_ENKF:-""}
use_correlated_oberrs=${use_correlated_oberrs:-".false."}
if [ $USE_CORRELATED_OBERRS == "YES" ]; then
   use_correlated_oberrs=".true."
fi
imp_physics=${imp_physics:-"99"}
lupp=${lupp:-".true."}
corrlength=${corrlength:-1250}
lnsigcutoff=${lnsigcutoff:-2.5}
analpertwt=${analpertwt:-0.85}
analpertwt_rtpp=${analpertwt_rtpp:-0.0}
readin_localization_enkf=${readin_localization_enkf:-".true."}
reducedgrid=${reducedgrid:-".true."}
letkf_flag=${letkf_flag:-".false."}
getkf=${getkf:-".false."}
denkf=${denkf:-".false."}
nobsl_max=${nobsl_max:-10000}
lobsdiag_forenkf=${lobsdiag_forenkf:-".false."}
write_spread_diag=${write_spread_diag:-".false."}
cnvw_option=${cnvw_option:-".false."}
netcdf_diag=${netcdf_diag:-".true."}
modelspace_vloc=${modelspace_vloc:-".false."} # if true, 'vlocal_eig.dat' is needed
IAUFHRS_ENKF=${IAUFHRS_ENKF:-6}
DO_CALC_INCREMENT=${DO_CALC_INCREMENT:-"NO"}
INCREMENTS_TO_ZERO=${INCREMENTS_TO_ZERO:-"'NONE'"}
RECENTER=${RECENTER:-1}

################################################################################
ATMGES_ENSMEAN=${COMIN_GES_ENS}/${GPREFIX}atmf006.ensmean${GSUFFIX}
LONB_ENKF=${LONB_ENKF:-$($NCLEN $ATMGES_ENSMEAN grid_xt)} # get LONB_ENKF
LATB_ENKF=${LATB_ENKF:-$($NCLEN $ATMGES_ENSMEAN grid_yt)} # get LATB_ENFK
LEVS_ENKF=${LEVS_ENKF:-$($NCLEN $ATMGES_ENSMEAN pfull)} # get LEVS_ENFK
use_gfs_ncio=".true."
use_gfs_nemsio=".false."
paranc=${paranc:-".true."}
WRITE_INCR_ZERO="incvars_to_zero= $INCREMENTS_TO_ZERO,"
if [ $DO_CALC_INCREMENT = "YES" ]; then
   write_fv3_incr=".false."
else
   write_fv3_incr=".true."
fi
LATA_ENKF=${LATA_ENKF:-$LATB_ENKF}
LONA_ENKF=${LONA_ENKF:-$LONB_ENKF}
SATANGL=${SATANGL:-${FIXgsi}/global_satangbias.txt}
SATINFO=${SATINFO:-${FIXgsi}/global_satinfo_shield.txt}
CONVINFO=${CONVINFO:-${FIXgsi}/global_convinfo.txt}
OZINFO=${OZINFO:-${FIXgsi}/global_ozinfo.txt}
SCANINFO=${SCANINFO:-${FIXgsi}/global_scaninfo.txt}
HYBENSINFO=${HYBENSINFO:-${FIXgsi}/global_hybens_info.l${LEVS_ENKF}.txt}
ANAVINFO=${ANAVINFO:-${FIXgsi}/global_anavinfo.l${LEVS_ENKF}.txt}
VLOCALEIG=${VLOCALEIG:-${FIXgsi}/vlocal_eig_l${LEVS_ENKF}.dat}
ENKF_SUFFIX="s"
[[ $SMOOTH_ENKF = "NO" ]] && ENKF_SUFFIX=""

################################################################################
# Preprocessing
mkdata=NO
if [ ! -d $DATA ]; then
   mkdata=YES
   mkdir -p $DATA
fi
cd $DATA || exit 99

################################################################################
# Fixed files
$NLN $SATANGL    satbias_angle
$NLN $SATINFO    satinfo
$NLN $SCANINFO   scaninfo
$NLN $CONVINFO   convinfo
$NLN $OZINFO     ozinfo
$NLN $HYBENSINFO hybens_info
$NLN $ANAVINFO   anavinfo
$NLN $VLOCALEIG  vlocal_eig.dat

# Bias correction coefficients based on the ensemble mean
$NLN $COMOUT_ANL_ENS/$GBIASe satbias_in

################################################################################
SFDATE=$($NDATE +6 $FDATE)
if [ $USE_CFP = "YES" ]; then
   [[ -f $DATA/untar.sh ]] && rm $DATA/untar.sh
   [[ -f $DATA/mp_untar.sh ]] && rm $DATA/mp_untar.sh
   set +x
   cat > $DATA/untar.sh << EOFuntar
#!/bin/sh
memchar=\$1
if [[ $CDATE -le $SFDATE && $EXP_WARM_START = ".false." && ! -f $RADSTAT ]]; then
   flist="$CNVSTAT $OZNSTAT"
else
   flist="$CNVSTAT $OZNSTAT $RADSTAT"
fi
for ftype in \$flist; do
   if [ \$memchar = "ensmean" ]; then
      fname=$COMOUT_ANL_ENS/\${ftype}.ensmean
   else
      fname=$COMOUT_ANL_ENS/\$memchar/\$ftype
   fi
   tar -xvf \$fname
done
EOFuntar
   chmod 755 $DATA/untar.sh
fi

set -x

################################################################################
# Ensemble guess, observational data and analyses/increments
if [[ $CDATE -le $SFDATE && $EXP_WARM_START = ".false." && ! -f $RADSTAT ]]; then
   flist="$CNVSTAT $OZNSTAT"
else
   flist="$CNVSTAT $OZNSTAT $RADSTAT"
fi
if [ $USE_CFP = "YES" ]; then
   echo "$nm $DATA/untar.sh ensmean" | tee -a $DATA/mp_untar.sh
   if [ ${CFP_MP:-"NO"} = "YES" ]; then
       nm=$((nm+1))
   fi
else
   for ftype in $flist; do
      fname=$COMOUT_ANL_ENS/${ftype}.ensmean
      tar -xvf $fname
   done
fi
nfhrs=$(echo $IAUFHRS_ENKF | sed 's/,/ /g')
for imem in $(seq 1 $NMEM_ENKF); do
   memchar="mem"$(printf %03i $imem)
   if [ $lobsdiag_forenkf = ".false." ]; then
      if [ $USE_CFP = "YES" ]; then
         echo "$nm $DATA/untar.sh $memchar" | tee -a $DATA/mp_untar.sh
         if [ ${CFP_MP:-"NO"} = "YES" ]; then
             nm=$((nm+1))
         fi
      else
         for ftype in $flist; do
            fname=$COMOUT_ANL_ENS/$memchar/$ftype
            tar -xvf $fname
         done
      fi
   fi
   mkdir -p $COMOUT_ANL_ENS/$memchar
   for FHR in $nfhrs; do
      if [ $RECENTER -le 1 ]; then
         $NLN $COMIN_GES_ENS/$memchar/${GPREFIX}atmf00${FHR}${ENKF_SUFFIX}${GSUFFIX}  sfg_${CDATE}_fhr0${FHR}_${memchar}
      else
         $NLN $COMIN_GES_ENS/$memchar/${GPREFIX}ratmf00${FHR}${ENKF_SUFFIX}${GSUFFIX}  sfg_${CDATE}_fhr0${FHR}_${memchar}
      fi
      if [ $cnvw_option = ".true." ]; then
         if [ $RECENTER -le 1 ]; then
            $NLN $COMIN_GES_ENS/$memchar/${GPREFIX}sfcf00${FHR}${GSUFFIX} sfgsfc_${CDATE}_fhr0${FHR}_${memchar}
         else
            $NLN $COMIN_GES_ENS/$memchar/${GPREFIX}rsfcf00${FHR}${GSUFFIX} sfgsfc_${CDATE}_fhr0${FHR}_${memchar}
         fi
      fi
      if [ $FHR -eq 6 ]; then
         if [ $DO_CALC_INCREMENT = "YES" ]; then
            $NLN $COMOUT_ANL_ENS/$memchar/${APREFIX}atmanl${ASUFFIX}             sanl_${CDATE}_fhr0${FHR}_${memchar}
         else
            $NLN $COMOUT_ANL_ENS/$memchar/${APREFIX}atminc${ASUFFIX}             incr_${CDATE}_fhr0${FHR}_${memchar}
         fi
      else
         if [ $DO_CALC_INCREMENT = "YES" ]; then
            $NLN $COMOUT_ANL_ENS/$memchar/${APREFIX}atma00${FHR}${ASUFFIX}             sanl_${CDATE}_fhr0${FHR}_${memchar}
         else
            $NLN $COMOUT_ANL_ENS/$memchar/${APREFIX}atmi00${FHR}${ASUFFIX}             incr_${CDATE}_fhr0${FHR}_${memchar}
         fi
      fi
   done
done

# Ensemble mean guess
for FHR in $nfhrs; do
   if [ $RECENTER -le 1 ]; then
      $NLN $COMIN_GES_ENS/${GPREFIX}atmf00${FHR}.ensmean${GSUFFIX} sfg_${CDATE}_fhr0${FHR}_ensmean
   else
      $NLN $COMIN_GES_CTL/${GPREFIX}atmf00${FHR}.ensres${GSUFFIX} sfg_${CDATE}_fhr0${FHR}_ensmean  
   fi
   if [ $cnvw_option = ".true." ]; then
      if [ $RECENTER -le 1 ]; then
        $NLN $COMIN_GES_ENS/${GPREFIX}sfcf00${FHR}.ensmean${GSUFFIX} sfgsfc_${CDATE}_fhr0${FHR}_ensmean
      else
        $NLN $COMIN_GES_CTL/${GPREFIX}sfcf00${FHR}.ensres${GSUFFIX} sfgsfc_${CDATE}_fhr0${FHR}_ensmean
      fi
   fi
done

if [ $USE_CFP = "YES" ]; then
   chmod 755 $DATA/mp_untar.sh
   ncmd=$(cat $DATA/mp_untar.sh | wc -l)
   if [ $ncmd -gt 0 ]; then
      ncmd_max=$((ncmd < npe_node_max ? ncmd : npe_node_max))
      APRUNCFP=$(eval echo $APRUNCFP)
      $APRUNCFP $DATA/mp_untar.sh
      export err=$?; err_chk
   fi
fi

################################################################################
# Create global_enkf namelist
cat > enkf.nml << EOFnml
&nam_enkf
   datestring="$CDATE",datapath="$DATA/",
   analpertwtnh=${analpertwt},analpertwtsh=${analpertwt},analpertwttr=${analpertwt},
   analpertwtnh_rtpp=${analpertwt_rtpp},analpertwtsh_rtpp=${analpertwt_rtpp},analpertwttr_rtpp=${analpertwt_rtpp},
   covinflatemax=1.e2,covinflatemin=1,pseudo_rh=${pseudo_rh:-.true.},iassim_order=0,
   corrlengthnh=${corrlength},corrlengthsh=${corrlength},corrlengthtr=${corrlength},
   lnsigcutoffnh=${lnsigcutoff},lnsigcutoffsh=${lnsigcutoff},lnsigcutofftr=${lnsigcutoff},
   lnsigcutoffpsnh=${lnsigcutoff},lnsigcutoffpssh=${lnsigcutoff},lnsigcutoffpstr=${lnsigcutoff},
   lnsigcutoffsatnh=${lnsigcutoff},lnsigcutoffsatsh=${lnsigcutoff},lnsigcutoffsattr=${lnsigcutoff},
   obtimelnh=1.e30,obtimelsh=1.e30,obtimeltr=1.e30,
   saterrfact=1.0,numiter=${numiter:-0},
   sprd_tol=1.e30,paoverpb_thresh=0.98,
   nlons=$LONA_ENKF,nlats=$LATA_ENKF,nlevs=$LEVS_ENKF,nanals=$NMEM_ENKF,
   deterministic=.true.,sortinc=.true.,lupd_satbiasc=.false.,
   reducedgrid=${reducedgrid},readin_localization=${readin_localization_enkf}.,
   use_gfs_nemsio=${use_gfs_nemsio},use_gfs_ncio=${use_gfs_ncio},imp_physics=$imp_physics,lupp=$lupp,
   univaroz=.false.,adp_anglebc=.true.,angord=4,use_edges=.false.,emiss_bc=.true.,
   letkf_flag=${letkf_flag},nobsl_max=${nobsl_max},denkf=${denkf},getkf=${getkf}.,
   nhr_anal=${IAUFHRS_ENKF},nhr_state=${IAUFHRS_ENKF},
   lobsdiag_forenkf=$lobsdiag_forenkf,
   write_spread_diag=$write_spread_diag,
   modelspace_vloc=$modelspace_vloc,
   use_correlated_oberrs=${use_correlated_oberrs},
   netcdf_diag=$netcdf_diag,cnvw_option=$cnvw_option,
   paranc=$paranc,write_fv3_incr=$write_fv3_incr,
   $WRITE_INCR_ZERO
   $NAM_ENKF
/
&satobs_enkf
   sattypes_rad(1) = 'amsua_n15',     dsis(1) = 'amsua_n15',
   sattypes_rad(2) = 'amsua_n18',     dsis(2) = 'amsua_n18',
   sattypes_rad(3) = 'amsua_n19',     dsis(3) = 'amsua_n19',
   sattypes_rad(4) = 'amsub_n16',     dsis(4) = 'amsub_n16',
   sattypes_rad(5) = 'amsub_n17',     dsis(5) = 'amsub_n17',
   sattypes_rad(6) = 'amsua_aqua',    dsis(6) = 'amsua_aqua',
   sattypes_rad(7) = 'amsua_metop-a', dsis(7) = 'amsua_metop-a',
   sattypes_rad(8) = 'airs_aqua',     dsis(8) = 'airs_aqua',
   sattypes_rad(9) = 'hirs3_n17',     dsis(9) = 'hirs3_n17',
   sattypes_rad(10)= 'hirs4_n19',     dsis(10)= 'hirs4_n19',
   sattypes_rad(11)= 'hirs4_metop-a', dsis(11)= 'hirs4_metop-a',
   sattypes_rad(12)= 'mhs_n18',       dsis(12)= 'mhs_n18',
   sattypes_rad(13)= 'mhs_n19',       dsis(13)= 'mhs_n19',
   sattypes_rad(14)= 'mhs_metop-a',   dsis(14)= 'mhs_metop-a',
   sattypes_rad(15)= 'goes_img_g11',  dsis(15)= 'imgr_g11',
   sattypes_rad(16)= 'goes_img_g12',  dsis(16)= 'imgr_g12',
   sattypes_rad(17)= 'goes_img_g13',  dsis(17)= 'imgr_g13',
   sattypes_rad(18)= 'goes_img_g14',  dsis(18)= 'imgr_g14',
   sattypes_rad(19)= 'goes_img_g15',  dsis(19)= 'imgr_g15',
   sattypes_rad(20)= 'avhrr_n18',     dsis(20)= 'avhrr3_n18',
   sattypes_rad(21)= 'avhrr_metop-a', dsis(21)= 'avhrr3_metop-a',
   sattypes_rad(22)= 'avhrr_n19',     dsis(22)= 'avhrr3_n19',
   sattypes_rad(23)= 'amsre_aqua',    dsis(23)= 'amsre_aqua',
   sattypes_rad(24)= 'ssmis_f16',     dsis(24)= 'ssmis_f16',
   sattypes_rad(25)= 'ssmis_f17',     dsis(25)= 'ssmis_f17',
   sattypes_rad(26)= 'ssmis_f18',     dsis(26)= 'ssmis_f18',
   sattypes_rad(27)= 'ssmis_f19',     dsis(27)= 'ssmis_f19',
   sattypes_rad(28)= 'ssmis_f20',     dsis(28)= 'ssmis_f20',
   sattypes_rad(29)= 'sndrd1_g11',    dsis(29)= 'sndrD1_g11',
   sattypes_rad(30)= 'sndrd2_g11',    dsis(30)= 'sndrD2_g11',
   sattypes_rad(31)= 'sndrd3_g11',    dsis(31)= 'sndrD3_g11',
   sattypes_rad(32)= 'sndrd4_g11',    dsis(32)= 'sndrD4_g11',
   sattypes_rad(33)= 'sndrd1_g12',    dsis(33)= 'sndrD1_g12',
   sattypes_rad(34)= 'sndrd2_g12',    dsis(34)= 'sndrD2_g12',
   sattypes_rad(35)= 'sndrd3_g12',    dsis(35)= 'sndrD3_g12',
   sattypes_rad(36)= 'sndrd4_g12',    dsis(36)= 'sndrD4_g12',
   sattypes_rad(37)= 'sndrd1_g13',    dsis(37)= 'sndrD1_g13',
   sattypes_rad(38)= 'sndrd2_g13',    dsis(38)= 'sndrD2_g13',
   sattypes_rad(39)= 'sndrd3_g13',    dsis(39)= 'sndrD3_g13',
   sattypes_rad(40)= 'sndrd4_g13',    dsis(40)= 'sndrD4_g13',
   sattypes_rad(41)= 'sndrd1_g14',    dsis(41)= 'sndrD1_g14',
   sattypes_rad(42)= 'sndrd2_g14',    dsis(42)= 'sndrD2_g14',
   sattypes_rad(43)= 'sndrd3_g14',    dsis(43)= 'sndrD3_g14',
   sattypes_rad(44)= 'sndrd4_g14',    dsis(44)= 'sndrD4_g14',
   sattypes_rad(45)= 'sndrd1_g15',    dsis(45)= 'sndrD1_g15',
   sattypes_rad(46)= 'sndrd2_g15',    dsis(46)= 'sndrD2_g15',
   sattypes_rad(47)= 'sndrd3_g15',    dsis(47)= 'sndrD3_g15',
   sattypes_rad(48)= 'sndrd4_g15',    dsis(48)= 'sndrD4_g15',
   sattypes_rad(49)= 'iasi_metop-a',  dsis(49)= 'iasi_metop-a',
   sattypes_rad(50)= 'seviri_m08',    dsis(50)= 'seviri_m08',
   sattypes_rad(51)= 'seviri_m09',    dsis(51)= 'seviri_m09',
   sattypes_rad(52)= 'seviri_m10',    dsis(52)= 'seviri_m10',
   sattypes_rad(53)= 'seviri_m11',    dsis(53)= 'seviri_m11',
   sattypes_rad(54)= 'amsua_metop-b', dsis(54)= 'amsua_metop-b',
   sattypes_rad(55)= 'hirs4_metop-b', dsis(55)= 'hirs4_metop-b',
   sattypes_rad(56)= 'mhs_metop-b',   dsis(56)= 'mhs_metop-b',
   sattypes_rad(57)= 'iasi_metop-b',  dsis(57)= 'iasi_metop-b',
   sattypes_rad(58)= 'avhrr_metop-b', dsis(58)= 'avhrr3_metop-b',
   sattypes_rad(59)= 'atms_npp',      dsis(59)= 'atms_npp',
   sattypes_rad(60)= 'atms_n20',      dsis(60)= 'atms_n20',
   sattypes_rad(61)= 'cris_npp',      dsis(61)= 'cris_npp',
   sattypes_rad(62)= 'cris-fsr_npp',  dsis(62)= 'cris-fsr_npp',
   sattypes_rad(63)= 'cris-fsr_n20',  dsis(63)= 'cris-fsr_n20',
   sattypes_rad(64)= 'gmi_gpm',       dsis(64)= 'gmi_gpm',
   sattypes_rad(65)= 'saphir_meghat', dsis(65)= 'saphir_meghat',
   sattypes_rad(66)= 'amsua_metop-c', dsis(66)= 'amsua_metop-c',
   sattypes_rad(67)= 'mhs_metop-c',   dsis(67)= 'mhs_metop-c',
   sattypes_rad(68)= 'ahi_himawari8', dsis(68)= 'ahi_himawari8',
   sattypes_rad(69)= 'abi_g16',       dsis(69)= 'abi_g16',
   sattypes_rad(70)= 'abi_g17',       dsis(70)= 'abi_g17',
   sattypes_rad(71)= 'iasi_metop-c',  dsis(71)= 'iasi_metop-c',
   $SATOBS_ENKF
/
&ozobs_enkf
   sattypes_oz(1) = 'sbuv2_n16',
   sattypes_oz(2) = 'sbuv2_n17',
   sattypes_oz(3) = 'sbuv2_n18',
   sattypes_oz(4) = 'sbuv2_n19',
   sattypes_oz(5) = 'omi_aura',
   sattypes_oz(6) = 'gome_metop-a',
   sattypes_oz(7) = 'gome_metop-b',
   sattypes_oz(8) = 'mls30_aura',
   sattypes_oz(9) = 'ompsnp_npp',
   sattypes_oz(10) = 'ompstc8_npp',
   $OZOBS_ENKF
/
EOFnml

################################################################################
# Run enkf update

export OMP_NUM_THREADS=$NTHREADS_ENKF
export pgm=$ENKFEXEC
. prep_step

$NCP $ENKFEXEC $DATA
$APRUN_ENKF ${DATA}/$(basename $ENKFEXEC) 1>stdout 2>stderr
export err=$?; err_chk

# Cat runtime output files.
cat stdout stderr > $COMOUT_ANL_ENS/$ENKFSTAT

echo "done EnKF"

# Tar spread diag file
echo 'START tar spread diag file'
if [ $write_spread_diag = ".true." ]; then
   # Set up lists and variables for various types of diagnostic files.
   ntype=3

   diagtype[0]="conv conv_gps conv_ps conv_pw conv_q conv_sst conv_t conv_tcp conv_uv conv_spd"
   diagtype[1]="pcp_ssmi_dmsp pcp_tmi_trmm"
   diagtype[2]="sbuv2_n16 sbuv2_n17 sbuv2_n18 sbuv2_n19 gome_metop-a gome_metop-b omi_aura mls30_aura ompsnp_npp ompstc8_npp  ompstc8_n20 ompsnp_n20 ompstc8_n21 ompsnp_n21 ompslp_npp gome_metop-c"
   diagtype[3]="hirs2_n14 msu_n14 sndr_g08 sndr_g11 sndr_g12 sndr_g13 sndr_g08_prep sndr_g11_prep sndr_g12_prep sndr_g13_prep sndrd1_g11 sndrd2_g11 sndrd3_g11 sndrd4_g11 sndrd1_g12 sndrd2_g12 sndrd3_g12 sndrd4_g12 sndrd1_g13 sndrd2_g13 sndrd3_g13 sndrd4_g13 sndrd1_g14 sndrd2_g14 sndrd3_g14 sndrd4_g14 sndrd1_g15 sndrd2_g15 sndrd3_g15 sndrd4_g15 hirs3_n15 hirs3_n16 hirs3_n17 amsua_n15 amsua_n16 amsua_n17 amsub_n15 amsub_n16 amsub_n17 hsb_aqua airs_aqua amsua_aqua imgr_g08 imgr_g11 imgr_g12 imgr_g14 imgr_g15 ssmi_f13 ssmi_f15 hirs4_n18 hirs4_metop-a amsua_n18 amsua_metop-a mhs_n18 mhs_metop-a amsre_low_aqua amsre_mid_aqua amsre_hig_aqua ssmis_f16 ssmis_f17 ssmis_f18 ssmis_f19 ssmis_f20 iasi_metop-a hirs4_n19 amsua_n19 mhs_n19 seviri_m08 seviri_m09 seviri_m10 seviri_m11 cris_npp cris-fsr_npp cris-fsr_n20 atms_npp atms_n20 hirs4_metop-b amsua_metop-b mhs_metop-b iasi_metop-b avhrr_metop-b avhrr_n18 avhrr_n19 avhrr_metop-a amsr2_gcom-w1 gmi_gpm saphir_meghat ahi_himawari8 abi_g16 abi_g17 amsua_metop-c mhs_metop-c iasi_metop-c avhrr_metop-c viirs-m_npp viirs-m_j1 abi_g18 ahi_himawari9 viirs-m_j2 cris-fsr_n21 atms_n21"

   diaglist[0]=listcnv
   diaglist[1]=listpcp
   diaglist[2]=listozn
   diaglist[3]=listrad

   diagfile[0]=${COMOUT_ANL_ENS}/${APREFIX}cnvsprd
   diagfile[1]=${COMOUT_ANL_ENS}/${APREFIX}pcpsprd
   diagfile[2]=${COMOUT_ANL_ENS}/${APREFIX}oznsprd
   diagfile[3]=${COMOUT_ANL_ENS}/${APREFIX}radsprd

   numfile[0]=0
   numfile[1]=0
   numfile[2]=0
   numfile[3]=0

   n=-1
   while [ $((n+=1)) -le $ntype ] ;do
      for type in $(echo ${diagtype[n]}); do
          if [ -s diag_${type}_ges.${CDATE}_ensmean_spread.nc4 ]; then
            echo "diag_${type}_ges.${CDATE}_ensmean_spread.nc4" >> ${diaglist[n]}
            numfile[n]=$(expr ${numfile[n]} + 1)
          elif [ -s diag_${type}_ges.ensmean_spread.nc4 ]; then
            mv diag_${type}_ges.ensmean_spread.nc4 diag_${type}_ges.${CDATE}_ensmean_spread.nc4
            echo "diag_${type}_ges.${CDATE}_ensmean_spread.nc4" >> ${diaglist[n]}
            numfile[n]=$(expr ${numfile[n]} + 1)
          fi
      done
   done

   n=-1
   while [ $((n+=1)) -le $ntype ] ;do
      TAROPTS="-uvf"
      if [ ! -s ${diagfile[n]} ]; then
         TAROPTS="-cvf"
      fi
      if [ ${numfile[n]} -gt 0 ]; then
         tar $TAROPTS ${diagfile[n]} $(cat ${diaglist[n]})
         export err=$?; err_chk
      fi
   done
fi

################################################################################
#  Postprocessing
cd $pwd
[[ $mkdata = "YES" ]] && rm -rf $DATA


exit $err
