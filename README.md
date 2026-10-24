# warden-spike-s1 — supply-chain compatibility spike

Throwaway repo for Warden spike **S1** (hub `ROADMAP.md`, weeks 1–3). It answers, with real artifacts, whether the
signing/attestation formats chosen in ADR-008/009 verify under Kyverno's `ImageValidatingPolicy` on GHCR.

| ID | Question |
|----|----------|
| Q1 | Does Kyverno 1.19.2 IVP find GitHub-generated provenance (`actions/attest-build-provenance`, pushed to GHCR) and cosign v3 attestations via the referrers fallback tag? |
| Q2 | Does `extractPayload()` return the in-toto statement (`.predicate.…`) or the predicate itself? |
| Q3 | Are Rekor entries written by cosign 3.1.4 accepted with `ctlog.url: https://rekor.sigstore.dev`? |
| Q4 | What exactly is in the Fulcio certificate subject when a **reusable** workflow signs (case of the org, ref form)? |
| Q5 | What is the provenance's `externalParameters.workflow` shape (repository URL form, ref)? |
| Q6 | Which identities sign Trivy's and Syft's release checksums (to tighten the regexps in `build-sign-attest.yml`)? |

## How it works

One workflow run (`spike.yml`) does everything in CI, nothing locally:

1. **build** — pushes three tiny images to `ghcr.io/warden-ccd/warden-spike-s1`: `signed`, `unsigned`, `foreign`.
2. **sign** — reusable workflow `sign.yml` (mirrors Warden's `sign-attest` job) signs `signed` keylessly and attaches
   SLSA provenance (GitHub), a CycloneDX SBOM and a Trivy vuln report (cosign attest).
3. **foreign-sign** — signs `foreign` from a *non*-reusable job: a valid Fulcio cert with the wrong identity (attack A03).
4. **verify** — CLI evidence (`cosign verify*`, `gh attestation verify`, referrers listing), then a kind cluster
   (Kubernetes 1.37) with Kyverno 1.19.2 and one IVP variant per namespace (`policies/`). Each namespace gets a Pod
   for each image; results land in the job summary and the `spike-s1-evidence` artifact.

Expected: `signed` admitted everywhere, `unsigned` and `foreign` denied everywhere. Any other result is a finding.

Outcome write-up: hub `evidence/spikes/S1.md`.

## Attack fixtures (evaluation E2)

This repo also builds the images the `warden-policy` attack suite needs:

- `attack-fixtures.yml` → `ghcr.io/warden-ccd/attack-fixtures:a03` (wrong signer), `:a07` (modified signed image),
  `:a08` (same digest, signature only).
- `deputy.yml` + the Maven project at the root → `ghcr.io/warden-ccd/warden-spike-s1:<sha>`: built and signed by the
  **real** platform workflow, but from a repository that is not `svc-*` (A04, confused deputy).
