pragma ton-solidity >= 0.39.0;

library Gas {
    uint128 constant GAME_SAVE                      = 0.3 ton;
    uint128 constant PLAYER_STORE                   = 0.2 ton;
    uint128 constant ASK_FOR_TOKENS                 = 0.2 ton;
    uint128 constant GAME_REQUEST_TOKENS            = 0.2 ton;
    uint128 constant TARGET_GAME_BALANCE            = 5 ton;
    uint128 constant TARGET_PLAYER_BALANCE          = 0.1 ton;

    uint128 constant TRANSFER_TO_RECIPIENT_VALUE    = 0.5 ton;
}

library TokenGas {
    uint128 constant TARGET_ROOT_BALANCE                            = 1 ton;
    uint128 constant TARGET_WALLET_BALANCE                          = 0.1 ton;
    uint128 constant SEND_EXPECTED_WALLET_VALUE                     = 0.1 ton;
}
