pragma ton-solidity >=0.63.0;
import "../abstracts/MenuHelper.sol";


library MenuItems {
    uint32 constant MENU_PLAY = 0; // "🎮 Play"
    uint32 constant MENU_LEVEL = 1; // "⏭ Jump to level"
    uint32 constant MENU_UNLOCK_LEVEL = 2; // "🔐 Unlock levels"
    uint32 constant MENU_SETTINGS = 3; // "⚙️Settings"

    uint32 constant MENU_ANSWER = 0; // "Answer"
    uint32 constant MENU_REQUEST_HINT = 1; // "💡 Need a hint"
    uint32 constant MENU_REQUEST_ANSWER = 2; // "✅ Show answer"
    uint32 constant MENU_BACK = 3; // "↩️ Menu"

    uint32 constant MENU_SAVE = 0; // "📥 Save"
    uint32 constant MENU_CONTINUE = 1; // "Continue"

    uint32 constant MENU_DELETE_USER = 0; // "Delete user"
    uint32 constant MENU_SETTINGS_BACK = 1; // "↩️ Menu"
}

library MenuID {
    uint32 constant MAIN = 0;
    uint32 constant GAME = 1;
    uint32 constant SAVE = 2;
    uint32 constant CONTINUE = 3;
    uint32 constant SETTINGS = 4;
    uint32 constant SAVE_FORCE = 5;
    uint32 constant SAVE_ON_EXIT = 6;
}

abstract contract MenuStrings is CommonMenuHandler{
    string[][] constant menu = [
        [ // MenuID.MAIN
            "🎮 Play",
            "⏭ Jump to level",
            "🔐 Unlock levels",
            "👤️ User"
        ], [ // MenuID.GAME
            "Answer",
            "💡 Need a hint",
            "✅ Show answer",
            "↩️ Menu"
        ], [ // MenuID.SAVE
            "📥 Save",
            "Continue"
        ], [ // MenuID.CONTINUE
            "Continue"
        ], [ // MenuID.SETTINGS
            "Delete progress",
            "↩️Main menu"
        ], [ // MenuID.SAVE_FORCE
            "📥 Save",
            "↩️Main menu"
        ], [ // MenuID.SAVE_ON_EXIT
            "📥 Save",
            "↩️Main menu"
        ]
    ];

    function GetMenuStrings() internal view inline override returns(string[][]) {return menu;}
}