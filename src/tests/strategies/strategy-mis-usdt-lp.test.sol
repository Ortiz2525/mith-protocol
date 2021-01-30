pragma solidity ^0.6.7;

import "../lib/test-strategy-mith-mis-farm-base.sol";

import "../../interfaces/strategy.sol";
import "../../interfaces/uniswapv2.sol";

import "../../mith-mis-jar.sol";
import "../../strategies/strategy-mis-usdt-lp.sol";

contract StrategyMisUsdtLpTest is StrategyMithMisFarmTestBase {
    function setUp() public {
        want = 0x066F3A3B7C8Fa077c71B9184d862ed0A4D5cF3e0; // Sushiswap MIS-USDT
        token1 = 0x4b4D2e899658FB59b1D518b68fe836B100ee8958; // MIS

        strategist = address(this);

        strategy = IStrategy(
            address(
                new StrategyMisUsdtLp(strategist)
            )
        );

        misJar = new MithMisJar(strategy);

        strategy.setJar(address(misJar));

        // Set time
        hevm.warp(startTime);
    }

    // **** Tests ****

    function test_mic_usdt_withdraw_release() public {
        // strategy.addToWhiteList(strategist);
        // strategy.removeFromWhiteList(strategist);
        _test_withdraw_release();
    }

    function test_mic_usdt_get_earn_harvest_rewards() public {
        _test_get_earn_harvest_rewards();
    }
}
