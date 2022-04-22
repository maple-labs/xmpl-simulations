// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

interface IBPoolLike {

    function getBalance(address token_) external view returns (uint256 balance_);

    function getDenormalizedWeight(address token_) external view returns (uint256 weight_);

    function getSpotPrice(address tokenIn_, address tokenOut_) external view returns (uint256 price_);

    function getSwapFee() external view returns (uint256 swapFee_);

    function joinswapExternAmountIn(address tokenIn_, uint256 tokenAmountIn_, uint256 minPoolAmountOut_) external;

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
