pragma solidity ^0.8.13;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {IAccount} from "src/external/IAccount.sol";
import {IEntryPoint} from "src/external/IEntryPoint.sol";
import {UserOperation} from "src/external/UserOperation.sol";

import "forge-std/console.sol";

/// @notice Smart contract wallet compatible with ERC-4337

contract SmartWallet is Ownable, IAccount {
    event UpdateEntryPoint(address indexed _newEntryPoint, address indexed _oldEntryPoint);
    event WithdrawERC20(address indexed _to, address _token, uint256 _amount);
    event PayPrefund(address indexed _payee, uint256 _amount);

    /// @notice EntryPoint contract in the ERC-4337 architecture
    IEntryPoint public entryPoint;

    /// @notice Nonce used for replay protection
    uint256 public nonce;

  
    modifier onlyEntryPoint() {
        require(msg.sender == address(entryPoint), "SmartWallet: Only entryPoint can call this method");
        _;
    }

    receive() external payable {}

    constructor(address _entryPoint, address _owner) Ownable() {
        entryPoint = IEntryPoint(_entryPoint);
        transferOwnership(_owner);
    }

    function setEntryPoint(address _newEntryPoint) external onlyOwner {
        emit UpdateEntryPoint(_newEntryPoint, address(entryPoint));
        entryPoint = IEntryPoint(_newEntryPoint);
    }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash, 
        address aggregator,
        uint256 missingWalletFunds
    ) external override onlyEntryPoint returns (uint256 deadline) {
        
        _validateSignature(userOp, userOpHash);

        if (userOp.initCode.length == 0) {
            // Validate nonce is correct - protect against replay attacks
            uint256 currentNonce = nonce;
            require(currentNonce == userOp.nonce, "SmartWallet: Invalid nonce");

          
            _updateNonce();
        }

        // Interactions
        _prefundEntryPoint(missingWalletFunds);
        return 0;
    }

   
    function executeFromEntryPoint(address target, uint256 value, bytes calldata payload) external onlyEntryPoint {
        string memory errorMessage = "SmartWallet: call reverted without message";
        (bool success, bytes memory returndata) = target.call{value: value}(payload);
        Address.verifyCallResult(success, returndata, errorMessage);
    }


    function withdrawERC20(address token, address to, uint256 amount) external onlyOwner {
        SafeERC20.safeTransfer(IERC20(token), to, amount);
        emit WithdrawERC20(to, token, amount);
    }


    function withdrawETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

 
    function _validateSignature(UserOperation calldata userOp, bytes32 userOpHash) internal view {
        bytes32 messageHash = ECDSA.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(messageHash, userOp.signature);
        require(signer == owner(), "SmartWallet: Invalid signature");
    }

  
    function _prefundEntryPoint(uint256 amount) internal onlyEntryPoint {
        if (amount == 0) {
            return;
        }

        (bool success,) = payable(address(entryPoint)).call{value: amount}("");
        require(success, "SmartWallet: ETH entrypoint payment failed");
        emit PayPrefund(address(this), amount);
    }


    function _updateNonce() internal {
        nonce++;
    }
}
