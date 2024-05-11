function [moveSequence, boardState] = genMoveSequence(move, boardState)
    % This function generates the via points for trajectory generation
    

    % Figure out piece typoe, starting position and ending position from boardstates
    startPos = [double(move(2)) - 48, double(move(1)) - 96];
    endPos = [double(move(4)) - 48, double(move(3)) - 96];

    movingPiece = boardState(startPos(1), startPos(2));

    destinationOccupant = boardState(endPos(1), endPos(2));

    %%%% Generate Via Points %%%%
    moveSequence = [];

    % Start at home pose

    % If there was a capture, move that to the capture zone first
    % Check for En passant (If a pawn moved diagonal into empty square)
    if destinationOccupant ~= 'e' || (destinationOccupant == 'e' && (movingPiece == 'p' || movingPiece == 'P') && abs(startPos(2) - endPos(2)) == 1)
        % move occupant to relevant capture area

        if destinationOccupant == 'e'
            if double(movingPiece) < 97 % moving pawn is white
                captureStart = [endPos(1)-1, endPos(2)];
            else
                captureStart = [endPos(1)+1, endPos(2)];
            end
        else
            captureStart = endPos;
        end
        capturePiece = boardState(captureStart(1), captureStart(2));

        captureEnd = findCaptureSpot(boardState, capturePiece);

        % update captureArea
        boardState(captureEnd(1), captureEnd(2)) = capturePiece;

        captureSequence = genViaPoints(captureStart, captureEnd, capturePiece);
        moveSequence = [moveSequence captureSequence];
    end


    % Move piece
    moveSequence = [moveSequence genViaPoints(startPos, endPos, movingPiece)];


    % if it was a castling move, move the castle
    if (movingPiece == 'k' || movingPiece == 'K') && abs(startPos(2) - endPos(2)) == 2
        if movingPiece == 'K' % white castle
            if startPos(2) - endPos(2) == 2
                castleStart = [1 1];
                castleEnd = [1 4];
            else
                castleStart = [1 8];
                castleEnd = [1 6];
            end
        else % black castle
            if startPos(2) - endPos(2) == 2
                castleStart = [8 1];
                castleEnd = [8 4];
            else
                castleStart = [8 8];
                castleEnd = [8 6];
            end
        end
        castleSequence = genViaPoints(castleStart, castleEnd, 'r');
        moveSequence = [moveSequence castleSequence];

    end
    

    % If there was a promotion, move that back on to the board
    % if last char in move string isn't an integer
    %disp(move(end))
    %disp(double(move(end)))
    if double(move(end))  > 64 % we have a promotion
        
        captureEnd = findCaptureSpot(boardState,movingPiece);

        % update captureArea
        boardState(captureEnd(1), captureEnd(2)) = movingPiece;
        
        promotionSequence1 = genViaPoints(startPos, captureEnd, movingPiece);

        promotionStart = findPromotionPiece(boardState, move(end));



        % update captureArea
        boardState(promotionStart(1), promotionStart(2)) = 'e';

        promotionSequence2 = genViaPoints(promotionStart, endPos, move(end));

        moveSequence = [moveSequence promotionSequence1 promotionSequence2];

    end
end