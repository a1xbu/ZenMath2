pragma ton-solidity >= 0.39.0;

library Fee {
    struct GameFees {
        uint128 hint;
        uint128 answer;
        uint128 leader;
        uint128 save;
        uint128 reward;
    }

    // default fees
    uint128 constant SAVE_FEE = 0.5 ton;
    uint128 constant HINT_FEE = 1 ton;
    uint128 constant ANSWER_FEE = 1.5 ton;
    uint128 constant REWARD_FEE = 2 ton;

    uint128 constant LEADER_FEE = 1 ton;
}