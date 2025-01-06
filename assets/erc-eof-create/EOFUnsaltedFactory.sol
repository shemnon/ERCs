/// SPDX-License-Identifier: CC0-1.0
pragma solidity >=0.8.21 <0.10.0;

/**
 * @title EOF Singleton Factory (ERC-TBD)
 * @notice Exposes TXCREATE (EIP-1014) to deploy EOF contracts on deterministic addresses based on
 *         the EOF init container a per-contract incrementing nonce.
 * @author Danno Ferrin
 */
contract EOFUnsaltedFactory {

    address private immutable original;

    constructor() {
        original = address(this);
    }

    function checkNotDelegateCall() private view {
        require(address(this) == original, "Execution is a delegatecall");
    }

    modifier noDelegateCall() {
        checkNotDelegateCall();
        _;
    }

    /**
     * @notice Deploys EOF container identified by `_codeHash` to a new address
     * @param _codeHash The code hash used by TXCREATE.
     * @return createdContract Created contract address.
     */
    function deploy(bytes32 _codeHash)
    public noDelegateCall
    returns (address payable createdContract)
    {
        assembly {
            let salt := add(sload(_codeHash), 1)
            sstore(_codeHash, salt)
            createdContract := txcreate(_codeHash, 0, salt, 0, 0)
            if iszero(createdContract) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    /**
     * @notice return the next nonce for a particular contract hash
     * @param _codeHash The code hash used by TXCREATE.
     * @return nonce the next nonce.
     */
    function nonceFor(bytes32 _codeHash)
    public view noDelegateCall
    returns (uint256 nonce)
    {
        assembly {
            nonce := sload(_codeHash)
        }
    }
}
