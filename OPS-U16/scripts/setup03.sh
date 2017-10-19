#!/bin/bas

###############################################################################
## Init enviroiment source
dir_path=$(dirname $0)
source $dir_path/config.cfg
source $dir_path/lib/functions.sh
source $dir_path/admin-openrc

### Running function
### Checking and help syntax command
if [ $# -ne 1 ]; then
        echocolor  "Syntax command "
        echo "Syntax command on Controller: bash $0 controller"
        echo "Syntax command on Compute1: bash $0 compute1"
        echo "Syntax command on Compute2: bash $0 compute2"
        exit 1;
fi

if [ "$1" == "controller" ]; then
		bash $dir_path/install/install_keystone.sh
        bash $dir_path/install/install_glance.sh
        bash $dir_path/install/install_nova.sh $1
        #Stope here and wait for other nodes to be up
        while true; do
          read -p "Are you sure all compute nodes are sucessfully installed?" yn
          case $yn in
            [Yy]* ) su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova
                    sleep 5
                    su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova
                    nova-status upgrade check
                    bash $dir_path/install/install_neutron.sh $1;;
                    bash $dir_path/install/install_horizon.sh;;
            [Nn]* ) echo "Please answer yes or no.";;
            * ) echo "Please answer yes or no.";;
          esac
        done

elif [ "$1" == "compute1" ] || [ "$1" == "compute2" ]; then
	bash $dir_path/install/install_nova.sh $1
        #Stope here and wait for other nodes to be up
        while true; do
          read -p "Are you sure the discovery command is run in controller node?" yn
          case $yn in
            [Yy]* ) bash $dir_path/install/install_neutron.sh $1;;
            [Nn]* ) echo "Please answer yes or no.";;
            * ) echo "Please answer yes or no.";;
          esac
        done
	

else
	echocolor "Error syntax"
    echocolor "Syntax command"
    echo "Syntax command on Controller: bash $0 controller"
    echo "Syntax command on Compute1: bash $0 compute1"
    echo "Syntax command on Compute2: bash $0 compute2"
	exit 1;

fi
