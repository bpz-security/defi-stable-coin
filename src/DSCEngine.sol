// SPDX-License-Identifier : MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";




/**
 * @title DSCEngine
 * System is design to be as minimal as possible, and have token maintain a 1 token == $1 peg.
 * Stablecoin properties:
 * - Exogenous Collateral
 * - Dollar Pegged
 * - Algoritmically Stable
 *
 * System is similar to DAI if DAI had no governane, fees and was only backed by WETH and WBTC.
 * Our DSC system should always be "overcollateralized". At no point, should the value of ALL Collateral be less than or equal to backed value of All the DSC.
 * @notice This contract is the core of the DSC system. It handles all the logic for mining and redeeming DSc, as well as depositing & withdrawing collateral.
 * @notice This contract is loosely based on the MakerDAO DSS (DAI) system.
 */
contract DSCEngine is ReentrancyGuard {
    ////////////////
    // Errors  //
    ///////////////
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__MintFailed();

    /////////////////
    // State Variables //
    ///////////////

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10; 
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // need to be 200 % over collateral 
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    mapping(address token => address priceFeed) private s_priceFeeds; // tokenToPriceFeed
    // token address is match to priceFeed address

    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    // map user balances to mapping of token which map to amount token that they have.

    mapping(address user => uint256 amountDscMinted ) private s_DSCMinted; 
    // keep track of how much DSC is being minted by an user. 
    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_dsc;

    /////////////////
    // Events //
    ///////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);


    /////////////////
    // Modifiers  //
    ///////////////

    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }

        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    /////////////////
    // Functions  //
    ///////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        // loop through token address array
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i]; // set price feed so token of i EQUAL priceFeed of I .. Set up what tokens are allow.
                // if token have a priceFeed then it's allow..
                s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    /////////////////
    // External Functions  //
    ///////////////

    function depositCollateralAndMintDsc() external {}

    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        // Emit an event since we are updated a State .  Updated collateral, internally 
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        // emit collateral deposited the person who is deposited, token address and colllateral amount 
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this),amountCollateral);
        if (!success){
            revert DSCEngine__TransferFailed();
        }
    }

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    function burnDsc() external {}
    /*
    * @param amountDscToMint = The amount of Decentralized stablecoin to mint
    * must have more collateral value than min Threshold.
    // check if Collateral value is greater than DSC amount.
    // need to check price feed , values, and etc. 
    */ 
    function mintDsc(uint256 amountDscToMint) external moreThanZero (amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }

    }

    function liquidate() external {}

    function getHealthFactor() external view {}

    /////////////////
    // Private & Internal View Functions  //
    ///////////////

    /*
    * _health factor Returns how CLOSE to liquidation a user is
    *If a user goes below 1, then they can get liquidated. 
    * this is use to figure out ratio of Collateral to USDC that a user can have. 
    */

    function _getAccountInformation (address user) private view returns (uint256 totalDscMinted, uint256 collateralValueInUsd){
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);

    }

    function _healthFactor(address user) private view returns (uint256){

        // total DSC minted
        // total collateral VALUE
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted; 

    }
    function _revertIfHealthFactorIsBroken(address user) internal view {
        //1. Check health Factor ( do they have enough collateral ?)
        //2. Revert if they don't have a good health factor 
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }

    }
       /////////////////
    // Public & External View Functions  //
    ///////////////
    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for(uint256 i = 0; i < s_collateralTokens.length; i++){
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
        
    }
    function getUsdValue(address token, uint256 amount) public view returns(uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (,int256 price,,,) = priceFeed.latestRoundData();
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / 1e18;

        // 1 ETH = $1000
        // The returned value from CL will be 1000 * 1e18
        

    }

}
