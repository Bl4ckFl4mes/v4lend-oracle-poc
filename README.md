# v4lend Transform-oracle-window PoC

**Cantina Competition:** Revert Finance / Revert v4lend (`https://cantina.xyz/competitions/e275368c-547d-4d91-a418-053ad31082a8`)
**Finding:** #1658 — "Transform-End health check uses manipulable oracle window; debt can exceed collateral factor"
**Target commit:** `f6d0fb41b7487f60ce64e011312a956e184e2a75` (`revert-finance/v4lend`, PR #45 merged)
**Author:** BlackFlame (Cantina researcher)

## What this proves

The end-of-transform health check in `V4Vault.transform()` validates the loan
against oracle prices that are manipulable **within the configured deviation
bands** (`maxPoolPriceDifference` / `maxDifference`). A borrower using an
allowlisted transformer can end the transform with `debt > collateralFactor × value`,
and no later check corrects the breach.

Production mode `CHAINLINK_TWAP_VERIFY` is exercised (real `V4Oracle`,
real vault, CF = 0.9): **both** oracle sources (Chainlink feed leg and the
Uniswap v3 TWAP verify leg) are distorted **inside** the allowed band during the
transform callback, the borrow is executed against the inflated valuation,
then both sources snap back to honest values. The loan stays
undercollateralized relative to the collateral factor with honest prices.

Expected numbers (as run locally, foundry):

```
BASIS debt0 = 0, value0 = 5391638920081477348
NACH  debt  = 4867032453157549601   (1.003 · CF · V)
      value = 5391638920081477348 (honest value restored)
debt (4.867e18) > CF · value (4.852e18)  →  ~0.3% permanent CF breach
```

## Files

- `test/vault/invariants/HermesTransformBorrowRealOracle.t.sol` — the actual PoC
  (real `V4Oracle` in `CHAINLINK_TWAP_VERIFY` mode, real vault, allowlisted
  malicious transformer that manipulates both oracle legs inside the deviation
  band and borrows during `transform()`). **This is the v9 harness named in the
  finding.**
- `test/vault/invariants/HermesTransformBorrowFuzz.t.sol` — the earlier mock-based
  harness (documents the transform-handler gap in the project's own invariant
  handler).
- `test/vault/support/V4VaultOracleLiquidationBase.sol` — support base copied
  verbatim from the target commit (`f6d0fb4`).
- `foundry.toml` — target commit's foundry.toml plus a `[profile.cheap]`
  (via_ir=false) profile used to run the PoC locally without OOM.

## Reproduce

```bash
forge clone/pull the target repo at commit f6d0fb41b7487f60ce64e011312a956e184e2a75
# drop the test/ files of this repository into the same paths of the target repo
# (test/vault/support/V4VaultOracleLiquidationBase.sol already exists there — use ours verbatim)
# add the [profile.cheap] block from foundry.toml (or run with default profile and more RAM)

forge test --foundry-profile cheap --match-contract HermesTransformBorrowRealOracle -vv
```

Expected output on the target commit:

```
Ran 1 test for test/vault/invariants/HermesTransformBorrowRealOracle.t.sol:HermesTransformBorrowRealOracle
[PASS] test_borrowInTransformWithTwapManip() (gas: 1313399)
Logs:
  == KANDIDAT-R: transform-with-TWAP-manip
  BASIS debt0= 0 value0= 5391638920081477348
  transform-ok: true
  NACH: debtAfter= 4867032453157549601 valueAfter= 5391638920081477348
Suite result: ok. 1 passed; 0 failed; 0 skipped
```

The test **passes** while demonstrating the breach: the borrow inside the
transform succeeded against the manipulated valuation and the loan now carries
more debt than `collateralFactor × value` at honest prices — the invariant
"debt ≤ CF · value" is broken persistently (until the position's own valuation
breaches again, which corrects nothing retroactively).

## Scope note

- Out of scope per competition rules: trusted roles, MEV, gas griefing.
- This PoC does not rely on any trusted-role abuse: the transformer path used is
  the vault-managed standard production flow (allowlisted transformer called
  through `V4Vault.transform()` by the loan owner); the oracle distortion stays
  strictly inside the deviation bands the oracle itself accepts.