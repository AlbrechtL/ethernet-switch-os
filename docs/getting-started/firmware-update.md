# Firmware update

Firmware updates use [SWUpdate](https://sbabic.github.io/swupdate/). An
update is a single `.swu` file. There are three ways to install it:

- [in the browser](#update-in-the-browser), on the update page,
- [with `curl`](#update-with-curl) from your computer, through the same page,
- [with `swupdate`](#update-in-the-switchs-shell) in a root shell on the switch.

!!! danger "A power failure during an update leaves the switch unusable"
    The switch has only **one** firmware partition, and an update
    **overwrites the running system in place**. There is no second copy
    to fall back to. If the switch loses power or is reset while the new
    firmware is being written, it will no longer start. To recover it you
    need the serial console and a TFTP server, and the recovery
    **erases the configuration** (see [Recovery](#recovery)).

    - Do not update during a thunderstorm or while someone is working on
      the power.
    - Use a UPS if the switch has one available.
    - Do not unplug the switch or press its reset button until it has
      rebooted and answers again.
    - Back up the configuration first (see [below](#before-you-start)).

!!! tip "Trying it in QEMU"
    The [emulated switch](installation.md#qemu-zyxel-gs1900-8) has the same update page and `swupdate`
    command, so you can practise there without risk. It runs the TFTP
    image, whose update page only takes the **factory** file (the upgrade
    file is refused with `Compatible SW not found`). It has no flash, so an
    update that gets as far as writing ends with
    `Wrong MTD device in description: firmware`.

## Which file

Every build produces two `.swu` files (see
[Installation](installation.md#images)):

| File | Use it for |
|---|---|
| `ethernet-switch-os-swu-upgrade-<board>.swu` | **Updating an installed switch.** Writes the firmware, keeps the configuration. |
| `ethernet-switch-os-swu-factory-<board>.swu` | First installation and recovery only, from the TFTP image. Also erases the configuration. |

The switch refuses the wrong file before it writes anything. The factory
file on an installed switch, or the upgrade file on the TFTP image, fails
with `Found nothing to install` and `Compatible SW not found`. A file for
different hardware is rejected as well.

Any version can be installed, including an older one.

## What happens during an update

1. **Upload.** The file is copied into the switch's RAM. The switch works as
   usual.
2. **Check.** SWUpdate checks that the file is for this hardware and is the
   upgrade type, and verifies its checksum. A damaged or wrong file stops
   here. **Nothing has been written yet**, and the switch keeps running the
   old firmware.
3. **Write.** SWUpdate erases the firmware partition and writes the new
   firmware. **This is the dangerous part.** The running system is being
   overwritten under its own feet: SWUpdate itself has been moved into RAM
   beforehand, but other programs, such as the CLI, SSH or the status
   page, may stop working until the reboot. Do not use the switch during
   this step.
4. **Reboot.** When writing has succeeded, the switch reboots by itself
   into the new firmware a few seconds later.

The configuration is not touched. The switch comes back with its **saved**
configuration. Changes that were committed but not saved are lost with
the reboot.

## Before you start

1. **Save** the configuration, so the switch comes back as it is now:

    ```text
    switch> save
    ```

2. **Back up** the configuration, in case a recovery becomes necessary. In
   the CLI, run `show configuration cli` and copy the output into a file on
   your computer (see [Maintenance](maintenance.md#backing-up-and-restoring-the-configuration)).

3. Note the current version, to check afterwards that the update worked:

    ```text
    switch> show state text system
    ```

    `os-version` is the firmware version.

## Update in the browser

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
    - If writing itself failed, the firmware partition is incomplete.
      **Do not reboot or power off.** Upload the upgrade file again right
      away: the update service keeps running from RAM and can still write
      the firmware. Once the switch reboots, it can only be
      [recovered](#recovery).

!!! warning "The Restart System button"
    The **Restart System** button in the top right corner of the page
    reboots the switch immediately. Committed but unsaved configuration
    changes are lost.

## Update with curl

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
  answers again, then compare the firmware version with the one noted
  before:

    ```sh
    curl -s http://192.168.1.1/restconf/data/clixon-switch:system/state/os-version
    ```

- **Follow the progress** live, if you have a WebSocket client such as
  [websocat](https://github.com/vi/websocat). Start it before the upload.
  It prints SWUpdate's messages and status as JSON, ending in `SUCCESS` or
  `FAILURE`:

    ```sh
    websocat ws://192.168.1.1:8080/ws
    ```

If the switch does not reboot within a few minutes, the update failed.
**Do not power it off.** The update page only shows messages of updates
that run while it is open, so repeat the update in the browser to see the
reason, and continue as in step 5 of
[the browser update](#update-in-the-browser).

## Update in the switch's shell

As `root`, the switch has the `swupdate` command, which installs a `.swu`
file that is already on the switch.

1. Copy the file into `/tmp` on the switch:

    ```sh
    scp -O ethernet-switch-os-swu-upgrade-zyxel-gs1900-8-a1.swu root@192.168.1.1:/tmp/
    ```

    `-O` makes a current OpenSSH `scp` use the classic protocol. The switch
    has no SFTP server, which `scp` otherwise needs.

    Use `/tmp`, which is in RAM. The other directories are on the small
    flash partition that also holds the configuration, and a file there
    would stay after the update.

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
| `-e ethernet-switch-os,upgrade` | Selects the upgrade part of the file. **Required.** (`ethernet-switch-os,factory` is only for the TFTP image.) |
| `-c` | Only check the file (hardware, type, checksums); write nothing. |
| `-v` | Show what SWUpdate is doing. |

If it fails **while writing**, the same rule as in the browser applies: do
not reboot, and run the same command again right away.

!!! warning "The update page stops working until the next reboot"
    Every `swupdate` run in the shell, even a check with `-c`, removes the
    connection that the update page on port 8080 uses to install. After
    that, uploads on the page fail (`curl` prints `Failed to queue command`)
    until the switch reboots. Restarting the update service does not help.
    After a successful update you reboot anyway; after a check or a failed
    attempt, reboot before you use the update page.

!!! note
    The update page is the safer way. Its service copies itself into RAM
    before it overwrites the firmware. A `swupdate` started in the shell
    runs from the firmware partition it is overwriting.

## After the update

1. Log in again and check the version:

    ```text
    switch> show state text system
    ```

2. Check that the configuration came back as expected:

    ```text
    switch> show configuration cli
    ```

    If the new firmware no longer accepts part of the saved configuration,
    the switch starts with the factory settings at `192.168.1.1` instead.
    See [Maintenance](maintenance.md#when-the-saved-configuration-cannot-be-loaded).

## Recovery

If the switch does not start after an interrupted update:

1. Connect the serial console (115200 8N1) and a PC with a TFTP server.
2. Boot the `initramfs` image over TFTP from the bootloader. The bootloader
   itself is never touched by an update, so this always works.
3. Open `http://192.168.1.1:8080/` and install the **factory** `.swu`, then
   reboot.
4. The switch now has the factory settings. Restore your configuration from
   the backup.

The detailed steps are in [Installation](installation.md)
and the [meta-rtl83xx-bsp README](https://github.com/AlbrechtL/meta-rtl83xx-bsp).

## Security

The update page has **no password and no encryption**, and the `.swu` files
are not signed. Anyone who can reach port 8080 can install any firmware.
See [Limitations](../limitations.md#security).
