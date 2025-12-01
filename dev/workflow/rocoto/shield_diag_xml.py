#!/usr/bin/env python3

"""
SHiELD Diagnosis XML generator module.

This module provides functionality to generate Rocoto XML workflow configurations
for SHiELD diagnosis runs. It handles cycle definitions and specific task configurations
needed for the SHiELD workflow.
"""

from rocoto.rocoto_xml import RocotoXML
from applications.applications import AppConfig
from wxflow import to_timedelta, timedelta_to_HMS
from typing import Dict


class SHiELDDiagRocotoXML(RocotoXML):
    """
    Rocoto XML generator for SHiELD diagnosis workflows.

    This class handles the generation of Rocoto XML configuration for SHiELD
    omf or ensregrid mode, including cycle definitions and workflow scheduling.

    Parameters
    ----------
    app_config : AppConfig
        Application configuration object containing GFS settings
    rocoto_config : Dict
        Dictionary containing Rocoto-specific configuration
    """

    def __init__(self, app_config: AppConfig, rocoto_config: Dict) -> None:
        """
        Initialize SHiELD diagnosis Rocoto XML generator.

        Parameters
        ----------
        app_config : AppConfig
            Application configuration object containing SHiELD settings
        rocoto_config : Dict
            Dictionary containing Rocoto-specific configuration
        """
        super().__init__(app_config, rocoto_config)

    def get_cycledefs(self):
        """
        Generate cycle definition strings for Rocoto XML.

        This method creates the cycle definitions for SHiELD omf or ensregrid 
        cycles based on the configured start dates, end dates, and intervals.

        Returns
        -------
        str
            Concatenated cycle definition strings formatted for Rocoto XML
        """
        sdate = self._base['SDATE']
        edate = self._base['EDATE']
        interval = to_timedelta(f"{self._base['diag_interval']}H")
        strings = []
        sdate_str = sdate.strftime("%Y%m%d%H%M")
        edate_str = edate.strftime("%Y%m%d%H%M")
        interval_str = timedelta_to_HMS(interval)
        strings.append(f'\t<cycledef group="gdas">{sdate_str} {edate_str} {interval_str}</cycledef>')

        strings.append('')
        strings.append('')

        return '\n'.join(strings)
