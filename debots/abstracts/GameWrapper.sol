pragma ton-solidity >=0.63.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;


import "https://raw.githubusercontent.com/tonlabs/DeBot-IS-consortium/main/Terminal/Terminal.sol";
import "https://raw.githubusercontent.com/tonlabs/DeBot-IS-consortium/main/UserInfo/UserInfo.sol";
import "https://raw.githubusercontent.com/tonlabs/DeBot-IS-consortium/main/Sdk/Sdk.sol";
import "https://raw.githubusercontent.com/tonlabs/DeBot-IS-consortium/main/ConfirmInput/ConfirmInput.sol";

import "../../interfaces/ILevelData.sol";
import "../../interfaces/IGameData.sol";
import "../../interfaces/IPlayer.sol";
import "../../interfaces/IUserWallet.sol";
import "../../interfaces/ITokenRoot.sol";
import "../../interfaces/ITokenWallet.sol";

import "../../lib/Gas.sol";
import "../../lib/BotConstants.sol";

import "State.sol";
import "Debug.sol";


abstract contract GameInteraction {
    address internal m_wallet; // User EVER wallet (Surf address)
    address internal m_game;

    uint32 private m_last_success_id;
    uint32 private m_last_error_id;
    TvmCell private m_last_tx;
    uint128 m_last_gas_value;
    bool internal m_is_player_deployed = false;

    /// @dev Submit new transaction using Surf wallet.
    /// @param target_contract Transfer target address.
    /// @param gas NanoEvers value to transfer.
    /// @param bounce Bounce flag. Set true if need to transfer grams to existing account; set false to create new account.
    /// @param payload Tree of cells used as body of outbound internal message.
    /// @param answerId Success callback ID.
    /// @param onErrorId Error callback ID.
    function SubmitTransaction(
        address user_wallet,
        address target_contract,
        uint128 gas,
        bool bounce,
        TvmCell payload,
        uint32 answerId,
        uint32 onErrorId
    )
        internal
        pure
        inline
    {
        optional(uint256) pubkey = 0;
        IUserWallet(user_wallet).submitTransaction{
                sign: true,
                pubkey: pubkey,
                time: uint64(now),
                expire: 0,
                callbackId: answerId,
                onErrorId: onErrorId
        }(target_contract, gas, bounce, false, payload).extMsg;
    }

    function ReSubmitTransaction() internal view {
        SubmitTransaction(m_wallet, m_game, m_last_gas_value, true, m_last_tx, m_last_success_id, m_last_error_id);
    }

    function GameSaveInternal(
        uint32 answerId,
        uint32 onErrorId,
        bool deploy,
        uint16 level,
        uint32 level_code,
        bool unlock_hint,
        bool unlock_answer,
        bool claim_reward,
        uint128 gas
    )
        internal
    {
        //Terminal.print(0, format("GameSaveInternal {}:{}", level, level_code));
        m_last_tx = tvm.encodeBody(
            IGameData.Save,
                deploy,
                level,
                level_code,
                unlock_hint,
                unlock_answer,
                claim_reward
        );

        m_last_success_id = answerId;
        m_last_error_id = onErrorId;
        m_last_gas_value = gas;

        ReSubmitTransaction();
    }
}


library Action {
    uint32 constant INIT = 100;
    uint32 constant UPDATE_PLAYER = 200;
    uint32 constant UPDATE_LEVEL = 300;
    uint32 constant SAVE_PLAYER = 400;
    uint32 constant SAVE_PLAYER_SUCCESS = 500; // update data after save
    uint32 constant UPDATE_TOKENS = 600; // update data after save

    uint32 constant INVALID_ACTION = 0xFFFFFFFF;
}

