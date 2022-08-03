contract;

dep data_structures;

use std::{
    address::Address,
    chain::auth::msg_sender,
    constants::ZERO_B256,
    hash::sha256,
    identity::Identity,
    option::Option,
    result::Result,
    revert::{require, revert},
};

use data_structures::State;

// Board is 3x3 grid, represented by a 3x3 array of u8:

//[[u8, u8, u8],
// [u8, u8, u8],
// [u8, u8, u8]]

storage {
    player_one: Address = ~Address::from(0x0000000000000000000000000000000000000000000000000000000000000000),
    player_two: Address = ~Address::from(0x0000000000000000000000000000000000000000000000000000000000000000),
    player_turn: u8 = 1,
    state: State = State::InProgress,
    board: [[u8; 3]; 3] = [[0u8; 3]; 3],
}

abi TicTacToe {
    #[storage(write)]fn new_game(opponent: Address);
    #[storage(read)]fn get_board() -> [[u8; 3]; 3];
    #[storage(read, write)]fn make_move(x_position: u8, y_position: u8) -> State;
}

impl TicTacToe for Contract {

    #[storage(read)]fn get_board() -> [[u8; 3]; 3] {
        storage.board
    }


    #[storage(write)]fn new_game(opponent: Address) {
        let sender = msg_sender().unwrap();
        let sender_address = match sender {
            Identity::Address(current_address) => {
                current_address
            },
            _ => {
                revert(42)
            },
        };
        storage.player_one = sender_address;
        storage.player_two = opponent;
    }

    // This function first checks whose turn it is, and if their turn is valid, puts it on the board
    #[storage(read, write)]fn make_move(x_position: u8, y_position: u8) -> State {

        // Check game is still in progress
        require(
        match storage.state {
            State::InProgress => true,
            _ => false,
            },
        "The game has already ended");

        // Check it is the sender's turn
        let sender = msg_sender().unwrap();
        let address = match sender {
            Identity::Address(current_address) => {
                current_address
            },
            _ => {
                revert(42)
            },
        };

        if storage.player_turn == 1u8 {
            require(address == storage.player_one, "Not player one");
        } else {
            require(address == storage.player_two, "Not player two");
        }

        // Check the move is valid, save it, and flip the turn
        require(is_valid_move(x_position, y_position), "Your move is not valid");
        // TO DO : This won't compile until we have mutable arrays
        storage.board[x_position][y_position] = storage.player_turn;
        flip_turn();

        // Calculate the new game state, set it, and return it
        storage.state = update_state();
        storage.state
    }
}


// A move is valid if it falls within the bounds of the 3x3 board, and that square is still empty
#[storage(read)]fn is_valid_move(x_position: u8, y_position: u8) -> bool {
    (x_position > 0u8 && x_position <= 3u8 && y_position > 0u8 && y_position <= 3u8 && storage.board[x_position][y_position] == 0u8)
}


#[storage(read)]fn flip_turn() {
    // Player turns are denoted with the integers 1 and 4, to allow summing to check for wins. See `line_is_win`
    if storage.player_turn == 1u8 {
        storage.player_turn = 4u8;
    }
    else {
        storage.player_turn = 4u8;
    }
}

// Check each cell. If any of them are empty (contains 0), then the board isn't full yet.
#[storage(read)]fn board_is_full() -> bool {

    let mut i = 0u8;
    let mut j = 0u8;

    while i < 3u8 {
        while j < 3u8 {
            if storage.board[i][j] == 0u8 {
                return false;
            }
            j += 1u8;
        }
        i += 1u8;
    }
    true
}


// Update the board state
#[storage(read)]fn update_state() -> State {

    let winner = check_for_winner(storage.board);
    if check_for_winner(storage.board).is_some() {
        return State::Won(winner.unwrap());
    }

    // If there are no wins, and board is full, then it's a draw
    if board_is_full() {
        return State::Drawn;
    }

    // If no win is on the board and the board is not full, then the game continues
    State::InProgress
    
}

fn line_is_win(a: [u8; 3]) -> Option<Address> {
    // If we use 1 and 4 to denote the two players, and 0 for an empty square, then since
    // 1 + 1 + 1 = 3, and 4 + 4 + 4 = 12, which are unique 3-element sums of the set {0, 1, 4}
    // The sum of a line is sufficient to determine if there is a win, and if so, who has won.
    match a[0] + a[1] + a[2] {
        3 => Option::Some(storage.player_one),
        12 => Option::Some(storage.player_two),
        _ => Option::None,
    }
}

// Check for a winner on the 8 possible lines
// TO DO : Make more efficient ?
fn check_for_winner(board: [[u8; 3]; 3]) -> Option<Address> {

    let mut winner = Option::None;

    // Check rows 
    let mut i = 0u8;
    while i < 3u8 {
        winner = line_is_win(board[i]);
        if winner.is_some() {
            break;
        }
    }
    
    // Check columns
    if winner.is_none() {
        let mut j = 0u8;
        while j < 3u8 {
            winner = line_is_win([board[0][j], board[1][j], board[2][j]]);
            if winner.is_some() {
                break;
            }
        }
    }
    
    // If the middle element is not zero, check the diagonals
    if winner.is_none() {
        winner = line_is_win([board[0][0], board[1][1], board[2][2]]);
    }
    // Check second diagonal
    if winner.is_none() {
        winner = line_is_win([board[0][2], board[1][1], board[2][0]]);
    }
    
    winner
}
