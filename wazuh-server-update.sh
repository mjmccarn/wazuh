# 2026-04-27 updated for 4.14.5
  # update section labeling
# 2026-03-25 updated for 4.14.4
  # update order to match https://documentation.wazuh.com/4.14/upgrade-guide/upgrading-central-components.html

# a. Preparing the upgrade
  # https://documentation.wazuh.com/4.14/upgrade-guide/upgrading-central-components.html#preparing-the-upgrade
# a.1: enable the repository
cd /etc/apt/sources.list.d && mv wazuh.list.disabled wazuh.list && apt update
# a.2: Export customizations
# (web only!)
printf "Navigate to Dashboard management > Dashboards Management > Saved objects on the Wazuh dashboard.\n"
printf "Select which objects to export and click Export, or click Export all objects to export everything.\n"
a="N"; while [[ ${a,,} != "y" ]]; do printf "\r continue (y/N)? "; read a; done
# a.3: Stop filebeat and wazuh-dashboard
systemctl stop filebeat && systemctl stop wazuh-dashboard


# b. Upgrading the wazuh indexer
  # https://documentation.wazuh.com/4.14/upgrade-guide/upgrading-central-components.html#upgrading-the-wazuh-indexer

# b.1: Backup the existing Wazuh indexer security configuration files:
/usr/share/wazuh-indexer/bin/indexer-security-init.sh --options "-backup /etc/wazuh-indexer/opensearch-security -icl -nhnv"

# b.2: Disable shard replication...
# set ${CRED} to "-u admin:<password>"
source ~/bin/cpw.sh
curl -X PUT "https://127.0.0.1:9200/_cluster/settings"  ${CRED} -k -H 'Content-Type: application/json' -d'
{
  "persistent": {
    "cluster.routing.allocation.enable": "primaries"
  }
}
'

# b.3: Perform a flush operation...
curl -X POST "https://127.0.0.1:9200/_flush" ${CRED} -k

# b.4: (Single node) Stop wazuh-manager
systemctl stop wazuh-manager

# c. Upgrading the Wazuh Indexer nodes
  # https://documentation.wazuh.com/4.14/upgrade-guide/upgrading-central-components.html#upgrading-the-wazuh-indexer-nodes

# c.1: Stop the Wazuh indexer service.
systemctl stop wazuh-indexer

# c.2: Backup /etc/wazuh-indexer/jvm.options
cp /etc/wazuh-indexer/jvm.options /etc/wazuh-indexer/jvm.options.old

# c.3: Upgrade the Wazuh indexer
apt-get install wazuh-indexer

# c.4: Manually reapply any custom settings to jvm.options
printf 'diff /etc/wazuh-indexer/jvm.options.old /etc/wazuh-indexer/jvm.options |less\n'
printf "Using the diff above, reapply any custom settings jvm.options (especially  -Xmsxxx and -Zmxxxx)\n"
a="N"; while [[ ${a,,} != "y" ]]; do printf "\r continue (y/N)? "; read a; done

# c.5: Restart the Wazuh indexer service.
systemctl daemon-reload; systemctl enable --now wazuh-indexer
systemctl start wazuh-indexer

# c.5a: Get the new Wazuh version for later reference in this script
WV=$(2>/dev/null apt list --installed |grep wazuh-indexer |sed -e 's/^[^ ]* //' -e 's/-.*//')

# d. Post-upgrade actions
  # https://documentation.wazuh.com/4.14/upgrade-guide/upgrading-central-components.html#post-upgrade-actions

# d.1: apply the security configuration files from backup
/usr/share/wazuh-indexer/bin/indexer-security-init.sh

# d.2: Check that the node is in the cluster
curl -k ${CRED} https://127.0.0.1:9200/_cat/nodes?v

# d.3: Re-enable shard allocation
curl -X PUT "https://127.0.0.1:9200/_cluster/settings" ${CRED} -k -H 'Content-Type: application/json' -d'
{
  "persistent": {
    "cluster.routing.allocation.enable": "all"
  }
}
'

# d.4: Check the status of the Wazuh indexer cluster again to see if the shard allocation has finished.
curl -k ${CRED} https://127.0.0.1:9200/_cat/nodes?v

# Note: plugins must be updated manually
# Run this command to list installed plugins that might need to be updated
/usr/share/wazuh-indexer/bin/opensearch-plugin list

# e. Upgradeing the Wazuh server
  # https://documentation.wazuh.com/4.14/upgrade-guide/upgrading-central-components.html#upgrading-the-wazuh-server

# e.1: Upgrade the Wazuh manager to the latest version:
apt-get install wazuh-manager

# e.2: Start and enable wazuh-manager
systemctl daemon-reload; systemctl enable --now wazuh-manager
systemctl start wazuh-manager

# f. Configuring CDB lists
  # https://documentation.wazuh.com/4.14/upgrade-guide/upgrading-central-components.html#configuring-cdb-lists

