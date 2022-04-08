// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

import { TestUtils } from "../modules/contract-test-utils/contracts/test.sol";

import { IERC20 } from "../modules/erc20/contracts/interfaces/IERC20.sol";

import { Staker }    from "../modules/revenue-distribution-token/contracts/test/accounts/Staker.sol";
import { xMPL }      from "../modules/xmpl/contracts/xMPL.sol";
import { xMPLOwner } from "../modules/xmpl/contracts/test/accounts/Owner.sol";

import { AddressRegistry } from "../contracts/AddressRegistry.sol";

import { IBPoolLike, IMapleTreasuryLike } from "../contracts/Interfaces.sol";

contract xMPLSimulation is AddressRegistry, TestUtils {

    IBPoolLike         internal _balancerPool = IBPoolLike(BALANCER_POOL);
    IERC20             internal _mpl          = IERC20(MPL);
    IERC20             internal _usdc         = IERC20(USDC);
    IMapleTreasuryLike internal _treasury     = IMapleTreasuryLike(MAPLE_TREASURY);

    xMPL      internal _xmpl;
    xMPLOwner internal _owner;

    uint256 internal constant DEPOSIT_SEED = 1;
    uint256 internal constant WARP_SEED    = 2;

    uint256 internal _start;

    function setUp() public virtual {
        _owner  = new xMPLOwner();
        _xmpl   = new xMPL("xMPL", "xMPL", address(_owner), address(_mpl), 1e30);
        _start  = block.timestamp;
    }

    function test_deposits() external {
        // Increase the treasury balance to simulate protocol revenue.
        _generateRevenue(10_000e6);

        // Protocol revenue is used to purchase MPL.
        uint256 mplRewards = _buyMpl(10_000e6);

        // The first MPL deposit is made to enable vesting schedule updates.
        _mintAndDepositMpl(address(new Staker()), 1);

        // MPL is transferred to the xMPL contract and vesting starts.
        uint256 issuanceRate = _issueRewards(mplRewards, 30 days);

        // Store the current state.
        uint256 mplBalance  = 1 + mplRewards;
        uint256 xmplBalance = 1;
        uint256 timeElapsed = 0;
        uint256 freeAssets  = 1;

        // Users continously deposit their MPL into the xMPL contract.
        for (uint256 i = 0; i < 25; i++) {
            Staker staker = new Staker();

            uint256 mplDeposit = constrictToRange(_generateNumber(DEPOSIT_SEED, i), 0.01e18,   10_000e18);
            uint256 warpTime   = constrictToRange(_generateNumber(WARP_SEED,    i), 1 seconds, 1 days);

            vm.warp(block.timestamp + warpTime);

            uint256 xmplAmount = _mintAndDepositMpl(address(staker), mplDeposit);

            // Update the expected current state.
            mplBalance  += mplDeposit;
            xmplBalance += xmplAmount;
            timeElapsed += warpTime;
            freeAssets  += mplDeposit + (issuanceRate * warpTime) / 1e30;

            assertEq(_mpl.balanceOf(address(staker)), 0);
            assertEq(_mpl.balanceOf(address(_xmpl)),  mplBalance);

            assertEq(_xmpl.balanceOf(address(staker)),       xmplAmount);
            assertEq(_xmpl.balanceOfAssets(address(staker)), _xmpl.convertToAssets(xmplAmount));

            assertEq(_xmpl.totalSupply(), xmplBalance);
            assertEq(_xmpl.freeAssets(),  freeAssets);
            assertEq(_xmpl.totalAssets(), freeAssets);

            assertEq(_xmpl.issuanceRate(),        issuanceRate);
            assertEq(_xmpl.lastUpdated(),         block.timestamp);
            assertEq(_xmpl.vestingPeriodFinish(), _start + 30 days);            
        }
    }

    /*************************/
    /*** Utility Functions ***/
    /*************************/

    function _generateRevenue(uint256 usdcAmount_) internal {
        erc20_mint(USDC, 9, MAPLE_TREASURY, usdcAmount_);

        vm.prank(GOVERNOR);
        _treasury.reclaimERC20(USDC, usdcAmount_);
    }

    function _buyMpl(uint256 usdcAmount_) internal returns (uint256 mplAmount_) {
        vm.startPrank(GOVERNOR);

        _usdc.approve(address(_balancerPool), usdcAmount_);
        ( mplAmount_, ) = _balancerPool.swapExactAmountIn({
            tokenIn:       USDC,
            tokenAmountIn: usdcAmount_,
            tokenOut:      MPL,
            minAmountOut:  0,
            maxPrice:      type(uint256).max
        });

        vm.stopPrank();
    }

    function _mintAndDepositMpl(address account_, uint256 mplAmount_) internal returns (uint256 xmplAmount_) {
        erc20_mint(MPL, 0, account_, mplAmount_);

        vm.startPrank(account_);

        _mpl.approve(address(_xmpl), mplAmount_);
        xmplAmount_ = _xmpl.deposit(mplAmount_, account_);

        vm.stopPrank();
    }

    function _issueRewards(uint256 mplAmount_, uint256 vestingPeriod_) internal returns (uint256 issuanceRate_) {
        vm.prank(MAPLE_TREASURY);
        _mpl.transfer(address(_xmpl), mplAmount_);

        vm.prank(address(_owner));
        ( issuanceRate_, ) = _xmpl.updateVestingSchedule(vestingPeriod_);
    }

    function _generateNumber(uint256 seed_, uint256 index_) internal pure returns (uint256 number_) {
        number_ = uint256(keccak256(abi.encodePacked(seed_, index_)));
    }
}
