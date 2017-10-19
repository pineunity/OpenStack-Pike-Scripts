#!/bin/bash
## Install NOVA

###############################################################################
## Init enviroiment source
dir_path=$(dirname $0)
source $dir_path/../config.cfg
source $dir_path/../lib/functions.sh

source admin-openrc

##  Init config path
nova_ctl=/etc/nova/nova.conf

if [ "$1" == "controller" ]; then
		
	echocolor "Create DB for NOVA"
	cat << EOF | mysql -uroot -p$MYSQL_PASS
CREATE DATABASE nova_api;
CREATE DATABASE nova;
CREATE DATABASE nova_cell0;
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_API_DBPASS';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_API_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';
FLUSH PRIVILEGES;
EOF
else
	echocolor "Database is just needed for controller node"
fi

if [ "$1" == "controller" ]; then

	echocolor "Create user, endpoint for NOVA"

	openstack user create --domain default  --password $NOVA_PASS nova
	openstack role add --project service --user nova admin
	openstack service create --name nova --description "OpenStack Compute" compute

	openstack endpoint create --region RegionOne \
		compute public http://$CTL_MGNT_IP:8774/v2.1
	openstack endpoint create --region RegionOne \
		compute internal http://$CTL_MGNT_IP:8774/v2.1
	openstack endpoint create --region RegionOne \
		   compute admin http://$CTL_MGNT_IP:8774/v2.1

        openstack user create --domain default --password $PLACEMENT_PASS placement
        openstack role add --project service --user placement admin
        openstack service create --name placement --description "Placement API" placement
        openstack endpoint create --region RegionOne placement public http://$CTL_MGNT_IP:8778
        openstack endpoint create --region RegionOne placement internal http://$CTL_MGNT_IP:8778
        openstack endpoint create --region RegionOne placement admin http://$CTL_MGNT_IP:8778
        
        
else
	echocolor "Endpoint is just needed for controller node"
fi



if [ "$1" == "controller" ]; then
	echocolor "Install NOVA in $CTL_MGNT_IP"
	sleep 3
	apt-get -y install nova-api nova-conductor nova-consoleauth \
	    	nova-novncproxy nova-scheduler nova-placement-api

elif [ "$1" == "compute1" ] || [ "$1" == "compute2" ] ; then
	echocolor "Install NOVA in $1"
	sleep 3
	 apt-get -y install nova-compute

else 
	 echocolor "Khong phai node COMPUE"
fi

######## Backup configurations for NOVA ##########"
test -f $nova_ctl.orig || cp $nova_ctl $nova_ctl.orig

echocolor "Config file nova.conf"
sleep 3

## [DEFAULT] section
ops_del $nova_ctl DEFAULT logdir
ops_del $nova_ctl DEFAULT verbose
#ops_edit $nova_ctl DEFAULT log-dir /var/log/nova
ops_edit $nova_ctl DEFAULT enabled_apis osapi_compute,metadata
ops_edit $nova_ctl DEFAULT rpc_backend rabbit
ops_edit $nova_ctl DEFAULT auth_strategy keystone
ops_edit $nova_ctl DEFAULT rootwrap_config /etc/nova/rootwrap.conf
ops_edit $nova_ctl DEFAULT use_neutron True
ops_edit $nova_ctl DEFAULT \
    firewall_driver nova.virt.firewall.NoopFirewallDriver
ops_edit $nova_ctl DEFAULT transport_url  rabbit://openstack:$RABBIT_PASS@$CTL_MGNT_IP

if [ "$1" == "controller" ]; then
	ops_edit $nova_ctl DEFAULT my_ip $CTL_MGNT_IP

elif [ "$1" == "compute1" ]; then
	ops_edit $nova_ctl DEFAULT my_ip $COM1_MGNT_IP

elif [ "$1" == "compute2" ]; then
	ops_edit $nova_ctl DEFAULT my_ip $COM2_MGNT_IP
else
	echocolor "Controller is not specified"
fi


if [ "$1" == "controller" ]; then
	## [api_database] section
	ops_edit $nova_ctl api_database \
	    connection mysql+pymysql://nova:$NOVA_API_DBPASS@$CTL_MGNT_IP/nova_api
	    
	## [database] section
	ops_edit $nova_ctl database \
	    connection mysql+pymysql://nova:$NOVA_DBPASS@$CTL_MGNT_IP/nova

	## [cinder] Section
	ops_edit $nova_ctl cinder os_region_name RegionOne

else
	echocolor "Khong phai node Controller"
fi

