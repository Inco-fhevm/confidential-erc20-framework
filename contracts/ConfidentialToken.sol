// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

// Confidential Coin to relay the idea of fungibility ?
abstract contract ConfidentialToken {
    function name() public view virtual returns (string memory);
    function symbol() public view virtual returns (string memory);

    function confidentialTotalSupply() public view virtual returns (euint??); // optional
    function totalSupply() public view virtual returns (uint256); // optional // required in ERC20 std, should we make it mandatory ?

    // minimal BTC value with 6 decimals : currenly 0.1 usd - we can't force 6 decimals
    // max uint64 value is 18,446,744,073,709,551,615 - with 6 decimals its 18,446,744,073,709.551615 - 18T 
    // that is not even enough for USD (inferior to the M2 historic top at 21T)
    // we should move to a larger type
    function decimals() public view virtual returns (uint8);

    // uint128 ?
    function confidentialBalanceOf(address account) public view virtual returns (euint??);

    // + bytes memory data ?
    function confidentialTransfer(address spender, euint?? amount) public virtual returns (ebool);

    function confidentialTransfer(address to, einput encryptedAmount, bytes calldata inputProof) external virtual returns (ebool);

    function confidentialTransferFrom(address spender, address to, euint?? amount) public virtual returns (ebool);

    function confidentialTransferFrom(address spender, address to, einput encryptedAmount, bytes calldata inputProof) external virtual returns (ebool);

    function confidentialApprove(address spender, euint?? amount) public virtual returns (ebool);

    function confidentialApprove(address spender, einput encryptedAmount, bytes calldata inputProof) external virtual returns (ebool);

    function confidentialAllowance(address owner, address spender) public view virtual returns (euint??);
}

abstract contract ConfidentialErc20 is ConfidentialToken {
    function transfer(address to, uint256 value) external returns (bool); // to check if we can change this to ebool
    // function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool); // same
    function transferFrom(address from, address to, uint256 value) external returns (bool); // same
}

abstract contract Erc20ConfidentialWrapper is ConfidentialErc20 {
    function underlyingDecimals() public view virtual returns (uint8);
    function wrap(uint256 amount) external virtual;
    function unwrap(uint?? amount, bytes data) external virtual;
} 
