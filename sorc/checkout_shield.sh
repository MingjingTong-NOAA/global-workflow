#!/bin/sh
#set -xue
set -x

while getopts "o" option;
do
 case $option in
  o)
   echo "Received -o flag for optional checkout of operational-only codes"
   checkout_gtg="YES"
   ;;
  :)
   echo "option -$OPTARG needs an argument"
   ;;
  *)
   echo "invalid option -$OPTARG, exiting..."
   exit
   ;;
 esac
done

topdir=$(pwd)
logdir="${topdir}/logs"
mkdir -p ${logdir}

echo cube2gaus checkout ...
if [[ ! -d cube2gaus.fd ]] ; then
    rm -f ${topdir}/checkout-cube2gaus.log
    git clone https://github.com/MingjingTong-NOAA/cube2gaus.git cube2gaus.fd >> ${logdir}/checkout-cube2gaus.log 2>&1
    cd ${topdir}
else
    echo 'Skip.  Directory cube2gaus.fd already exists.'
fi

echo gsi checkout ...
if [[ ! -d gsi.fd ]] ; then
    rm -f ${topdir}/checkout-gsi.log
    git clone --recursive https://github.com/MingjingTong-NOAA/GSI.git gsi.fd >> ${logdir}/checkout-gsi.log 2>&1
    cd gsi.fd
    git checkout gfdl_mtong
    git submodule update
    cd ${topdir}
else
    echo 'Skip.  Directory gsi.fd already exists.'
fi

echo gldas checkout ...
if [[ ! -d gldas.fd ]] ; then
    rm -f ${topdir}/checkout-gldas.log
    git clone https://github.com/NOAA-EMC/GLDAS.git gldas.fd >> ${logdir}/checkout-gldas.fd.log 2>&1
    cd gldas.fd
    git checkout gldas_gfsv16_release.v1.15.0
    cd ${topdir}
else
    echo 'Skip.  Directory gldas.fd already exists.'
fi

echo ufs_utils checkout ...
if [[ ! -d ufs_utils.fd ]] ; then
    rm -f ${topdir}/checkout-ufs_utils.log
    git clone https://github.com/MingjingTong-NOAA/UFS_UTILS.git ufs_utils.fd >> ${logdir}/checkout-ufs_utils.fd.log 2>&1
    cd ufs_utils.fd
    git checkout gfdl-mtong
    cd ${topdir}
else
    echo 'Skip.  Directory ufs_utils.fd already exists.'
fi

echo UPP checkout ...
if [[ ! -d gfs_post.fd ]] ; then
    rm -f ${topdir}/checkout-gfs_post.log
    git clone https://github.com/NOAA-EMC/UPP.git gfs_post.fd >> ${logdir}/checkout-gfs_post.log 2>&1
    cd gfs_post.fd
    git checkout upp_v10.0.8
    git submodule update --init CMakeModules
    ################################################################################
    # checkout_gtg
    ## yes: The gtg code at NCAR private repository is available for ops. GFS only.
    #       Only approved persons/groups have access permission.
    ## no:  No need to check out gtg code for general GFS users.
    ################################################################################
    checkout_gtg=${checkout_gtg:-"NO"}
    if [[ ${checkout_gtg} == "YES" ]] ; then
      ./manage_externals/checkout_externals
      cp sorc/post_gtg.fd/*F90 sorc/ncep_post.fd/.
      cp sorc/post_gtg.fd/gtg.config.gfs parm/gtg.config.gfs
    fi
    cd ${topdir}
else
    echo 'Skip.  Directory gfs_post.fd already exists.'
fi


echo EMC_verif-global checkout ...
if [[ ! -d verif-global.fd ]] ; then
    rm -f ${topdir}/checkout-verif-global.log
    git clone --recursive https://github.com/NOAA-EMC/EMC_verif-global.git verif-global.fd >> ${logdir}/checkout-verif-global.log 2>&1
    cd verif-global.fd
    git checkout verif_global_v2.8.0
    cd ${topdir}
else
    echo 'Skip. Directory verif-global.fd already exist.'
fi

exit 0
