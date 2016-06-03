#![feature(lang_items)]
#![no_std]

extern crate rlibc;
mod io;

#[no_mangle]
pub extern fn rust_main() {
    // ATTENTION: we have a very small stack and no guard page
    io::vga::print(0x0F, b"Hello World!", 0);
    io::vga::print(0x0F, b"Goodbye World!", 13);

    loop{}
}

#[lang = "eh_personality"] extern fn eh_personality() {}
#[lang = "panic_fmt"] extern fn panic_fmt() -> ! {loop{}}
