// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

interface IBPoolLike {

    function swapExactAmountIn(address tokenIn, uint256 tokenAmountIn, address tokenOut, uint256 minAmountOut, uint256 maxPrice) external;
}

interface IMapleTreasuryLike {

    function reclaimERC20(address asset_, uint256 amount_) external;

}
