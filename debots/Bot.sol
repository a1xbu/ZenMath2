pragma ton-solidity >=0.63.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "https://raw.githubusercontent.com/tonlabs/debots/main/Debot.sol";
import "https://raw.githubusercontent.com/tonlabs/DeBot-IS-consortium/main/Media/Media.sol";

import "../abstracts/Transferable.sol";
import "abstracts/GameWrapper.sol";

import "menu/Menu.sol";


contract GameBot is Debot, GameWrapper, MenuStrings, Transferable {
    bytes internal m_icon;
    uint32 private nonce = 331;

    constructor() public {
        tvm.accept();
        m_public_key = msg.pubkey();
    }

    function start() public override {
        m_images = new bytes[](ImageClass.NUM_CLASSES);
        InitMenu();
        run_action(Action.INIT);
    }

    function SetGameContract(address game_address) public onlyOwner {
        tvm.accept();
        m_game = game_address;
    }

    function SetIcon(bytes icon) public onlyOwner {
        tvm.accept();
        m_icon = icon;
    }

    function MenuHandler(uint32 index) public override {
        if(MenuId() == MenuID.MAIN) MainMenuHandler(index);
        else if(MenuId() == MenuID.GAME) GameMenuHandler(index);
        else if(MenuId() == MenuID.SAVE) SaveMenuHandler(index);
        else if(MenuId() == MenuID.CONTINUE) ContinueMenuHandler(index);
        else if(MenuId() == MenuID.SETTINGS) SettingsMenuHandler(index);
        else if(MenuId() == MenuID.SAVE_FORCE) SaveForceMenuHandler(index);
        else if(MenuId() == MenuID.SAVE_ON_EXIT) SaveForceMenuHandler(index);
    }

    function StartGame() internal {
        run_action(Action.UPDATE_PLAYER);
    }

    function OnAction(uint32 action) internal override {
        //DbgPrint(format("OnAction: {}", action));
        if(action == Action.INIT) {
            ShowImage(ImageClass.LOGO_IMAGE);
            StartGame();
        }
        else if(action == Action.UPDATE_PLAYER) {
            ShowMenu(MenuID.MAIN, FormatPlayerInfo());
        }
        else if(action == Action.UPDATE_LEVEL) {
            ShowTask();
        }
        else if(action == Action.SAVE_PLAYER) {
            Terminal.print(0, "Not saved");
            if(DeleteUserRequested() || MenuId() == MenuID.SAVE_ON_EXIT) {
                ResetSaveRequest();
                StartGame();
            }
            else
                Play();
        }
        else if(action == Action.SAVE_PLAYER_SUCCESS) {
            if(DeleteUserRequested())
            {
                if((m_player_info.level == 0 || m_level_locks.hint_unlocked || m_level_locks.answer_unlocked))
                    Terminal.print(0, "User data have been successfully deleted");
                else
                    Terminal.print(0, "User data have not been deleted");
                ResetSaveRequest();
                StartGame();
            }
            else if(MenuId() == MenuID.SAVE_ON_EXIT) {
                ResetSaveRequest();
                StartGame();
            }
            else {
                if(m_game_info.token_root.value != 0)
                    run_action(Action.UPDATE_TOKENS); // -> MenuID.CONTINUE -> Play()
                else
                    Play();
            }
        }
        else if(action == Action.UPDATE_TOKENS) {
            if(m_token_balance > m_prev_token_balance) {
                ShowImage(ImageClass.REWARD_IMAGE);
                string text = format("{}\n{} {}",
                    "Your reward:",
                    toFractional(m_token_balance - m_prev_token_balance, 9),
                    "⭐");
                ShowMenu(MenuID.CONTINUE, text); // -> Play()
            }
            else
                Play();
        }
    }

    function Play() private {
        if((m_level_id + 1) % 10 == 0 && m_player_info.level < m_level_id) {
            ShowMenu(MenuID.SAVE_FORCE, "Please save your progress to continue.");
        }
        else if (m_level_id >= m_game_info.count_levels) {
            EndGame();
        }
        else {
            run_action(Action.UPDATE_LEVEL);
        }
    }

    function EndGame() internal {
        Terminal.print(0, "No more levels left.");
        if(m_max_level == m_player_info.level) {
            Terminal.print(0, "You can chose any unlocked level and play it again.");
            StartGame();
        }
        else
            ShowMenu(MenuID.SAVE_ON_EXIT, "You have finished the game!");
    }

    function ShowTask() internal {
        if(HintUnlockRequested() && m_level_locks.hint_unlocked) {
            ShowHint();
            ResetSaveRequest();
            ShowMenu(MenuID.CONTINUE, "");
        }
        else if(AnswerUnlockRequested() && m_level_locks.answer_unlocked) {
            ShowAnswer();
            ResetSaveRequest();
            ShowMenu(MenuID.CONTINUE, "");
        }
        else {
            if((AnswerUnlockRequested() && !m_level_locks.answer_unlocked) ||
                (HintUnlockRequested() && !m_level_locks.hint_unlocked)) {
                Terminal.print(0, "Sorry, the hint has not been unlocked yet. Please wait or try again.");
                ResetSaveRequest();
            }

            Terminal.print(0, format("{} {}\n{}",
                "Level ",
                m_level_id + 1,
                "❓ Task:")); // "Уровень X ❓ Задача:"
            if (m_level_data.task.text.byteLength() != 0)
                Terminal.print(0, m_level_data.task.text);
            if (m_level_data.task.image.length != 0)
                Media.output(0, "", m_level_data.task.image);

            ShowMenu(MenuID.GAME, "");
        }
    }

    function ShowHint() internal view {
        if (m_level_data.hint.text.byteLength() != 0)
            Terminal.print(0, m_level_data.hint.text);
        if (m_level_data.hint.image.length != 0)
            Media.output(0, "", m_level_data.hint.image);
    }

    function ShowAnswer() internal view {
        if (m_level_data.answer.text.byteLength() != 0)
            Terminal.print(0, m_level_data.answer.text);
        if (m_level_data.answer.image.length != 0)
            Media.output(0, "", m_level_data.answer.image);
    }

    function FormatPlayerInfo() private view returns(string){
        //uint32 points = m_player_info.points + (m_max_level - m_player_info.level) * 10;
        string saved = "";
        string reward = "";
        if(m_max_level != m_player_info.level)
            saved = " (unsaved)";

        if(m_token_balance > 0)
            reward = format("{} {} {}",
                "\nYour reward:",
                toFractional(m_token_balance, 9),
                "⭐"
            );

        return format("{} {}{}\n{} {}\n{} {}\n{}",
            "Unlocked levels:",
            m_max_level >= m_game_info.count_levels ? m_game_info.count_levels : m_max_level + 1,
            saved,
            "Current level:",
            m_level_id >= m_game_info.count_levels ? m_game_info.count_levels : m_level_id + 1,
            "Total levels:",
            m_game_info.count_levels,
            reward);
    }

    function MainMenuHandler(uint32 index) private {
        if(index == MenuItems.MENU_PLAY) {
            Play();
        }
        else if(index == MenuItems.MENU_LEVEL) {
            ChooseLevel();
        }
        else if(index == MenuItems.MENU_UNLOCK_LEVEL) {
            //AmountInput.get(tvm.functionId(UnlockLevel), "Enter level code:", 0, 1, 65535);
            Input(GameConstants.INPUT_READ_LEVEL_CODE, "Enter level code:");
        }
        else if(index == MenuItems.MENU_SETTINGS) {
            ShowMenu(MenuID.SETTINGS, "");
        }
    }

    function GameMenuHandler(uint32 index) private {
        if(index == MenuItems.MENU_ANSWER) {
            Input(GameConstants.INPUT_READ_ANSWER, "Your answer (integer):");
        }
        else if(index == MenuItems.MENU_REQUEST_HINT) {
            UnlockHint();
        }
        else if(index == MenuItems.MENU_REQUEST_ANSWER) {
            UnlockAnswer();
        }
        else if(index == MenuItems.MENU_BACK) {
            if(m_max_level != m_player_info.level) {
                ShowMenu(MenuID.SAVE_ON_EXIT, "You have unsaved progress. Would you like to save?");
            }
            else {
                StartGame();
            }
        }
    }

    function SaveMenuHandler(uint32 index) private {
        if(index == MenuItems.MENU_SAVE) {
            GameSave();
        }
        else if(index == MenuItems.MENU_CONTINUE) {
            Play();
        }
    }

    function ContinueMenuHandler(uint32) private {
        Play();
    }

    function SettingsMenuHandler(uint32 index) private {
        if(index == MenuItems.MENU_DELETE_USER) {
            DeleteUser();
        }
        if(index == MenuItems.MENU_SETTINGS_BACK) {
            StartGame();
        }
    }

    function SaveForceMenuHandler(uint32 index) private {
        if(index == MenuItems.MENU_SAVE) {
            GameSave();
        }
        else if(index == MenuItems.MENU_CONTINUE) {
            StartGame();
        }
    }

    uint8 private input_reason;
    function Input(uint8 reason, string text) internal {
        input_reason = reason;
        Terminal.input(tvm.functionId(InputHandler), text, false);
    }

    function InputHandler(string value) public {
        optional(int256) int_val;
        int_val = stoi(value);

        if(input_reason == GameConstants.INPUT_READ_LEVEL) {
            if(int_val.hasValue() && int_val.get() >= 0 && int_val.get() < m_game_info.count_levels) {
                uint16 level_id = uint16(int_val.get());
                ReadLevel(level_id);
            }
        }
        else if(input_reason == GameConstants.INPUT_READ_ANSWER){
            ReadAnswer(value);
        }
        else if(input_reason == GameConstants.INPUT_READ_LEVEL_CODE) {
            if(int_val.hasValue() && int_val.get() >= 0) {
                uint32 level_code = uint32(int_val.get());
                UnlockLevel(level_code);
            }
        }
    }

    function ReadAnswer(string value) private {
        uint256 answer_hash;
        string salted_value = value + m_level_data.salt;

        answer_hash = tvm.hash(salted_value);
        if (m_level_data.answer_hash == answer_hash) {
            NotifyCorrect();
        }
        else {
            Terminal.print(0, "❌ Wrong. Try again.");
            Play();
        }
    }

    function ChooseLevel() internal {
        string message = format("{} (1-{}):", "Choose level", m_max_level + 1);
        Input(GameConstants.INPUT_READ_LEVEL, message);
    }

    function ReadLevel(uint16 value) private {
        if(value > 0 && value <= m_max_level)
            m_level_id = value - 1;
        else
            m_level_id = m_max_level;
        Play();
    }

    function UnlockLevel(uint32 value) private {
        uint16 level;

        // check only up to 10 levels close to the saved level id
        // because every 10 levels the user is required to save
        uint16 level_start = m_player_info.level - m_player_info.level % 10;
        uint16 level_end = level_start + 10;
        if (level_end > m_game_info.count_levels)
            level_end = uint16(m_game_info.count_levels);

        if(value != 0) {
            for(level = level_start; level < level_end; level ++) {
                if (CalculateLevelCode(level) == uint32(value & 0xFFFF)) {
                    m_level_id = level;
                    if (level > m_max_level)
                        m_max_level = level;
                    ChooseLevel();
                    return;
                }
            }
        }

        Terminal.print(0, "Invalid code");
        ShowMenu(MenuID.MAIN, FormatPlayerInfo());
    }

    function NotifyCorrect() private {
        m_level_id += 1;
        if(m_level_id > m_max_level)
            m_max_level = m_level_id;

        uint32 level_code = CalculateLevelCode(uint16(m_level_id));
        string notification = "";

        if(m_level_id < m_game_info.count_levels) {
            notification = format(
                "{}: {}\n{}: {}",
                    "Level",
                    m_level_id + 1,
                    "Level code",
                    level_code
                );
        }

        ShowImage(ImageClass.LEVEL_IMAGE);

        if(m_max_level > m_player_info.level) {
            ShowMenu(MenuID.SAVE, notification);
        }
        else {
            ShowMenu(MenuID.CONTINUE, notification);
        }
    }

    function getDebotInfo() public functionID(0xDEB) override view returns(
        string name, string version, string publisher, string caption, string author,
        address support, string hello, string language, string dabi, bytes icon
    ) {
        name = "ZenMath²";
        version = "0.2.1";
        publisher = "";
        caption = "ZenMath² quiz";
        author = "";
        hello = "";
        support = address(0);
        language = "en";
        dabi = m_debotAbi.get();
        icon = m_icon;
    }

    function getRequiredInterfaces() public view override returns (uint256[] interfaces) {
        return [ Terminal.ID, UserInfo.ID, Media.ID, Menu.ID, Sdk.ID, ConfirmInput.ID ];
    }

    function toFractional(uint128 balance, uint8 decimals) internal pure returns (string) {
        uint8 digits = 0;
        uint8 start_digit = 0;
        if(decimals > 3) start_digit = decimals - 3;

        uint256 pow = uint256(10) ** decimals;
        uint left_part = balance / pow;
        uint right_part = pow + balance % pow;
        for(digits=start_digit; digits < decimals; digits++) {
            if((right_part / (uint256(10) ** digits)) % 10 != 0)
                break;
        }
        if(digits == decimals)
            return format("{}", left_part);

        bytes low_part = format("{}", right_part).substr(1, decimals-digits);
        return format("{}.{}", left_part, low_part);
    }

    function ShowImage(uint8 image_class) private view {
        if(image_class < ImageClass.NUM_CLASSES && m_images[image_class].length != 0)
            Media.output(0, "", m_images[image_class]);
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

        TvmCell stateVars = abi.encode(m_game);
        // Call function onCodeUpgrade of the 'new' code.
		onCodeUpgrade(stateVars);
	}

    // This function will never be called. But it must be defined.
	function onCodeUpgrade(TvmCell stateVars) private pure {
	}
}
