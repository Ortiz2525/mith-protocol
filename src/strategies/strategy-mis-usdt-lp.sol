// SPDX-License-Identifier: MIT
pragma solidity ^0.6.7;

import "./strategy-mith-farm-base.sol";

contract StrategyMisUsdtLp is StrategyMithFarmBase {
    // Token addresses
    address public mith_rewards = 0x14E33e1D6Cc4D83D7476492C0A52b3d4F869d892;
    address public uni_mis_usdt_lp = 0x066F3A3B7C8Fa077c71B9184d862ed0A4D5cF3e0;
    address public token_mis = 0x4b4D2e899658FB59b1D518b68fe836B100ee8958;

    constructor(address _strategist)
        public
        StrategyMithFarmBase(
            token_mis,
            mith_rewards,
            uni_mis_usdt_lp,
            _strategist
        )
    {
        // Redefined the performances fees - 1% goes to the initiator
        performanceInitiatorFee = 100;
        performanceStrategistFee = 200;
    }

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyMisUsdtLp";
    }
}
