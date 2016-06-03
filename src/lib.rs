#![feature(lang_items, const_fn, unique)]
#![no_std]
extern crate rlibc;
extern crate spin;

#[macro_use]
mod io;

use core::fmt::Write;
use io::vga::WRITER;

#[no_mangle]
pub extern fn rust_main() {
    // ATTENTION: we have a very small stack and no guard page
    println!("Hello this is a line of text!");
    println!("New line!");
    loop{}
}

#[lang = "eh_personality"] extern fn eh_personality() {}
#[lang = "panic_fmt"] extern fn panic_fmt() -> ! {loop{}}
