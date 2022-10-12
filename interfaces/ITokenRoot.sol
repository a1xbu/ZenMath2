pragma ton-solidity >= 0.57.0;


interface ITokenRoot {

    /*
        @notice Get root owner
        @returns rootOwner
    */
    function rootOwner() external view responsible returns (address);

    /*
        @notice Derive TokenWallet address from owner address
        @param _owner TokenWallet owner address
        @returns Token wallet address
    */
    function walletOf(address owner) external view responsible returns (address);

    /*
        @notice Deploy new TokenWallet
        @dev Can be called by anyone
        @param owner Token wallet owner address
        @param deployWalletValue Gas value to
    */
    function deployWallet(
        address owner,
        uint128 deployWalletValue
    ) external responsible returns (address);

    function decimals() external view responsible returns (uint8);
}

library TokenRoot {
	function walletOf(
        uint32 answerId, address token_root, address owner
    ) public {
		optional(uint256) pubkey;
		ITokenRoot(token_root).walletOf{
            sign: false,
            pubkey: pubkey,
            time: uint64(now),
            expire: 0,
            callbackId: answerId,
            onErrorId: 0
        }(owner).extMsg;
	}

    function decimals(
        uint32 answerId, address token_root
    ) public {
		optional(uint256) pubkey;
		ITokenRoot(token_root).decimals{
            sign: false,
            pubkey: pubkey,
            time: uint64(now),
            expire: 0,
            callbackId: answerId,
            onErrorId: 0
        }().extMsg;
	}
}