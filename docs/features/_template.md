<!--
Template for a feature page. Copy it to docs/features/<feature>.md and
follow "Documenting a new feature" in docs/development/contributing.md.
This file is excluded from the site (exclude_docs in mkdocs.yml).

Every feature page has the same four major sections, in this order. Say
things that hold for all interfaces (rules, limits, what status fields
mean) once, in the introduction. The interface sections show only how to
do it there.
-->

# Feature name

<!--
Introduction, without a heading:
- What the feature does and when you need it. Its factory setting.
- The concepts the reader needs (for example access and trunk ports).
- Rules and limits, as a table "Rule | Error when broken" if the switch
  checks them.
- What the status fields mean, as a table "Field | Meaning".
-->

## Web UI

<!--
Where on the status page (https://<switch-ip>/) the feature shows up, and
which Edit/Add/Delete dialogs change it. Caveats, such as changes that cut
off your own connection. Remind of **Save configuration** where it matters.
Link the general parts to ../getting-started/web-ui.md.

If the web UI cannot configure it:

!!! note "Not in the web UI"
    ... is configured with the [CLI](#cli) or [RESTCONF](#restconf).
-->

## CLI

<!--
Task-oriented subsections (### Do X), each with the complete command
sequence including `commit` and, where it makes sense, `save`. End with
the status: `show state text ...` and an excerpt of its output.
Link the general parts to ../getting-started/cli.md.
-->

## RESTCONF

<!--
Same tasks as in the CLI section, as curl calls:

    curl -k -u ops -X PATCH -H 'Content-Type: application/yang-data+json' \
        -d '{...}' \
        https://192.168.1.1/restconf/data/<module>:<container>

Until they are written, keep the placeholder below and list the resources.
-->

!!! note "Coming later"
    Examples are not written yet. See [Using RESTCONF](../getting-started/restconf.md)
    for how the CLI paths above map to RESTCONF resources.

The feature is configured under:

```text
/restconf/data/<module>:<container>
```

## Not supported

<!--
Optional. Settings the data model offers but the switch rejects, with
their error messages.
-->
