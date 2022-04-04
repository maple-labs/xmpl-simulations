// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

import { TestUtils } from "../modules/contract-test-utils/contracts/test.sol";
import { IERC20 }    from "../modules/erc20/contracts/interfaces/IERC20.sol";
import { Staker }    from "../modules/revenue-distribution-token/contracts/test/accounts/Staker.sol";
import { xMPL }      from "../modules/xmpl/contracts/xMPL.sol";
import { xMPLOwner } from "../modules/xmpl/contracts/test/accounts/Owner.sol";

import { AddressRegistry } from "../contracts/AddressRegistry.sol";

import { IBPoolLike, IMapleTreasuryLike } from "../contracts/interfaces/Interfaces.sol";

contract xMPLSimulation is AddressRegistry, TestUtils {

    IBPoolLike         bPool    = IBPoolLike(BALANCER_POOL);
    IERC20             mpl      = IERC20(MPL);
    IERC20             usdc     = IERC20(USDC);
    IMapleTreasuryLike treasury = IMapleTreasuryLike(MAPLE_TREASURY);

    Staker    staker;
    xMPL      xmpl;
    xMPLOwner owner;

    function setUp() public virtual {
        staker = new Staker();
        owner  = new xMPLOwner();
        xmpl   = new xMPL("xMPL", "xMPL", address(owner), address(mpl), 1e30);
    }

    function test_setUpVesting() public {
        erc20_mint(USDC, 9, MAPLE_TREASURY, 1_000_000e6);

        vm.startPrank(GOVERNOR);
        treasury.reclaimERC20(USDC, 1_000_000e6);

        usdc.approve(address(bPool), 1_000_000e6);

        bPool.swapExactAmountIn({
            tokenIn:       USDC,
            tokenAmountIn: 1000e6,
            tokenOut:      MPL,
            minAmountOut:  0,
            maxPrice:      type(uint256).max
        });
    }

}
