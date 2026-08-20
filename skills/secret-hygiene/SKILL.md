---
name: secret-hygiene
description: |-
  Trigger before a repo goes public, before any history rewrite, and whenever the user asks whether a secret has been committed, wants credentials scrubbed, or is adding a secret to a vault or config. Also when a token, key, internal hostname or IP address may be reaching a log, an error message, or a chat block.
  Keywords: secret, secrets, credential, token, api key, committed a secret, is it encrypted, vault, ansible-vault, scrub history, rewrite history, make the repo public, leaked, redact, logging the token
---

# Secret Hygiene

Find and remove credentials from where they should not be: the working tree, the index, the history, and the runtime.

⚠️ Never print a secret's value to prove it exists. Report the file, line, and kind. A grep that dumps the match into chat has just leaked it again, into a transcript and a backup.

## What counts as a secret

Broader than the obvious. Treat all of these as sensitive:

- Tokens, API keys, passwords, private keys, certificates, connection strings
- **IP addresses and internal hostnames** - they map the network
- **Personal or internal domains**
- **Webhook UUIDs** - the URL *is* the credential
- Workspace- or tenant-scoped identifiers that grant access on their own

## Where to look

Four places, and the last two are the ones that get skipped.

```bash
# 1. Working tree and untracked files - the ignored ones especially
rg -uu -n -i '(api[_-]?key|secret|token|password|passwd|bearer|private[_-]?key|BEGIN [A-Z ]*PRIVATE KEY)'

# 2. Staged content, before it becomes history
git diff --cached

# 3. History - the whole thing, all branches
git log --all -p -S'<the distinctive fragment>'
git log --all --diff-filter=A --name-only -- '*.pem' '*.key' '.env*'

# 4. Runtime - code that emits a credential into a log or error
rg -n 'log.*(token|secret|key|password)' --glob '!*test*'
```

For each vault-managed file, confirm it is actually encrypted rather than assuming - a file that was decrypted for editing and committed plaintext looks identical in a directory listing.

## Removal

**A secret in the working tree** - remove it, replace with a reference to a vault entry or environment variable, and add the path to `.gitignore` if it should never have been tracked.

**A secret already committed** - deleting it in a new commit does nothing. The blob stays reachable. Either rewrite history, or accept it is public and rotate.

🧨 **Rotate regardless.** Anything that reached a remote must be treated as compromised, even after a rewrite - it was in a clone, a CI cache, a fork, or a backup. A rewrite without rotation is theatre.

**Rewriting history** is destructive and shared-branch-hostile. Do not start it on your own initiative: state what needs rewriting, the exact commands, and who else needs to re-clone, then wait. After any rewrite, re-run the history checks above to confirm the fragment is actually gone rather than assuming the tool worked.

## Preventing the next one

- **Generate at runtime rather than committing.** Certificates and keys the deployment can create do not need to be in the repo at all.
- **Vault entries, never inline values** - including in the config that references them, and in any brief you write for another agent (see `/agent-brief`).
- **Re-encrypt without reading the plaintext** where the tooling allows it.
- **A pre-commit hook** that refuses to commit an unencrypted vault-managed file is the only check that runs every time. See `/hooks` - and note it must fail closed: a hook that passes when it cannot tell is worse than none, because it manufactures confidence.

## Report

Per finding: kind of secret, location, which of the four places it lives in, and whether rotation is required. Lead with anything still exposed right now. State plainly what you could not check - a shallow clone cannot clear history, and saying so is the finding.
