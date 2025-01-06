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

Full source code for the contracts can be found in the [ERC-TBD assets](../assets/erc-eof-create) directory.  The ERC will discuss the most pertinent sections 

### [EOF Singleton Factory](../assets/erc-eof-create/EOFSingletonFactory.sol)

This is heavily inspired by [ERC-2470]'s singleton contract. One needed change is we set input data to empty.  The call to `deploy` also reverts if no valid contract address is returned.

```solidity
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
```

### [EOF Unsalted Factory](../assets/erc-eof-create/EOFUnsaltedFactory.sol)

Instead of accepting an external salt a monononically increasing nonce is used.  This nonce is stored per-code hash so other contract deployments don't interact. The nonces are stored via a direct indexed in storage.  a `noncesFor` method is provided to query the current nonce. Because of this the `noDelegateCall` modifier applies to all methods of all contracts.

```solidity
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
```

### [EOF Counterfactual Factory](../assets/erc-eof-create/EOFCounterfactualFactory.sol)

The counterfactual contract highly similar to the singleton contract, except that only the code hash can be used as the salt. To differentiate instances the data stored in the EOF data section (which is part of the input to the code has) should be updated.

```solidity
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
```


### Deployment Transactions

Deployment is a process involving three transactions.  The first transaction deploys the Counterfactual Factory using an [EIP-7698] EOF creation transaction.

```
//deployment bytes goes here
```

The next two transaction can be done by any account, and use [EIP-TBD] TXCREATE transactions through the Counterfactual Factory.

* Singleton Factory
  * initcode: `//TODO get bytecode`
  * input data: `//TODO encoding of deploy(initcode_hash)`
* Unsalted Factory
   * initcode: `//TODO get bytecode`
   * input data: `//TODO encoding of deploy(initcode_hash)`

### Deployment Method

The contracts are deployed via a combination of the keyless deployment method---also known as [Nick]'s method---which relies on a single-use address, to create a toehold contract and then using this toehold to deploy the other two contracts. (See [Nick's article] for more details). 

This operation can be done on any chain, guaranteeing that the contract address is always the same and nobody can use that address with a different contract.

The Counterfactual Factory will be deployed via the keyless deployment method first. In two subsequent transactions it will be used to deploy the other two contracts to deterministic addresses based on that toehold address.

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
    "inputs": [
      {
        "internalType": "bytes32",
        "name": "_codeHash",
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
    "stateMutability": "nonpayable",
    "type": "function"
  }
]
```

#### Unsalted Factory:
```json
[
  {
    "inputs": [
      {
        "internalType": "bytes32",
        "name": "_codeHash",
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
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "bytes32",
        "name": "_codeHash",
        "type": "bytes32"
      }
    ],
    "name": "nonceFor",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "nonce",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  }
]
```

#### Counterfactual Factory:
```json
[
  {
    "inputs": [
      {
        "internalType": "bytes32",
        "name": "_codeHash",
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

Source code for the solidity contracts is in the [ERC-TBD Assets](../assets/erc-eof-create).

## Security Considerations

* Some contracts can possibly not support being deployed on any chain, or require a different address per chain, that can be safely verified using the CHAINID Opcode ([EIP-1344]) in the constructor.
* Account contracts are singletons in the point of view of each user, when wallets want to signal what chain id is intended, [ERC-1191] should be used.
* Contracts deployed on factory must not use `msg.sender` in constructor, instead use constructor parameters, otherwise the factory would end up being the controller/only owner of those.
* External contracts may attempt to use the facilities via chained delegate calls to access and manipulate data that the contract at the original address hasn't intended to be shared as well as use the creation facilities with a different source address. To proactively prevent such problems all functions have code preventing use via DELEGATECALL and EXTDELEGATECALL. Contracts wishing to use this functionality at different address are free to include the source code in their own contracts without restriction.

## Copyright
Copyright and related rights waived via [CC0](../LICENSE.md).

[EIP-155]: https://eips.ethereum.org/EIPS/eip-155.md
[EIP-1344]: https://eips.ethereum.org/EIPS/eip-1344.md
[EIP-2429]: https://gitlab.com/status-im/docs/EIPs/blob/secret-multisig-recovery/EIPS/eip-2429.md
[EIP-TBD]: https://github.com/ethereum/EIPs/commit/4badb4ae5185a942b5c24cda7a5e0063fb8d2858
[ERC-1191]: ./erc-1191.md
[Nick's article]: https://medium.com/@weka/how-to-send-ether-to-11-440-people-187e332566b7
[Nick]: https://github.com/Arachnid/

