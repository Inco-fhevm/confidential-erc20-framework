// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;
import "fhevm/lib/TFHE.sol";
interface ITransferRules {
    function transferAllowed(address from, address to, euint64 amount) external returns (ebool);
}
