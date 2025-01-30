// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

type ebool is uint256;
type euint4 is uint256;
type euint8 is uint256;
type euint16 is uint256;
type euint32 is uint256;
type euint64 is uint256;
type eaddress is uint256;
type ebytes256 is uint256;
type einput is bytes32;

// should be extended to include all e types for every solidity type

// create an interface for the TFHE lib

interface ITFHE {
    function isInitialized(uint256 v) external pure returns (bool);
    function add(euint4 a, euint4 b) external returns (euint4);
    function sub(euint4 a, euint4 b) external returns (euint4);
    function mul(euint4 a, euint4 b) external returns (euint4);
    function and(euint4 a, euint4 b) external returns (euint4);
    function or(euint4 a, euint4 b) external returns (euint4);
    function xor(euint4 a, euint4 b) external returns (euint4);
    function eq(euint4 a, euint4 b) external returns (ebool);
    function ne(euint4 a, euint4 b) external returns (ebool);
    function ge(euint4 a, euint4 b) external returns (ebool);
    function gt(euint4 a, euint4 b) external returns (ebool);
    function le(euint4 a, euint4 b) external returns (ebool);
    function lt(euint4 a, euint4 b) external returns (ebool);
    function min(euint4 a, euint4 b) external returns (euint4);
    function max(euint4 a, euint4 b) external returns (euint4);
    // ...additional function signatures for other types...
}
