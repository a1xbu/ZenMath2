pragma ton-solidity >=0.63.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;


import "../interfaces/ILevelData.sol";
import "../abstracts/Transferable.sol";
import "../lib/ErrCodes.sol";


library LevelsDataConstants {
    uint16 constant MaxLevels = 1024;
}

abstract contract LevelsData is ILevelData, Transferable{
    Level[] m_levels;

    function AddLevel(
        uint16 level_id,
        bytes task_image,
        string task,
        bytes hint_image,
        string hint,
        bytes answer_image,
        string answer,
        string question,
        uint256 answer_hash,
        string salt,
        uint128 reward
    )
        public
        onlyOwner
    {
        require(level_id < LevelsDataConstants.MaxLevels, ErrCodes.LEVEL_OUT_OF_BOUND);
        tvm.accept();
        Level level;

        if (level_id >= uint16(m_levels.length)) {
            level.level_id = uint16(m_levels.length);
            m_levels.push(level);
            level_id = level.level_id;
        }

        m_levels[level_id].task.image = task_image;
        m_levels[level_id].task.text = task;
        m_levels[level_id].hint.image = hint_image;
        m_levels[level_id].hint.text = hint;
        m_levels[level_id].answer.image = answer_image;
        m_levels[level_id].answer.text = answer;
        m_levels[level_id].answer_hash = answer_hash;
        m_levels[level_id].salt = salt;
        m_levels[level_id].question = question;
        m_levels[level_id].reward = reward;
    }
}