# This file defines manifest constants related to the Autolab
# backend. If you change anything here you'll need to restart the
# server for the changes to take effect.

# Hostname for Tango RESTful API
RESTFUL_HOST = "tango"

# Port for Tango RESTful API
RESTFUL_PORT = 3000

# How many seconds to wait for Tango RPC calls before timing out?
AUTOCONFIG_TANGO_TIMEOUT = 15

# How big is the Tango dead job queue?
AUTOCONFIG_MAX_DEAD_JOBS = 500

# Default number of dead jobs to display
AUTOCONFIG_DEF_DEAD_JOBS = 15

# Key for Tango RESTful API
RESTFUL_KEY = "test"

# Whether or not Autolab should use polling to get Tango results
RESTFUL_USE_POLLING = false
