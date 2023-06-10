// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract RaffleGovUpgradeable is OwnableUpgradeable{
    address public govAddress;
    function raffleInit(address _gov) internal {
        __Ownable_init();
        govAddress = _gov;
    }
    modifier onlyGov{
        require(msg.sender == govAddress, "!gov");
        _;
    }
    function setGov(address gov) external onlyOwner {
        govAddress = gov;
    }
}