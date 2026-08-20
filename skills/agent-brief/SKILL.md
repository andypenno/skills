---
name: agent-brief
description: |-
  Trigger when the user needs a block to carry to an agent working on a different system - "give me a prompt to pass to the X agent", "what do you need from them", "put it in a markdown block I can copy". Also when a counterpart agent's reply is pasted back and must be reconciled against this repo. For continuing your own work elsewhere use /handoff.
  Keywords: prompt to pass to, pass it on, other agent, infrastructure agent, give me a markdown block, copyable prompt, what do you need from them, ferry this across, contract with the other agent
---

# Agent Brief

Two agents own two halves of one interface and cannot talk to each other. The user is the message bus. Your job is to make one round trip enough.

Block-writing mechanics - one fenced block, absolute paths, reference artifacts rather than restating them - come from `/handoff`. This skill is the **contract**: what the other side needs to build its half, and what you need back.

## Before writing

Establish what is actually true on your side. A brief built on intent rather than state is what forces the second round trip.

- What have you already implemented, deployed, and *verified*? Name the evidence.
- What is the exact interface: URLs, endpoint paths, method, auth mechanism, secret **names**.
- What is still assumption rather than fact? Say so in the brief rather than presenting it as settled.

## The block

```
# <What this is> - request to the <name> agent

## Context
Two sentences. What system you own, what they own, what we are connecting.

## Interface
| Item | Value | Notes |
Endpoint URL, method, auth header, and the NAME of each secret or variable
they must read. Never the value.

## Payload contract
| key | type | required | notes |
Every field, with an example message at the end.

## Already done on my side
One line each, with evidence. This is the section that stops them redoing work.

## What I need from you
Numbered. Each item a concrete action on their system.

## How to verify
The command or observation that proves the connection works end to end.

## Reply format
Ask for exactly the shape you want back: what they did, what they changed
in the contract, what is still outstanding. State that corrections to the
interface above are expected and wanted.
```

Drop empty sections. Do not pad it to look thorough.

## Secrets

⚠️ Names, never values. A brief travels through chat, a clipboard, and possibly a paste bin.

Treat as secret, beyond the obvious tokens: IP addresses, internal hostnames, personal domains, webhook UUIDs, workspace-scoped tokens. If one has already been written somewhere it should not be, say so plainly - see `/secret-hygiene`.

## Receiving a reply

When the user pastes the counterpart's block back, do not implement it directly.

1. **Reconcile against the repo first.** Read the real config, route, or vault entry. A counterpart agent describes what it *intended*; the file is what exists.
2. **Diff intent against reality** and report the mismatches before writing code. Contract corrections discovered by live testing are common and expected.
3. **State what you accept versus dispute**, then implement your half.
4. If the reply leaves the interface underspecified, produce the follow-up brief rather than guessing - a wrong guess costs another full round trip.

## Standing obligations

Two things that get forgotten because neither side owns them: a new endpoint needs its monitoring entry, and a new secret needs its vault entry rather than an inline value. Name whichever applies in the brief, and say which side is doing it.
