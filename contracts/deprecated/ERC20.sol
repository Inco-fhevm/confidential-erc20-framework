// SPDX-License-Identifier: BSD-3-Clause-Clear
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    constructor() ERC20("MyToken", "MTK") {
        _mint(msg.sender, 1000);
    }
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}
