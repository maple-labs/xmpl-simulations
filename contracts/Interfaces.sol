// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

interface IBPoolLike {

    function swapExactAmountIn(
        address tokenIn_,
        uint256 tokenAmountIn_,
        address tokenOut_,
        uint256 minAmountOut_,
        uint256 maxPrice_
    )
        external
        returns (uint256 tokenAmountOut_, uint256 spotPriceAfter_);
}

interface IMapleTreasuryLike {

    function reclaimERC20(address asset_, uint256 amount_) external;

}
