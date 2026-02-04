// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Identity is Ownable {
    mapping(address => bool) private isRegistered;
    mapping(address => euint64) private dateOfBirth; // Store Date of Birth as an encrypted timestamp

    event IdentityRegistered(address indexed user);
    event dateOfBirthUpdated(address indexed user);

    constructor() {}

    // Register identity with encrypted Date of Birth (DOB)
    function registerIdentity(address user, einput encryptedDOB, bytes calldata inputProof) external onlyOwner {
        require(!isRegistered[user], "Identity already registered");

        euint64 dob = TFHE.asEuint64(encryptedDOB, inputProof);
        dateOfBirth[user] = dob;
        isRegistered[user] = true;

        TFHE.allow(dateOfBirth[user], msg.sender);
        TFHE.allow(dateOfBirth[user], user);
        TFHE.allow(dateOfBirth[user], address(this));

        emit IdentityRegistered(user);
    }

    // Update DOB for a user
    function updateDOB(address user, einput encryptedDOB, bytes calldata inputProof) external onlyOwner {
        require(isRegistered[user], "Identity not registered");

        euint64 dob = TFHE.asEuint64(encryptedDOB, inputProof);
        dateOfBirth[user] = dob;

        // Allow access to the updated encrypted DOB
        TFHE.allow(dateOfBirth[user], msg.sender);
        TFHE.allow(dateOfBirth[user], address(this));

        emit dateOfBirthUpdated(user);
    }

    // Calculate if user meets the minimum age requirement
    function checkAgeRequirement(address from, address to, uint8 minAge) public returns (ebool) {
        require(isRegistered[from], "From address is not registered");
        require(isRegistered[to], "To address is not registered");

        euint64 fromDOB = dateOfBirth[from];
        euint64 toDOB = dateOfBirth[to];

        uint64 currentTime = uint64(block.timestamp);

        euint64 fromAgeInSeconds = TFHE.sub(currentTime, fromDOB);
        euint64 toAgeInSeconds = TFHE.sub(currentTime, toDOB);

        uint64 secondsInYear = 31557600; // 365.25 * 24 * 60 * 60

        euint64 fromAge = TFHE.div(fromAgeInSeconds, secondsInYear);
        euint64 toAge = TFHE.div(toAgeInSeconds, secondsInYear);
        ebool fromAgeValid = TFHE.ge(fromAge, minAge);
        ebool toAgeValid = TFHE.ge(toAge, minAge);
        ebool result = TFHE.and(fromAgeValid, toAgeValid);

        // Allow querying contract to access the result
        TFHE.allow(result, msg.sender);
        TFHE.allow(result, address(this));

        return result;
    }

    function isUserRegistered(address user) external view returns (bool) {
        return isRegistered[user];
    }

    function getDOB(address user) external returns (euint64) {
        require(isRegistered[user], "User is not registered");

        euint64 dob = dateOfBirth[user];
        TFHE.allow(dob, msg.sender);
        TFHE.allow(dob, address(this));
        return dob;
    }
}
