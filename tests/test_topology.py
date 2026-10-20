import ipaddress
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).parents[1]

def validate_topology(topology):
    networks = {"hub": topology["hub"], **topology["spokes"]}
    address_spaces = {}
    for name, settings in networks.items():
        vnet = ipaddress.ip_network(settings["address_space"])
        if not vnet.is_private:
            raise ValueError("VNet address spaces must be private")
        address_spaces[name] = vnet
        subnets = [ipaddress.ip_network(value) for key, value in settings.items() if key.endswith("_subnet")]
        if any(not subnet.subnet_of(vnet) for subnet in subnets):
            raise ValueError("Subnet outside parent VNet")
        for i, subnet in enumerate(subnets):
            if any(subnet.overlaps(other) for other in subnets[i+1:]):
                raise ValueError("Overlapping subnets")
    items = list(address_spaces.values())
    for i, network in enumerate(items):
        if any(network.overlaps(other) for other in items[i+1:]):
            raise ValueError("Overlapping VNets")
    hub = topology["hub"]
    if ipaddress.ip_network(hub["firewall_subnet"]).prefixlen > 26 or ipaddress.ip_network(hub["bastion_subnet"]).prefixlen > 26:
        raise ValueError("Firewall and Bastion require at least /26")
    rule = topology["interspoke_rule"]
    if rule["source"] == rule["destination"] or any(rule[key] not in topology["spokes"] for key in ("source", "destination")):
        raise ValueError("Invalid interspoke relationship")
    if not 1 <= rule["tcp_port"] <= 65535:
        raise ValueError("Use one explicit TCP port")
    if any('*' in fqdn or '/' in fqdn for fqdn in topology["allowed_egress_fqdns"]):
        raise ValueError("Egress must name explicit domains")

class NetworkDesignTests(unittest.TestCase):
    def setUp(self):
        self.topology = json.loads((ROOT/'config/topology.json').read_text())

    def test_real_topology(self):
        validate_topology(self.topology)

    def test_overlapping_vnets_rejected(self):
        self.topology['spokes']['app']['address_space'] = '10.10.0.0/16'
        self.topology['spokes']['app']['workload_subnet'] = '10.10.3.0/24'
        self.topology['spokes']['app']['private_subnet'] = '10.10.4.0/24'
        with self.assertRaisesRegex(ValueError, 'Overlapping VNets'):
            validate_topology(self.topology)

    def test_overlapping_subnets_rejected(self):
        self.topology['spokes']['app']['private_subnet'] = '10.20.1.0/24'
        with self.assertRaisesRegex(ValueError, 'Overlapping subnets'):
            validate_topology(self.topology)

    def test_subnet_outside_vnet_rejected(self):
        self.topology['spokes']['data']['private_subnet'] = '10.40.1.0/24'
        with self.assertRaisesRegex(ValueError, 'outside parent'):
            validate_topology(self.topology)

    def test_wildcard_egress_rejected(self):
        self.topology['allowed_egress_fqdns'] = ['*']
        with self.assertRaisesRegex(ValueError, 'explicit domains'):
            validate_topology(self.topology)

    def test_examples_match_environments(self):
        for environment in ('dev','prod'):
            config = json.loads((ROOT/f'infra/environments/{environment}.tfvars.json.example').read_text())
            self.assertEqual(config['environment'], environment)
            self.assertFalse(config['test_vms_enabled'])
            self.assertIsNone(config['ssh_public_key'])
            self.assertEqual(config['resource_group_name'], f'rg-hubspoke-{environment}')

if __name__ == '__main__':
    unittest.main()
