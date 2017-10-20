
#!/bin/bash


###############################################################################
## Init enviroiment source
dir_path=$(dirname $0)
source $dir_path/config.cfg
source $dir_path/lib/functions.sh

source $dir_path/admin-openrc
#############################################
	
echocolor "Nova cell verification in controller node"
sleep 3

if [ "$1" == "controller" ]; then
          
  su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova
          
  sleep 5
          
  su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova
          
  nova-status upgrade check

fi


