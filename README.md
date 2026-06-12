# Wazuh

Scripts that I use to manage and update wazuh all-in-one installations

Installation:
- create `~/bin`
- download both files to `~/bin`
- run using `bin/wazuh-server-update.sh`
  * `wazuh-server-update.sh` uses `ccerts.sh` to load the environment variable CREDS, which gets used to execute various commands included in the upgrade instructions.
  * The script will pause from time to time and ask you to perform other actions included in the [wazuh upgrade instructions](https://documentation.wazuh.com/current/upgrade-guide/upgrading-central-components.html)

Minimally tested on two nearly identical all-in-one wazuh servers, both running on Ubuntu 24.04

No warranty of any sort / your mileage may vary 
