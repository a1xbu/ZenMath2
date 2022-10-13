pragma ton-solidity >=0.63.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../interfaces/ITransferOwner.sol";

abstract contract Transferable is ITransferOwner{

    // Contract owner's public key (for external owner)
    uint256 m_public_key;
    // Or contract owner's address (for internal owner)
    address m_owner_address;

    /*
        @notice Transfer root token ownership
        @param m_public_key_ Root token owner public key
        @param m_owner_address_ Root token owner address
    */
    function transferOwner(
        uint256 m_public_key_,
        address m_owner_address_
    )
        override
        external
        onlyOwner
    {
        require((m_public_key_ != 0 && m_owner_address_.value == 0) ||
                (m_public_key_ == 0 && m_owner_address_.value != 0),
                200);
        tvm.accept();
        m_public_key = m_public_key_;
        m_owner_address = m_owner_address_;
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
        return m_owner_address.value != 0 && m_owner_address == msg.sender;
    }

    function isExternalOwner() private inline view returns (bool) {
        return m_public_key != 0 && m_public_key == msg.pubkey();
    }

}
