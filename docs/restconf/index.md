# RESTCONF

!!! note "Coming later"
    This chapter is not written yet.

The switch serves a [RESTCONF](https://datatracker.ietf.org/doc/html/rfc8040)
API (RFC 8040) at `https://<switch-ip>/restconf`. It works on the same data
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
    curl -k -u ops -X POST -H 'Content-Type: application/yang-data+json' \
        -d '{"ietf-netconf:input":{"target":{"startup":[null]},"source":{"running":[null]}}}' \
        https://192.168.1.1/restconf/operations/ietf-netconf:copy-config
    ```

- Every request needs the admin login, as HTTP basic auth (`curl -u ops`
  asks for the password of the admin `ops`; the examples use that name).
  `-k` accepts the switch's self-signed certificate.
- Two operations of the module `clixon-switch` manage the switch itself:
  `set-password` (`username`, `current-password`, `new-password`) and
  `factory-reset`.
  During the [first-login setup](../getting-started.md#first-login-create-the-admin-account)
  `set-password` works without a login: it creates the admin account with
  `username` and `new-password`.

    ```sh
    curl -k -X POST -H 'Content-Type: application/yang-data+json' \
        -d '{"clixon-switch:input":{"username":"ops","new-password":"my new password"}}' \
        https://192.168.1.1/restconf/operations/clixon-switch:set-password
    ```

    Afterwards it only changes the password, and needs `current-password`
    instead of `username`: the username stays until a factory reset.

Until this chapter is written, the
[clixon-switch-rs README](https://github.com/AlbrechtL/clixon-switch-rs#data-model)
has RESTCONF examples for DHCP, spanning tree and SNMP.
