library data_structures;

use std::address::Address;

pub enum State {
    InProgress: (),
    Drawn: (),
    Won: Address,
}
