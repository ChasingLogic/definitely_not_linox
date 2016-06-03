pub fn print(color_code: u8, string: &[u8], position: i64) {
    let mut output_colored = [color_code; 24];
    for (i, char_byte) in string.into_iter().enumerate() {
        output_colored[i*2] = *char_byte;
    }

    let buffer_ptr = (0xb8000 + position) as *mut _;
    unsafe { *buffer_ptr = output_colored }
}
