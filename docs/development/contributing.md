# Contributing

Contributions are welcome: bug reports, documentation fixes, support for more
hardware, and code. This project is a proof of concept, so expect rough edges.

## Where things go

The project is split over several repositories. Send a change to the one that
owns the code:

| Change | Repository |
|---|---|
| Build configuration (kas files), CI, this documentation | [ethernet-switch-os](https://github.com/AlbrechtL/ethernet-switch-os) |
| The configuration backend, CLI data model, SNMP | [clixon-switch-rs](https://github.com/AlbrechtL/clixon-switch-rs) |
| The distro, the userspace, the web UI, firmware update | [meta-ethernet-switch-os](https://github.com/AlbrechtL/meta-ethernet-switch-os) |
| Realtek RTL83xx machines, kernel, device trees | [meta-rtl83xx-bsp](https://github.com/AlbrechtL/meta-rtl83xx-bsp) |
| The Raspberry Pi switch | [meta-rpi-managed-switch-bsp](https://github.com/AlbrechtL/meta-rpi-managed-switch-bsp) |
| The QEMU x86-64 switch | [meta-qemu-switch-bsp](https://github.com/AlbrechtL/meta-qemu-switch-bsp) |
| The RTL838x emulator | [rtl838x-qemu](https://github.com/AlbrechtL/rtl838x-qemu) |

See [Layers and kas files](kas.md) for how the layers fit together, and
[Adding a board](kas.md#adding-a-board) if you want to bring up new hardware.

## Reporting a problem

Open an issue in the repository that owns the code, or in
[ethernet-switch-os](https://github.com/AlbrechtL/ethernet-switch-os/issues)
if you are not sure which one that is. Say which board you use, the firmware
version (shown on the [status page](../web-ui.md)) and how to reproduce the
problem.

## Sending a change

1. Fork the repository and create a branch from `master`.
2. [Build](building.md) the board you changed. While you work on a layer, add
   `kas/opt/local-layers.yml` so kas does not reset your commits, see
   [Working on a layer](kas.md#working-on-a-layer).
3. Try the result. You do not need hardware for most changes, see
   [Testing and CI](testing.md).
4. Open a pull request against `master`. CI builds every board.

Keep a change to one topic and describe why it is needed, not only what it
does.

## Documentation

Documentation changes are as welcome as code. The pages are Markdown files in
[`docs/`](https://github.com/AlbrechtL/ethernet-switch-os/tree/master/docs)
and the navigation is in `mkdocs.yml`. Build it locally with
`build --strict` before you send it, as CI does, see
[Building this documentation](building.md#building-this-documentation).

## License

The project is licensed under the [MIT License](https://github.com/AlbrechtL/ethernet-switch-os/blob/master/LICENSE).
By contributing you agree that your contribution is licensed the same way.
