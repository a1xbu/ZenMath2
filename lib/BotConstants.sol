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
