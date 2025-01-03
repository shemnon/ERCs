---
eip: TBD
title: EOF Deterministic Deployment Factories
author: Danno Ferrin (@shemnon)
discussions-to: //FIXME
status: DRAFT
type: Standards Track
category: ERC
created: 2025-01-03
requires: 7692
---

## Abstract

Existing smart contract practices have made extensive use of the skinny CREATE2 opcode introduced in [EIP-1014] and the Singleton Factory contracts found in [EIP-2470]. EOF, introduced in [EIP-7692], significantly changes the contract creation process. This causes the existing contracts to be unsuitable for contracts packaged in an EOF container.

This EIP proposes a series of smart contracts that will provide within EOF, leveraging TXCREATE [EIP-TBD], the same functionality for three essential use cases: singleton factories that are commonly provided by CREATE2 factories, multiple deployments that were commonly handled by contract creation transactions, and counterfactual deployments that were enabled by CREATE2 factories.

## Motivation

Cross-chain address reuse is predicated on well known toehold contracts providing common services to all callers. The needs for toehold also have several divergent requirements. There is the traditional singleton contract that is known and should only be deployable at a single address. There are also some changes in EOF contract creation relating to code introspection that is impacting two other common patterns: unsalted deployments to new addresses and counterfactual deployments. These patterns can easily be handled by standard deployment patterns, so this ERC presents these patterns as standard contracts.   

## Specification

### EOF Singleton Factory

> This is heavily inspired by [ERC-2470]'s singleton contract.

```solidity
pragma solidity 0.9.1;

/**
 * @title EOF Singleton Factory (ERC-TBD)
 * @notice Exposes TXCREATE (EIP-1014) to deploy EOF contracts on deterministic addresses based on 
 *         the EOF init container and salt.
 * @author Danno Ferrin
 * @author Ricardo Guilherme Schmidt (Status Research & Development GmbH)
 */
contract EOFSingletonFactory {
    /**
     * @notice Deploys EOF container identified by `_codeHash` using `_salt` for defining the
     *         deterministic address.
     * @param _codeHash The code hash used by TXCREATE.
     * @param _salt Arbitrary value to modify resulting address.
     * @return createdContract Created contract address.
     */
    function deploy(bytes32 _codeHash, bytes32 _salt)
        public
        returns (address payable createdContract)
    {
        assembly {
            createdContract := txcreate(_codeHash, 0wei, _salt, 0, 0)
        }
    }
}
```

### EOF Unsalted Factory

> The current nonce is  unique per code hash, so each subsequent deployment address is independent of other contract interactions.

```solidity
pragma solidity 0.9.1;

/**
 * @title EOF Singleton Factory (ERC-TBD)
 * @notice Exposes TXCREATE (EIP-1014) to deploy EOF contracts on deterministic addresses based on 
 *         the EOF init container a per-contract incrementing nonce.
 * @author Danno Ferrin
 */
contract EOFUnsaltedFactory {
    
    mapping(bytes32 => uint) nonces;

    /**
     * @notice Deploys EOF container identified by `_codeHash` to a new address
     * @param _codeHash The code hash used by TXCREATE.
     * @return createdContract Created contract address.
     */
    function deploy(bytes32 _codeHash)
        public
        returns (address payable createdContract)
    {
        uint salt = (uint) nonces[_codeHash];
        nonces[_codeHash] = (bytes32) (salt+1)
        assembly {
            createdContract := txcreate(_codeHash, 0wei, salt, 0, 0)
        }
    }
    
    /**
     * @notice return the next nonce for a particular contract hash
     * @param _codeHash The code hash used by TXCREATE.
     * @return salt the next nonce.
     */
     function nonce(bytes32 _codeHash)
         public
         returns (bytes32 nonce)
     {
        nonce = nonces[_codeHash];
    }
}
```

### EOF Counterfactual Factory

```solidity
pragma solidity 0.9.1;

/**
 * @title EOF Counterfactual Factory (ERC-TBD)
 * @notice Exposes TXCREATE (EIP-1014) to deploy EOF contracts on deterministic addresses without
 *         salt.
 * @author Danno Ferrin
 */
contract EOFCounterfactualFactory {
    
    /**
     * @notice Deploys EOF container identified by `_codeHash` to a new address
     * @param _codeHash The code hash used by TXCREATE.
     * @return createdContract Created contract address.
     */
    function deploy(bytes32 _codeHash)
        public
        returns (address payable createdContract)
    {
        assembly {
            createdContract := txcreate(_codeHash, 0wei, _codeHash, 0, 0)
        }
    }
}
```


### Deployment Transactions

Deployment is a process involving three transactions.  The first transaction deploys the Counterfactual Factory using an [EIP-7698] EOF creation transaction.

```
//deployment byes goes here
```

The next two transaction can be done by any account, and use [EIP-TBD] TXCREATE transactions through the Counterfactual Factory.

* Singleton Factory
  * initcode: `//TODO get bytecode`
  * input data: `//TODO encoding of deploy(initcode_hash)`
* Unsalted Factory
   * initcode: `//TODO get bytecode`
   * input data: `//TODO encoding of deploy(initcode_hash)`

### Deployment Method

The contracts are deployed via a combination of the keyless deployment method---also known as [Nick]'s method---which relies on a single-use address, to create a toehold contract and then using this toehold to deploy the other two contracts. 

