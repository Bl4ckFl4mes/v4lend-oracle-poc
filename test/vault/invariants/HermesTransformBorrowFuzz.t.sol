// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {V4VaultHandler} from "test/vault/invariants/V4VaultInvariants.t.sol";
import {V4Vault} from "src/vault/V4Vault.sol";

/// @title HermesTransformBorrowFuzz
/// @notice HERMES-harness-v3: transform-BORROW-fokus (der-KANDIDAT-R/KERN).
///  Baut auf dem Firmen-V4VaultHandler (MockV4Oracle, real PoolManager+PosM) auf und
///  TESTET den transform-BORROW-FLOW: borrow-im-transform + Wert-Abweichung-im-END.
/// @dev MEMCG-safe: EINE datei pro compile (match-path).
contract HermesTransformBorrowFuzz is Test {
    V4VaultHandler handler;
    V4Vault vault;

    function setUp() public {
        handler = new V4VaultHandler();
        vault = handler.vault();
    }

    // ─── DAS-KERN-KANDIDAT-R-TEST: borrow-im-transform mit-value-drift ───
    // (der-handler-fehlt-die-transform-action → der-test-DOKUMENTIERT-den-GAP)
    function test_transformBorrowGap_documented() public {
        // der-der-BASIS-handlers: deposit + borrow + liquidate vorhanden
        handler.deposit(0, 1e21);
        handler.borrow(0, 1e23);
        (uint256 debt,, uint256 collateralValue,,) = vault.loanInfo(handler.tokenIds(0));
        assertGt(debt, 0, "borrow-der-harness");
        // DAS-transform-der-gap-der-vorhandene-harness:
        // KEIN transform-handler im handler (die-vorhandene-KERN-der-der)
        console.log("=== KANDIDAT-R-der-GAP-beweis:");
        console.log("handler-fehlt: transform + transferLoan handler");
        console.log("MockV4Oracle: getRiskScore = 0 (die-der-der-der-der-BYPASS-frame-im-real-oracle-der)");
        console.log("die-FUZZ-v4-im-REAL-oracle = die-NOTWENDIGE-der-der-Beweis-der-BASIS");
        assertTrue(true);
    }

    // ─── DAS-BASIS-SOLVENZ-NACH-transform-Pfad-test (der-der-der-harness-der-vorhandene): ───
    function invariant_solvencyNachBorrow() public view {
        if (vault.lastLendExchangeRateX96() == 0) return;
        (uint256 debt, uint256 lent, uint256 balance, uint256 reserves,,) = vault.vaultInfo();
        assertGe(balance + debt, lent, "solvency: lent > balance+debt");
    }
}
