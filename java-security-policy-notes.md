# Notes on the agent-to-controller security subsystem

Kept separate from `security-hardening.md` because this got long enough
to deserve its own scratch notes - this is the more "reference" version,
the other doc is the narrative version of what I actually did.

## What it protects against

By default, an agent that connects to the controller runs code that's
allowed to do a lot - read files, call internal APIs, etc - because
historically the remoting channel didn't distinguish "trusted controller
code" from "code an agent asked the controller to run on its behalf." The
`hudson.remoting.ClassFilter` and the agent-to-controller access control
layer (`jenkins.security.s2m.AdminWhitelistRule` and friends, in older
versions) exist to narrow that down.

## Where I looked at this in the UI

`Manage Jenkins → Security → Agent to Controller Access Control`. Current
Jenkins ships this enabled with a sane default deny list. I did NOT add any
custom whitelist entries in this lab - every plugin I used worked fine
under the default rules. If you hit a specific plugin operation that gets
blocked, the log will name the exact class/method being denied - only
whitelist that specific one, not a wildcard.

## Class filtering

There's a separate, lower-level `remoting` class filter
(`hudson.remoting.ClassFilter`) that blocks certain Java classes from being
deserialized across the channel at all, as a defense against arbitrary code
execution via crafted serialized objects. I didn't touch this either - it's
meant to be invisible unless something is actively trying to abuse
deserialization, and loosening it defeats the point.

## Takeaway for this lab

The honest summary: I didn't need to write any custom security policy for
any of the four agents. The defaults, left alone, plus the network-level
stuff (dedicated user, dedicated key, firewalled port, WebSocket instead of
a raw port where possible) covered what a lab like this needs. The value of
reading through this was understanding *why* the defaults look the way they
do, not ending up with some clever custom policy.
