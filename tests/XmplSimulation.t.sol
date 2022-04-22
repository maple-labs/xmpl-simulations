// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

import { TestUtils } from "../modules/contract-test-utils/contracts/test.sol";

import { IERC20 } from "../modules/erc20/contracts/interfaces/IERC20.sol";

import { Staker }    from "../modules/revenue-distribution-token/contracts/test/accounts/Staker.sol";
import { xMPL }      from "../modules/xmpl/contracts/xMPL.sol";

import { AddressRegistry } from "../contracts/AddressRegistry.sol";

import { IBPoolLike, IMapleTreasuryLike } from "../contracts/Interfaces.sol";

contract xMPLSimulationBase is AddressRegistry, TestUtils {

    uint256 internal constant DEPOSIT_SEED = 1;
    uint256 internal constant WARP_SEED    = 2;

    uint256 internal START;

    IBPoolLike         internal _balancerPool = IBPoolLike(BALANCER_POOL);
    IERC20             internal _mpl          = IERC20(MPL);
    IERC20             internal _usdc         = IERC20(USDC);
    IMapleTreasuryLike internal _treasury     = IMapleTreasuryLike(MAPLE_TREASURY);

    xMPL internal _xmpl;

    function setUp() public virtual {
        START = block.timestamp;
    }

    // TODO: Check if user depositing after vesting schedule ends work properly.
    // TODO: Check if multiple overlapping/spaced vesting schedule updates work properly.

    /*************************/
    /*** Utility Functions ***/
    /*************************/

    function _buyMpl(uint256 usdcAmount_) internal returns (uint256 mplAmount_) {
        vm.startPrank(GOVERNOR);

        _usdc.approve(address(_balancerPool), usdcAmount_);

        ( mplAmount_, ) = _balancerPool.swapExactAmountIn({
            tokenIn_:       USDC,
            tokenAmountIn_: usdcAmount_,
            tokenOut_:      MPL,
            minAmountOut_:  0,
            maxPrice_:      type(uint256).max
        });

        vm.stopPrank();
    }

    // Adapted from https://stackoverflow.com/questions/47129173/how-to-convert-uint-to-string-in-solidity
    function _convertUintToString(uint256 input_) internal pure returns (string memory output_) {
        if (input_ == 0) return "0";

        uint256 j = input_;
        uint256 length;

        while (j != 0) {
            length++;
            j /= 10;
        }

        bytes memory output = new bytes(length);
        uint256 k = length;

        while (input_ != 0) {
            k = k - 1;

            uint8 temp = (48 + uint8(input_ - input_ / 10 * 10));
            bytes1 b1  = bytes1(temp);

            output[k] = b1;
            input_ /= 10;
        }

        return string(output);
    }

    function _distributeRevenue(uint256 mplAmount_, uint256 vestingPeriod_) internal returns (uint256 issuanceRate_) {
        vm.startPrank(GOVERNOR);
        _mpl.transfer(address(_xmpl), mplAmount_);

        ( issuanceRate_, ) = _xmpl.updateVestingSchedule(vestingPeriod_);
        vm.stopPrank();
    }

    function _generateNumber(uint256 seed_, uint256 index_) internal pure returns (uint256 number_) {
        number_ = uint256(keccak256(abi.encodePacked(seed_, index_)));
    }

    function _generateRevenue(uint256 usdcAmount_) internal {
        erc20_mint(USDC, 9, MAPLE_TREASURY, usdcAmount_);

        vm.prank(GOVERNOR);
        _treasury.reclaimERC20(USDC, usdcAmount_);
    }

    function _mintMpl(address account_, uint256 mplAmount_) internal {
        erc20_mint(MPL, 0, account_, mplAmount_);
    }

    function _mintMplAndDistributeRevenue(uint256 mplAmount_, uint256 vestingPeriod_) internal {
        _mintMpl(GOVERNOR, mplAmount_);
        _distributeRevenue(mplAmount_, vestingPeriod_);
    }

    function _logState(uint256 month_, uint256 mplDistribution_, string memory filePath_) internal  {
        _writeToFile("--------------", filePath_);
        _writeToFile("Month ", month_, filePath_);
        _writeToFile("--------------", filePath_);

        _writeToFile("MPL Distributed: ", mplDistribution_ * 100 / 1e18,                                         filePath_);
        _writeToFile("MPL Issued-----: ", _xmpl.issuanceRate() * 30 days * 100 / 1e30 / 1e18,                    filePath_);
        _writeToFile("Exchange Rate--: ", _xmpl.convertToAssets(10_000),                                         filePath_);
        _writeToFile("Total Supply---: ", _xmpl.totalSupply() * 100 / 1e18,                                      filePath_);
        _writeToFile("Total Assets---: ", _xmpl.totalAssets() * 100 / 1e18,                                      filePath_);
        _writeToFile("IssuanceRate---: ", _xmpl.issuanceRate() / 1e30,                                           filePath_);
        _writeToFile("APY------------: ", _xmpl.issuanceRate() * 365 days * 10_000 / _xmpl.totalAssets() / 1e30, filePath_);

        _writeToFile(" ", filePath_);
    }

    function _mintAndDepositMpl(address account_, uint256 mplAmount_) internal returns (uint256 xmplAmount_) {
        erc20_mint(MPL, 0, account_, mplAmount_);

        vm.startPrank(account_);

        _mpl.approve(address(_xmpl), mplAmount_);
        xmplAmount_ = _xmpl.deposit(mplAmount_, account_);

        vm.stopPrank();
    }

    function _rmFile(string memory filePath) internal {
        string[] memory inputs = new string[](3);
        inputs[0] = "scripts/rm-file.sh";
        inputs[1] = "-f";
        inputs[2] = filePath;

        vm.ffi(inputs);
    }

    function _setMplPrice(uint256 newMplPrice_) internal {
        uint256 mplWeight  = _balancerPool.getDenormalizedWeight(MPL);
        uint256 usdcWeight = _balancerPool.getDenormalizedWeight(USDC);
        uint256 mplBal     = _balancerPool.getBalance(MPL);
        uint256 usdcBal    = _balancerPool.getBalance(USDC);
        uint256 swapFee    = _balancerPool.getSwapFee();

        uint256 usdcDepositAmount = ((usdcWeight * newMplPrice_) * (1e18 - swapFee) * (mplBal / mplWeight) / 1e18 / 1e18) - usdcBal;

        erc20_mint(USDC, 9, address(this), usdcDepositAmount);
        _usdc.approve(BALANCER_POOL, usdcDepositAmount);
        _balancerPool.joinswapExternAmountIn(USDC, usdcDepositAmount, 0);
    }

    function _writeToFile(string memory line, string memory filePath) internal {
        string[] memory inputs = new string[](5);
        inputs[0] = "scripts/write-to-file.sh";
        inputs[1] = "-f";
        inputs[2] = filePath;
        inputs[3] = "-i";
        inputs[4] = line;

        vm.ffi(inputs);
    }

    function _writeToFile(string memory key, uint256 value, string memory filePath) internal {
        string memory line = string(abi.encodePacked(key, _convertUintToString(value)));

        _writeToFile(line, filePath);
    }

}

