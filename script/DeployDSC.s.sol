// SPDX-License-Identifier:MIT

pragma solidity ^ 0.8.19;

import {Script} from "forge-std/Script.sol";
import {DefiStableCoin} from "../src/DefiStableCoin.sol";
import {DSCLogic} from "../src/DSCLogic.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (DecentralizedStableCoin, DSCEngine, HelperConfig) {
        HelperConfig config = new HelperConfig ();
        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            config.activeNetworkConfig();

        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast(deployerKey);
        DefiStableCoin dsc = new DefiStableCoin();
        DSCLogic engine = new DSCLogic(tokenAddresses, priceFeedAddresses, address(dsc));
        dsc.transferOwnership(address(engine));
        vm.stopBroadcast();
        return (dsc, engine, config);

        // DSCLogic = new DSCLogic();
    }
}
