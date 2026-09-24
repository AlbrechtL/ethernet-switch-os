# Maintenance

## Saving the configuration

Changes take effect with `commit`, but only `save` makes them survive a
reboot (see [CLI basics](cli/basics.md#candidate-running-startup)).

```text
switch> save
switch> show startup
```

`show startup` shows what the switch will load on the next boot.

!!! note "RESTCONF changes are not saved automatically either"
    Changes made over RESTCONF also only reach the running configuration.
    A `save` in the CLI saves them together with everything else.

## Backing up and restoring the configuration

To back up, copy the output of `show configuration cli` into a file.

To restore on the same or another switch, put `set ` in front of every
line, paste the lines into the CLI, then `commit` and `save`. If the
target switch has a different configuration, start with `delete all` in
the same session, so nothing from before is left over. The commit
then replaces everything at once.

!!! note "SNMP access lines need two edits"
    `show configuration cli` prints the SNMP access entries like this:

    ```text
    snmp vacm group readers access (null) usm auth-priv
    snmp vacm group readers access (null) usm auth-priv read-view all
    ```

    Before pasting:

    1. Replace `(null)` with `""` (the empty context), or the commit fails
       with `context (null) is not supported`.
    2. Remove the first, shorter line. Once the entry exists, the CLI no
       longer parses the second line (`'usm' is not a number`).

## Firmware update

See [Firmware update](getting-started/firmware-update.md). An update overwrites the running
system in place, so a power failure during the update leaves the switch
unusable until it is recovered over the serial console.

## Factory reset

There is no CLI command for a factory reset. Log in as `root` and delete
the saved configuration, then reboot:

```text
$ ssh root@<switch-ip>
# rm /var/lib/clixon/clixon-switch/startup_db
# reboot
```

The switch comes back with the [factory settings](getting-started/first-login.md#factory-settings),
at `192.168.1.1`.

## When the saved configuration cannot be loaded

If the saved configuration fails to apply at boot, for example after an
update that no longer accepts part of it, the switch starts with the factory
settings instead. It is then at `192.168.1.1`. The saved configuration is
still there: `show startup` shows it. Fix the problem in the CLI, commit
and save.

## Recovering access

| Situation | What to do |
|---|---|
| A committed but unsaved change cut you off | Power-cycle the switch. It boots with the saved configuration. |
| A saved configuration cut you off | Connect to a port that is still in the management VLAN, or use the serial console (115200 8N1, login `root`) and fix it with `clixon_cli`, or do a factory reset. |
| The switch does not boot | Boot the TFTP image and reinstall with the factory `.swu`, see [Recovery](getting-started/firmware-update.md#recovery). |
