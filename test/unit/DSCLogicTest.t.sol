// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDsc.s.sol";
import {DefiStableCoin} from "../../src/DefiStableCoin.sol";
import {DSCLogic} from "../../src/DSCLogic.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {ERC20Mock} from "openzeppelin/contracts/mocks/ERC20Mock.sol";

contract DSCLogicTest is Test {
    DeployDSC deployer;
    DefiStableCoin dsc;
    DSCLogic dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed,btcUsdPriceFeed, weth,,) = config.activeNetworkConfig();
    }

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCLogic.
        DSCLogic__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCLogic(tokenAddresses, priceFeedAddresses, address(dsc));

    }

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        // need to update expectedUSd price... currently hardcoded , need to use priceFeed to get correct price
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }
}
