function moveSequence = genMoveSequence(CM,move, prevFen)
    % Generates the via points for trajectory generation

    % Get current and prev engine board FEN (before and after most recent move)
    currentFEN = CM.GetFENstr();

    prevBoard = FEN2Board(prevFen)
    currentBoard = FEN2Board(currentFEN)

    % Figure out piece typoe, starting position and ending position from
    % boardstates
    disp(class(move(1)))
    disp(move(1))
    disp(double(move(1)))
    startpos = [double(move(2)) - 48, double(move(1)) - 96]
    endpos = [double(move(4)) - 48, double(move(3)) - 96]

    movingPiece = prevBoard(startpos(1), startpos(2));

    destinationOccupant = prevBoard(endpos(1), endpos(2));

    %%%% Generate Via Points %%%%

    % Start at home pose

    % If there was a capture, move that to the capture zone first
    if destinationOccupant != 'e'
       % move occupant to relevant capture area

    end

    % Move piece
    % Go to location above piece
    % Go to height of piece
    % grip piece
    % got to location above piece
    % got to location above destination
    % go down to height of piece
    % release grip
    % go to loaction above destination




    % if it was a castling move, move the other piece
    % if piece = 'k' or 'K' and destination is more than 1 square away
    % move relevant castle next to the king

    % If there was a promotion, move that back on to the board
    % if last char in move string isn't an integer
    % move pawn off the board to capture area
    % switch case for q, b, n, c
    % find q, b, n, or c in relevant capture zone
    % move that piece on to the board

    % End at home pose

    moveSequence = CM;
end