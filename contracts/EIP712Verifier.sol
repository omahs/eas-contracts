// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "./IEIP712Verifier.sol";

/// @title EIP712 typed signatures verifier for EAS delegated attestations.
contract EIP712Verifier is IEIP712Verifier {
    string public constant VERSION = "0.2";

    // EIP712 domain separator, making signatures from different domains incompatible.
    bytes32 public immutable DOMAIN_SEPARATOR; // solhint-disable-line var-name-mixedcase

    // The hash of the data type used to relay calls to the attest function. It's the value of
    // keccak256("Attest(address recipient,uint256 ao,uint256 expirationTime,bytes32 refUUID,bytes data,uint256 nonce)").
    bytes32 public constant ATTEST_TYPEHASH = 0x65c1f6a23cba082e11808f5810768554fa9dfba7aa5f718980214483e87e1031;

    // The hash of the data type used to relay calls to the revoke function. It's the value of
    // keccak256("Revoke(bytes32 uuid,uint256 nonce)").
    bytes32 public constant REVOKE_TYPEHASH = 0xbae0931f3a99efd1b97c2f5b6b6e79d16418246b5055d64757e16de5ad11a8ab;

    // Replay protection nonces.
    mapping(address => uint256) private _nonces;

    /// @dev Creates a new EIP712Verifier instance.
    constructor() {
        uint256 chainId;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            chainId := chainid()
        }

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("EAS")),
                keccak256(bytes(VERSION)),
                chainId,
                address(this)
            )
        );
    }

    /// @dev Returns the current nonce per-account.
    ///
    /// @param account The requested accunt.
    //
    /// @return The current nonce.
    function getNonce(address account) external view override returns (uint256) {
        return _nonces[account];
    }

    /// @dev Verifies signed attestation.
    ///
    /// @param recipient The recipient the attestation.
    /// @param ao The ID of the AO.
    /// @param expirationTime The expiration time of the attestation.
    /// @param refUUID An optional related attestation's UUID.
    /// @param data The additional attestation data.
    /// @param attester The attesting account.
    /// @param v The recovery ID.
    /// @param r The x-coordinate of the nonce R.
    /// @param s The signature data.
    function attest(
        address recipient,
        uint256 ao,
        uint256 expirationTime,
        bytes32 refUUID,
        bytes calldata data,
        address attester,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        ATTEST_TYPEHASH,
                        recipient,
                        ao,
                        expirationTime,
                        refUUID,
                        keccak256(data),
                        _nonces[attester]++
                    )
                )
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == attester, "ERR_INVALID_SIGNATURE");
    }

    /// @dev Verifies signed revocations.
    ///
    /// @param uuid The UUID of the attestation to revoke.
    /// @param attester The attesting account.
    /// @param v The recovery ID.
    /// @param r The x-coordinate of the nonce R.
    /// @param s The signature data.
    function revoke(
        bytes32 uuid,
        address attester,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(REVOKE_TYPEHASH, uuid, _nonces[attester]++))
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == attester, "ERR_INVALID_SIGNATURE");
    }
}