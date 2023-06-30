# terraform-azure-pan-ha
Deploys an HA pair of Palo Alto firewalls in Azure. In regions that support it, Availability Zones are used. Otherwise the VMs are put into an Availability set.

Default username: panadmin

Password is specified.

See example/main.tf for an example.
