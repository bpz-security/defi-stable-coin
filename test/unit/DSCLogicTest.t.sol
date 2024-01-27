// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDsc.s.sol";
import {DefiStableCoin} from "../../src/DefiStableCoin.sol";
import {DSCLogic} from "../../src/DSCLogic.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract DSCLogicTest is Test {
    DeployDSC deployer;
    DefiStableCoin dsc;
    DSCLogic dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address weth;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed,, weth,,) = config.activeNetworkConfig();
    }

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        // need to update expectedUSd price... currently hardcoded , need to use priceFeed to get correct price
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }
}
