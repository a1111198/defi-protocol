// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzepplin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DecentralizedStableCoin dsc;
    DSCEngine dscEngine;
    ERC20Mock weth;
    ERC20Mock wbtc;
    uint256 public mintCalled;
    uint256 public mintCalled1;
    uint256 public mintCalled2;
    uint256 public mintCalled4;
    address[] public s_depositors;
    uint256 MAX_COLLETRAL_DEPOSIT = type(uint96).max;
    MockV3Aggregator v3EthPriceFeedAggregator;
    MockV3Aggregator v3BtcPriceFeedAggregator;

    constructor(DecentralizedStableCoin _dsc, DSCEngine _dscEngine) {
        dsc = _dsc;
        dscEngine = _dscEngine;
        address[] memory colletralArray = dscEngine.getAllowedColletrals();
        weth = ERC20Mock(colletralArray[0]);

        wbtc = ERC20Mock(colletralArray[1]);
        v3EthPriceFeedAggregator = MockV3Aggregator(
            dscEngine.getPriceFeed(address(weth))
        );
        v3BtcPriceFeedAggregator = MockV3Aggregator(
            dscEngine.getPriceFeed(address(wbtc))
        );
    }

    function depositColletral(
        uint256 colletralSeed,
        uint256 colleteralAmount
    ) external {
        console.log("CALLED DEposit");
        ERC20Mock colleteral = _getColletralFromSeed(colletralSeed);
        colleteralAmount = bound(colleteralAmount, 1, MAX_COLLETRAL_DEPOSIT);
        vm.startPrank(msg.sender);
        colleteral.mint(msg.sender, colleteralAmount);
        colleteral.approve(address(dscEngine), colleteralAmount);
        dscEngine.depositCollateral(address(colleteral), colleteralAmount);
        s_depositors.push(msg.sender);
        vm.stopPrank();
    }

    function redeemColleteral(
        uint256 colletralSeed,
        uint256 colleteralAmount
    ) external {
        console.log("CALLED Redeem");
        vm.startPrank(msg.sender);
        ERC20Mock colleteral = _getColletralFromSeed(colletralSeed);
        uint256 max_redeem_Colleteral = dscEngine.getColletralValueOfaUser(
            msg.sender,
            address(colleteral)
        );
        uint256 boundColletralAmount = bound(
            colleteralAmount,
            0,
            max_redeem_Colleteral
        );
        if (boundColletralAmount == 0) return;
        if (dscEngine.getHealthFactor(msg.sender) >= 1e18) return;
        console.log("user Balance", max_redeem_Colleteral);
        console.log("bound Amount", boundColletralAmount);

        dscEngine.redeemCollateral(address(colleteral), boundColletralAmount);
        vm.stopPrank();
    }

    function mintDSC(uint256 dscAmount, uint256 senderAddressSeed) external {
        console.log("CALLED Mint DSC");
        if (s_depositors.length == 0) return;
        address sender = s_depositors[senderAddressSeed % s_depositors.length];
        vm.startPrank(sender);
        (uint256 dscMinted, uint256 totalColleteralValueInUSD) = dscEngine
            .getAccountInformation(sender);
        mintCalled1++;
        console.log("ROUND", mintCalled);
        console.log("DSC minted", dscMinted);
        console.log("totla colleteral", totalColleteralValueInUSD);
        uint256 colleteralToMaintainHealthFactor = (totalColleteralValueInUSD /
            2);
        console.log(
            "totla colleteral maintain",
            colleteralToMaintainHealthFactor
        );
        if (colleteralToMaintainHealthFactor <= dscMinted) return;
        uint256 dscCanBeMinted = colleteralToMaintainHealthFactor - dscMinted;
        console.log("CAN BE MINTED", dscCanBeMinted);
        mintCalled2++;
        dscAmount = bound(dscAmount, 0, dscCanBeMinted);
        mintCalled++;
        if (dscAmount == 0) return;
        dscEngine.mintDSC(dscAmount);
    }

    // If prices flutuates too much obvious protocol Invariant breaks in this case.

    // function updatePriceFeed(uint96 ethPrice, uint96 btcPrice) external {
    //     console.log("CALLED UPDATE PRICE FEED");
    //     int256 _ethPrice = int256(uint256(ethPrice));
    //     int256 _btcPrice = int256(uint256(btcPrice));
    //     v3EthPriceFeedAggregator.updateAnswer(_ethPrice);
    //     v3BtcPriceFeedAggregator.updateAnswer(_btcPrice);
    // }

    // function shouldNotRevertOnViewCalls(
    //     address user,
    //     uint256 colleteralSeed,
    //     uint256 amount
    // ) external view {
    //     amount = bound(amount, 0, type(uint96).max);
    //     ERC20Mock colleteral = _getColletralFromSeed(colleteralSeed);
    //     dscEngine.getAccountInformation(user);
    //     dscEngine.getAccountInformation(user);
    //     dscEngine.getAllowedColletrals();
    //     dscEngine.getColletralValueOfaUser(user, address(colleteral));
    //     dscEngine.getDscContractAddress();
    //     dscEngine.getHealthFactor(user);
    //     dscEngine.getPriceFeed(address(colleteral));
    //     dscEngine.getPriceInUSD(address(colleteral), amount);
    //     dscEngine.getTokenValueFromUSD(address(colleteral), amount);
    //     dscEngine.getTotalColleteralValueInUSD(user);
    // }

    function _getColletralFromSeed(
        uint256 seed
    ) private view returns (ERC20Mock) {
        if (seed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}
