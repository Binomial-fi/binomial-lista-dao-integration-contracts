// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IBnWClisBnb} from "./interfaces/IBnWClisBnb.sol";
import {TransferHelper} from "./libs/TransferHelper.sol";

contract BnWClisBnb is IBnWClisBnb, ERC20, AccessControl, ReentrancyGuard {
    bytes32 public constant MINT_BURN_ROLE = keccak256("MINT_BURN_ROLE");

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mint(address _account, uint256 _amount) public onlyRole(MINT_BURN_ROLE) nonReentrant {
        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) public onlyRole(MINT_BURN_ROLE) nonReentrant {
        _burn(_account, _amount);
    }

    function decimals() public pure override returns (uint8) {
        return 8;
    }
}
