pragma ton-solidity >=0.44.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;



library GameConstants {
    uint16 constant MaxLevels = 1024;
    uint16 constant MaxLeaderboardLength = 3;

    uint8 constant FLAG_UNLOCK_HINT = 1;
    uint8 constant FLAG_UNLOCK_ANSWER = 2;
    uint8 constant FLAG_CLAIM_REWARD = 4;

    uint8 constant INPUT_READ_LEVEL = 0;
    uint8 constant INPUT_READ_ANSWER = 1;
    uint8 constant INPUT_READ_LEVEL_CODE = 2;
}

library ImageClass {
    uint8 constant LEVEL_IMAGE = 0;
    uint8 constant GRADE_IMAGE = 1;
    uint8 constant FINAL_IMAGE = 2;
    uint8 constant REWARD_IMAGE = 3;
    uint8 constant LOGO_IMAGE = 4;
    uint8 constant NUM_CLASSES = 5;
}

interface IGameData {
    struct GameInfo {
        Fee.GameFees fees;
        uint32 count_levels;
        uint128 count_players;
        address player;
        string salt;
        uint128 reward_left;
        address token_root;
        address game_token_wallet;
    }

    function GetInfo(address user_wallet) external view returns(GameInfo value);
    function Save(
        bool deploy,
        uint16 level,
        uint32 level_code,
        bool unlock_hint,
        bool unlock_answer,
        bool claim_reward
    )
        external
    returns (
        address
    );

    function RequestTokens(address recipient_address, uint16 level_id) external;
    function GetLevelImage(uint32 index, uint16 level_id) external view returns(bytes, uint8);
    function GetImage(uint32 index, uint8 class) external view returns(bytes, uint8);
}


library GameData {

	function GetInfo(uint32 answerId, address game_contract_address, address user_wallet) public {
        optional(uint256) pubkey;
		IGameData(game_contract_address).GetInfo{
            sign: false,
            pubkey: pubkey,
            time: uint64(now),
            expire: 0,
            callbackId: answerId,
            onErrorId: 0
        }(user_wallet).extMsg;
	}

    function GetLevelImage(uint32 answerId, address game_contract_address, uint32 index, uint16 level_id) public {
        optional(uint256) pubkey;
		IGameData(game_contract_address).GetLevelImage{
            sign: false,
            pubkey: pubkey,
            time: uint64(now),
            expire: 0,
            callbackId: answerId,
            onErrorId: 0
        }(index, level_id).extMsg;
	}

    function GetImage(uint32 answerId, address game_contract_address, uint32 index, uint8 class) public {
        optional(uint256) pubkey;
		IGameData(game_contract_address).GetImage{
            sign: false,
            pubkey: pubkey,
            time: uint64(now),
            expire: 0,
            callbackId: answerId,
            onErrorId: 0
        }(index, class).extMsg;
	}

}
