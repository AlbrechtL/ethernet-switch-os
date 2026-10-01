# Comparison with other switch firmware

This page compares Ethernet Switch OS, feature by feature, with two
commercial firmwares for 8-port managed switches:

- **Zyxel GS1900-8 stock firmware.** The firmware the
  [Zyxel GS1900-8](installation/zyxel-gs1900-8.md) is sold with, and which
  Ethernet Switch OS replaces. This column shows what you give up and what
  you gain when you install it.
- **Teltonika TSW202 with TSWOS.** An industrial switch with an
  OpenWrt-based firmware. It is a point of reference for what a
  Linux-based switch firmware offers. Ethernet Switch OS does **not** run on
  the TSW202.

Both commercial firmwares have far more features. Ethernet Switch OS is a
proof of concept, but it is open source, and all of its configuration is
described by YANG models and reachable through a CLI and RESTCONF.

!!! note "Where the columns come from"
    The two commercial columns are taken from the vendors' own documents,
    for the latest firmware at the time of writing. Neither firmware was
    tested for this comparison. "Not described" means the documents do not
    mention the feature; it may still exist.

    **Zyxel GS1900-8**, firmware V2.90(AAHH.2), from the
    [download page for the GS1900-8](https://www.zyxel.com/us/en-us/support/download?model=gs1900-8):

    - User's Guide, V2.90 Edition 2: the features and their settings.
    - Datasheet, version 22: standards, MAC table and frame size.
    - Release note of V2.90(AAHH.2)C0: the limits.

    **Teltonika TSW202**, firmware TSW2_R_00.01.10.2:

    - Datasheet v1.04 (2026-05-06).
    - The [TSW202 manual](https://wiki.teltonika-networks.com/view/TSW202_Manual)
      in the Teltonika Networks wiki.

    The Ethernet Switch OS column is what the feature pages and
    [Limitations](limitations.md) describe.

## Hardware

| | Zyxel GS1900-8 | Teltonika TSW202 | Ethernet Switch OS |
|---|---|---|---|
| Ports | 8 × Gigabit Ethernet | 8 × Gigabit Ethernet with PoE+ (240 W in total), 2 × SFP | Runs on the GS1900-8 and the other [supported boards](index.md#supported-hardware), not on the TSW202 |
| RAM, flash | 128 MB, 16 MB | 128 MB, 16 MB | |
| Build | Desktop, fanless, 0 °C to 50 °C | DIN rail, 7 V to 57 V DC, −40 °C to 75 °C | |
| MAC address table | 8K | 8K | The GS1900-8's switch chip |

## Management

| Feature | Zyxel GS1900-8 | Teltonika TSW202 | Ethernet Switch OS |
|---|---|---|---|
| Web UI | Yes. Every setting, with a setup wizard. | Yes. Every setting. | Yes. Status and the everyday settings. See [Using the web UI](getting-started/web-ui.md). |
| CLI | Telnet and SSH access can be turned on, but the User's Guide does not name the CLI as a way to manage the switch and does not describe its commands. | SSH into the Linux shell, and a CLI page in the web UI. | Yes, over SSH. Every setting. See [Using the CLI](getting-started/cli.md). |
| Telnet | Yes, can be turned off. | Not described. | No. |
| API | No. | Teltonika Networks Web API (beta). | RESTCONF. Every setting. See [Using RESTCONF](getting-started/restconf.md). |
| Data model | Zyxel's own. | Teltonika's own. | [YANG](reference/yang-models.md), mostly OpenConfig. |
| HTTPS | Yes, and plain HTTP. A certificate of your own can be imported. | Yes, and plain HTTP, with redirect to HTTPS. Certificate manager. | Yes, no plain HTTP. Self-signed certificate only. |
| SNMP | SNMPv1, v2c and v3. Read and write. Traps. | SNMPv1, v2c and v3. Read and write. SNMPv3 with MD5 or SHA, DES or AES. | SNMPv3 only. Read-only. No traps. SHA and AES only. See [SNMP](features/snmp.md). |
| RMON | Groups 1, 2, 3 and 9. | Not described. | No. |
| User accounts | Several, with the levels admin and user. | Several, in the groups root, admin and user (read-only). | One admin account. |
| Factory login | `admin` / `1234`. Must be changed at the first login. | User `admin`. Configurable password policy. | None. The admin account is created at the [first login](getting-started/index.md#first-login-create-the-admin-account). |
| Login through RADIUS or TACACS+ | Yes. | Yes. | No. |
| Block addresses after failed logins | Not described. | Yes. | No. |
| Limit who may manage the switch | Yes, remote access control. | SSH, HTTP and HTTPS can each be turned off. | No. |
| Vendor cloud or discovery tool | Zyxel ZON utility. | Teltonika RMS. | No. |
| Syslog | Local log and remote servers. | Local log in RAM or flash, remote server over UDP or TCP. | No forwarding. |
| Time | SNTP, time zone, daylight saving time. | NTP, time zone. | No. The clock starts at a fixed time on every boot. |
| Host name | Configurable. | Configurable. | Fixed. |
| Contact and location | Yes. | Not described. | Yes. See [System information](features/system.md). |
| Ping, traceroute and cable test in the web UI | Yes. | Yes. | No. |
| Reboot | From the web UI. | From the web UI. | From the root shell only. |

## IP

| Feature | Zyxel GS1900-8 | Teltonika TSW202 | Ethernet Switch OS |
|---|---|---|---|
| Static IPv4 address | Yes. | Yes. | Yes. See [Management IP address](features/management-ip.md). |
| DHCP client | Yes. | Yes. | Yes. |
| Default gateway and DNS servers with a static address | Yes. | Yes. | No. Only the DHCP client sets them. |
| IPv6 | Yes: static address, auto-configuration, DHCPv6 client. | Yes: static address, DHCPv6 client. | No. |
| Management in a VLAN | One management VLAN. | Interfaces in one or more VLANs. | Addresses on one or more VLANs. |
| Routing | No. | Static IPv4 and IPv6 routes, BGP, OSPFv2, RIP, EIGRP. | No. |
| DHCP server | No. | Yes. | No. |

## Ports

| Feature | Zyxel GS1900-8 | Teltonika TSW202 | Ethernet Switch OS |
|---|---|---|---|
| Enable and disable a port | Yes. | Yes. | Yes. See [Ports](features/ports.md). |
| Port description | Yes. | Not described. | Yes. |
| Port counters | Yes. | Yes. | Yes. |
| Fixed speed and duplex | Yes. | Yes. | No. Every port auto-negotiates. |
| Flow control (IEEE 802.3x) | Yes. | Listed in the datasheet. | No. |
| Energy Efficient Ethernet (IEEE 802.3az) | Yes. | Yes. | No. |
| Jumbo frames | Yes, up to 9K. | Yes, up to 10000 bytes. | No setting. |
| Link aggregation | Static and LACP. | LACP, up to 8 ports per group. | No. |
| Port mirroring | Yes. | Yes. | No. |
| Rate limiting, incoming and outgoing | Yes. | Yes. | No. |
| Storm control | Yes. | Yes. | No. |
| Port isolation | Yes. | Yes. | No. [Port-based VLANs](features/vlans.md#port-based-vlans) split the switch into separate groups. |
| Port security (allowed MAC addresses) | Yes, a limit of learned addresses. | Yes, up to 30 allowed addresses per port. | No. |
| PoE management | No (no PoE on the GS1900-8). | Yes, with a restart of PoE when a ping fails. | No. |

## VLANs

| Feature | Zyxel GS1900-8 | Teltonika TSW202 | Ethernet Switch OS |
|---|---|---|---|
| IEEE 802.1Q VLANs | Yes. Ids 1 to 4094, at most 1000 static VLANs. | Yes. Ids 1 to 4094. | Yes. Ids 1 to 4094. See [VLANs](features/vlans.md). |
| How a port is put into VLANs | A port VLAN id (PVID), and tagged or untagged membership per VLAN. | Tagged or untagged membership per VLAN. | Access ports, and trunk ports with a native VLAN and trunk VLANs. |
| Port-based VLANs without tags | Yes. | Through untagged membership only. | Yes, as a mode of its own. |
| Suspend a VLAN | No. | Not described. | Yes. |
| Guest VLAN | Yes, one. | Not described. | No. |
| Voice VLAN | Yes. | Not described. | No. |

## Layer 2

| Feature | Zyxel GS1900-8 | Teltonika TSW202 | Ethernet Switch OS |
|---|---|---|---|
| STP, RSTP | Yes. | Yes. | Yes. See [Spanning tree](features/spanning-tree.md). |
| MSTP | Yes, 16 instances. | No. | Yes. |
| Edge ports | Yes. | Yes. | Yes. |
| BPDU filter | Yes. | Not described. | Yes. |
| BPDU guard, root guard | Not described. | Not described. | Yes. |
| Loop detection, independent of spanning tree | Yes, loop guard. | Yes, with automatic recovery. | No. |
| Media Redundancy Protocol (MRP) | No. | Yes, client and manager. | No. |
| IGMP snooping | Yes, v1, v2 and v3. | Yes, with querier. | No. |
| MLD snooping | No. | Not described. | No. |
| LLDP | Yes, and LLDP-MED. | Yes. | No. |
| Static MAC addresses | Yes, 64 entries. | Not described. | No. |
| MAC address ageing time | Configurable. | Not described. | No setting. |

## Quality of service and security

| Feature | Zyxel GS1900-8 | Teltonika TSW202 | Ethernet Switch OS |
|---|---|---|---|
| Priority queues (IEEE 802.1p) | Strict priority and WRR. | Strict priority, WRR and WFQ. | No. |
| CoS, DSCP and IP precedence mapping | Yes, with trust mode. | Yes. | No. |
| Port authentication (IEEE 802.1X) with RADIUS | Yes. | Yes. | No. |
| DoS prevention | Yes. | Not described. | No. |

## Industrial protocols

| Feature | Zyxel GS1900-8 | Teltonika TSW202 | Ethernet Switch OS |
|---|---|---|---|
| PROFINET | No. | Class B, with a separate order code. | No. |
| EtherNet/IP, Modbus, OPC UA server | No. | Yes. | No. |
| Precision Time Protocol (PTP) | No. | Yes. | No. |

## Firmware and configuration

| Feature | Zyxel GS1900-8 | Teltonika TSW202 | Ethernet Switch OS |
|---|---|---|---|
| Firmware update | From the web UI, or from a TFTP server. | From the web UI, from Teltonika's update server, or for many switches at once through RMS. | From a web page, with `curl` or with `swupdate`. See [Firmware update](installation/update.md#firmware-update). |
| Configuration kept on update | Yes. | Yes, can be turned off. | Yes. |
| Two firmware images | Yes, an active and a backup image. | Not described. | No on the GS1900-8: the two slots are merged into one, see [Non-A/B updates](installation/update.md#non-ab-updates). Yes on the Raspberry Pi and QEMU x86-64 boards. |
| Configuration backup and restore | As a file, to your computer or a TFTP server. A second, backup configuration is kept on the switch. | As a file, optionally encrypted, only onto a switch with the same product code. Configuration profiles. | As CLI text, see [Backing up and restoring the configuration](installation/update.md#backing-up-and-restoring-the-configuration). |
| Factory reset | Reset button, web UI. | Reset button, web UI. Can also reset to a default configuration of your own. | Reset button, web UI, CLI. See [Factory reset](installation/update.md#factory-reset). |
| Security fixes | Released by Zyxel as firmware updates. | Released by Teltonika as firmware updates. | No process. See [Limitations](limitations.md#cyber-resilience-act-cra-gap-analysis). |
| Own software on the switch | No. | Package manager, and an SDK with a build environment. | Yes, the whole firmware is built from source. See [Building the firmware](development/building.md). |
