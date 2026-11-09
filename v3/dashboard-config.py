## hblink3 v3 dashboard config - mount at /opt/HBlink3/dashboard/config.py
## carried over from the HBmonitor config.py; see dashboard/README.md upstream

REPORT_NAME     = 'poa.nyc hblink server'   # Shown in the dashboard header
LOGO_FILE       = ''                        # Path to a logo image (png/jpg/svg/gif); '' = no logo

## the report feed comes over a unix socket - hblink and the dashboard share the container,
## and with host networking a tcp feed would listen on the host's interfaces
HBLINK_TRANSPORT = 'unix'                   # [REPORTS] REPORT_TRANSPORT in hblink.cfg ('tcp' to use the port below)
HBLINK_SOCKET   = '/tmp/hblink3-report.sock'  # [REPORTS] REPORT_SOCKET in hblink.cfg
HBLINK_IP       = '127.0.0.1'               # tcp only: HBlink3 reporting host (same container)
HBLINK_PORT     = 4321                      # tcp only: [REPORTS] REPORT_PORT in hblink.cfg

WEB_HOST        = '0.0.0.0'                 # Interface to bind the dashboard web server
WEB_PORT        = 8080                      # Port (must be > 1024 if not running as root)

LOG_LINES        = 300                      # Number of recent call-log entries to retain
LAST_HEARD       = 'open'                   # 'open' | 'closed' | 'off'
LAST_HEARD_COUNT = 10                       # Number of recent callers to list
SERVER_REPEATERS = 'open'                   # 'open' | 'closed'

## alias files - same /alias volume HBmonitor used
TRY_DOWNLOAD    = True
PATH            = '/alias/'                 # MUST END IN '/'
PEER_FILE       = 'peer_ids.json'
SUBSCRIBER_FILE = 'subscriber_ids.json'
TGID_FILE       = 'talkgroup_ids.json'
LOCAL_SUB_FILE  = 'local_subscriber_ids.json'
LOCAL_PEER_FILE = 'local_peer_ids.json'
PEER_URL        = 'https://database.radioid.net/static/rptrs.json'
SUBSCRIBER_URL  = 'https://database.radioid.net/static/users.json'
STALE_DAYS      = 30                        # HBmonitor's FILE_RELOAD
## only these countries are written to the alias files ([] keeps every country). the full radioid
## database costs the dashboard ~250MB more RAM; filtered to the US it runs at ~100MB.
## the filter applies on download - move the old files aside (or wait STALE_DAYS) after changing it
FILTER_COUNTRIES = ['United States']
