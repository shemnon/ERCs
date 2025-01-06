/// SPDX-License-Identifier: CC0-1.0
pragma solidity >=0.8.21 <0.10.0;

/**
 * @title EOF Singleton Factory (ERC-TBD)
 * @notice Exposes TXCREATE (EIP-1014) to deploy EOF contracts on deterministic addresses based on
 *         the EOF init container and salt.
 * @author Danno Ferrin
 * @author Ricardo Guilherme Schmidt (Status Research & Development GmbH)
 */
contract EOFSingletonFactory {

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
     * @notice Deploys EOF container identified by `_codeHash` using `_salt` for defining the
     *         deterministic address.
     * @param _codeHash The code hash used by TXCREATE.
     * @param _salt Arbitrary value to modify resulting address.
     * @return createdContract Created contract address.
     * @revert Reverts with parent revert data if contract create failed
     */
    function deploy(bytes32 _codeHash, bytes32 _salt)
    public noDelegateCall
    returns (address payable createdContract)
    {
        assembly {
            createdContract := txcreate(_codeHash, 0, _salt, 0, 0)
            //TODO trigger off of zero contract or non-zero returndata?
            if iszero(createdContract) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }
}