## [oslo_messaging_rabbit] section
# ops_edit $nova_ctl oslo_messaging_rabbit rabbit_host $CTL_MGNT_IP
# ops_edit $nova_ctl oslo_messaging_rabbit rabbit_userid openstack
# ops_edit $nova_ctl oslo_messaging_rabbit rabbit_password $RABBIT_PASS

## [keystone_authtoken] section
ops_edit $nova_ctl keystone_authtoken auth_uri http://$CTL_MGNT_IP:5000
ops_edit $nova_ctl keystone_authtoken auth_url http://$CTL_MGNT_IP:35357
ops_edit $nova_ctl keystone_authtoken memcached_servers $CTL_MGNT_IP:11211
ops_edit $nova_ctl keystone_authtoken auth_type password
ops_edit $nova_ctl keystone_authtoken project_domain_name default
ops_edit $nova_ctl keystone_authtoken user_domain_name default
ops_edit $nova_ctl keystone_authtoken project_name service
ops_edit $nova_ctl keystone_authtoken username nova
ops_edit $nova_ctl keystone_authtoken password $NOVA_PASS

## [vnc] section
if [ "$1" == "controller" ]; then
	ops_edit $nova_ctl vnc vncserver_listen \$my_ip
	ops_edit $nova_ctl vnc vncserver_proxyclient_address \$my_ip

elif [ "$1" == "compute1" ] || [ "$1" == "compute2" ] ; then
        #Configure vnc
	ops_edit $nova_ctl vnc enabled  true
	ops_edit $nova_ctl vnc vncserver_listen 0.0.0.0
	ops_edit $nova_ctl vnc vncserver_proxyclient_address \$my_ip
	ops_edit $nova_ctl vnc novncproxy_base_url http://$CTL_MGNT_IP:6080/vnc_auto.html

else
	echo "VNC is not required"
fi
	

## [glance] section
ops_edit $nova_ctl glance api_servers http://$CTL_MGNT_IP:9292

## [oslo_concurrency] section
ops_edit $nova_ctl oslo_concurrency lock_path /var/lib/nova/tmp

#Configure placement api
ops_del $nova_ctl placement os_region_name
ops_edit $nova_ctl placement os_region_name RegionOne
ops_edit $nova_ctl placement project_domain_name Default
ops_edit $nova_ctl placement project_name service
ops_edit $nova_ctl placement auth_type password
ops_edit $nova_ctl placement user_domain_name Default
ops_edit $nova_ctl placement auth_url = http://$CTL_MGNT_IP:35357/v3
ops_edit $nova_ctl placement username placement
ops_edit $nova_ctl placement password $PLACEMENT_PASS

## [neutron] section
ops_edit $nova_ctl neutron url http://$CTL_MGNT_IP:9696
ops_edit $nova_ctl neutron auth_url http://$CTL_MGNT_IP:35357
ops_edit $nova_ctl neutron auth_type password
ops_edit $nova_ctl neutron project_domain_name default
ops_edit $nova_ctl neutron user_domain_name default
ops_edit $nova_ctl neutron region_name RegionOne
ops_edit $nova_ctl neutron project_name service
ops_edit $nova_ctl neutron username neutron
ops_edit $nova_ctl neutron password $NEUTRON_PASS
ops_edit $nova_ctl neutron service_metadata_proxy True
ops_edit $nova_ctl neutron metadata_proxy_shared_secret $METADATA_SECRET

if [ "$1" == "controller" ]; then 
	echocolor "Remove Nova default db "
	sleep 5
	rm /var/lib/nova/nova.sqlite

	echocolor "Syncing Nova DB"
	sleep 5
	su -s /bin/sh -c "nova-manage api_db sync" nova

        #Register for cell 0
        su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
        #Register for cell 1
        su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova

        su -s /bin/sh -c "nova-manage db sync" nova
        nova-manage cell_v2 list_cells
	echocolor "Restarting NOVA on $1"
	sleep 3
	service nova-api restart
	service nova-cert restart
	service nova-consoleauth restart
	service nova-scheduler restart
	service nova-conductor restart
	service nova-novncproxy restart

	sleep 7
	echocolor "Restarting NOVA on $1"
	service nova-api restart
	service nova-cert restart
	service nova-consoleauth restart
	service nova-scheduler restart
	service nova-conductor restart
	service nova-novncproxy restart

	echocolor "Testing NOVA service"
	openstack compute service list

elif [ "$1" == "compute1" ] || [ "$1" == "compute2" ]; then
	echocolor "Restarting NOVA on $1"
	sleep 3
	service nova-compute restart


else
	echocolor "Khong phai NOVA - CTL"
fi