# f.1: Edit the /var/ossec/etc/ossec.conf file and update the <ruleset> block with the CDB lists highlighted below.
if [ $(grep -c 'malicious-ioc' /var/ossec/etc/ossec.conf) != 3 ]; 
then
  printf "You need to add the new malicious-ioc entries to /var/ossec/etc/ossec.conf\n"
  printf "as described here:\n\n"
  printf "https://documentation.wazuh.com/4.14/upgrade-guide/upgrading-central-components.html#configuring-cdb-lists\n"
  a="N"; while [[ ${a,,} != "y" ]]; do printf "\r continue (y/N)? "; read a; done
  # f.2: Restart the wazuh manager to apply configuration changes
  systemctl restart wazuh-manager
fi

# g. Configuring the vulnerability detection and indexer connector
  # https://documentation.wazuh.com/4.14/upgrade-guide/upgrading-central-components.html#configuring-the-vulnerability-detection-and-indexer-connector

# g.1: Update the configuration file
if [ $(grep -c 'vulnerability-detection' /var/ossec/etc/ossec.conf) != 2 ];
then
  printf "You need to add the new vulnerability-detection to /var/ossec/etc/ossec.conf\n"
  printf "as described here:\n\n"
  printf "https://documentation.wazuh.com/4.14/upgrade-guide/upgrading-central-components.html#configuring-the-vulnerability-detection-and-indexer-connector\n"
  a="N"; while [[ ${a,,} != "y" ]]; do printf "\r continue (y/N)? "; read a; done
  # 2. Restart the wazuh manager to apply configuration changes
fi

# g.2: Configure the indexer block
printf "Your vulnerability indexer hosts:\n"
grep -A15 '<indexer>' /var/ossec/etc/ossec.conf |grep '<host>'
printf "\nMake sure all of your wazuh nodes are included before proceeding\n"
a="N"; while [[ ${a,,} != "y" ]]; do printf "\r continue (y/N)? "; read a; done

# g.3: Store Wazuh indexer credentials
#
# (not included here...)

# g.4: Restart Wazuh manager to apply the configuration changes
systemctl restart wazuh-manager

# h. Configuring Filebeat
  # https://documentation.wazuh.com/4.14/upgrade-guide/upgrading-central-components.html#configuring-filebeat

# h.1: Download the Wazuh module for Filebeat:
curl -s https://packages.wazuh.com/4.x/filebeat/wazuh-filebeat-0.5.tar.gz | sudo tar -xvz -C /usr/share/filebeat/module

# h.2: Download the alerts template
curl -so /etc/filebeat/wazuh-template.json.new https://raw.githubusercontent.com/wazuh/wazuh/v4.14.4/extensions/elasticsearch/7.x/wazuh-template.json
# h.2a: Backup exisgint wazuh-template.json
cp /etc/filebeat/wazuh-template.json /etc/filebeat/wazuh-template.json.old
# h.2b: Activate new template.json, but with shards set to 1 instead of 3
sed 's/^\(.*shards.*\)3\(.*\)/\11\2/' /etc/filebeat/wazuh-template.json.new > /etc/filebeat/wazuh-template.json
chmod go+r /etc/filebeat/wazuh-template.json

# h.3: Backup /etc/filebeat/filebeat.yml 
cp /etc/filebeat/filebeat.yml  /etc/filebeat/filebeat.yml.old

# h.4: Upgrade Filebeat to the latest version
apt-get install filebeat

# h.5: Restore your custom Filebeat configuration settings:
cp /etc/filebeat/filebeat.yml.old  /etc/filebeat/filebeat.yml

# h.6: Restart Filebeat
systemctl daemon-reload
systemctl enable --now filebeat
systemctl start filebeat


# h.7: Upload the new Wazuh template and pipelines for Filebeat
filebeat setup --pipelines
filebeat setup --index-management -E output.logstash.enabled=false

# h.8: If upgrading from 4.8 or 4.9
#
printf "there is a separate command available online to update your index mapping if you're coming from 4.8 or 4.9\n"
printf "https://documentation.wazuh.com/4.14/upgrade-guide/upgrading-central-components.html#configuring-filebeat\n"
a="N"; while [[ ${a,,} != "y" ]]; do printf "\r continue (y/N)? "; read a; done

# i. Upgrading the Wazuh dashboard
  # https://documentation.wazuh.com/4.14/upgrade-guide/upgrading-central-components.html#upgrading-the-wazuh-dashboard

# i.1: Upgrade the Wazuh dashboard
apt-get install wazuh-dashboard

# i.2: Manually reapply changes to /etc/wazuh-dashboard/opensearch_dashboards.yml

# i.3: If you are upgrading from v4.7 or earlier...
if (grep 'uiSettings.overrides.defaultRoute: /app/wz-home' /etc/wazuh-dashboard/opensearch_dashboards.yml>/dev/null);
then
  printf "uiSettings.overrides.defaultRoute: OK"
else
  printf "update uiSettings.overrides.defaultRoute in /etc/wazuh-dashboard/opensearch_dashboards.yml\n"
  printf "uiSettings.overrides.defaultRoute: /app/wz-home\n"
  a="N"; while [[ ${a,,} != "y" ]]; do printf "\r continue (y/N)? "; read a; done
fi

# i.4: Restart the Wazuh dashboard

systemctl daemon-reload
systemctl enable --now wazuh-dashboard
systemctl start wazuh-dashboard

# i.5: Import the saved customizations exported while preparing the upgrade
# (not included here)

# Disable wazuh repos
cd /etc/apt/sources.list.d && mv wazuh.list wazuh.list.disabled && apt update
