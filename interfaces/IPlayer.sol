pragma ton-solidity >=0.39.0;
pragma AbiHeader expire;

interface IPlayer {
    struct LevelLocks {
        bool hint_unlocked;
        bool answer_unlocked;
    }

    struct PlayerInfo {
        uint16 level;
        uint32 points;
        uint32 prev_points;
        uint128 last_reward;
        address owner;
        string name;
        uint16 reward_paid_at; // the level reward paid at
    }

    function getLocks(uint16 level_id) external view responsible returns (LevelLocks);
    function save(address gas_back_address, uint16 level_id, bool unlock_hint, bool unlock_answer, bool claim_reward) external;
    function erase(address gas_back_address) external;
    function get() external view returns (PlayerInfo value);
}

library PlayerData {

	function getLocks(uint32 answerId, address player_contract, uint16 level_id) public {
		optional(uint256) pubkey;
		IPlayer(player_contract).getLocks{
            sign: false,
            pubkey: pubkey,
            time: uint64(now),
            expire: 0,
            callbackId: answerId,
            onErrorId: 0
        }(level_id).extMsg;
	}

    function get(uint32 answerId, address player_contract) public {
		optional(uint256) pubkey;
		IPlayer(player_contract).get{
            sign: false,
            pubkey: pubkey,
            time: uint64(now),
            expire: 0,
            callbackId: answerId,
            onErrorId: 0
        }().extMsg;
	}
}