(See [Nick's article] for more details). This method works as follows:

1. Generate a transaction which deploys the contract from a new random account.
   - This transaction MUST NOT use [EIP-155] in order to work on any chain.
   - This transaction MUST have a relatively high gas price to be deployed on any chain. In this case, it is going to be 100 Gwei.

2. Forge a transaction with the following parameters:
    ```js
    {
        nonce: 0,
        gasPrice: 100000000000,
        value: 0,
        data: '//FIXME',
        gasLimit: 247000,
        v: 27,
        r: '0x247000',
        s: '0x2470'
    }
    ```
   > The `r` and `s` values, made of starting `2470`, are obviously a human determined value, instead of a real signature.

3. We recover the sender of this transaction, i.e., the single-use deployment account.

   > Thus, we obtain an account that can broadcast that transaction, but we also have the warranty that nobody knows the private key of that account.

4. Send exactly 0.0247 ether to this single-use deployment account.

5. Broadcast the deployment transaction.

   > Note: 247000 is the double of gas needed to deploy the smart contract, this ensures that future changes in OPCODE pricing are unlikely to cause this deploy transaction to fail out of gas. A left over will sit in the address of about 0.01 ETH will be forever locked in the single use address.

The resulting transaction hash is `//TBD`.

This operation can be done on any chain, guaranteeing that the contract address is always the same and nobody can use that address with a different contract.

Once the Counterfactual Factory is deployed then it can be used to deploy the other two contracts to deterministic addresses based on that toehold. 

### Single-use Factory Deployment Account

`//FIXME`

This account is generated by reverse engineering it from its signature for the transaction.
This way no one knows the private key, but it is known that it is the valid signer of the deployment transaction.

> To deploy the registry, 0.0247 ether MUST be sent to this account *first*.

### Factory Contract Addresses

* Counterfactual Factory: `//TODO`
* Singleton Factory: `//TODO`
* Unsalted Factory: `//TODO`

The contract has the addresses above for every chain on which they are deployed.

### ABIs

#### SingletonFactory:
```json
[
    {
        "constant": false,
        "inputs": [
            {
                "internalType": "bytes32",
                "name": "_initCode",
                "type": "bytes32"
            },
            {
                "internalType": "bytes32",
                "name": "_salt",
                "type": "bytes32"
            }
        ],
        "name": "deploy",
        "outputs": [
            {
                "internalType": "address payable",
                "name": "createdContract",
                "type": "address"
            }
        ],
        "payable": false,
        "stateMutability": "nonpayable",
        "type": "function"
    }
]
```

#### Unsalted Factory:
```json
[
    {
        "constant": false,
        "inputs": [
            {
                "internalType": "bytes32",
                "name": "_initCode",
                "type": "bytes32"
            }
        ],
        "name": "deploy",
        "outputs": [
            {
                "internalType": "address payable",
                "name": "createdContract",
                "type": "address"
            }
        ],
        "payable": false,
        "stateMutability": "nonpayable",
        "type": "function"
    }
]
```

#### Counterfactual Factory:
```json
[
    {
        "constant": false,
        "inputs": [
            {
                "internalType": "bytes32",
                "name": "_initCode",
                "type": "bytes32"
            }
        ],
        "name": "deploy",
        "outputs": [
            {
                "internalType": "address payable",
                "name": "createdContract",
                "type": "address"
            }
        ],
        "payable": false,
        "stateMutability": "nonpayable",
        "type": "function"
    }
]
```


## Rationale

* Three separate contracts were chosen to prevent possible collision attacks with craftily chosen salts values colliding with unsalted and counterfactual addresses.
* The Factory do not allow sending value nor setting any input data.  This was done to prevent different results on the created object.
* EOFSingletonFactory allows user defined salt to facilitate the creation of vanity addresses for other projects. If vanity address is not necessary and the contract is to be deployed exactly once then salt `bytes(0)` should be used.
Con* tracts that are constructed by the SingletonFactory MUST not use `msg.sender` in their constructor, all variables must come through the Data section of the initcode. This is intentional, as if allowing a callback after creation to aid initialization state would lead to contracts with same address (but different chains) to have the same address but different initial state.
* The resulting addresses can be calculated in chain by any contract using this formula: `//FIXME` or in javascript using //FIXME find a javascript solution.

## Backwards Compatibility

Does not apply as there are no past versions of Singleton Factory being used.

## Test Cases

TBD

## Implementation

//TBD 

## Security Considerations

* Some contracts can possibly not support being deployed on any chain, or require a different address per chain, that can be safely verified using the CHAINID Opcode ([EIP-1344]) in the constructor.
* Account contracts are singletons in the point of view of each user, when wallets want to signal what chain id is intended, [ERC-1191] should be used.
* Contracts deployed on factory must not use `msg.sender` in constructor, instead use constructor parameters, otherwise the factory would end up being the controller/only owner of those.

## Copyright
Copyright and related rights waived via [CC0](../LICENSE.md).

[EIP-155]: https://eips.ethereum.org/EIPS/eip-155.md
[EIP-1344]: https://eips.ethereum.org/EIPS/eip-1344.md
[EIP-2429]: https://gitlab.com/status-im/docs/EIPs/blob/secret-multisig-recovery/EIPS/eip-2429.md
[EIP-TBD]: https://github.com/ethereum/EIPs/commit/4badb4ae5185a942b5c24cda7a5e0063fb8d2858
[ERC-1191]: ./erc-1191.md
[Nick's article]: https://medium.com/@weka/how-to-send-ether-to-11-440-people-187e332566b7
[Nick]: https://github.com/Arachnid/

