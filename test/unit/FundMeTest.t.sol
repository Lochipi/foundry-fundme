// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    address USER = makeAddr("USER");
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTING_BALANCE = 100 ether;
    uint256 constant GAS_PRICE = 1;

    //our fn to deploy the contract , this set up would be run first
    function setUp() external {
        // fundme var of type FundMe
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMinimumDollarIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOnlyOwner() public view {
        // we are not the owner
        // the fundme test is the owner since it deployed the contract
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedIsAccurate() public view {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughEth() public {
        vm.expectRevert();
        fundMe.fund(); // send 0 eth
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER); // pretend to be user, and the next tx will be sent by USER
        fundMe.fund{value: SEND_VALUE}();

        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFundersToArrayOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();

        address funder = fundMe.getFunders(0);
        assertEq(funder, USER);
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        // vm.prank(USER);
        // fundMe.fund{value: SEND_VALUE}();

        vm.prank(USER);
        vm.expectRevert();
        fundMe.withdraw();
    }

    function testWithdrawWithASingleFunder() public funded {
        // arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;
        // act
        uint256 gasStart = gasleft();
        vm.txGasPrice(GAS_PRICE);
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();
        uint256 gasEnd = gasleft();
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;
        console.log("Gas used: ", gasUsed);

        // assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(
            endingOwnerBalance,
            startingOwnerBalance + startingFundMeBalance
        );
        assertEq(endingFundMeBalance, 0);
    }

    function testWithdrawFromMultipleFunders() public funded {
        //arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;

        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            //vm.prank new address
            // vm.deal new address
            hoax(address(i), SEND_VALUE);
            // fund the address
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // act
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        // assert
        assert(address(fundMe).balance == 0);
        assert(
            fundMe.getOwner().balance ==
                startingOwnerBalance + startingFundMeBalance
        );
    }

    // function testWithdrawFromMultipleFundersCheaper() public funded {
    //     //arrange
    //     uint160 numberOfFunders = 5;
    //     uint160 startingFunderIndex = 1;

    //     for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
    //         //vm.prank new address
    //         // vm.deal new address
    //         hoax(address(i), SEND_VALUE);
    //         // fund the address
    //         fundMe.fund{value: SEND_VALUE}();
    //     }

    //     uint256 startingOwnerBalance = fundMe.getOwner().balance;
    //     uint256 startingFundMeBalance = address(fundMe).balance;

    //     // act
    //     vm.startPrank(fundMe.getOwner());
    //     fundMe.cheaperWithdraw();
    //     vm.stopPrank();

    //     // assert
    //     assert(address(fundMe).balance == 0);
    //     assert(
    //         fundMe.getOwner().balance ==
    //             startingOwnerBalance + startingFundMeBalance
    //     );
    // }
}
