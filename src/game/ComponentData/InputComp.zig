// Holds state about how an entity should be acting on inputs
pub const KeyboardInputTableLen: comptime u8 = @typeInfo(KeyboardInputTable).Enum.fields.len;
pub const KeyboardInputTable = enum {
    SPACE_DOWN,
};

pub const InputState = struct {
    inputsDown: [KeyboardInputTableLen]bool = [_]bool{false ** KeyboardInputTableLen},
    inputsPressed: [KeyboardInputTableLen]bool = [_]bool{false ** KeyboardInputTableLen},
};

pub const InputComp = struct {
    inputState: InputState = InputState{},
    //TODO
};
