// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ConfidentialToken} from "../../contracts/ConfidentialERC20/ConfidentialToken.sol";

/// @dev Foundry coverage for the plaintext/control-flow surface of the
///      confidential token: construction, metadata, and the owner-gated
///      access control. These paths execute before any TFHE operation, so
///      they run under pure `forge test` without the fhEVM mock coprocessor.
///      FHE value paths (mint/transfer success, decryption, gateway callbacks)
///      stay in the Hardhat suite, which wires the off-chain mock.
contract ConfidentialTokenTest is Test {
    ConfidentialToken internal token;
    address internal owner = address(this);
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    function setUp() public {
        token = new ConfidentialToken("Confidential USD", "cUSD");
    }

    function test_Metadata() public view {
        assertEq(token.name(), "Confidential USD");
        assertEq(token.symbol(), "cUSD");
        assertEq(token.decimals(), 6);
        assertEq(token.totalSupply(), 0);
    }

    function test_DeployerIsOwner() public view {
        assertEq(token.owner(), owner);
    }

    function test_Mint_RevertWhen_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert(bytes("Only owner"));
        token.mint(alice, 1_000);
    }

    function test_Mint_RevertWhen_ZeroReceiver() public {
        // Owner path; the zero-address guard in _mint reverts before TFHE.add,
        // so this exercises real mint validation without the coprocessor.
        vm.expectRevert();
        token.mint(address(0), 1_000);
    }

    function test_Burn_RevertWhen_NotOwner() public {
        vm.prank(bob);
        vm.expectRevert(bytes("Only owner"));
        token.burn(alice, 1_000);
    }

    function test_TransferOwnership_RevertWhen_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        token.transferOwnership(alice);
    }

    function test_TransferOwnership_UpdatesOwner() public {
        token.transferOwnership(bob);
        assertEq(token.owner(), bob);

        // New owner is now authorised; old owner is not.
        vm.prank(bob);
        vm.expectRevert(); // reverts in _mint's zero guard, not on access control
        token.mint(address(0), 1);

        vm.prank(owner);
        vm.expectRevert(bytes("Only owner"));
        token.mint(alice, 1);
    }

    function testFuzz_Mint_RevertWhen_NotOwner(address caller, uint64 amount) public {
        vm.assume(caller != token.owner());
        vm.prank(caller);
        vm.expectRevert(bytes("Only owner"));
        token.mint(caller, amount);
    }
}
