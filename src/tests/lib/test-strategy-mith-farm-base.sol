pragma solidity ^0.6.7;

import "../lib/hevm.sol";
import "../lib/user.sol";
import "../lib/test-approx.sol";
import "../lib/test-sushi-base.sol";

import "../../interfaces/strategy.sol";
import "../../interfaces/uniswapv2.sol";

import "../../mith-jar.sol";

contract StrategyMithFarmTestBase is DSTestSushiBase {
    address want;
    address token1;

    address strategist;

    address mis = 0x4b4D2e899658FB59b1D518b68fe836B100ee8958;

    uint256 performanceInitiatorFee = 75;
    uint256 performanceStrategistFee = 225;
    uint256 stakingContractFee = 1200;

    MithJar mithJar;
    IStrategy strategy;

    function _getWant(uint256 usdtAmount, uint256 amount) internal {
        address[] memory path = new address[](3);
        path[0] = weth;
        path[1] = usdt;
        path[2] = token1;

        _getERC20(usdt, usdtAmount);
        _getERC20WithPath(amount, path);

        uint256 _usdt = IERC20(usdt).balanceOf(address(this));
        uint256 _token1 = IERC20(token1).balanceOf(address(this));

        IERC20(usdt).safeApprove(address(sushiRouter), 0);
        IERC20(usdt).safeApprove(address(sushiRouter), _usdt);

        IERC20(token1).safeApprove(address(sushiRouter), 0);
        IERC20(token1).safeApprove(address(sushiRouter), _token1);

        sushiRouter.addLiquidity(
            usdt,
            token1,
            _usdt,
            _token1,
            0,
            0,
            address(this),
            now + 60
        );
    }

    // **** Tests ****

    function _test_withdraw_release() internal {
        uint256 decimals = ERC20(token1).decimals();
        _getWant(10000 * 10 ** 6, 4000 * (10**decimals)); // USDT decimals is 6
        uint256 _want = IERC20(want).balanceOf(address(this));
        IERC20(want).safeApprove(address(mithJar), 0);
        IERC20(want).safeApprove(address(mithJar), _want);
        mithJar.deposit(_want);
        mithJar.earn();
        hevm.warp(block.timestamp + 1 weeks);
        strategy.harvest();

        uint256 _before = IERC20(want).balanceOf(address(this));
        mithJar.withdrawAll();
        uint256 _after = IERC20(want).balanceOf(address(this));
        assertTrue(_after > _before);

        // Check if we gained interest
        assertTrue(_after > _want);
    }

    function _test_get_earn_harvest_rewards() internal {
        uint256 decimals = ERC20(token1).decimals();
        _getWant(10000 * 10 ** 6, 4000 * (10**decimals)); // USDT decimals is 6
        uint256 _want = IERC20(want).balanceOf(address(this));
        IERC20(want).safeApprove(address(mithJar), 0);
        IERC20(want).safeApprove(address(mithJar), _want);
        mithJar.deposit(_want);
        mithJar.earn();
        hevm.warp(block.timestamp + 1 weeks);

        // Call the harvest function
        uint256 _before = mithJar.balance();
        uint256 _strategistBefore = IERC20(want).balanceOf(strategist);
        uint256 _initiatorBefore = IERC20(want).balanceOf(strategy.initiator());

        uint256 _stakingContractBefore;
        if (strategy.stakingContract() != address(0)) {
            _stakingContractBefore = IERC20(mis).balanceOf(strategy.stakingContract());
        } else {
            _stakingContractBefore = IERC20(mis).balanceOf(strategy.treasury());
        }

        uint256 misRewards = strategy.getHarvestable();
        strategy.harvest();

        uint256 _after = mithJar.balance();
        uint256 _strategistAfter = IERC20(want).balanceOf(strategist);
        uint256 _initiatorAfter = IERC20(want).balanceOf(strategy.initiator());
        
        uint256 _stakingContractAfter;
        if (strategy.stakingContract() != address(0)) {
            _stakingContractAfter = IERC20(mis).balanceOf(strategy.stakingContract());
        } else {
            _stakingContractAfter = IERC20(mis).balanceOf(strategy.treasury());
        }

        uint256 earned = _after.sub(_before).mul(1000).div(850);
        uint256 strategistRewards = earned.mul(performanceStrategistFee).div(10000); // 2.25%
        uint256 initiatorRewards = earned.mul(performanceInitiatorFee).div(10000); // 0.75%
        uint256 stakingContractRewards = misRewards.mul(stakingContractFee).div(10000); // 12%

        uint256 strategistRewardsEarned = _strategistAfter.sub(_strategistBefore);
        uint256 initiatorRewardsEarned = _initiatorAfter.sub(_initiatorBefore);
        uint256 stakingContractRewardsEarned = _stakingContractAfter.sub(_stakingContractBefore);

        // 2.25% strategist fee is given
        assertEqApprox(strategistRewards, strategistRewardsEarned);

        // 0.75% initiator fee is given
        assertEqApprox(initiatorRewards, initiatorRewardsEarned);

        // 12% goes to staking contract
        assertEqApprox(stakingContractRewards, stakingContractRewardsEarned);
    }
}