library Step {
    uint32 constant INIT_WALLET = 0;
    uint32 constant INIT_RANDOM_SEED = 1;
    uint32 constant INIT_LOGO_IMAGE = 2;
    uint32 constant INIT_REWARD_IMAGE = 3;
    uint32 constant INIT_GAME = 4;
    uint32 constant INIT_TOKEN_WALLET = 5;
    uint32 constant INIT_TOKEN_DECIMALS = 6;
    uint32 constant INIT_DONE = 7;

    uint32 constant UPDATE_PLAYER_CHECK = 0;
    uint32 constant UPDATE_PLAYER_DATA = 1;
    uint32 constant UPDATE_PLAYER_TOKENS_CHECK = 2; // check if wallet deployed
    uint32 constant UPDATE_PLAYER_TOKENS = 3;
    uint32 constant UPDATE_PLAYER_DONE = 4;

    uint32 constant UPDATE_LEVEL = 0;
    uint32 constant UPDATE_LEVEL_IMAGE = 1;
    uint32 constant UPDATE_LEVEL_DONE = 2;

    uint32 constant SAVE_PLAYER_CHECK = 0; // check if player contract deployed
    uint32 constant SAVE_PLAYER_UPDATE_INFO = 1; // load contract data if available
    uint32 constant SAVE_PLAYER_UPDATE_LEVEL_LOCKS = 2; // load level locks
    uint32 constant SAVE_PLAYER_GET_BALANCE = 3; // Check if the user has enough EVER to pay for the operation
    uint32 constant SAVE_PLAYER_COMMIT = 4; // save new data in the blockchain

    uint32 constant UPDATE_TOKENS_CHECK = 0;
    uint32 constant UPDATE_TOKENS = 1;
}

library Account {
    uint8 constant PLAYER = 0;
    uint8 constant TOKEN_WALLET = 1;
}

