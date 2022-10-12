pragma ton-solidity >=0.63.0;

abstract contract State {
    uint32 private m_action = 0;
    uint32 private m_step = 0;

    function action() internal view returns(uint32) {
        return m_action;
    }

    function step() internal view returns(uint32) {
        return m_step;
    }

    function next_step() internal returns(uint32) {
        m_step ++;
        return m_step;
    }

    function set_action(uint32 action_id) internal {
        m_action = action_id;
        m_step = 0;
    }

    function run() internal virtual;
    function OnAction(uint32 action_id) internal virtual;
    function next() internal inline { next_step(); run(); }
    function run_action(uint32 action_id) internal inline { set_action(action_id); run(); }
    function finish() internal inline { OnAction(m_action); }
}
