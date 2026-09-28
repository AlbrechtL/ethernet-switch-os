# Password and factory reset

The switch has one **admin account**. It is created at the
[first login](../getting-started/index.md#first-login-create-the-admin-account)
and logs in to the web pages, SSH and the serial console, and it is the
login for RESTCONF. Its username stays until a factory reset; its password
can be changed at any time. The password has 8 to 128 characters.

A **factory reset** erases everything the switch has stored: the saved
configuration, the admin account, the SSH host keys and the HTTPS
certificate. The firmware stays. The switch reboots and comes back like a
freshly installed one, at `https://192.168.1.1/` with the first-login
setup. It is also the way back in when the admin password is lost. The
reset button, the serial console and what exactly is erased are described
in [Factory reset](../installation/update.md#factory-reset).

With a serial cable, a lost password can also be replaced without losing
the settings: see
[Lost password, but keep the settings](../installation/update.md#lost-password-but-keep-the-settings).

Neither changing the password nor a factory reset changes the
configuration, so neither needs a save.

## Web UI

The **Administration** part of the [status page](../getting-started/web-ui.md#status-page):

- **Change password** asks for the current and the new admin password. The
  browser then asks for the new one.
- **Factory reset** asks for confirmation, erases everything and reboots.
  The browser warns about the new HTTPS certificate once the switch is back.

## CLI

| Command | What it does |
|---|---|
| `password` | Changes the admin password: asks for the current one and the new one twice, without echo. |
| `factory-reset` | Asks for confirmation, then erases everything and reboots. |

```text
switch> factory-reset
All settings, the admin account, the SSH host keys and the HTTPS certificate
will be erased, and the switch reboots. Continue? [y/N] y
Rebooting. The switch comes back with the factory settings.
```

## RESTCONF

Two operations of the module `clixon-switch` manage the admin account and
the reset: `set-password` (`username`, `current-password`, `new-password`)
and `factory-reset`.

### Create the admin account

During the first-login setup, `set-password` works without a login: it
creates the admin account with `username` and `new-password`. This is how a
script sets up a new switch without a browser:

```sh
curl -k -X POST -H 'Content-Type: application/yang-data+json' \
    -d '{"clixon-switch:input":{"username":"ops","new-password":"my new password"}}' \
    https://192.168.1.1/restconf/operations/clixon-switch:set-password
```

### Change the password

Afterwards `set-password` only changes the password, and needs
`current-password` instead of `username`: the username stays until a
factory reset.

```sh
curl -k -u ops -X POST -H 'Content-Type: application/yang-data+json' \
    -d '{"clixon-switch:input":{"current-password":"my new password","new-password":"another password"}}' \
    https://192.168.1.1/restconf/operations/clixon-switch:set-password
```

### Factory reset

```sh
curl -k -u ops -X POST https://192.168.1.1/restconf/operations/clixon-switch:factory-reset
```
