pragma ton-solidity >=0.63.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../interfaces/ITransferOwner.sol";

abstract contract Transferable is ITransferOwner{

    // Contract owner's public key (for external owner)
    uint256 root_public_key;
    // Or contract owner's address (for internal owner)
    address root_owner_address;

    /*
        @notice Transfer root token ownership
        @param root_public_key_ Root token owner public key
        @param root_owner_address_ Root token owner address
    */
    function transferOwner(
        uint256 root_public_key_,
        address root_owner_address_
    )
        override
        external
        onlyOwner
    {
        require((root_public_key_ != 0 && root_owner_address_.value == 0) ||
                (root_public_key_ == 0 && root_owner_address_.value != 0),
                200);
        tvm.accept();
        root_public_key = root_public_key_;
        root_owner_address = root_owner_address_;
    }

    // =============== Support functions ==================

    modifier onlyOwner() {
        require(isOwner(), 100);
        _;
    }

    modifier onlyInternalOwner() {
        require(isInternalOwner(), 100);
        _;
    }

    function isOwner() private inline view returns (bool) {
        return isInternalOwner() || isExternalOwner();
    }

    function isInternalOwner() private inline view returns (bool) {
        return root_owner_address.value != 0 && root_owner_address == msg.sender;
    }

    function isExternalOwner() private inline view returns (bool) {
        return root_public_key != 0 && root_public_key == msg.pubkey();
    }

}
