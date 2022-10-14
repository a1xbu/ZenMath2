pragma ton-solidity >=0.63.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;


import "../interfaces/IPlayer.sol";
import "../interfaces/IGameData.sol"
;
import "../lib/MsgFlag.sol";
import "../lib/Gas.sol";


contract Player is IPlayer{
    address static root_address; // the address of the Game contract
    //TvmCell static code;
    //for internal owner
    address static owner_address;

    PlayerInfo player;

    uint256[] m_answer_locks;  // max levels = 1024
    uint256[] m_hint_locks;

    uint32 m_prev_points;

    /*
        @notice Creates new Player
        @dev All the parameters are specified as initial data
        @dev If owner_address is not empty, it will be notified with .notifyWalletDeployed
    */
    constructor() public {
        tvm.accept();
        player.owner = owner_address;
        init();
    }

    function init() private {
        player.points = 0;
        player.level = 0;
        player.last_reward = 0;
        player.prev_points = 0;
        player.name = "";
        player.reward_paid_at = 0;
        m_answer_locks = new uint256[](4);
        m_hint_locks = new uint256[](4);
    }

    function save(
        address gas_back_address,
        uint16 level,
        bool unlock_hint,
        bool unlock_answer,
        bool claim_reward
    )
        external
        override
        onlyRoot
    {
        require(level < 1024);
        // The user must save every 10 levels, the difference between save and unsaved level
        // can't be bore than 10
        require(level < player.level || level - player.level <= 10);

        tvm.rawReserve(_reserve(), 0);
        unlock_hints(level, unlock_hint, unlock_answer);

        if(claim_reward && player.reward_paid_at < level) {
            RequestReward();
        }
        else {
            gas_back_address.transfer({
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS,
                bounce: false
            });
        }
    }

    function erase(
        address gas_back_address
    )
        external
        override
    {
        tvm.rawReserve(_reserve(), 0);
        init();
        gas_back_address.transfer({
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS,
            bounce: false
        });
    }

    function RequestReward() private {
        player.reward_paid_at = player.level;
        player.last_reward = player.points - player.prev_points;
        player.prev_points = player.points;
        IGameData(root_address).RequestTokens{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED // transfer back all unused gas
        }(
            player
        );
    }

    /*
        @notice Requests to unlock hint or answer
        @dev Can be called only by root token
        @param level Level to unlock tip
        @param unlock_hint If true unlocks the hint
        @param unlock_answer If true unlocks the answer
    */
    function unlock_hints(
        uint16 level,
        bool unlock_hint,
        bool unlock_answer
    )
        private
        inline
    {
        uint32 penalty = 0;

        if(unlock_hint || unlock_answer) {
            uint8 chunk = uint8((level >> 8) & 0x3);

            if(unlock_hint) {
                m_hint_locks[chunk] |= uint256(1) << uint8(level % 256);
                penalty += 3;
            }
            if(unlock_answer) {
                m_answer_locks[chunk] |= uint256(1) << uint8(level % 256);
                penalty += 6;
            }
        }

        if (level > player.level) {
            player.points += (level - player.level) * 10;
            player.level = level;
        }

        if (player.points > penalty)
            player.points -= penalty;
        else
            player.points = 0;
    }

    function get()
        override
        external
        view
        returns (PlayerInfo)
    {
        return player;
    }

    function getLocks(uint16 level_id)
        override
        external
        view
        responsible
        returns (LevelLocks)
    {
        LevelLocks locks;
        uint8 chunk = uint8((level_id >> 8) & 0x3);
        locks.hint_unlocked = ((m_hint_locks[chunk] >> uint8(level_id % 256)) & 1) != 0;
        locks.answer_unlocked = ((m_answer_locks[chunk] >> uint8(level_id % 256)) & 1) != 0;
        return { value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS }locks;
    }

    modifier onlyRoot() {
        require(root_address == msg.sender, 150);
        _;
    }

    function _targetBalance() internal pure returns (uint128) {
        return Gas.TARGET_PLAYER_BALANCE;
    }

    function _reserve() internal pure returns (uint128) {
        return math.max(address(this).balance - msg.value, _targetBalance());
    }

    fallback() external {
    }

}