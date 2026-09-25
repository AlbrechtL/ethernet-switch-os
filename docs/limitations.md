# Limitations

Ethernet Switch OS is a proof of concept. This page lists what it does not
do yet, so you can decide whether it fits your use.

## Security

!!! danger
    There is **no access control** of any kind. Do not connect the
    management address to an untrusted network.

- The users `root` and `cli` have **no password**, and passwords cannot be
  set through the configuration.
- RESTCONF and the web page have no authentication and no TLS: anyone who
  reaches port 80 can read and change the configuration.
- The firmware update page on port 8080 has no authentication either.
- There are no user accounts, roles or read-only access.

## Known problems in the current firmware

These are bugs, found while testing this guide on the emulated switch.
The guide shows the commands as they are meant to work.

**The CLI rejects most numbers on the switch.** Any value whose allowed
range starts above 0 is refused, whatever the value:

```text
switch> set vlans vlan 20 config vlan-id 20
CLI syntax error: "set vlans vlan 20 config vlan-id 20": Number 20 out of range: 1 - 4094
```

This affects all VLAN ids (`vlans`, `access-vlan`, `native-vlan`,
`trunk-vlans`, port-based group ids, MSTI ids), and the spanning tree
timers, `hold-count`, `max-hop`, port `cost` and `port-priority`. Values
whose range starts at 0 work, for example `prefix-length` and
`bridge-priority`. The same commands work in the x86 development container,
so the cause is in the CLI's number parsing on the switch's big-endian MIPS
processor.

Until it is fixed, set these values over RESTCONF. For example, to declare
VLAN 20 and put `lan3` into it:

```sh
curl -X PATCH -H 'Content-Type: application/yang-data+json' \
    -d '{"clixon-switch:vlans":{"vlan":[{"vlan-id":20,"config":{"vlan-id":20,"name":"office"}}]}}' \
    http://192.168.1.1/restconf/data/clixon-switch:vlans
curl -X PATCH -H 'Content-Type: application/yang-data+json' \
    -d '{"openconfig-vlan:config":{"interface-mode":"ACCESS","access-vlan":20}}' \
    http://192.168.1.1/restconf/data/openconfig-interfaces:interfaces/interface=lan3/openconfig-if-ethernet:ethernet/openconfig-vlan:switched-vlan/config
```

The change is applied at once; `save` in the CLI makes it permanent.
Routed VLAN interfaces can refer to their VLAN by **name** in the CLI
(`routed-vlan config vlan office`), which is not affected.

