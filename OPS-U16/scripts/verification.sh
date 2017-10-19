
#!/bin/bash


###############################################################################
## Init enviroiment source
dir_path=$(dirname $0)
source $dir_path/config.cfg
source $dir_path/lib/functions.sh


#############################################
function nova_verification {
	echocolor "Nova cell verification in controller node"
	sleep 3
	if [ "$1" == "controller" ]; then
          su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova
          sleep 5
          su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova
          nova-status upgrade check
}

### Running function
### Checking and help syntax command
if [ $# -ne 1 ]
    then
        echocolor  "Syntax command "
        echo "Syntax command on Controller: bash $0 controller"
        echo "Syntax command on Compute1: bash $0 compute1"
        echo "Syntax command on Compute2: bash $0 compute2"
        exit 1;
fi

if [ "$1" == "controller" ]; then 
	nova_verification
fi
