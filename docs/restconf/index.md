# RESTCONF

!!! note "Coming later"
    This chapter is not written yet.

The switch serves a [RESTCONF](https://datatracker.ietf.org/doc/html/rfc8040)
API (RFC 8040) at `http://<switch-ip>/restconf`. It works on the same data
models and the same configuration as the [CLI](../cli/basics.md), so the
CLI chapters apply: a CLI path like

```text
interfaces interface lan3 ethernet switched-vlan config access-vlan
```

is the RESTCONF resource

```text
/restconf/data/openconfig-interfaces:interfaces/interface=lan3/openconfig-if-ethernet:ethernet/openconfig-vlan:switched-vlan/config/access-vlan
```

Differences from the CLI:

- RESTCONF changes are applied to the running configuration at once. There
  is no candidate and no separate `commit`.
- Like CLI commits, they are not saved. Save with `save` in the CLI, or with
  a `copy-config` from running to startup:

    ```sh
    curl -X POST -H 'Content-Type: application/yang-data+json' \
        -d '{"ietf-netconf:input":{"target":{"startup":[null]},"source":{"running":[null]}}}' \
        http://192.168.1.1/restconf/operations/ietf-netconf:copy-config
    ```

- There is no authentication (see [Limitations](../reference/limitations.md#security)).

Until this chapter is written, the
[clixon-switch-rs README](https://github.com/AlbrechtL/clixon-switch-rs#data-model)
has RESTCONF examples for DHCP, spanning tree and SNMP.
