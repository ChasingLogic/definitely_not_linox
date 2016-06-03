#![feature(lang_items, const_fn, unique)]
#![no_std]

extern crate rlibc;
extern crate spin;

mod io;

use core::fmt::Write;
use io::vga::WRITER;

#[no_mangle]
pub extern fn rust_main() {
    // ATTENTION: we have a very small stack and no guard page
    WRITER.lock().write_str("Hello this is a line of text!\n");
    WRITER.lock().write_str("New line!");
    loop{}
}

#[lang = "eh_personality"] extern fn eh_personality() {}
#[lang = "panic_fmt"] extern fn panic_fmt() -> ! {loop{}}
