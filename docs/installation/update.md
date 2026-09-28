# Update

Keeping a switch running: saving and backing up its configuration,
installing new firmware, and getting back in when something went wrong.


## Saving the configuration

Changes take effect with `commit`, but only `save` makes them survive a
reboot (see [CLI basics](../cli/basics.md#candidate-running-startup)).

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

### Which firmware is installed

There are no releases and no tags yet, so the firmware version is a base
version and the git revision of `meta-ethernet-switch-os` the firmware was
built from, for example `0.0.0-3eae8394`. Two builds from different commits
therefore have different versions, and every version names its commit.

Where to read it:

- the CLI: `show state text system` ([System status](../cli/system.md#system-status)),
  as `os-version`, with the revision on its own in `os-build-id`,
- the [status page](../web-ui.md#system) of the web UI, as **Firmware**,
- RESTCONF:

    ```sh
    curl -sk -u <username> https://192.168.1.1/restconf/data/clixon-switch:system/state/os-version
    ```

- in a `root` shell: `/etc/os-release` (`VERSION`, `BUILD_ID`), and
  `/etc/buildinfo`, which names the branch and revision of *every* layer the
  firmware was built from; the version can only name one of them.

The same version is in the `.swu` file's `sw-description`, and CI publishes it
next to the images as `ethernet-switch-os-version-<machine>.txt`.

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
    [first installation](zyxel-gs1900-8.md#first-installation), which **erases
    the configuration**.

    - Do not update during a thunderstorm or while someone is working on
      the power.
    - Use a UPS if the switch has one available.
    - Do not unplug the switch or press its reset button until it has
      rebooted and answers again.
    - Back up the configuration first (see
      [Backing up and restoring the configuration](#backing-up-and-restoring-the-configuration)).

!!! tip "Trying it in QEMU"
    The [emulated Zyxel GS1900-8](zyxel-gs1900-8.md#qemu) has
    a flash of its own, the same update page and the same `swupdate`
    command, see
    [Update the firmware](zyxel-gs1900-8.md#6-update-the-firmware).
    CI updates it too. So does the A/B update of the
    [QEMU x86-64 switch](qemu-x86-64.md).

### Which file

Every build produces an upgrade `.swu` file. The Zyxel GS1900-8 and the
Albrecht RTL8382MI test switch also get a factory `.swu` (see
[Download](download.md#files)):

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

!!! note "Updating from firmware with the fixed admin account `cli`"
    Older firmware had a fixed admin account, `cli`, instead of one named in
    the [first-login setup](../getting-started.md#first-login-create-the-admin-account).
    An update keeps it: `cli` logs in as before, with its password. Only a
    factory reset replaces it with the setup.

### Update in the browser

1. Open `https://<switch-ip>/update/` and log in with the admin username
   and password. The status page at `https://<switch-ip>/` links there with its
   **Firmware update** button.
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
      [first installation](zyxel-gs1900-8.md#first-installation).

!!! warning "The Restart System button"
    The **Restart System** button in the top right corner of the page
    reboots the switch immediately. Committed but unsaved configuration
    changes are lost.

### Update with curl

The update page accepts the file with a plain HTTP upload, so `curl` on
your computer can do the same as the browser. `-u <username>` asks for the
admin password, `-k` accepts the switch's self-signed certificate:

```sh
curl -k -u <username> -F "file=@ethernet-switch-os-swu-upgrade-zyxel-gs1900-8-a1.swu" \
     https://192.168.1.1/update/upload
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
    curl -sk -u <username> https://192.168.1.1/restconf/data/clixon-switch:system/state/os-version
    ```

    With A/B, the old version after the reboot means the new firmware was
    not confirmed and the switch went back. See
    [Which firmware is installed](#which-firmware-is-installed).

- **Follow the progress** live, if you have a WebSocket client such as
  [websocat](https://github.com/vi/websocat). Start it before the upload.
  It prints SWUpdate's messages and status as JSON, ending in `SUCCESS` or
  `FAILURE`:

    ```sh
    websocat -k --basic-auth cli:<password> wss://192.168.1.1/update/ws
    ```

If the switch does not reboot within a few minutes, the update failed.
On a switch without A/B, **do not power it off.** The update page only
shows messages of updates that run while it is open, so repeat the update
in the browser to see the reason, and continue as in step 5 of
[the browser update](#update-in-the-browser).

### Update in the switch's shell

As `root`, the switch has the `swupdate` command, which installs a `.swu`
file that is already on the switch. `root` logs in on the serial console
only (115200 8N1), not over SSH.

1. Log in as `root` on the serial console.

2. Fetch the file into `/tmp` on the switch, for example from a web or TFTP
   server on your computer:

    ```text
    # cd /tmp
    # wget http://192.168.1.10:8000/ethernet-switch-os-swu-upgrade-zyxel-gs1900-8-a1.swu
    ```

    (`python3 -m http.server` in the directory with the file is such a web
    server; `tftp -g -r <file> <server>` fetches from TFTP.)

    Use `/tmp`, which is in RAM. The other directories are on the partition
    that also holds the configuration, and a file there would stay after
    the update.

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
    connection that the update page uses to install. After
    that, uploads on the page fail (`curl` prints `Failed to queue command`)
    until the switch reboots. Restarting the update service does not help.
    After a successful update you reboot anyway; after a check or a failed
    attempt, reboot before you use the update page.

## Factory reset

A factory reset erases everything the switch has stored: the saved
configuration, the admin account, the SSH host keys and the HTTPS
certificate. The firmware stays. The switch reboots and comes back like a
freshly installed one: with the
[factory settings](../getting-started.md#factory-settings) at `192.168.1.1`,
without an admin account until the [first-login setup](../getting-started.md#first-login-create-the-admin-account)
creates one, with a new SSH host key
(ssh warns that it changed) and a new certificate.

It is also the way back in when the admin password is lost. Any of these
starts it:

| Where | How |
|---|---|
| Reset button (Zyxel GS1900-8) | Hold it for at least 5 seconds, then release. A shorter press only reboots. |
| DIP switch 6 ([Albrecht RTL8382MI test switch](albrecht-rtl8382mi-test.md#leds-and-dip-switches)) | Switch it on, wait at least 5 seconds, switch it off again. |
| CLI | `factory-reset`, then confirm with `y`. |
| Web page | **Administration → Factory reset**. |
| Serial console | Log in as `root`, run `ethernet-switch-os-factory-reset`. |

```text
switch> factory-reset
All settings, the admin account, the SSH host keys and the HTTPS certificate
will be erased, and the switch reboots. Continue? [y/N] y
Rebooting. The switch comes back with the factory settings.
```

On the RTL83xx boards the flash partition that holds this data is erased,
so nothing of it can be read back. On the Raspberry Pi and QEMU the files
are deleted, but an SD card may keep the old blocks.

### Lost password, but keep the settings

With a serial cable, `root` can set a new admin password without a factory
reset. It changes the password of the admin account, whatever its name (here
`ops`):

```text
zyxel-gs1900-8-a1 login: root
# ethernet-switch-os-set-password
New password for ops:
Repeat new password:
```

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
| A saved configuration cut you off | Connect to a port that is still in the management VLAN, or use the serial console (115200 8N1, login `root`) and fix it with `clixon_cli`, or do a [factory reset](#factory-reset). |
| The admin password is lost | A [factory reset](#factory-reset), or with a serial cable [a new password as root](#lost-password-but-keep-the-settings). |
| The switch does not boot | Boot the TFTP image and reinstall with the factory `.swu`, see the installation of the [Zyxel GS1900-8](zyxel-gs1900-8.md#first-installation) or the [Albrecht RTL8382MI test switch](albrecht-rtl8382mi-test.md#first-installation). |
