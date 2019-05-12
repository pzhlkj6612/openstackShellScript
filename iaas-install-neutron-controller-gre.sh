#!/bin/bash
source /etc/xiandian/openrc.sh
source /etc/keystone/admin-openrc.sh

crudini --set /etc/neutron/neutron.conf DEFAULT service_plugins router,lbaas,firewall
crudini --set /etc/neutron/neutron_lbaas.conf service_providers service_provider LOADBALANCER:Haproxy:neutron_lbaas.services.loadbalancer.drivers.haproxy.plugin_driver.HaproxyOnHostPluginDriver:default
crudini --set /etc/neutron/lbaas_agent.ini DEFAULT device_driver neutron_lbaas.services.loadbalancer.drivers.haproxy.namespace_driver.HaproxyNSDriver
crudini --set /etc/neutron/lbaas_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
crudini --set /etc/neutron/lbaas_agent.ini haproxy user_group haproxy

crudini --set /etc/neutron/neutron.conf service_providers FIREWALL:Iptables:neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver:default
crudini --set /etc/neutron/fwaas_driver.ini fwaas driver neutron_fwaas.services.firewall.drivers.linux.iptables_fwaas.IptablesFwaasDriver
crudini --set /etc/neutron/fwaas_driver.ini fwaas enabled True

crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types  gre
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre tunnel_id_ranges  1:1000

ovs-vsctl add-br br-ex
ovs-vsctl add-port br-ex $INTERFACE_NAME 
cat > /etc/sysconfig/network-scripts/ifcfg-$INTERFACE_NAME <<EOF
DEVICE=$INTERFACE_NAME
TYPE=Ethernet
BOOTPROTO=none
ONBOOT=yes
EOF
systemctl restart network
crudini --set  /etc/neutron/l3_agent.ini DEFAULT  external_network_bridge  br-ex
crudini --set  /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs bridge_mappings  physnet1:br-ex
crudini --set  /etc/neutron/plugins/ml2/openvswitch_agent.ini agent tunnel_types  gre
crudini --set  /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs local_ip $HOST_IP
crudini --set  /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs  enable_tunneling True
crudini --set  /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs bridge_mappings external:br-ex

neutron-db-manage --service lbaas upgrade head
neutron-db-manage --subproject neutron-fwaas upgrade head

systemctl restart neutron-server 
systemctl restart neutron-l3-agent neutron-openvswitch-agent 

systemctl restart neutron-lbaas-agent
systemctl enable neutron-lbaas-agent
