pragma ton-solidity >=0.44.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "../interfaces/IPlayer.sol";
import "../lib/Fee.sol";


interface IGameData {
    struct GameInfo {
        Fee.GameFees fees;
        uint32 count_levels;
        uint128 count_players;
        address player;
        uint128 reward_left;
        address token_root;
        //address game_token_wallet;
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

    function RequestTokens(IPlayer.PlayerInfo player) external;
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