abstract contract GameWrapper is State, DebugOutput, GameInteraction{
    uint16 internal m_level_id = 0;
    uint16 internal m_max_level = 0;
    ILevelData.Level internal m_level_data;
    IGameData.GameInfo internal m_game_info;
    IPlayer.PlayerInfo internal m_player_info;
    IPlayer.LevelLocks internal m_level_locks;
    bytes[] internal m_images;
    uint32 m_rnd_seed = 13794513;

    // ZEN token
    address internal m_token_wallet; // token wallet address
    bool internal m_is_token_wallet_deployed = false;
    uint128 internal m_token_balance;
    uint128 internal m_prev_token_balance;
    uint8 internal m_token_decimals = 9;

    uint32 private m_last_success_id;
    uint32 private m_last_error_id;

    // Wallet
    bool internal m_not_enough_money; // EVER wallet balance

    // Saved unlock flags
    uint32 private m_flags; // FLAG_UNLOCK_HINT, FLAG_UNLOCK_ANSWER, FLAG_CLAIM_REWARD
    uint16 private m_save_level_id;

    bool internal m_last_tx_success;

    // Entry points
    function Init() internal { run_action(Action.INIT); }
    function UpdatePlayer() internal { run_action(Action.UPDATE_PLAYER); }
    function UpdateLevel() internal { run_action(Action.UPDATE_LEVEL); }

    function run() internal override {
        DbgPrint(format("ACTION: {}, STEP: {}", action(), step()));
        if (action() == Action.INVALID_ACTION) return;

        else if(action() == Action.INIT) InitHandler(step());
        else if(action() == Action.UPDATE_PLAYER) UpdatePlayerHandler(step());
        else if(action() == Action.UPDATE_LEVEL) UpdateLevelHandler(step());
        else if(action() == Action.SAVE_PLAYER) SavePlayerHandler(step());
        else if(action() == Action.SAVE_PLAYER_SUCCESS) SavePlayerSuccessHandler(step());
        else if(action() == Action.UPDATE_TOKENS) UpdateTokensHandler(step());
    }

    // Utilities
    function CalculateLevelCode(uint16 level_id) internal view returns(uint32) {
        TvmBuilder builder;
        builder.store(level_id);
        builder.store(m_wallet);
        builder.store(m_game);
        return uint32(tvm.hash(builder.toCell()) & 0xFFFF);
    }

    // Callbacks
    // Init game
    function _OnGetAddress(address value) public { m_wallet = value; next(); }
    function _OnGenRandom(bytes buffer) public { m_rnd_seed = uint32(bytes4(buffer)); next(); }
    function _OnGetInfo(IGameData.GameInfo value) public {
        m_game_info = value; m_game_info.token_root.value == 0 ? finish() : next(); }
    function _OnGetTokenWallet(address value) public { m_token_wallet = value; next(); }
    function _OnGetTokenDecimals(uint8 value) public { m_token_decimals = value; finish(); }

    // Init level
    function _OnGetLevel(ILevelData.Level value) public { m_level_data = value; next(); }
    function _OnGetImage(bytes image, uint8 class) public {
        if(action() == Action.UPDATE_LEVEL) {
            m_images[ImageClass.LEVEL_IMAGE] = image;
            finish();
        }
        else if(action() == Action.INIT) {
            m_images[class] = image;
            next();
        }
    }

    // Check if account deployed (callback)
    function _IsDeployed(int8 acc_type) public {
        DbgPrint(format("_IsDeployed {}", _account_type()));
        bool deployed = !((acc_type==-1)||(acc_type==0));
        if(_account_type() == Account.PLAYER)
            _IsPlayerDeployed(deployed);
        else if(_account_type() == Account.TOKEN_WALLET)
            _IsWalletDeployed(deployed);
    }

    function _IsPlayerDeployed(bool deployed) private inline {
        if (!deployed) {
            m_is_player_deployed = false;
            DbgPrint("Player NOT deployed");

            // skip steps
            if(action() == Action.SAVE_PLAYER) {
                next_step(); // SAVE_PLAYER_INFO
                next_step(); // SAVE_PLAYER_UPDATE_LEVEL_LOCKS
                next(); // SAVE_PLAYER_COMMIT
            }
            else if(action() == Action.UPDATE_PLAYER) {
                next_step(); // UPDATE_PLAYER_TOKENS_CHECK
                next(); // UPDATE_PLAYER_TOKENS
            }
            else // Action.SAVE_PLAYER_SUCCESS
                // Here the Player contract must be already deployed, but could be the case
                // when it didn't happen (timeout, connection issues)
                finish();
        }
        else {
            m_is_player_deployed = true;
            DbgPrint("Player already deployed");
            next();
        }
    }
    function _OnUpdatePlayer(IPlayer.PlayerInfo value) public {
        m_player_info = value;
        if(action() == Action.UPDATE_PLAYER) {
            // overwrite current m_level_id only if m_max_level will change
            // This prevents overwriting m_level_id in case if the user
            // explores previous levels that he has already passed
            if(m_level_id < m_player_info.level && m_max_level < m_player_info.level)
                m_level_id = m_player_info.level; // set current level to saved level on Init
        }
        if(m_max_level < m_player_info.level)
            m_max_level = m_player_info.level;
        next();
    }
    function _OnUpdateLevelLocks(IPlayer.LevelLocks value) public {
        m_level_locks = value;
        // check locks and finish if required
        if(action() == Action.SAVE_PLAYER) {
            if((AnswerUnlockRequested() && !m_level_locks.answer_unlocked) || (HintUnlockRequested() && !m_level_locks.hint_unlocked))
                next(); // contract write interaction is required to unlock hints
            else if(DeleteUserRequested())
                next(); // This is a forced operation which must be executed anyway
            else if(m_player_info.level < m_level_id)
                next(); // contract write interaction is required to save level
            else {
                set_action(Action.SAVE_PLAYER_SUCCESS);
                finish(); // contract interaction is not required - everything is already in the blockchain
            }
        }
        else
            finish();
    }

    // Tokens
    function _IsWalletDeployed(bool deployed) private inline {
        if (!deployed) {
            m_is_token_wallet_deployed = false;
            finish();
        }
        else {
            m_is_token_wallet_deployed = true;
            next();
        }
    }
    function _OnGetTokenBalance(uint128 value) public {
        m_prev_token_balance = m_token_balance;
        m_token_balance = value;
        finish();
    }

    // Wallet
    function _OnGetEverBalance(uint128 nanotokens) public {
        if(nanotokens > m_last_gas_value) {
            m_not_enough_money = false;
            next();
        }
        else {
            m_not_enough_money = true;
            finish();
        }
    }

    // Game interaction callbacks
    function _OnSaveSuccess(uint64) public {
        m_last_tx_success = true;
        run_action(Action.SAVE_PLAYER_SUCCESS);
    }

    function _OnTxFailed(uint32 sdkError, uint32 exitCode) public {
        sdkError;
        exitCode;
        m_last_tx_success = false;
        Terminal.print(0, format("{} ({}, {})", "Error", sdkError, exitCode));
        ConfirmInput.get(tvm.functionId(RetryTransaction), "Retry?");
    }

    function RetryTransaction(bool value) public {
        if (value) ReSubmitTransaction();
        else finish();
    }

    // Handlers
    function InitHandler(uint32 step) private {
        if(step == Step.INIT_WALLET)
            UserInfo.getAccount(tvm.functionId(_OnGetAddress));
        else if(step == Step.INIT_RANDOM_SEED)
            Sdk.genRandom(tvm.functionId(_OnGenRandom), 4);
        else if(step == Step.INIT_LOGO_IMAGE)
            GameData.GetImage(tvm.functionId(_OnGetImage), m_game, rand(), ImageClass.LOGO_IMAGE);
        else if(step == Step.INIT_REWARD_IMAGE)
            GameData.GetImage(tvm.functionId(_OnGetImage), m_game, 0, ImageClass.REWARD_IMAGE);
        else if(step == Step.INIT_GAME)
            GameData.GetInfo(tvm.functionId(_OnGetInfo), m_game, m_wallet);
        else if(step == Step.INIT_TOKEN_WALLET)
            TokenRoot.walletOf(tvm.functionId(_OnGetTokenWallet), m_game_info.token_root, m_wallet);
        else if(step == Step.INIT_TOKEN_DECIMALS)
            TokenRoot.decimals(tvm.functionId(_OnGetTokenDecimals), m_game_info.token_root);
    }

    uint8 private m_account_type;
    function CheckIfAccountDeployed(uint8 account_type, address addr) private {
        m_account_type = account_type;
        Sdk.getAccountType(tvm.functionId(_IsDeployed), addr);
    }
    function _account_type() private view returns(uint8) { return m_account_type; }

    function UpdatePlayerHandler(uint32 step) private {
        if(step == Step.UPDATE_PLAYER_CHECK) {
            CheckIfAccountDeployed(Account.PLAYER, m_game_info.player);
        }
        else if(step == Step.UPDATE_PLAYER_DATA) {
            PlayerData.get(tvm.functionId(_OnUpdatePlayer), m_game_info.player);
        }
        else if(step == Step.UPDATE_PLAYER_TOKENS_CHECK) {
            CheckIfAccountDeployed(Account.TOKEN_WALLET, m_token_wallet);
        }
        else if(step == Step.UPDATE_PLAYER_TOKENS) {
            TokenWallet.balance(tvm.functionId(_OnGetTokenBalance), m_token_wallet);
        }
    }

    function UpdateLevelHandler(uint32 step) private {
        if(step == Step.UPDATE_LEVEL)
            LevelData.GetLevel(
                tvm.functionId(_OnGetLevel),
                m_game,
                m_wallet,
                m_level_id,
                CalculateLevelCode(m_level_id)
            );
        else if(step == Step.UPDATE_LEVEL_IMAGE) {
            // This function retrieves the image that is shown after completing a level
            // The image could be a regular "Correct!" image, or the "Next grade" image
            // if the (m_level_id % 10) == 0, or the "Graduated!" image if this is the last
            // level.
            // The image is automatically selected by the Game contract depending
            // on the index value (which is rand()) and the m_level_id. Therefore,
            // for the "Correct!" image a random image from the list of images is selected.
            GameData.GetLevelImage(tvm.functionId(_OnGetImage), m_game, rand(), m_level_id);
        }
    }

    function SavePlayerHandler(uint32 step) private {
        if(step == Step.SAVE_PLAYER_CHECK) {
            CheckIfAccountDeployed(Account.PLAYER, m_game_info.player);
        }
        else if(step == Step.SAVE_PLAYER_UPDATE_INFO) {
            PlayerData.get(tvm.functionId(_OnUpdatePlayer), m_game_info.player);
        }
        else if(step == Step.SAVE_PLAYER_UPDATE_LEVEL_LOCKS) {
            PlayerData.getLocks(tvm.functionId(_OnUpdateLevelLocks), m_game_info.player, m_level_id);
        }
        else if(step == Step.SAVE_PLAYER_GET_BALANCE) {
            Sdk.getBalance(tvm.functionId(_OnGetEverBalance), m_wallet);
        }
        else if(step == Step.SAVE_PLAYER_COMMIT) {
            GameSaveInternal(
                tvm.functionId(_OnSaveSuccess),
                tvm.functionId(_OnTxFailed),
                !m_is_player_deployed,
                m_save_level_id,
                CalculateLevelCode(m_save_level_id),
                HintUnlockRequested(),
                AnswerUnlockRequested(),
                ClaimRewardRequested(),
                m_last_gas_value
            );
        }
    }

    function SavePlayerSuccessHandler(uint32 step) private {
        if(step == Step.SAVE_PLAYER_CHECK) {
            // reset saved level ids
            m_max_level = 0;
            m_level_id = 0;

            CheckIfAccountDeployed(Account.PLAYER, m_game_info.player);
        }
        if(step == Step.SAVE_PLAYER_UPDATE_INFO) {
            PlayerData.get(tvm.functionId(_OnUpdatePlayer), m_game_info.player);
        }
        else if(step == Step.SAVE_PLAYER_UPDATE_LEVEL_LOCKS) {
            PlayerData.getLocks(tvm.functionId(_OnUpdateLevelLocks), m_game_info.player, m_level_id);
        }
    }

    function UpdateTokensHandler(uint32 step) private {
        if(step == Step.UPDATE_TOKENS_CHECK) {
            CheckIfAccountDeployed(Account.TOKEN_WALLET, m_token_wallet);
        }
        else if(step == Step.UPDATE_TOKENS) {
            TokenWallet.balance(tvm.functionId(_OnGetTokenBalance), m_token_wallet);
        }
    }

    // Interaction helpers
    function GameSaveWrapperInternal(
        uint128 gas,
        uint16 level_id,
        bool unlock_hint,
        bool unlock_answer,
        bool claim_reward
    )
        private
    {
        // store variables
        m_last_gas_value = gas;

        m_flags = 0;
        if(unlock_hint) m_flags += GameConstants.FLAG_UNLOCK_HINT;
        if(unlock_answer) m_flags += GameConstants.FLAG_UNLOCK_ANSWER;
        if(claim_reward) m_flags += GameConstants.FLAG_CLAIM_REWARD;

        m_save_level_id = level_id;

        if(!m_is_player_deployed)
            m_last_gas_value += Gas.TARGET_PLAYER_BALANCE;

        // do the sequence of async actions
        run_action(Action.SAVE_PLAYER);
    }

    function GameSave() public {
        bool claim_reward = false;
        uint128 gas = Gas.GAME_SAVE + Gas.PLAYER_STORE + m_game_info.fees.save;
        if((m_level_id + 1) % 10 == 0) {
            claim_reward = true;
            gas += m_game_info.fees.reward + Gas.ASK_FOR_TOKENS +
                Gas.TRANSFER_TO_RECIPIENT_VALUE + TokenGas.TARGET_WALLET_BALANCE;
            DbgPrint("Claim reward");
        }

        GameSaveWrapperInternal(gas, m_level_id, false, false, claim_reward);
    }

    function UnlockHint() internal {
        GameSaveWrapperInternal(Gas.GAME_SAVE + m_game_info.fees.hint, m_level_id, true, false, false);
    }

    function UnlockAnswer() internal {
        GameSaveWrapperInternal(Gas.GAME_SAVE + m_game_info.fees.answer, m_level_id, false, true, false);
    }

    function DeleteUser() internal {
        GameSaveWrapperInternal(Gas.GAME_SAVE, 0xFFFF, false, false, false);
    }

    //---------------------

    function HintUnlockRequested() internal inline view returns(bool) {
        return (m_flags & GameConstants.FLAG_UNLOCK_HINT) != 0;
    }

    function AnswerUnlockRequested() internal inline view returns(bool) {
        return (m_flags & GameConstants.FLAG_UNLOCK_ANSWER) != 0;
    }

    function ClaimRewardRequested() internal inline view returns(bool) {
        return (m_flags & GameConstants.FLAG_CLAIM_REWARD) != 0;
    }

    function DeleteUserRequested() internal view returns(bool) {
        return m_save_level_id == 0xFFFF;
    }

    function ResetSaveRequest() internal {
        m_flags = 0;
        m_not_enough_money = false;
        m_save_level_id = m_level_id;
    }

    function rand() internal returns(uint32) {
        m_rnd_seed = uint32(((uint64(m_rnd_seed) * 73129 + 95121)) & 0xFFFFFFFF);
        return m_rnd_seed;
    }
}
