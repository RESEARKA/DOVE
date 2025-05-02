// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title StringUtils
 * @dev String utility functions for DOVE token contracts
 */
library StringUtils {
    /**
     * @dev Helper for string conversion of bytes32
     * @param source Source bytes32 to convert
     */
    function bytes32ToString(bytes32 source) internal pure returns (string memory) {
        bytes memory bytesArray = new bytes(32);
        for (uint256 i; i < 32; i++) {
            bytesArray[i] = source[i];
        }
        return string(bytesArray);
    }
    
    /**
     * @dev Helper for uint256 conversion to string for better error messages
     * @param value The uint to convert
     * @return string representation
     */
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        
        uint256 temp = value;
        uint256 digits;
        
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        
        return string(buffer);
    }
}
