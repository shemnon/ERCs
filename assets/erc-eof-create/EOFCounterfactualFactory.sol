/// SPDX-License-Identifier: CC0-1.0
pragma solidity >=0.8.21 <0.10.0;

/**
 * @title EOF Counterfactual Factory (ERC-TBD)
 * @notice Exposes TXCREATE (EIP-1014) to deploy EOF contracts on deterministic addresses without
 *         salt.
 * @author Danno Ferrin
 */
contract EOFCounterfactualFactory {

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
     * @revert Reverts with parent revert data if contract create failed
     */
    function deploy(bytes32 _codeHash)
    public noDelegateCall
    returns (address payable createdContract)
    {
        assembly {
            createdContract := txcreate(_codeHash, 0, _codeHash, 0, 0)
            if iszero(createdContract) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }
}
