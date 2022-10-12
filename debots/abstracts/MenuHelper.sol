pragma ton-solidity >= 0.39.0;

import "https://raw.githubusercontent.com/tonlabs/DeBot-IS-consortium/main/Menu/Menu.sol";

abstract contract CommonMenuHandler {
    uint32 private m_current_menu = 0;
    function setMenuId(uint32 id) internal { m_current_menu = id; }
    function MenuId() internal view returns(uint32) { return m_current_menu; }
    MenuItem[][] private m_menu;

    function MenuHandler(uint32 index) public virtual;
    function GetMenuStrings() internal view inline virtual returns(string[][]);

    function InitMenuItems(uint32 menu_id) internal view returns(MenuItem[] menuItems) {
        for(uint32 i = 0; i < GetMenuStrings()[menu_id].length; i++)
            menuItems.push(MenuItem(GetMenuStrings()[menu_id][i], "", tvm.functionId(MenuHandler)));
    }

    function InitMenu() internal {
        for(uint32 i = 0; i < GetMenuStrings().length; i++)
            m_menu.push(InitMenuItems(i));
    }

    function GetMenu(uint32 menu_id) internal view returns (MenuItem[]) {
        return m_menu[menu_id];
    }

    function ShowMenu(uint32 menu_id, string message) internal {
        setMenuId(menu_id);
        Menu.select(message, "", GetMenu(menu_id));
    }
}