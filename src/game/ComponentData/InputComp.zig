// Holds state about how an entity should be acting on inputs
pub const KeyboardInputTable = enum {
    SPACE_DOWN,
};

pub const InputState = struct {
    inputsDown: [@memberCount(KeyboardInputTable)]bool = [_]bool{false ** @memberCount(KeyboardInputTable)},
    inputsPressed: [@memberCount(KeyboardInputTable)]bool = [_]bool{false ** @memberCount(KeyboardInputTable)},
};

pub const InputComp = struct {
    inputState: InputState = InputState{},
    //TODO
};
