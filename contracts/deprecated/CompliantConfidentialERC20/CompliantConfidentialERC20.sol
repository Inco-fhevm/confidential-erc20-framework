// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import { ConfidentialToken } from "../ConfidentialERC20/ConfidentialToken.sol";
import "./Identity.sol";
import "./Interfaces/ITransferRules.sol";

contract CompliantConfidentialERC20 is ConfidentialToken {
    Identity public identityContract;
    ITransferRules public transferRulesContract;
    constructor(
        string memory name_,
        string memory symbol_,
        address _identityContract,
        address _transferRulesContract
    ) ConfidentialToken(name_, symbol_) {
        identityContract = Identity(_identityContract);
        transferRulesContract = ITransferRules(_transferRulesContract);
    }

    // Overridden transfer function handling encrypted inputs
    function transfer(
        address to,
        einput encryptedAmount,
        bytes calldata inputProof
    ) public virtual override returns (bool) {
        euint64 amount = TFHE.asEuint64(encryptedAmount, inputProof);
        return transfer(to, amount);
    }

    // Internal transfer function applying the transfer rules
    function transfer(address to, euint64 amount) public override returns (bool) {
        require(TFHE.isSenderAllowed(amount), "Sender not allowed");

        ebool hasEnough = TFHE.le(amount, _balances[msg.sender]);
        euint64 transferAmount = TFHE.select(hasEnough, amount, TFHE.asEuint64(0));

        // Apply transfer rules
        TFHE.allow(transferAmount, address(transferRulesContract));
        ebool rulesPassed = transferRulesContract.transferAllowed(msg.sender, to, transferAmount);
        transferAmount = TFHE.select(rulesPassed, transferAmount, TFHE.asEuint64(0));

        TFHE.allow(transferAmount, address(this));
        _transfer(msg.sender, to, transferAmount);

        return true;
    }

    // Internal transfer function with encrypted balances
    function _transfer(address from, address to, euint64 _amount) internal {
        euint64 newBalanceFrom = TFHE.sub(_balances[from], _amount);
        _balances[from] = newBalanceFrom;
        TFHE.allow(newBalanceFrom, from);

        euint64 newBalanceTo = TFHE.add(_balances[to], _amount);
        _balances[to] = newBalanceTo;
        TFHE.allow(newBalanceTo, address(this));
        TFHE.allow(newBalanceTo, to);
    }

    // Allows admin to view any user's encrypted balance
    function adminViewUserBalance(address user) public onlyOwner {
        TFHE.allow(_balances[user], owner());
    }
}
