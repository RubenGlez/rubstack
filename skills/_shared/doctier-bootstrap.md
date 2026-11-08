# Doctier bootstrap

Encrypted mode only: the once-per-repo setup for tracking `.rubstack/` as age-encrypted blobs in a **public** repository. Private repositories never use doctier — see [doc-store.md](doc-store.md), which decides the mode and sends you here. Run every step in order.

1. Check the binary: `command -v doctier`. In a cloud session the SessionStart hook installs it when `RUBSTACK_DOCTIER_KEY` is set; if it is still missing there, tell the user to add the install line to the cloud environment's setup script. Otherwise, if missing, STOP and tell the user: "rubstack doc skills require doctier. Install it with `brew tap RubenGlez/doctier https://github.com/RubenGlez/doctier && brew install doctier`, or without Homebrew: `curl -fsSL https://raw.githubusercontent.com/RubenGlez/doctier/main/install.sh | sh`. Then re-run this skill." Do not write `.rubstack/` docs without it.
2. Write `.doctier.yml` at the repo root (if the rules change later, re-run `doctier init` — it syncs the managed `.gitattributes`/`.gitignore` blocks):

   ```yaml
   version: 1

   # .rubstack/ is the private doc store: encrypted in git, decrypted on checkout.
   # Prototype/spike code is sensitive scratch: never committed, dies with the worktree.
   docs:
     - path: ".rubstack/**"
       visibility: private
       lifetime: durable

     - path: "**/_prototype-*"
       visibility: private
       lifetime: ephemeral
       sensitive: true

     - path: "**/_spike/**"
       visibility: private
       lifetime: ephemeral
       sensitive: true

   recipients_file: .doctier/recipients.txt
   ```

3. Run `doctier init` (configures the git filter and decrypted-diff textconv, writes the managed attribute/ignore blocks, installs pre-commit, pre-push, and post-merge hooks).
4. Grant the current key: `doctier grant "$(ssh-keygen -y -f "${DOCTIER_SSH_KEY:-$HOME/.ssh/id_ed25519}")"`. In a cloud session this is the dedicated cloud key from `RUBSTACK_DOCTIER_KEY` (the SessionStart hook sets `DOCTIER_SSH_KEY` to it); tell the user to also grant their personal key from their own machine, or they will not be able to read the docs locally.
5. If `.gitignore` has a legacy standalone `.rubstack/` line, delete that line.
6. Protect the policy files: `.doctier.yml`, `.doctier/recipients.txt`, and `.gitattributes` are tracked, unauthenticated files — anyone with commit access can reclassify a private path as public or add their own key. Add CODEOWNERS entries for those three paths assigning the repo owner (create `.github/CODEOWNERS` if absent), and treat any diff to them as a security review.
7. Verify with `doctier check`, then commit the scaffolding: `git add .doctier.yml .doctier/ .gitattributes .gitignore .github/CODEOWNERS && git commit -m "chore: adopt doctier for .rubstack/ docs"`.
