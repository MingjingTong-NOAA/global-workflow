#!/usr/bin/env python3

import os
from logging import getLogger
from typing import Any, Dict, List
import tarfile

from wxflow import (Task, htar, mkdir_p,
                    logit, parse_j2yaml, chdir)
# import tarfile


logger = getLogger(__name__.split('.')[-1])


class Fetch(Task):
    """Task to pull ROTDIR data from HPSS (or locally)
    """

    @logit(logger, name="Fetch")
    def __init__(self, config: Dict[str, Any]) -> None:
        """Constructor for the Fetch task
        The constructor is responsible for collecting necessary yamls based on
        the runtime options and RUN.

        Parameters
        ----------
        config : Dict[str, Any]
            Incoming configuration for the task from the environment

        Returns
        -------
        None
        """
        super().__init__(config)

    @logit(logger)
    def configure(self, fetch_dict: Dict[str, Any]):
        """Determine which tarballs will need to be extracted

        Parameters
        ----------
        fetch_dict : Dict[str, Any]
            Task specific keys, e.g. COM directories, etc

        Return
        ------
        parsed_fetch: Dict[str, Any]
           Dictionary derived from the yaml file with necessary HPSS info.
        """

        fetch_yaml = fetch_dict.FETCH_YAML_TMPL
        fetch_parm = os.path.join(fetch_dict.PARMgfs, "fetch")

        parsed_fetch = parse_j2yaml(os.path.join(fetch_parm, fetch_yaml),
                                    fetch_dict)
        return parsed_fetch

    @logit(logger)
    def configure_fetch(self, fetch_dict: Dict[str, Any]) -> (List[Dict[str, Any]]):
        """Determine which tarballs will need to be created.

        Parameters
        ----------
        fetch_dict : Dict[str, Any]
            Task specific keys, e.g. COM directories, etc

        Return
        ------
        fetch_sets : List[Dict[str, Any]]
            List of tarballs and instructions for fetch data from them via htar
        """

        if not os.path.isdir(fetch_dict.SAVEDIR):
            mkdir_p(fetch_dict.SAVEDIR)

        if not os.path.isdir(fetch_dict.ROTDIR):
            raise FileNotFoundError(f"FATAL ERROR: The ROTDIR ({fetch_dict.ROTDIR}) does not exist!")

        # Collect datasets that need to be fetched
        # Each dataset represents one tarball

        self.htar = htar.Htar()

        fetch_parm = os.path.join(fetch_dict.PARMgfs, "fetch")
        master_yaml = "master_" + fetch_dict.RUN + ".yaml.j2"

        parsed_sets = parse_j2yaml(os.path.join(fetch_parm, master_yaml),
                                   fetch_dict,
                                   allow_missing=False)

        fetch_sets = []
        for dataset in parsed_sets.datasets.values():
            dataset["fileset"] = Fetch._create_fileset(dataset)
            fetch_sets.append(dataset)

        return fetch_sets

    @logit(logger)
    def execute_pull_data(self, fetchdir_set: Dict[str, Any]) -> None:
        """Pull data from HPSS based on a yaml dictionary and store at the
           specified destination.

        Parameters
        ----------
        fetchdir_set: Dict[str, Any],
            Dict defining set of tarballs to pull and where to put them.

        Return
            None
        """

        f_names = fetchdir_set.target.contents
        if len(f_names) <= 0:     # Abort if no files
            raise FileNotFoundError("FATAL ERROR: The tar ball has no files")

        on_hpss = fetchdir_set.target.on_hpss
        dest = fetchdir_set.target.destination
        tarball = fetchdir_set.target.tarball

        f_names_new = []
        for f_name in f_names:
            if not os.path.exists(os.path.join(dest, f_name)):
                f_names_new.append(f_name)

        if len(f_names_new) <= 0:
            print("all required files exist, skip pulling data")
            return

        # Select action whether no_hpss is True or not, and pull these
        #    data from tape or locally and place where it needs to go
        # DG - these need testing
        with chdir(dest):
            logger.info(f"Changed working directory to {dest}")
            if on_hpss is True:  # htar all files in fnames
                htar_obj = htar.Htar()
                htar_obj.xvf(tarball, f_names)
            else:  # extract from a specified tarball
                with tarfile.open(tarball, "r") as tar:
                    members = [m for m in tar.getmembers() if m.name in f_names]
                    tar.extractall(members=members)
            # Verify all data files were extracted
            missing_files = []
            for f in f_names_new:
                if not os.path.exists(f):
                    missing_files.append(f)
            if len(missing_files) > 0:
                message = "Failed to extract all required files.  Missing files:\n"
                for f in missing_files:
                    message += f"{f}\n"

                raise FileNotFoundError(message)

    @staticmethod
    @logit(logger)
    def _create_fileset(fetchdir_set: Dict[str, Any]) -> List:
        """
        Collect the list of all files from the parsed yaml dict.

        Parameters
        ----------
        fetchdir_set: Dict
            Contains full paths for required and optional files to be archived.
        """

        fileset = []
        # Check that all required files are present and add them to the list of files to archive
        if "contents" in fetchdir_set.target:
            if fetchdir_set.target.contents is not None:
                for item in fetchdir_set.target.contents:
                    fileset.append(item)

        return fileset
