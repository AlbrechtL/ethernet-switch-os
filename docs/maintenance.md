# Firmware update and maintenance

Keeping a switch running: saving and backing up its configuration,
installing new firmware, and getting back in when something went wrong.


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

Firmware updates use [SWUpdate](https://sbabic.github.io/swupdate/). An
update is a single `.swu` file. There are three ways to install it:

- [in the browser](#update-in-the-browser), on the update page,
- [with `curl`](#update-with-curl) from your computer, through the same page,
- [with `swupdate`](#update-in-the-switchs-shell) in a root shell on the switch.

Some switches have [A/B updates](#ab-updates), which survive an
interrupted update; the others have [non-A/B updates](#non-ab-updates):

| Hardware | A/B | Rollback |
|---|---|---|
| Zyxel GS1900-8 | No, one slot | None |
| Albrecht RTL8382MI test switch | No, one slot | None |
| Zyxel GS1900-8 emulated in QEMU | No, one slot | None |
| Raspberry Pi switch | Yes | After 3 starts that were not confirmed. There is no watchdog yet: a firmware that hangs without crashing needs a power cycle before it is counted. |
| QEMU x86-64 switch | Yes | On the next start after one that was not confirmed. |

!!! tip "Back up the configuration first"
    A backup of the configuration is highly recommended before every
    update. See [Backing up and restoring the configuration](#backing-up-and-restoring-the-configuration).

### Update types

There are two types of update. Which one a switch uses depends on its
hardware, see the table above.

#### A/B updates

A switch with **A/B** updates has two firmware slots, A and B. It runs from
one of them, and an update writes the other one. The running firmware is
not touched, so if the update is interrupted, the switch simply starts the
old firmware again.

The first start of the new firmware is a trial. When the switch is fully
up, it confirms the new firmware. If the new firmware never gets that far,
because it hangs, crashes or loses power, the switch goes back to the
previous firmware by itself. The configuration is shared by both slots and
is kept either way.

##### Which slot is written

In the [switch's shell](#update-in-the-switchs-shell), `swupdate` needs,
instead of `-e ethernet-switch-os,upgrade`, the slot that is **not** running:
`-e ethernet-switch-os,slot-a` or `-e ethernet-switch-os,slot-b`.
`cat /proc/cmdline` shows the running one:

| Running (`root=`) | Use |
|---|---|
| Raspberry Pi switch: `/dev/mmcblk0p2` (A) | `ethernet-switch-os,slot-b` |
| Raspberry Pi switch: `/dev/mmcblk0p3` (B) | `ethernet-switch-os,slot-a` |
| QEMU x86-64 switch: `/dev/vda4` (A) | `ethernet-switch-os,slot-b` |
| QEMU x86-64 switch: `/dev/vda5` (B) | `ethernet-switch-os,slot-a` |

Naming the running slot would overwrite the running firmware. The update
page picks the right slot by itself.

#### Non-A/B updates

A switch **without** A/B has only one firmware slot, and an update
overwrites the running firmware in place.

The Zyxel GS1900-8 and the Albrecht RTL8382MI test switch cannot have A/B
updates because of their 16 MB flash: it is too small for two firmware
slots next to the bootloader and the configuration.

!!! danger "A power failure during an update leaves the switch unusable"
    An update **overwrites the running system in place**. There is no
    second copy to fall back to. If the switch loses power or is reset
    while the new firmware is being written, it will no longer start. To
    get it back you need the serial console, a TFTP server and a new
    [first installation](installation/zyxel-gs1900-8.md#first-installation-in-short), which **erases
    the configuration**.

    - Do not update during a thunderstorm or while someone is working on
      the power.
    - Use a UPS if the switch has one available.
    - Do not unplug the switch or press its reset button until it has
      rebooted and answers again.
    - Back up the configuration first (see
      [Backing up and restoring the configuration](#backing-up-and-restoring-the-configuration)).

!!! warning "Not tested in QEMU"
    The [emulated Zyxel GS1900-8](installation/zyxel-gs1900-8.md#qemu) has
    the same update page and `swupdate` command, but updates there are not
    tested. The emulation has no flash, so an update cannot be written
    there in any case. The A/B update of the
    [QEMU x86-64 switch](installation/qemu-x86-64.md) is tested in
    CI.

### Which file

Every build produces an upgrade `.swu` file. The Zyxel GS1900-8 and the
Albrecht RTL8382MI test switch also get a factory `.swu` (see
[Download](installation/download.md#files)):

| File | Use it for |
|---|---|
| `ethernet-switch-os-swu-upgrade-<board>.swu` | **Updating an installed switch.** Writes the firmware, keeps the configuration. |
| `ethernet-switch-os-swu-factory-<board>.swu` | First installation only, from the TFTP image. Also erases the configuration. |

The switch refuses the wrong file before it writes anything. The factory
file on an installed switch, or the upgrade file on the TFTP image, fails
with `Found nothing to install` and `Compatible SW not found`. A file for
different hardware is rejected as well.

Any version can be installed, including an older one.

### What happens during an update

1. **Upload.** The file is copied onto the switch. The switch works as
   usual.
2. **Check.** SWUpdate checks that the file is for this hardware and is the
   upgrade type, and verifies its checksum. A damaged or wrong file stops
   here. **Nothing has been written yet**, and the switch keeps running the
   old firmware.
3. **Write.**
    - **With A/B**, SWUpdate writes the new firmware into the slot that is
      not running, and only then tells the bootloader to start that slot.
      The switch keeps working normally during this step.
    - **Without A/B**, SWUpdate erases the firmware partition and writes the
      new firmware. **This is the dangerous part.** The running system is
      being overwritten under its own feet: SWUpdate itself has been moved
      into RAM beforehand, but other programs, such as the CLI, SSH or the
      status page, may stop working until the reboot. Do not use the switch
      during this step.
4. **Reboot.** When writing has succeeded, the switch reboots by itself
   into the new firmware a few seconds later. With A/B, it confirms the new
   firmware once it is fully up, or goes back to the old one (see
   [A/B updates](#ab-updates)).

The configuration is not touched. The firmware and the configuration live
on separate partitions:

- The **firmware** partition (one per slot with A/B) holds the operating
  system as a read-only image. This is what an update replaces.
- The **data** partition holds everything the switch writes itself,
  including the saved configuration. The upgrade `.swu` contains nothing
  for it, so it is not written.

At boot, the data partition is laid over the firmware image, so the new
firmware finds the configuration where the old one left it. With A/B, both
slots share the same data partition. Only the factory `.swu` writes the data
partition, and it erases it.

The switch comes back with its **saved** configuration. Changes that were committed but not saved are lost with
the reboot.

### Update in the browser

1. Open `http://<switch-ip>:8080/`. The status page at `http://<switch-ip>/`
   links there with its **Firmware update** button.
2. Drop the **upgrade** `.swu` file on the "Software Update" area, or click
   the area and choose the file. The upload starts at once; there is no
   separate start button.
3. The progress bar shows the upload and then the writing. Under
   **Messages** the page lists what SWUpdate is doing, and errors if there
   are any.
4. On success the page shows "Updated successfully", then "Restarting
   system" and a dialog while the switch reboots. It reloads by itself once
   the switch is back, usually after about a minute.
5. On failure it shows "Update failed", and **Messages** says why. It does
   not reboot.
    - If the failure happened before writing started (wrong file, bad
      checksum), the old firmware is untouched. Nothing else needs doing.
    - With A/B, a failure while writing only affects the slot that is not
      running. The switch keeps running, and still starts, the old
      firmware. Try again when you like.
    - Without A/B, a failure while writing leaves the firmware partition
      incomplete. **Do not reboot or power off.** Upload the upgrade file
      again right away: the update service keeps running from RAM and can
      still write the firmware. Once the switch reboots, it needs a new
      [first installation](installation/zyxel-gs1900-8.md#first-installation-in-short).

!!! warning "The Restart System button"
    The **Restart System** button in the top right corner of the page
    reboots the switch immediately. Committed but unsaved configuration
    changes are lost.

### Update with curl

The update page accepts the file with a plain HTTP upload, so `curl` on
your computer can do the same as the browser:

```sh
curl -F "file=@ethernet-switch-os-swu-upgrade-zyxel-gs1900-8-a1.swu" \
     http://192.168.1.1:8080/upload
```

The form field name does not matter, but the file name must be sent, which
`-F "name=@file"` does.

`curl` returns as soon as the **upload** is complete:

```text
Ok, ethernet-switch-os-swu-upgrade-zyxel-gs1900-8-a1.swu - <size> bytes.
```

This only means the switch received the file. Checking and writing happen
afterwards, and the answer does not tell whether they succeeded. As in the
browser, the switch reboots by itself when the update succeeds. If the
switch rejects the file early, for example the wrong type, `curl` may
print nothing at all.

To tell whether it worked:

- **Watch it.** The switch stops answering while it reboots. Wait until it
  answers again, then compare the firmware version with the one it had
  before:

    ```sh
    curl -s http://192.168.1.1/restconf/data/clixon-switch:system/state/os-version
    ```

    With A/B, the old version after the reboot means the new firmware was
    not confirmed and the switch went back.

- **Follow the progress** live, if you have a WebSocket client such as
  [websocat](https://github.com/vi/websocat). Start it before the upload.
  It prints SWUpdate's messages and status as JSON, ending in `SUCCESS` or
  `FAILURE`:

    ```sh
    websocat ws://192.168.1.1:8080/ws
    ```

If the switch does not reboot within a few minutes, the update failed.
On a switch without A/B, **do not power it off.** The update page only
shows messages of updates that run while it is open, so repeat the update
in the browser to see the reason, and continue as in step 5 of
[the browser update](#update-in-the-browser).

### Update in the switch's shell

As `root`, the switch has the `swupdate` command, which installs a `.swu`
file that is already on the switch.

1. Copy the file into `/tmp` on the switch:

    ```sh
    scp -O ethernet-switch-os-swu-upgrade-zyxel-gs1900-8-a1.swu root@192.168.1.1:/tmp/
    ```

    `-O` makes a current OpenSSH `scp` use the classic protocol. The switch
    has no SFTP server, which `scp` otherwise needs.

    Use `/tmp`, which is in RAM. The other directories are on the partition
    that also holds the configuration, and a file there would stay after
    the update.

2. Log in as `root`:

    ```sh
    ssh root@192.168.1.1
    ```

3. Optionally, check the file without writing anything (`-c`):

    ```text
    # swupdate -c -e ethernet-switch-os,upgrade -i /tmp/ethernet-switch-os-swu-upgrade-zyxel-gs1900-8-a1.swu
    ```

4. Install it:

    ```text
    # swupdate -v -e ethernet-switch-os,upgrade -i /tmp/ethernet-switch-os-swu-upgrade-zyxel-gs1900-8-a1.swu
    ```

    It ends with `SWUpdate was successful !`, or with an error and
    `SWUpdate *failed* !`. The exit code is 0 on success and 1 on failure.

5. On success, reboot:

    ```text
    # reboot
    ```

    Unlike the update page, `swupdate` in the shell does **not** reboot by
    itself.

| Option | Meaning |
|---|---|
| `-i <file>` | The `.swu` file to install. |
| `-e ethernet-switch-os,upgrade` | Selects the upgrade part of the file. **Required.** (`ethernet-switch-os,factory` is only for the TFTP image. On a switch with A/B, the slot instead, see [Which slot is written](#which-slot-is-written).) |
| `-c` | Only check the file (hardware, type, checksums); write nothing. |
| `-v` | Show what SWUpdate is doing. |

If it fails **while writing** on a switch without A/B, the same rule as in
the browser applies: do not reboot, and run the same command again right
away.

!!! warning "The update page stops working until the next reboot"
    Every `swupdate` run in the shell, even a check with `-c`, removes the
    connection that the update page on port 8080 uses to install. After
    that, uploads on the page fail (`curl` prints `Failed to queue command`)
    until the switch reboots. Restarting the update service does not help.
    After a successful update you reboot anyway; after a check or a failed
    attempt, reboot before you use the update page.

## Factory reset

There is no CLI command for a factory reset. Log in as `root` and delete
the saved configuration, then reboot:

```text
$ ssh root@<switch-ip>
# rm /var/lib/clixon/clixon-switch/startup_db
# reboot
```

The switch comes back with the [factory settings](installation/first-login.md#factory-settings),
at `192.168.1.1`.

On the [Albrecht RTL8382MI test switch](installation/albrecht-rtl8382mi-test.md#leds-and-dip-switches), DIP switch 6 does the same: switch it
on, wait at least 5 seconds, and switch it off again.

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
| The switch does not boot | Boot the TFTP image and reinstall with the factory `.swu`, see the installation of the [Zyxel GS1900-8](installation/zyxel-gs1900-8.md#first-installation-in-short) or the [Albrecht RTL8382MI test switch](installation/albrecht-rtl8382mi-test.md#first-installation). |
