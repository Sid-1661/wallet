pragma solidity ^0.8.13;

import {PayMaster} from "./PayMaster.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "openzeppelin-contracts/security/Pausable.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";


contract PayMasterToken is PayMaster, Pausable {
    using SafeERC20 for IERC20;

    event AddToken(address indexed token, address indexed oracle);
    event RemoveToken(address indexed token, address indexed oracle);
    event Deposit(address indexed token, address indexed from, uint256 amount);
    event Withdraw(address indexed token, address indexed to, uint256 amount);
    event EmergencyWithdraw(address indexed token, address indexed to, uint256 amount);

    mapping(address => address) public tokenToOracle;

    mapping(address => mapping(address => uint256)) public tokenBalances;

    constructor(address _entryPoint) PayMaster(_entryPoint) Pausable() {}

    function getBalance(address token, address user) public view returns (uint256) {
        return tokenBalances[token][user];
    }

    function getTokenOracle(address token) public view returns (address) {
        return tokenToOracle[token];
    }

    function addToken(address token, address oracle) external onlyOwner {
        require(tokenToOracle[token] == address(0));
        tokenToOracle[token] = oracle;
        emit AddToken(token, oracle);
    }

    function removeToken(address token) external onlyOwner {
        delete tokenToOracle[token];
        emit RemoveToken(token, tokenToOracle[token]);
    }

    function deposit(address token, uint256 amount) external {

        require(tokenToOracle[token] != address(0), "Unsupported token");

        tokenBalances[token][msg.sender] += amount;

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(token, msg.sender, amount);
    }

    function withdrawToken(address token, uint256 amount) external {
        _withdraw(token, msg.sender, amount);
        emit Withdraw(token, msg.sender, amount);
    }

    function emergencyWithdraw(address token, address user, uint256 amount) external onlyOwner {
        _withdraw(token, user, amount);
        emit EmergencyWithdraw(token, owner(), amount);
    }

    function _withdraw(address token, address user, uint256 amount) internal {
        require(tokenToOracle[token] != address(0), "Unsupported token");
        uint256 userBalance = tokenBalances[token][user];
        require(userBalance >= amount, "Insufficient balance");
        tokenBalances[token][user] -= amount;
        IERC20(token).safeTransfer(msg.sender, amount);
    }
}
