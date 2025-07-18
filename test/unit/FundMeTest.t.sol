// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
// import {console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    // uint num = 1;
    FundMe fundMe;

    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant GAS_PRICE = 1;

    uint160 public constant USER_NUMBER = 50;
    address USER = makeAddr("user");

    uint256 public constant SEND_VALUE =  0.1 ether;


    function setUp() external {
        // num = 2;
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_USER_BALANCE);
    }

    // function testDemo() public {
    // console.log(num);
    // console.log("Hello, World!");
    // assertEq(num, 2, "Num should be 2");
    // }

    function testMinimumDollarIsFive() public view {
        // Arrange
        // FundMe fundMe = new FundMe();
        uint256 expectedMinimumUsd = 5 * 10 ** 18; // 5 USD in wei

        // Act
        uint256 actualMinimumUsd = fundMe.MINIMUM_USD();
        // console.log("Hello, World!");
        // Assert
        assertEq(
            actualMinimumUsd,
            expectedMinimumUsd,
            "Minimum USD should be 5"
        );
    }

    function testSenderIsOwner() public {
        assertEq(fundMe.i_owner(), msg.sender, "Sender should be the owner");
    }

    // function testPriceFeedVersionIsAccurate() public {
    //     uint version = fundMe.getVersion();
    //     assertEq(version, 4, "Price feed version should be 4");
    // }

    // function testFundFailsWithoutEnoughETH() public skipZkSync {
    //     vm.expectRevert();
    //     fundMe.fund();
    // }

    function testFundUpdatesFundedDataStructure() public {
        vm.startPrank(USER);
        fundMe.fund{value: SEND_VALUE}();
        vm.stopPrank();

        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.startPrank(USER);
        fundMe.fund{value: SEND_VALUE}();
        vm.stopPrank();

        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    // // https://twitter.com/PaulRBerg/status/1624763320539525121

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        assert(address(fundMe).balance > 0);
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded{
        vm.expectRevert();
        vm.prank(address(3)); // Not the owner
        fundMe.withdraw();
    }

    function testWithdrawFromASingleFunder() public funded {
        // Arrange
        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        // vm.txGasPrice(GAS_PRICE);
        // uint256 gasStart = gasleft();
        // // Act
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        // uint256 gasEnd = gasleft();
        // uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;

        // Assert
        uint256 endingFundMeBalance = address(fundMe).balance;
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            endingOwnerBalance // + gasUsed
        );
    }

    // Can we do our withdraw function a cheaper way?
    function testWithdrawFromMultipleFunders() public funded {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 2 + USER_NUMBER;

        uint256 originalFundMeBalance = address(fundMe).balance; // This is for people running forked tests!

        for (uint160 i = startingFunderIndex; i < numberOfFunders + startingFunderIndex; i++) {
            // we get hoax from stdcheats
            // prank + deal
            hoax(address(i), STARTING_USER_BALANCE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingFundedeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        assert(address(fundMe).balance == 0);
        assert(startingFundedeBalance + startingOwnerBalance == fundMe.getOwner().balance);

        uint256 expectedTotalValueWithdrawn = ((numberOfFunders) * SEND_VALUE) + originalFundMeBalance;
        uint256 totalValueWithdrawn = fundMe.getOwner().balance - startingOwnerBalance;

        assert(expectedTotalValueWithdrawn == totalValueWithdrawn);
    }

}
