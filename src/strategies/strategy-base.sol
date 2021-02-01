pragma solidity ^0.6.7;

import "../lib/erc20.sol";
import "../lib/safe-math.sol";

import "../interfaces/jar.sol";
import "../interfaces/staking-rewards.sol";
import "../interfaces/uniswapv2.sol";

// Strategy Contract Basics

abstract contract StrategyBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    // Performance Fee addresses and staking contract address
    address public initiator = 0xb919F030B334A20424e942E77d22b99dAdf15B4B;
    address public stakingContract;
    address public treasury = 0xdC11e3B995845a94531D45b563C053AFaddC9aDC;

    // Performance fees - start with 3%
    uint256 public performanceInitiatorFee = 75;
    // 12% fee has been sent to staking pool/treasury as mis upfront, so should be divided by 8800
    uint256 public constant performanceInitiatorMax = 8800;

    uint256 public performanceStrategistFee = 225;
    uint256 public constant performanceStrategistMax = 8800;

    // Tokens
    address public want;
    address public constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // User accounts
    address public strategist;
    address public jar;

    // Dex
    address public univ2Router2 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public sushiRouter = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;

    mapping(address => bool) whiteList;

    constructor(
        address _want,
        address _strategist
    ) public {
        require(_want != address(0));
        require(_strategist != address(0));

        whiteList[_strategist] = true;
        whiteList[initiator] = true;

        want = _want;
        strategist = _strategist;
    }

    // **** Modifiers **** //

    modifier onlyBenevolent {
        require(
            msg.sender == tx.origin || msg.sender == strategist
        );
        _;
    }

    // **** Views **** //

    function balanceOfWant() public view returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    function balanceOfPool() public virtual view returns (uint256);

    function getHarvestable() external virtual view returns (uint256);

    function balanceOf() public view returns (uint256) {
        return balanceOfWant().add(balanceOfPool());
    }

    function getName() external virtual pure returns (string memory);

    // **** Setters **** //

    function setInitiator(address _initiator) external {
        require(msg.sender == initiator, "!initiator");
        initiator = _initiator;
    }

    function setStakingContract(address _stakingContract) external {
        require(msg.sender == strategist, "Not strategist");
        require(stakingContract == address(0), "Staking Contract already set");
        stakingContract = _stakingContract;
    }

    function setJar(address _jar) external {
        require(msg.sender == strategist, "Not strategist");
        require(jar == address(0), "jar already set");
        jar = _jar;
    }

    // **** State mutations **** //
    function deposit() public virtual;

    // Jar only function for creating additional rewards from dust
    function withdraw(IERC20 _asset) external returns (uint256 balance) {
        require(msg.sender == jar, "!jar");
        require(want != address(_asset), "want");
        balance = _asset.balanceOf(address(this));
        _asset.safeTransfer(jar, balance);
    }

    // Withdraw partial funds, normally used with a jar withdrawal
    function withdraw(uint256 _amount) external {
        require(msg.sender == jar, "!jar");
        uint256 _balance = IERC20(want).balanceOf(address(this));
        if (_balance < _amount) {
            _amount = _withdrawSome(_amount.sub(_balance));
            _amount = _amount.add(_balance);
        }

        IERC20(want).safeTransfer(jar, _amount);
    }

    // Withdraw funds, used to swap between strategies
    function withdrawForSwap(uint256 _amount)
        external
        returns (uint256 balance)
    {
        require(msg.sender == jar, "!jar");
        _withdrawSome(_amount);

        balance = IERC20(want).balanceOf(address(this));

        IERC20(want).safeTransfer(jar, balance);
    }

    function _withdrawAll() internal {
        _withdrawSome(balanceOfPool());
    }

    function _withdrawSome(uint256 _amount) internal virtual returns (uint256);

    function harvest() public virtual;

    // **** Emergency functions ****

    function execute(address _target, bytes memory _data)
        public
        payable
        returns (bytes memory response)
    {
        require(msg.sender == strategist, "Not strategist");
        require(_target != address(0), "!target");

        // call contract in current context
        assembly {
            let succeeded := delegatecall(
                sub(gas(), 5000),
                _target,
                add(_data, 0x20),
                mload(_data),
                0,
                0
            )
            let size := returndatasize()

            response := mload(0x40)
            mstore(
                0x40,
                add(response, and(add(add(size, 0x20), 0x1f), not(0x1f)))
            )
            mstore(response, size)
            returndatacopy(add(response, 0x20), 0, size)

            switch iszero(succeeded)
                case 1 {
                    // throw if delegatecall failed
                    revert(add(response, 0x20), size)
                }
        }
    }

    // **** Internal functions ****
    function _swapUniswap(
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        require(_to != address(0));

        // Swap with uniswap
        IERC20(_from).safeApprove(univ2Router2, 0);
        IERC20(_from).safeApprove(univ2Router2, _amount);

        address[] memory path;

        if (_from == weth || _to == weth) {
            path = new address[](2);
            path[0] = _from;
            path[1] = _to;
        } else {
            path = new address[](3);
            path[0] = _from;
            path[1] = weth;
            path[2] = _to;
        }

        UniswapRouterV2(univ2Router2).swapExactTokensForTokens(
            _amount,
            0,
            path,
            address(this),
            now.add(60)
        );
    }

    function _swapUniswapWithPath(
        address[] memory path,
        uint256 _amount
    ) internal {
        require(path[1] != address(0));

        // Swap with uniswap
        IERC20(path[0]).safeApprove(univ2Router2, 0);
        IERC20(path[0]).safeApprove(univ2Router2, _amount);

        UniswapRouterV2(univ2Router2).swapExactTokensForTokens(
            _amount,
            0,
            path,
            address(this),
            now.add(60)
        );
    }

    function _swapSushiswap(
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        require(_to != address(0));

        // Swap with uniswap
        IERC20(_from).safeApprove(sushiRouter, 0);
        IERC20(_from).safeApprove(sushiRouter, _amount);

        address[] memory path;

        if (_from == weth || _to == weth) {
            path = new address[](2);
            path[0] = _from;
            path[1] = _to;
        } else {
            path = new address[](3);
            path[0] = _from;
            path[1] = weth;
            path[2] = _to;
        }

        UniswapRouterV2(sushiRouter).swapExactTokensForTokens(
            _amount,
            0,
            path,
            address(this),
            now.add(60)
        );
    }

    function _swapSushiswapWithPath(
        address[] memory path,
        uint256 _amount
    ) internal {
        require(path[1] != address(0));

        // Swap with uniswap
        IERC20(path[0]).safeApprove(sushiRouter, 0);
        IERC20(path[0]).safeApprove(sushiRouter, _amount);

        UniswapRouterV2(sushiRouter).swapExactTokensForTokens(
            _amount,
            0,
            path,
            address(this),
            now.add(60)
        );
    }

    function _distributePerformanceFeesAndDeposit() internal {
        uint256 _want = IERC20(want).balanceOf(address(this));

        if (_want > 0) {
            // Initiator fee
            IERC20(want).safeTransfer(
                initiator,
                _want.mul(performanceInitiatorFee).div(performanceInitiatorMax)
            );

            // Strategist fee
            IERC20(want).safeTransfer(
                strategist,
                _want.mul(performanceStrategistFee).div(performanceStrategistMax)
            );

            deposit();
        }
    }

    function addToWhiteList(address _address) public {
        require(msg.sender == strategist, "Not strategist");
        whiteList[_address] = true;
    }

    function removeFromWhiteList(address _address) public {
        require(msg.sender == strategist, "Not strategist");
        whiteList[_address] = false;
    }

    function isWhitelisted(address _address) public view returns(bool) {
        return whiteList[_address];
    }
}
