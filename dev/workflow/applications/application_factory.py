from wxflow import Factory
from applications.gfs_cycled import GFSCycledAppConfig
from applications.gfs_forecast_only import GFSForecastOnlyAppConfig
from applications.gefs import GEFSAppConfig
from applications.shield_cycled import SHiELDCycledAppConfig
from applications.shield_forecast_only import SHiELDForecastOnlyAppConfig
from applications.shield_replay import SHiELDReplayAppConfig
from applications.shield_omf import SHiELDOmfAppConfig
from applications.shield_ensregrid import SHiELDEnsregridAppConfig
from applications.sfs import SFSAppConfig


app_config_factory = Factory('AppConfig')
app_config_factory.register('gfs_cycled', GFSCycledAppConfig)
app_config_factory.register('gfs_forecast-only', GFSForecastOnlyAppConfig)
app_config_factory.register('gefs_forecast-only', GEFSAppConfig)
app_config_factory.register('shield_cycled', SHiELDCycledAppConfig)
app_config_factory.register('shield_forecast-only', SHiELDForecastOnlyAppConfig)
app_config_factory.register('shield_replay', SHiELDReplayAppConfig)
app_config_factory.register('shield_omf', SHiELDOmfAppConfig)
app_config_factory.register('shield_ensregrid', SHiELDEnsregridAppConfig)
app_config_factory.register('sfs_forecast-only', SFSAppConfig)
