// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
library  RandomNumbers {
    using SafeMathUpgradeable for uint256;
    function generateNumbers(uint256 str, uint256 total, uint256 min, uint256 count) internal pure returns (uint256[] memory) {
        require(count <= 1000, "count too large!!");
        bytes32 seed = keccak256(abi.encode(str));
        uint256[] memory results = new uint256[](count);
        if(min.mul(count) >= total){
            for (uint256 i = 0; i < count; i++) {
                results[i] = total.div(count);
            }
            return results;
        }
        uint256 opened = 0x0;
        uint256 reserved = count.mul(min);
        uint256 t = total.sub(reserved);
        for (uint256 i = 0; i < count; i++) {
            uint256 random = uint256(keccak256(abi.encode(seed, i)));
            uint256 avgLeft = t.sub(opened).div(count -i + 1).mul(2);
            uint256 raffle = random.mod(avgLeft);
            if(i == count -1){
                raffle = t.sub(opened);
            }
            raffle = raffle.div(10**16).mul(10**16);
            opened = opened.add(raffle);
            results[i] = raffle.add(min);
        }
        return shuffle(results, seed);
    }
    function shuffle(uint256[] memory _arr, bytes32 seed) internal pure returns(uint256[] memory) {
        uint256[] memory arr = _arr;
        uint256 N = arr.length;

        for(uint256 i = N - 1; i > 0; i--) {
            uint256 j = uint256(seed) % (i+1);
            (arr[i], arr[j]) = (arr[j], arr[i]);
        }

        return arr;
    }
}