function captureEnd = findCaptureSpot(boardState, capturePiece)
    if double(capturePiece) < 97 % capture piece is white
        captureCol = 5; % white's capture area is on the right
    else
        captureCol = 1;
    end

    captureRow = 9; % start searching for capture spot off the board in boardState

    while true
        if boardState(captureRow, captureCol) == 'e'
            captureEnd = [captureRow, captureCol]; % first empty square in captureArea
            break
        else
            if captureRow == 12
                if captureCol == 4 || captureCol == 8
                    error("No places left in the capture area!")
                else 
                    captureRow = 9;
                    captureCol = captureCol + 1;
                end
            else
                captureRow = captureRow + 1;
            end
        end
    end
end
