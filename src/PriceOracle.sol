// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <=0.8.30;

import "lib/chainlink-evm/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract PriceOracle {
    address public owner;

    mapping(address => AggregatorV3Interface) public priceFeeds; // token address => price feed contract

    uint256 public constant STALE_PRICE_THRESHOLD = 3600; // 1 hour

    //Events
    event PriceFeedSet(address indexed token, address indexed priceFeed);   
    event PriceFeedRemoved(address indexed token);

    //Errors
    error NotOwner();
    error PriceFeedNotSet();
    error InvalidPrice();   
    error StalePriceData();

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if(msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    function setPriceFeed(address token, address priceFeed) external onlyOwner {
        priceFeeds[token] = AggregatorV3Interface(priceFeed);
        emit PriceFeedSet(token, priceFeed);
    }

    function removePriceFeed(address token) external onlyOwner {
        priceFeeds[token] = AggregatorV3Interface(address(0));
    }

    function getPrice(address token) external view returns (uint256) {
        return getChainlinkPrice(token);
    }

function getChainlinkPrice(address token) internal view returns (uint256) {
    AggregatorV3Interface priceFeed = priceFeeds[token];
    if(address(priceFeed) == address(0)) {
        revert PriceFeedNotSet();
    }

    (, int256 price, , uint256 updatedAt, ) = priceFeed.latestRoundData();
    if(price <= 0) {
        revert InvalidPrice();
    }
    if(block.timestamp - updatedAt > STALE_PRICE_THRESHOLD) {
        revert StalePriceData();
    }

    // Normalize to 8 decimals
    uint8 feedDecimals = priceFeed.decimals();
    uint256 adjustedPrice;

    if(feedDecimals < 8) {
        adjustedPrice = uint256(price) * (10 ** (8 - feedDecimals));
    } else if(feedDecimals > 8) {
        adjustedPrice = uint256(price) / (10 ** (feedDecimals - 8));
    } else {
        adjustedPrice = uint256(price);
    }

    return adjustedPrice;
}
}