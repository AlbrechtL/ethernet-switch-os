# Testing and CI

## Testing without hardware

There are two ways to run a built image without a switch:

- The **QEMU x86-64 switch** is a board of its own. It boots in seconds under
  KVM and exercises the A/B update. See
  [QEMU x86-64 switch](../installation/qemu-x86-64.md).
- **rtl838x-qemu** runs the GS1900-8's own image on an emulated RTL8380.
  Frames really cross between the eight emulated front ports, so VLANs and
  spanning tree can be exercised. See [Zyxel GS1900-8 in QEMU](../installation/zyxel-gs1900-8.md#qemu).

Both pages cover the build, the forwarded ports, and cabling several switches
together with `SWITCH` and `CABLES`.

### The scripts

| Script | What it does |
|---|---|
| `scripts/x86-64-q35-qemu` | Boots a copy of the built QEMU x86-64 disk with the QEMU and UEFI firmware from the build, on the serial console of the terminal (`Ctrl-a x` quits). It always boots the image of the last build and never modifies it: every start is the factory state, and changes are lost when QEMU exits. |
| `scripts/x86-64-q35-qemu-test` | Boots a fresh disk, installs the `.swu` and checks that the other slot comes up and is confirmed. This is what CI runs. |
| `scripts/mips-rtl838x-qemu` | Boots the built GS1900-8 firmware with `qemu-rtl838x-native` from an emulated flash that it lays out like a factory install, with the QEMU from the build, on the serial console of the terminal (`Ctrl-a x` quits). The machine loads the uImage from the flash the way the stock bootloader does, so `rt-loader` runs exactly as it does on the real switch. It always boots the firmware of the last build and never modifies it: every start is the factory state, a reboot keeps changes and firmware updates, and QEMU exiting drops them. |
| `scripts/mips-rtl838x-qemu-test` | Boots the firmware from flash, installs the upgrade `.swu` and checks that the switch comes back from flash with all eight ports in RESTCONF. This is what CI runs. |

`kas/opt/rtl838x-qemu.yml` adds `qemu-rtl838x-native` from `meta-rtl83xx-bsp`
to the build: QEMU with [rtl838x-qemu](https://github.com/AlbrechtL/rtl838x-qemu)'s
models, at the QEMU version rtl838x-qemu pins.

The disk layout of the QEMU x86-64 switch, EFI Boot Guard and how an update
is confirmed or rolled back are in
[meta-qemu-switch-bsp](https://github.com/AlbrechtL/meta-qemu-switch-bsp)'s
README.

## Continuous integration

`.github/workflows/build.yml` runs the same `./kas-container build` as a
local build, one job per board, on every push to `master` and on pull
requests, and uploads the files the board file lists under `artifacts:` as a
job artifact. For the QEMU switch it then runs `scripts/x86-64-q35-qemu-test`
on the runner: boot, update into the other slot, check that it is confirmed.

The layer repositories do not build images of their own. A push to
`meta-ethernet-switch-os` runs a parse check there (this configuration, this
machine, no task executed), which catches a broken recipe in minutes. It
cannot trigger this workflow, so this one also runs weekly, which is what
turns the layers' current `master` into images. Because almost nothing is
pinned, that run doubles as a check that the upstream branches still build.

`.github/workflows/docs.yml` builds this documentation with
`mkdocs build --strict` on every change to it, so a broken link fails the
build, and publishes it to GitHub Pages from `master`.
