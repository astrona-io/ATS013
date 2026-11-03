# Customize Gateways And Control Plane Resources — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-013-playground-020-03
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading
- **Status:** UNTESTED

A single sandbox environment that spins up, runs OS prep, and stays running so
you can explore the module's topic on a clean machine. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-013-playground-020-03
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-013-playground-020-03`), not
the configuration file path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime + bootstrap only) |
| `bootstrap/prepare.sh` | OS prep run once at startup |
| `docs/overview.md` | What the environment contains and ideas to try |
