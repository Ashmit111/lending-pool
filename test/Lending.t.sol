// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <=0.8.30;

import {Test} from "forge-std/Test.sol";
import {LendingPool} from "../src/LendingPool.sol";
import {PriceOracle} from "../src/PriceOracle.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint8 public decimals = 18;

    string public name = "Mock Token";
    string public symbol = "MOCK";

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(
            allowance[from][msg.sender] >= amount,
            "Insufficient allowance"
        );
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

contract TestLendingPool is Test {
    LendingPool public lendingpool;
    PriceOracle public priceOracle;
    MockERC20 public mockToken;
    MockERC20 public mockToken2;

    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);

    function setUp() public {
        // Deploy contracts (this runs before each test)
        priceOracle = new PriceOracle();
        
        vm.prank(owner);
        lendingpool = new LendingPool(address(priceOracle));
        mockToken = new MockERC20();
        mockToken2 = new MockERC20();

        mockToken.mint(user1, 1000 ether);
        mockToken.mint(user2, 1000 ether);

        mockToken2.mint(user1, 1000 ether);
    }

    // Test 1: Only owner can add supported token
    function testAddSupportedTokenByOwner() public {
        vm.prank(owner);
        lendingpool.addSupportedToken(address(mockToken), 7500);

        assertTrue(lendingpool.supportedTokens(address(mockToken)));
        assertEq(lendingpool.collateralFactors(address(mockToken)), 7500);
    }

    // Test 2: Non-owner cannot add supported token
    function testOnlyOwnerCanAddSupportedToken() public {
        vm.prank(user1);
        vm.expectRevert(LendingPool.OnlyOwner.selector);
        lendingpool.addSupportedToken(address(mockToken), 7500);
    }

    // Test 3: Deposit into supported token
    function testDeposit() public {
        vm.prank(owner);
        lendingpool.addSupportedToken(address(mockToken), 7500);

        uint256 depositAmount = 100 ether;

        vm.prank(user1);
        mockToken.approve(address(lendingpool), depositAmount);

        vm.prank(user1);
        lendingpool.deposit(address(mockToken), depositAmount);

        assertEq(
            lendingpool.deposits(user1, address(mockToken)),
            depositAmount
        );
        assertEq(
            lendingpool.availableLiquidity(address(mockToken)),
            depositAmount
        );
    }

    // Test 4: Deposit into unsupported token should fail
    function testDepositUnsupportedToken() public {
        uint256 depositAmount = 100 ether;
        vm.prank(user1);
        mockToken.approve(address(lendingpool), depositAmount);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(LendingPool.TokenNotSupported.selector, address(mockToken)));
        lendingpool.deposit(address(mockToken), depositAmount);
    }

    // Test 6: Withdraw test
    function testWithdraws() public {
        // Setup: Add token and deposit first
        vm.prank(owner);
        lendingpool.addSupportedToken(address(mockToken), 7500);

        uint256 depositAmount = 1000 ether;
        vm.prank(user1);
        mockToken.approve(address(lendingpool), depositAmount);
        vm.prank(user1);
        lendingpool.deposit(address(mockToken), depositAmount);
        // Now withdraw
        vm.prank(user1);
        lendingpool.withdraw(address(mockToken), 50 ether);
        assertEq(lendingpool.deposits(user1, address(mockToken)), 50 ether);
        assertEq(mockToken.balanceOf(user1), 950 ether);
    }

    // Test 7: Withdraw more than balance should fail
    function testWithdrawInsufficientBalance() public {
        vm.prank(address(this));
        lendingpool.addSupportedToken(address(mockToken), 7500);

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                LendingPool.InsufficientBalance.selector,
                0,
                100 ether
            )
        );
        lendingpool.withdraw(address(mockToken), 100 ether);
    }

    // Test 8 : Borrow Test
    function testBorrorWithSufficientCollateral() public {
        vm.prank(owner);
        lendingpool.addSupportedToken(address(mockToken), 7500);
        vm.prank(owner);
        lendingpool.addSupportedToken(address(mockToken2), 8000);

        vm.prank(user1);
        mockToken.approve(address(lendingpool), 100 ether);
        vm.prank(user1);
        lendingpool.deposit(address(mockToken), 100 ether);

        vm.prank(user2);
        mockToken2.approve(address(lendingpool), 1000 ether);
        vm.prank(user2);
        lendingpool.deposit(address(mockToken2), 1000 ether);

        uint256 borrowAmount = 800 ether;

        vm.prank(user1);
        lendingpool.borrow(address(mockToken2), borrowAmount);

        assertEq(lendingpool.borrows(user1, address(mockToken2)), borrowAmount);
        assertEq(mockToken2.balanceOf(user1), borrowAmount);
    }

    function testBorrowInsufficientCollateral() public {
        vm.prank(owner);
        lendingpool.addSupportedToken(address(mockToken), 7500);
        vm.prank(owner);
        lendingpool.addSupportedToken(address(mockToken2), 8000);
    
        vm.prank(user1);
        mockToken.approve(address(lendingpool), 100 ether);
        vm.prank(user1);
        lendingpool.deposit(address(mockToken), 100 ether);

        // User2 deposits only 1000 ether of mockToken2
        vm.prank(user2);
        lendingpool.deposit(address(mockToken2), 1000 ether);
        // But trying to borrow 150,000 ether
        uint256 borrowAmount = 151000 ether;

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                LendingPool.InsufficientCollateral.selector,
                150000 ether,
                750 ether
            )
        );
        lendingpool.borrow(address(mockToken2), borrowAmount);
    }

    function testRepay() public {
        vm.prank(owner);
        lendingpool.addSupportedToken(address(mockToken), 7500);
        vm.prank(owner);
        lendingpool.addSupportedToken(address(mockToken2), 8000);

        vm.prank(user1);
        mockToken.approve(address(lendingpool), 100 ether);
        vm.prank(user1);
        lendingpool.deposit(address(mockToken), 100 ether);

        vm.prank(user2);
        mockToken.approve(address(lendingpool), 1000 ether);
        vm.prank(user2);
        lendingpool.deposit(address(mockToken), 1000 ether);

        uint256 borrowAmount = 500 ether;
        vm.prank(user1);
        lendingpool.borrow(address(mockToken2), borrowAmount);
        assertEq(lendingpool.borrows(user1, address(mockToken2)), borrowAmount);
        assertEq(mockToken2.balanceOf(user1), borrowAmount);

        // Now repay
        vm.prank(user1);
        mockToken2.approve(address(lendingpool), 200 ether);
        vm.prank(user1);
        lendingpool.repay(address(mockToken2), 200 ether);  
        assertEq(lendingpool.borrows(user1, address(mockToken2)), 300 ether);
        assertEq(mockToken2.balanceOf(user1), 300 ether);

        // Repay remaining
        vm.prank(user1);
        mockToken2.approve(address(lendingpool), 300 ether);
        vm.prank(user1);
        lendingpool.repay(address(mockToken2), 300 ether);
        assertEq(lendingpool.borrows(user1, address(mockToken2)), 0);
        assertEq(mockToken2.balanceOf(user1), 0);
    }

    function testRepayExceedsBorrowed() public {
        vm.prank(owner);
        lendingpool.addSupportedToken(address(mockToken), 7500);
        vm.prank(owner);
        lendingpool.addSupportedToken(address(mockToken2), 8000);

        vm.prank(user1);
        mockToken.approve(address(lendingpool), 100 ether);
        vm.prank(user1);
        lendingpool.deposit(address(mockToken), 100 ether);

        vm.prank(user2);
        mockToken.approve(address(lendingpool), 1000 ether);
        vm.prank(user2);
        lendingpool.deposit(address(mockToken), 1000 ether);

        uint256 borrowAmount = 500 ether;
        vm.prank(user1);
        lendingpool.borrow(address(mockToken2), borrowAmount);
        assertEq(lendingpool.borrows(user1, address(mockToken2)), borrowAmount);
        assertEq(mockToken2.balanceOf(user1), borrowAmount);

        // Now repay more than borrowed
        vm.prank(user1);
        mockToken2.approve(address(lendingpool), 600 ether);
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                LendingPool.RepayAmountExceedsBorrowed.selector,
                600 ether,
                500 ether
            )
        );
        lendingpool.repay(address(mockToken2), 600 ether);  
    }
}
