# Security policy

## Report a vulnerability

Report a vulnerability privately. Do not open a public issue for it.

1. On the page of this repository, click the **Security and quality** tab.
2. Click **Report a vulnerability**.
3. Write the version that you used, what happens, and the steps that show it.

## Supported versions

Security fixes go to the newest version on the `main` branch.

## Scope

These parts of fvTrace read data that can come from other people:

- `fvtrace serve`: the web server and its secret link. With `--host`, other computers on your
  network can reach it.
- The page that `fvtrace export --html` writes and the folder that `fvtrace export --bundle`
  writes.
- Trace files and the evidence files that they name.

A replay command runs only when you add `--run` or `--replay`, and it runs with your rights. Read
the commands with `fvtrace verify` before you use `--run` or `--replay` on a trace from someone
else.
