use core::ptr::Unique;
use spin::Mutex;

macro_rules! print {
    ($($arg:tt)*) => ({
        use core::fmt::Write;
        let mut writer = $crate::io::vga::WRITER.lock();
        writer.write_fmt(format_args!($($arg)*)).unwrap();
    })
}

macro_rules! println {
    ($fmt:expr) => (print!(concat!($fmt, "\n")));
    ($fmt:expr, $($arg:tt)*) => (print!(concat!($fmt, "\n"), $($arg)*));
}

pub static WRITER: Mutex<Writer> = Mutex::new(Writer {
    column_position: 0,
    color_code: ColorCode::new(Color::LightGreen, Color::Black),
    buffer: unsafe { Unique::new(0xb8000 as *mut _) }
});

#[allow(dead_code)]
#[repr(u8)]
pub enum Color {
    Black      = 0,
    Blue       = 1,
    Green      = 2,
    Cyan       = 3,
    Red        = 4,
    Magenta    = 5,
    Brown      = 6,
    LightGray  = 7,
    DarkGray   = 8,
    LightBlue  = 9,
    LightGreen = 10,
    LightCyan  = 11,
    LightRed   = 12,
    Pink       = 13,
    Yellow     = 14,
    White      = 15,
}

#[derive(Clone, Copy)]
struct ColorCode(u8);

impl ColorCode {
    const fn new(foreground: Color, background: Color) -> ColorCode {
        ColorCode((background as u8) << 4 | (foreground as u8))
    }
}

// Repr(C) guarantees the field ordering in memory.
#[repr(C)]
#[derive(Clone, Copy)]
struct ScreenChar {
    ascii_character: u8,
    color_code: ColorCode,
}

// Terminal is 80 columns X 25 rows
const BUFFER_HEIGHT: usize = 25;
const BUFFER_WIDTH: usize = 80;

// Screen Buffer
struct Buffer {
    chars: [[ScreenChar; BUFFER_WIDTH]; BUFFER_HEIGHT],
}

pub struct Writer {
    column_position: usize,
    color_code: ColorCode,
    buffer: Unique<Buffer>,
}

impl Writer {
    pub fn write_byte(&mut self, byte: u8) {
        match byte {
            b'\n' => self.new_line(),
            byte => {
                if self.column_position >= BUFFER_WIDTH {
                    self.new_line();
                }

                let row = BUFFER_HEIGHT - 1;
                let col = self.column_position;

                self.buffer().chars[row][col] = ScreenChar {
                    ascii_character: byte,
                    color_code: self.color_code,
                };
                self.column_position += 1;
            }
        }
    }

    fn buffer(&mut self) -> &mut Buffer {
        unsafe { self.buffer.get_mut() }
    }

    fn new_line(&mut self) {
        for row in 0..(BUFFER_HEIGHT - 1) {
            let buffer = self.buffer();
            buffer.chars[row] = buffer.chars[row + 1]
        }
        self.clear_row(BUFFER_HEIGHT - 1);
        self.column_position = 0;
    }

    fn clear_row(&mut self, row: usize) {
        let blank = ScreenChar {
            ascii_character: b' ',
            color_code: self.color_code,
        };
        self.buffer().chars[row] = [ blank; BUFFER_WIDTH ]
    }
}

impl ::core::fmt::Write for Writer {
    fn write_str(&mut self, s: &str) -> ::core::fmt::Result {
        for byte in s.bytes() {
            self.write_byte(byte)
        }
        Ok(())
    }
}

pub fn clear_screen() {
    for _ in 0..BUFFER_HEIGHT {
        println!("");
    }
}

pub fn raw_print(color_code: u8, string: &[u8], position: i64) {
    let mut output_colored = [color_code; 24];
    for (i, char_byte) in string.into_iter().enumerate() {
        output_colored[i*2] = *char_byte;
    }

    let buffer_ptr = (0xb8000 + position) as *mut _;
    unsafe { *buffer_ptr = output_colored }
}

