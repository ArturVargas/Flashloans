pragma solidity ^0.7.2;
pragma experimental ABIEncoderV2;

import "@studydefi/money-legos/dydx/contracts/DydxFlashloanBase.sol";
import "@studydefi/money-legos/dydx/contracts/ICallee.sol";
import {
    KyberNetworkProxy as IKyberNetworkProxy
} from "@studydefi/money-legos/dydx/contracts/KyberNetworkProxy.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IUniswapV2Router02.sol";
import "./IWeth.sol";

contract Flashloan is ICallee, DydxFlashloanBase {
    enum Direction {UniswapToKyber, KyberToUniswap}
    struct ArbInfo {
        Direction direction;
        uint256 repayAmount;
    }
    event NewArbitrage(Direction direction, uint profit, uint date);
    address beneficiary;

    IKyberNetworkProxy kyber;
    IUniswapV2Router02 uniswap;
    IWeth weth;
    IERC20 dai;
    address constant KYBER_ETH_ADDRESS =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    constructor(
        address kyberAddress,
        address uniswapAddress,
        address wethAddress,
        address daiAddress,
        address beneficiaryAddress
    ) public {
        kyber = IKyberNetworkProxy(kyberAddress);
        uniswap = IUniswapV2Router02(uniswapAddress);
        weth = IWeth(wethAddress);
        dai = IERC20(daiAddress);
        beneficiary = beneficiaryAddress;
    }

    function callFunction(
        address sender,
        Account.Info memory account,
        bytes memory data
    ) public {
        ArbInfo memory arbInfo = abi.decode(data, (ArbInfo));
        uint256 balOfDai = dai.balanceOf(address(this));

        if (arbInfo.direction == Direction.KyberToUniswap) {
            // Buy ETH on Kyber //
            dai.approve(address(kyber), balOfDai);
            kyber.getExpectedRate(dai, IERC20(KYBER_ETH_ADDRESS), balOfDai);
            kyber.swapTokenToEther(dai, balOfDai, expectedRate);

            // Sell ETH on Uniswap //
            address[] memory path = new address[](2);
            path[0] = address(weth);
            path[1] = address(dai);
            uint256[] memory minOuts =
                uniswap.getAmountsOut(address(this).balance, path);
            uniswap.swapExactETHForTokens.value(address(this).balance)(
                minOuts[1],
                path,
                address(this),
                now
            );
        } else {
            // Buy on Uniswap
            dai.approve(address(uniswap), balOfDai);
            address[] memory path = new address[](2);
            path[0] = address(dai);
            path[1] = address(weth);
            uint[] memory minOuts = uniswap.getAmountsOut(balOfDai, path);
            uniswap.swapExactTokensForETH(balOfDai, minOuts[1], path, address(this), now);

            // Sell on Kyber
            (uint expectedRate, ) = kyber.getExpectedRate(IERC20(KYBER_ETH_ADDRESS), dai, address(this).balance);
            kyber.swapEtherToToken.value(address(this).balance)(dai, expectedRate);
        }

        require(
            dai.balanceOf(address(this)) >= arbInfo.repayAmount,
            "Not enough funds to repay dydx loan!"
        );

        uint profit = dai.balanceOf(address(this)) - arbInfo.repayAmount;
        dai.transfer(beneficiary, profit);
        emit NewArbitrage(arbInfo.direction, profit, now);
    }

    function initiateFlashloan(
        address _solo,
        address _token,
        uint256 _amount,
        Direction _direction
    ) external {
        ISoloMargin solo = ISoloMargin(_solo);

        // Get marketId from token address
        uint256 marketId = _getMarketIdFromTokenAddress(_solo, _token);

        // Calculate repay amount (_amount + (2 wei))
        // Approve transfer from
        uint256 repayAmount = _getRepaymentAmountInternal(_amount);
        IERC20(_token).approve(_solo, repayAmount);

        // 1. Withdraw $
        // 2. Call callFunction(...)
        // 3. Deposit back $
        Actions.ActionArgs[] memory operations = new Actions.ActionArgs[](3);

        operations[0] = _getWithdrawAction(marketId, _amount);
        operations[1] = _getCallAction(
            // Encode ArbInfo for callFunction
            abi.encode(
                ArbInfo({direction: _direction, repayAmount: repayAmount})
            )
        );
        operations[2] = _getDepositAction(marketId, repayAmount);

        Account.Info[] memory accountInfos = new Account.Info[](1);
        accountInfos[0] = _getAccountInfo();

        solo.operate(accountInfos, operations);
    }

    fallback() external payable {}
}
