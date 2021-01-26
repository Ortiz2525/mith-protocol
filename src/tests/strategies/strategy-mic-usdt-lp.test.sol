pragma solidity ^0.6.7;

import "../lib/test-strategy-mith-farm-base.sol";

import "../../interfaces/strategy.sol";
import "../../interfaces/uniswapv2.sol";

import "../../mith-jar.sol";
import "../../strategies/strategy-mic-usdt-lp.sol";

contract StrategyMicUsdtLpTest is StrategyMithFarmTestBase {
    function setUp() public {
        want = 0xC9cB53B48A2f3A9e75982685644c1870F1405CCb; // Sushiswap MIC-USDT
        token1 = 0x368B3a58B5f49392e5C9E4C998cb0bB966752E51; // MIC

        strategist = address(this);

        strategy = IStrategy(
            address(
                new StrategyMicUsdtLp(strategist)
            )
        );

        mithJar = new MithJar(strategy);

        strategy.setJar(address(mithJar));
        strategy.addToWhiteList(strategist);

        // Set time
        hevm.warp(startTime);
    }

    // **** Tests ****

    function test_mic_usdt_withdraw_release() public {
        _test_withdraw_release();
    }

    function test_mic_usdt_get_earn_harvest_rewards() public {
        _test_get_earn_harvest_rewards();
    }
}
