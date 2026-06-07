pub const ASSISTANT_OPEN: &str = "<|im_start|>assistant\n";

pub fn system_turn(message: &str) -> String {
    format!("<|im_start|>system\n{message}<|im_end|>\n")
}

pub fn user_turn(message: &str) -> String {
    format!("<|im_start|>user\n{message}<|im_end|>\n")
}

pub fn tool_turn(content: &str) -> String {
    format!("<|im_start|>tool\n{content}<|im_end|>\n")
}