**`snmp` is missing from the CLI.** `set snmp ...` fails with
`Unknown command`. Configure [SNMP](snmp/index.md) over RESTCONF; the
[clixon-switch-rs README](https://github.com/AlbrechtL/clixon-switch-rs#snmp)
has a complete example.

**`show compare` fails** with
`compare_dbs: ... Expected arguments: <db1> <db2> <format>`.

## Firmware update

- **One firmware slot, no fallback.** An update overwrites the running
  system in place. A power failure or reset while it is written leaves the
  switch unable to start. Recovery needs the serial console and TFTP, and
  erases the configuration. See [Firmware update](getting-started/firmware-update.md).
- No automatic rollback if the new firmware does not work.
- Update files are not signed.

## IP and management

- **No static default gateway, static routes or static DNS servers.** With
  static addresses, the switch can only be reached from its own subnets.
  Only the DHCP client sets a default route and DNS.
- No IPv6.
- The host name cannot be configured.
- No time synchronisation (NTP), no time zone. The clock starts at the
  same fixed time (2018-03-09 12:34:56 UTC) on every boot, so time stamps
  in logs are not real times.
- No syslog forwarding.
- No routing between VLANs. Routed VLAN interfaces are only for reaching
  the switch itself.
- At most one DHCP client.

## Ports

- No fixed speed or duplex; every port auto-negotiates.
- No MTU or jumbo frame setting.
- No flow control.
- No link aggregation (LAG, LACP).
- No port mirroring, storm control, rate limiting or port security.
- Albrecht RTL8382MI test switch: ports 17 to 20 (RTL8214FC combo ports)
  are driven as copper ports only; their SFP side is not supported.

## Layer 2

- No IGMP/MLD snooping.
- No LLDP.
- Spanning tree: no Rapid PVST, loop guard, bridge assurance, EtherChannel
  guard or automatic recovery after BPDU guard.

## SNMP

- SNMPv3 only; no SNMPv1/v2c or communities.
- Read-only.
- No traps or informs.
- SHA and AES only; no MD5 or DES.
- No MIB for MSTP instances.

## CLI

- No factory-reset command (see [Maintenance](getting-started/maintenance.md#factory-reset)).
- No reboot command; use the root shell.
- Error messages include internal details (timestamps, function names) in
  front of the actual reason.

## Cyber Resilience Act (CRA) gap analysis

The EU [Cyber Resilience Act](https://digital-strategy.ec.europa.eu/en/policies/cyber-resilience-act)
(Regulation (EU) 2024/2847) sets security requirements for products with
digital elements sold in the EU. Its reporting obligations apply from
11 September 2026, all other requirements from 11 December 2027.

Ethernet Switch OS is a non-commercial open-source project and is itself
outside the CRA's scope. Whoever ships it on a switch sold in the EU is the
manufacturer and must meet the CRA. Switches are *important products,
class I* (Annex III), so conformity must be shown with harmonised standards
or through a notified body.

The firmware is **not CRA compliant**. The points below are the ones
missing; requirements already met are not listed.

!!! warning
    This list may be incomplete and may contain mistakes. It is not legal
    advice and does not replace a proper CRA assessment.

### Product security (Annex I, Part I)

| # | Requirement | Gap |
|---|---|---|
| 1 | Secure by default configuration (2b) | `root` and `cli` log in over SSH and the serial console with an empty password. No forced password change on first start. |
| 2 | Protection from unauthorised access, authentication and access management (2d) | RESTCONF, the web page and the firmware update page (port 8080) have no authentication. No user accounts, roles or read-only access. |
| 3 | Confidentiality of data in transit (2e) | RESTCONF, the web page and firmware upload use plain HTTP, no TLS. |
| 4 | Integrity of data and firmware (2f) | Update files are not signed and not checked before installation. No verified or secure boot. |
| 5 | Minimised attack surface (2j) | SSH, RESTCONF with the web page, and the firmware update page always run on every management address. The configuration cannot turn them off or limit them to a management VLAN. |
| 6 | Resilience, availability of essential functions (2h, 2i) | One firmware slot without fallback: an interrupted update leaves the switch unable to start. No automatic rollback. |
| 7 | Security-relevant logging and monitoring (2l) | No record of logins or configuration changes, no syslog forwarding, no real time (no NTP, fixed clock at boot), so log entries cannot be dated. |
| 8 | Secure deletion of data and settings (2m) | No factory-reset command that removes the configuration and credentials. |
| 9 | Security updates, automatic where possible, with user notification and opt-out (2c) | Updates are manual only. The switch does not check for or notify about new firmware. Any older version can be installed, so a downgrade to a vulnerable version is not prevented. |
| 10 | No known exploitable vulnerabilities at release (2a) | No release process that checks the image for known CVEs before shipping. |

### Vulnerability handling (Annex I, Part II)

| # | Requirement | Gap |
|---|---|---|
| 11 | Software bill of materials (1) | Yocto writes SPDX files during the build, but they are not published with the images and not maintained per release. |
| 12 | Address and remediate vulnerabilities without delay (2) | No CVE monitoring of the included components (Linux kernel, busybox, dropbear, clixon, SWUpdate, ...). No `cve-check` or equivalent in CI. |
| 13 | Regular security testing (3) | CI builds and boots images, but runs no security tests (port scans, fuzzing of RESTCONF/CLI, static analysis). |
| 14 | Public disclosure of fixed vulnerabilities (4) | No security advisories, no changelog of security fixes. |
| 15 | Coordinated vulnerability disclosure policy (5) | No `SECURITY.md` or other published policy. |
| 16 | Contact address for reporting vulnerabilities (6) | No security contact. |
| 17 | Secure distribution of updates (7) | Images are GitHub Actions build artifacts, not signed releases. |
| 18 | Security updates free of charge, separate from feature updates (8) | No releases and no versioning policy: CI builds the tip of every layer branch, so security fixes cannot be delivered on their own. |

### Manufacturer obligations (Articles 13, 14, 31, 32 and Annexes II, VII)

| # | Requirement | Gap |
|---|---|---|
| 19 | Support period of at least five years, stated at purchase (Art. 13(8), 13(19)) | No support period defined. The project states it is a proof of concept. |
| 20 | Cybersecurity risk assessment (Art. 13(2), 13(3)) | None documented. |
| 21 | Reporting of actively exploited vulnerabilities and severe incidents to ENISA / the CSIRT within 24 h, 72 h and 14 days (Art. 14), **applies since 11 September 2026** | No process and no responsible party. |
| 22 | Due diligence for third-party components (Art. 13(5)) | No review or tracking of upstream component security. |
| 23 | User information and instructions (Annex II) | Missing: support end date, security contact, secure setup and hardening guide, how to receive security updates, how to securely decommission the switch. |
| 24 | Technical documentation (Annex VII) | Missing: security architecture description, risk assessment, SBOM, list of applied standards, test reports. |
| 25 | Conformity assessment, EU declaration of conformity and CE marking (Art. 28, 30, 32) | Not done. As a class I important product this needs harmonised standards (Module A) or a notified body. |
