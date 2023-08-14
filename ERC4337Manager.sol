import "./AmbireAccount.sol";
import "./libs/SignatureValidatorV2.sol";
import "../node_modules/accountabstraction/contracts/interfaces/IAccount.sol";
import "../node_modules/accountabstraction/contracts/interfaces/IEntryPoint.sol";

contract AmbireERC4337Manager is AmbireAccount, IAccount {
	address public immutable entryPoint;

	uint256 constant internal SIG_VALIDATION_FAILED = 1;

	constructor(address[] memory privs, address _entryPoint) AmbireAccount(privs) {
		entryPoint = _entryPoint;
	}

	function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, address /*aggregator*/, uint256 missingAccountFunds)
	    external override returns (uint256 sigTimeRange)
	{
		require(msg.sender == entryPoint, "account: not from entrypoint");
                address signer = SignatureValidator.recoverAddr(userOpHash, userOp.signature);
		if (privileges[signer] == bytes32(0)) {
			sigTimeRange = SIG_VALIDATION_FAILED;
		}

		if (userOp.initCode.length == 0) {
			require(nonce++ == userOp.nonce, "account: invalid nonce");
		}

		if (missingAccountFunds > 0) {

			(bool success,) = payable(msg.sender).call{value : missingAccountFunds}("");
			(success);
		}
		return 0; 
	}
}