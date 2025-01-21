// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "./Identity.sol";
import "./Interfaces/ITransferRules.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

contract ExampleTransferRules is ITransferRules, Ownable2Step {
    Identity public immutable identityContract;
    uint8 private minimumAge;
    uint64 public constant transferLimit = (20000 * 10 ** 6);


    mapping(address => bool) public userBlocklist;

    event BlacklistUpdated(address indexed user, bool isBlacklisted);
    error AddressBlacklisted(address user);

    constructor(address _identityContract) Ownable(msg.sender) {
        identityContract = Identity(_identityContract);
    }
    function setMinimumAge(uint8 _minimumAge) external onlyOwner {
        minimumAge = _minimumAge;
    }

    function transferAllowed(
        address from,
        address to,
        einput amount,
        bytes calldata inputproof
    ) public returns (ebool) {
        euint64 eamount = TFHE.asEuint64(amount, inputproof);
        return transferAllowed(from, to, eamount);
    }

    function transferAllowed(address from, address to, euint64 amount) public override returns (ebool) {
        // Condition 1: Check that addresses are not blacklisted
        if (userBlocklist[from] || userBlocklist[to]) {
            ebool transferable = TFHE.asEbool(false);
            TFHE.allow(transferable, address(this));
            TFHE.allow(transferable, msg.sender);
            return transferable;
        }
        ebool ageCondition = identityContract.checkAgeRequirement(from, to, minimumAge);
        TFHE.allow(ageCondition, address(this));
        ebool belowLimit = TFHE.le(amount, 20000000000);
        TFHE.allow(belowLimit, address(this));
        // check if below limit and age condition is true
        ebool transferAllowedAll = TFHE.and(belowLimit, ageCondition);
        // euint64 result = TFHE.select(transferAllowed, amount, TFHE.asEuint64(0));
        TFHE.allow(transferAllowedAll, address(this));
        TFHE.allow(transferAllowedAll, msg.sender);
        return transferAllowedAll;
    }

    function setBlacklist(address user, bool isBlacklisted) external onlyOwner {
        require(user != address(0), "Invalid address");
        userBlocklist[user] = isBlacklisted;
        emit BlacklistUpdated(user, isBlacklisted);
    }
}
