extern "C" {
    fn x() -> i32;
}

fn main() {
    println!("Hello, world!: {:?}", unsafe { x() });
}
