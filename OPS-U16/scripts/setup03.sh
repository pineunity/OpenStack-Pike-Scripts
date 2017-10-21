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
          read -p "Are you sure all compute nodes were already in the last step?" yn
          case $yn in
            [Yy]* ) bash $dir_path/verification.sh $1
                    bash $dir_path/install/install_neutron.sh $1
                    bash $dir_path/install/install_horizon.sh
                    echocolor "Installed succesfully OpenStack in controller node"
                    exit;;
            [Nn]* ) echo "Please firstly run the last step in all compute nodes.";;
            * ) echo "Please answer yes or no.";;
          esac
        done

elif [ "$1" == "compute1" ] || [ "$1" == "compute2" ]; then
	bash $dir_path/install/install_nova.sh $1
        #Stope here and wait for other nodes to be up
        while true; do
          read -p "you already ran verification.sh in controller node, didnt you?" yn
          case $yn in
            [Yy]* ) bash $dir_path/install/install_neutron.sh $1
                    exit;;
            [Nn]* ) echo "Please firstly run verification.sh in controller node.";;
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
