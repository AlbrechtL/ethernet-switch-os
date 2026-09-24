# System

## Contact and location

Two free-text lines that describe the switch. SNMP reports them as
`sysContact` and `sysLocation`:

```text
switch> set system config contact "Network team, noc@example.com"
switch> set system config location "Rack 3, room 101"
switch> commit
switch> save
```

Each is one line of up to 255 characters. Line breaks and other control
characters are rejected.

## System status

```text
switch> show state text system
clixon-switch:system {
   config {
      contact "Network team, noc@example.com";
      location "Rack 3, room 101";
   }
   state {
      contact "Network team, noc@example.com";
      location "Rack 3, room 101";
      hostname zyxel-gs1900-8-a1;
      os-name "Ethernet Switch OS";
      os-version "6.0.3 (wrynose)";
      kernel-release 6.18.39-yocto-tiny;
      current-datetime 2018-03-09T12:36:02Z;
      uptime 67;
      load-average-1 0.22;
      load-average-5 0.07;
      load-average-15 0.02;
      memory-total 122528;
      memory-available 52168;
   }
}
```

| Field | Meaning |
|---|---|
| `hostname` | The switch's host name. Fixed by the firmware; it cannot be configured yet. |
| `os-name`, `os-version` | The firmware and its version. |
| `kernel-release` | Linux kernel version. |
| `current-datetime` | The clock, in UTC. The switch has no battery-backed clock and no time synchronisation, so it starts at the same fixed time on every boot (2018-03-09 12:34:56 UTC in the current firmware). |
| `uptime` | Seconds since boot. |
| `load-average-*` | CPU load over 1, 5 and 15 minutes. |
| `memory-total`, `memory-available` | RAM in kilobytes. |

The [status page](../getting-started/first-login.md#web-pages) shows the
same information.

`show version` shows the version of the configuration software (clixon),
not the firmware version.
