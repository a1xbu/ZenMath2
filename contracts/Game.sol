pragma ton-solidity >=0.63.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../interfaces/ILevelData.sol";
import "../interfaces/IGameData.sol";
import "../interfaces/ITokenWallet.sol";
import "../interfaces/ITokenRoot.sol";

import "../lib/Fee.sol";
import "../lib/BotConstants.sol";

import "../abstracts/LevelsData.sol";
import "../abstracts/PlayerDeployer.sol";


contract Game is Transferable, LevelsData, PlayerDeployer, IGameData {

    uint128 m_start_balance = 0;
    Fee.GameFees m_fees;

    address m_token_root;
    address m_token_wallet;
    address m_vault_address;

    uint128 m_total_reward = 0;
    uint128 m_reward_ratio = 1000;

    uint32 private nonce = 5;

    bytes[][] m_images;

    constructor() public {
        tvm.accept();
        m_start_balance = address(this).balance;
        m_public_key = msg.pubkey();

        m_fees.save = Fee.SAVE_FEE;
        m_fees.hint = Fee.HINT_FEE;
        m_fees.answer = Fee.ANSWER_FEE;
        m_fees.leader = Fee.LEADER_FEE;
        m_fees.reward = Fee.REWARD_FEE;

        m_images = new bytes[][](ImageClass.NUM_CLASSES);
    }

    function AddImage(
        bytes image,
        uint32 index,
        uint8 image_class
    )
        public
        onlyOwner
    {
        require(image_class < ImageClass.NUM_CLASSES);
        tvm.accept();
        if(index == 0xFFFFFFFF)
            m_images[image_class].push(image);
        else if(index < m_images[image_class].length)
            m_images[image_class][index] = image;
    }

    function GetImage(uint32 index, uint8 class) external view override returns(bytes, uint8){
        return _get_image(index, class);
    }

    function GetLevelImage(uint32 index, uint16 level_id) public view override returns(bytes, uint8){
        // "Graduated" images
        if(level_id >= m_levels.length - 1)
            return _get_image(index, ImageClass.FINAL_IMAGE);

        // "Next grade" images
        else if((level_id + 2) % 10 == 0)
            return _get_image(level_id / 10, ImageClass.GRADE_IMAGE);

        // regular level images
        return _get_image(index, ImageClass.LEVEL_IMAGE);
    }

    function _get_image(uint32 index, uint8 class) internal view returns(bytes, uint8) {
        if(m_images[class].length == 0)
            return ("", class);
        return (m_images[class][index % m_images[class].length], class);
    }

    function CleanData()
        public
        onlyOwner
    {
        tvm.accept();
        m_images = new bytes[][](ImageClass.NUM_CLASSES);
        m_levels = new Level[](0);
    }

    function SetFees(
        uint128 fee_save,
        uint128 fee_hint,
        uint128 fee_answer,
        uint128 fee_leader,
        uint128 fee_reward
    )
        public
        onlyOwner
    {
        tvm.accept();
        m_fees.save = fee_save;
        m_fees.hint = fee_hint;
        m_fees.answer = fee_answer;
        m_fees.leader = fee_leader;
        m_fees.reward = fee_reward;
    }

    function SetTokenRoot(address token_root)
        public
        onlyOwner
    {
        tvm.accept();
        m_token_root = token_root;

        // See: https://github.com/broxus/ton-dex/blob/master/contracts/DexPair.sol
        ITokenRoot(token_root).walletOf{
            value: TokenGas.SEND_EXPECTED_WALLET_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            callback: Game.SetTokenWallet
        }(address(this));
    }

    function SetTokenWallet(address token_wallet)
        external
    {
        require(msg.sender == m_token_root);
        m_token_wallet = token_wallet;
    }

    function SetVault(address vault)
        public
        onlyOwner
    {
        tvm.accept();
        m_vault_address = vault;
    }

    function SetTotalReward(uint128 reward, uint128 reward_ratio)
        public
        onlyOwner
    {
        tvm.accept();
        m_total_reward = reward;
        m_reward_ratio = reward_ratio;
    }

    function GetInfo(address user_wallet)
        override
        external
        view
        returns(GameInfo)
    {
        GameInfo info;
        info.count_levels = uint16(m_levels.length);
        info.count_players = m_total_players;
        info.player = getExpectedPlayerAddress(user_wallet);
        info.fees = m_fees;
        info.reward_left = m_total_reward;
        info.token_root = m_token_root;
        //info.game_token_wallet = m_token_wallet;
        return info;
    }

    function GetLevel(address user_address, uint16 level_id, uint32 prev_level_code)
        override
        external
        view
        returns(Level)
    {
        require(level_id < m_levels.length, ErrCodes.LEVEL_OUT_OF_BOUND);
        if(level_id > 0)
            _validate_level(user_address, level_id, prev_level_code);

        Level out = m_levels[level_id];

        // calculating reward in Project tokens
        out.reward = _calculate_reward(m_levels[level_id].reward);
        return out;
    }

    function Save(
        bool deploy,
        uint16 level,
        uint32 level_code,
        bool unlock_hint,
        bool unlock_answer,
        bool claim_reward
    )
        external override
    returns (
        address
    ) {
        require(unlock_answer ? unlock_answer && msg.value > m_fees.answer : true);
        require(unlock_hint ? unlock_hint && msg.value > m_fees.hint : true);
        _validate_level(msg.sender, level, level_code);

        tvm.rawReserve(_reserve(), 0);

        address player;
        if(deploy)
            player = DeployPlayer();
        else
            player = getExpectedPlayerAddress(msg.sender);

        if (level == 0xFFFF) // Erase player
            IPlayer(player).erase{value: Gas.PLAYER_STORE, flag: MsgFlag.SENDER_PAYS_FEES}(msg.sender);
        else // Save player
        {
            uint128 gas = Gas.PLAYER_STORE;

            claim_reward = claim_reward && (m_token_wallet.value != 0); // pay reward at levels 10, 20, ...
            if(claim_reward)
                gas += m_fees.reward + Gas.TRANSFER_TO_RECIPIENT_VALUE + TokenGas.TARGET_WALLET_BALANCE;

            IPlayer(player).save{value: gas, flag: MsgFlag.SENDER_PAYS_FEES}
                    (msg.sender, level, unlock_hint, unlock_answer, claim_reward);

            uint128 fee = m_fees.save;
            if(unlock_answer || unlock_hint)
                unlock_answer ? fee = m_fees.answer : fee = m_fees.hint;

            m_vault_address.transfer({ value: fee, flag: 0, bounce: false });
        }

        msg.sender.transfer({ value: 0, flag: MsgFlag.ALL_NOT_RESERVED });
        return player;
    }

    function RequestTokens(address recipient_address, uint16 level_id)
        external override
    {
        address player = getExpectedPlayerAddress(recipient_address);
        // if someone tries to send a fake message from the Player contract created by himself,
        // the Player contract address will differ and the fake transaction will fail therefore
        require(msg.sender == player);
        tvm.rawReserve(_reserve(), 0);

        uint16 prev_level = level_id - 1;
        if(msg.value < m_fees.reward || level_id == 0 || prev_level >= m_levels.length) {
            // not enough gas attached or invalid level_id
            recipient_address.transfer({ value: 0, flag: MsgFlag.ALL_NOT_RESERVED });
            return;
        }

        if(m_levels[prev_level].reward > 0 && m_total_reward > 0 && m_token_wallet.value != 0) {
            uint128 amount = _calculate_reward(m_levels[prev_level].reward);
            m_vault_address.transfer({ value: m_fees.reward, flag: MsgFlag.SENDER_PAYS_FEES, bounce: false });

            m_total_reward -= amount;
            TvmCell empty;
            ITokenWallet(m_token_wallet).transfer{
                value: Gas.TRANSFER_TO_RECIPIENT_VALUE,
                flag: MsgFlag.SENDER_PAYS_FEES
            }(
                amount, // amount of tokens
                recipient_address, // recipient address
                TokenGas.TARGET_WALLET_BALANCE, // 0.1 EVER
                m_vault_address,  // Remaining gas receiver
                false, // Notify receiver on incoming transfer
                empty  // Notification payload
            );
        }

        recipient_address.transfer({ value: 0, flag: MsgFlag.ALL_NOT_RESERVED });
    }

    function WithdrawReward(uint128 amount, address recipient_address)
        public
        view
        onlyOwner
    {
        require(m_token_wallet.value != 0);
        tvm.accept();
        TvmCell empty;
        ITokenWallet(m_token_wallet).transfer{
            value: Gas.TRANSFER_TO_RECIPIENT_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES
        }(
            amount, // amount of tokens
            recipient_address, // recipient address
            TokenGas.TARGET_WALLET_BALANCE, // 0.1 EVER
            address(this),  // Remaining gas receiver
            false, // Notify receiver on incoming transfer
            empty  // Notification payload
        );
    }

    function _validate_level(address user_address, uint16 level_id, uint32 level_code) internal pure inline {
        uint32 hash;
        TvmBuilder builder;
        builder.store(level_id);
        builder.store(user_address);
        builder.store(address(this));
        hash = uint32(tvm.hash(builder.toCell()) & 0xFFFF);
        require(hash == level_code || level_id == 0xFFFF);
    }

    function _calculate_reward(uint128 level_reward) internal inline view returns(uint128){
        uint128 reward;
        uint128 max = uint128(m_levels.length / 10);
        uint128 sum = max*(1 + max)/2;
        if(sum == 0)
            sum = 1;
        reward = (level_reward * m_total_reward) / (m_reward_ratio * sum);
        return reward;
    }

    function _targetBalance() internal pure returns (uint128) {
        return Gas.TARGET_GAME_BALANCE;
    }

    function _reserve() internal pure returns (uint128) {
        return math.max(address(this).balance - msg.value, _targetBalance());
    }

    // Function that changes the code of current contract.
    uint32 private upgrading = 0;
	function upgrade(TvmCell newcode) public onlyOwner {
        tvm.accept();
        upgrading++;
		// Runtime function that creates an output action that would change this
		// smart contract code to that given by cell newcode.
		tvm.setcode(newcode);
		// Runtime function that replaces current code (in register C3) of the contract with newcode.
		// It needs to call new `onCodeUpgrade` function
		tvm.setCurrentCode(newcode);

        TvmCell stateVars = abi.encode(m_start_balance);
        // Call function onCodeUpgrade of the 'new' code.
		onCodeUpgrade(stateVars);
	}

    // This function will never be called. But it must be defined.
	function onCodeUpgrade(TvmCell stateVars) private pure {
	}
}
