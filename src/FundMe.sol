// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import {PriceConverter} from "./PriceConverter.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

error FundMeErr_NotOwner();

contract FundMe {
    address private immutable i_owner;
    AggregatorV3Interface private s_priceFeed;

    using PriceConverter for uint256; // attaching the converter library to all uint256

    uint256 public constant MINIMUM_USD = 5 * (10 ** 18); // 5e18

    address[] private s_funders;
    mapping(address funder => uint256 amountFunded)
        private s_addressToAmountFunded;

    constructor(address priceFeed) {
        i_owner = msg.sender;
        s_priceFeed = AggregatorV3Interface(priceFeed);
    }

    modifier onlyOwner() {
        require(msg.sender == i_owner, "You are not the owner");
        if (msg.sender != i_owner) {
            revert FundMeErr_NotOwner();
        }
        _;
    }

    function fund() public payable {
        require(
            msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD,
            "You cant send less than 1 ETH"
        );

        s_funders.push(msg.sender);
        s_addressToAmountFunded[msg.sender] += msg.value;
    }

    function cheaperWithdraw() public onlyOwner {
        uint256 fundersLength = s_funders.length;
        for (uint256 funderIdx = 0; funderIdx < fundersLength; funderIdx++) {
            address funder = s_funders[funderIdx];
            uint256 amount = s_addressToAmountFunded[funder];
            s_addressToAmountFunded[funder] = 0;

            s_funders = new address[](0);
            (bool success, ) = funder.call{value: amount}("");
            require(success, "Withdrawal failed");
        }
    }

    function withdraw() public onlyOwner {
        for (
            uint256 funderIndex = 0;
            funderIndex < s_funders.length;
            funderIndex++
        ) {
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        // resettting the funders array
        s_funders = new address[](0);

        // withdraw the funds
        // payable(msg.sender).transfer(address(this).balance);
        // bool sendSuccess = payable(msg.sender).send(address(this).balance);
        // require(sendSuccess, "Send failed!");
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }

    function getVersion() public view returns (uint256) {
        return s_priceFeed.version();
    }

    receive() external payable {
        fund();
    }

    fallback() external payable {
        fund();
    }

    // view / pure functions (getters)
    function getAddressToAmountFunded(
        address fundingAddress
    ) external view returns (uint256) {
        return s_addressToAmountFunded[fundingAddress];
    }

    function getFunders(uint256 index) external view returns (address) {
        return s_funders[index];
    }

    function getOwner() external view returns (address) {
        return i_owner;
    }
}
