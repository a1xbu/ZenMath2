pragma ton-solidity >=0.44.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

interface ILevelData {
    struct LevelData {
        bytes image;
        string text;
    }

    struct Level {
        uint16 level_id;
        LevelData task;
        LevelData hint;
        LevelData answer;
        string question;
        uint256 answer_hash;
        uint128 reward;
    }

    function GetLevel(address user_address, uint16 level_id, uint32 prev_level_code) external view returns(Level);
}


library LevelData {

	function GetLevel(
        uint32 answerId, address game_contract_address,
        address user_address, uint16 level_id, uint32 prev_level_code
    ) public {
		optional(uint256) pubkey;
		ILevelData(game_contract_address).GetLevel{
            sign: false,
            pubkey: pubkey,
            time: uint64(now),
            expire: 0,
            callbackId: answerId,
            onErrorId: 0
        }(user_address, level_id, prev_level_code).extMsg;
	}
}
