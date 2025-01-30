// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "./ConfidentialERC20.sol";
import "fhevm/lib/TFHE.sol";

/**
 * @dev Example Implementation of the {ConfidentialERC20} contract, providing minting and additional functionality.
 */
contract ConfidentialToken is ConfidentialERC20 {
    address private _owner;

    /**
     * @dev Sets the initial values for {name} and {symbol}, and assigns ownership to the deployer.
     */
    constructor(string memory name_, string memory symbol_) ConfidentialERC20(name_, symbol_) {
        _owner = msg.sender;
    }

    /**
     * @dev Mint new tokens.
     *
     */
    function mint(address to, uint64 amount) public {
        require(msg.sender == _owner, "Only owner");
        _mint(to, amount);
    }

    /**
     * @dev Burn tokens from an account.
     *
     */
    function burn(address from, uint64 amount) public {
        require(msg.sender == _owner, "Only owner");
        burn(from, amount);
    }

    /**
     * @dev Change the owner
     *
     */
    function transferOwnership(address newOwner) public override {
        require(msg.sender == _owner, " Only owner");
        _owner = newOwner;
    }

    /**
     * @dev Get the owner of the contract.
     */
    function owner() public view override returns (address) {
        return _owner;
    }
}
