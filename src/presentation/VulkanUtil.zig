const c = @import("../c.zig");

const VkError = error{
    FailedToFindMemoryType,
    FailedToRecordCommandBuffers,
    UnspecifiedError, // prefer creating new more specific errors
};

pub fn CheckVkSuccess(result: c.VkResult, errorToReturn: anyerror) !void {
    if (result != c.VK_SUCCESS) {
        return errorToReturn;
    }
}