// Spreadsheet https://docs.google.com/spreadsheets/d/17OrOxwvLpr8FJTswe-Wn_kz14JJhFPIR/edit#gid=1922218837
contract xMPLSimulation1 is xMPLSimulationBase {

    function _runSimulation(
        uint256[24] memory mplDistributions_,
        uint256 totalDeposited_,
        uint256 vestingPeriod_,
        uint256 initialFeeDeposit_,
        string memory filePath_
    )
        internal
    {
        vm.warp(START);

        _xmpl = new xMPL("xMPL", "xMPL", GOVERNOR, MPL, 1e30);

        Staker staker1 = new Staker();
        Staker staker2 = new Staker();
        Staker staker3 = new Staker();

        /***************************/
        /*** Governor xMPL Setup ***/
        /***************************/

        // Stake initial amount of MPL (1 MPL) to seed contract
        _mintAndDepositMpl(address(staker1), 1e18);

        uint256 mplFromInitialFeeDeposit = initialFeeDeposit_ * 1e12 / 50;

        // Initial Fee Deposit + Month 1 fee revenue
        _mintMplAndDistributeRevenue(mplDistributions_[0] + mplFromInitialFeeDeposit, vestingPeriod_);

        /************************/
        /*** Initial Deposits ***/
        /************************/

        // Stake second amount of MPL (999,999 MPL) to seed contract
        _mintAndDepositMpl(address(staker2), 999_999e18);

        // Stake second amount of MPL (2m MPL) to seed contract (30% of circulating supply staked)
        _mintAndDepositMpl(address(staker3), totalDeposited_ - 1_000_000e18);

        /********************************************/
        /*** All Governance Revenue Distributions ***/
        /********************************************/

        for (uint256 i = 1; i < mplDistributions_.length - 1; ++i) {
            vm.warp(START + 30 days * i);

            uint256 mplDistribution = i == 1 ? mplDistributions_[0] + mplFromInitialFeeDeposit : mplDistributions_[i - 1];
            _logState(i, mplDistribution, filePath_);
            _mintMplAndDistributeRevenue(mplDistributions_[i], vestingPeriod_);
        }
    }

    function test_runAllSimulations() public {
        uint256[24] memory mplDistributions = [
            uint256(3_254e18),  // Month 1  =>   162,739 @ 50.00  USDC (not including initial deposit)
            uint256(3_410e18),  // Month 2  =>   179,014 @ 52.50  USDC
            uint256(3_572e18),  // Month 3  =>   196,915 @ 55.13  USDC
            uint256(3_742e18),  // Month 4  =>   216,607 @ 57.88  USDC
            uint256(3_920e18),  // Month 5  =>   238,267 @ 60.78  USDC
            uint256(4_107e18),  // Month 6  =>   262,094 @ 63.81  USDC
            uint256(4_303e18),  // Month 7  =>   288,303 @ 67.00  USDC
            uint256(4_508e18),  // Month 8  =>   317,134 @ 70.36  USDC
            uint256(4_722e18),  // Month 9  =>   348,847 @ 73.87  USDC
            uint256(4_947e18),  // Month 10 =>   383,732 @ 77.57  USDC
            uint256(5_183e18),  // Month 11 =>   422,105 @ 81.44  USDC
            uint256(5_430e18),  // Month 12 =>   464,315 @ 85.52  USDC
            uint256(5_688e18),  // Month 13 =>   510,747 @ 89.79  USDC
            uint256(5_959e18),  // Month 14 =>   561,822 @ 94.28  USDC
            uint256(6_243e18),  // Month 15 =>   618,004 @ 99.00  USDC
            uint256(6_540e18),  // Month 16 =>   679,804 @ 103.95 USDC
            uint256(6_851e18),  // Month 17 =>   747,785 @ 109.14 USDC
            uint256(7_178e18),  // Month 18 =>   822,563 @ 114.60 USDC
            uint256(7_519e18),  // Month 19 =>   904,819 @ 120.33 USDC
            uint256(7_877e18),  // Month 20 =>   995,301 @ 126.35 USDC
            uint256(8_253e18),  // Month 21 => 1,094,831 @ 132.66 USDC
            uint256(8_646e18),  // Month 22 => 1,204,315 @ 139.30 USDC
            uint256(9_057e18),  // Month 23 => 1,324,746 @ 146.26 USDC
            uint256(9_489e18)   // Month 24 => 1,457,221 @ 153.58 USDC
        ];

        uint256[7] memory totalDeposits = [
            uint256(1_500_000e18),
            uint256(2_000_000e18),
            uint256(2_200_000e18),
            uint256(2_266_000e18),
            uint256(2_333_980e18),
            uint256(2_403_999e18),
            uint256(2_476_119e18)
        ];

        uint256[3] memory vestingPeriods     = [uint256(90 days), uint256(180 days), uint256(270 days)];
        uint256[2] memory initialFeeDeposits = [uint256(1_250_000_000000), uint256(1_500_000_000000)];

        uint256 count;

        for (uint256 i; i < totalDeposits.length; ++i) {
            for (uint256 j; j < vestingPeriods.length; ++j) {
                for (uint256 k; k < initialFeeDeposits.length; ++k) {
                    string memory totalDeposit      = _convertUintToString(totalDeposits[i] / 1e18);
                    string memory vestingPeriod     = _convertUintToString(vestingPeriods[j] / 30 days);
                    string memory initialFeeDeposit = _convertUintToString(initialFeeDeposits[k] / 1e6);

                    string memory filePath = string(abi.encodePacked(
                        "simulation-output/sim_",
                        _convertUintToString(++count),
                        "_",
                        totalDeposit,
                        "_deposits_",
                        vestingPeriod,
                        "_mo_vesting_",
                        initialFeeDeposit,
                        "_initial_fee_deposit.txt"
                    ));

                    _rmFile(filePath);
                    _writeToFile("--------------------------",  filePath);
                    _writeToFile("Total MPL Deposits-------: ", totalDeposits[i] / 1e18,     filePath);
                    _writeToFile("Vesting Schedule (Months): ", vestingPeriods[j] / 30 days, filePath);
                    _writeToFile("Initial Fee Deposit------: ", initialFeeDeposits[k] / 1e6, filePath);
                    _writeToFile("--------------------------",  filePath);
                    _writeToFile(" ", filePath);

                    _runSimulation(
                        mplDistributions,
                        totalDeposits[i],
                        vestingPeriods[j],
                        initialFeeDeposits[k],
                        filePath
                    );
                }
            }
        }
    }

}
