function promotionLoc = findPromotionPiece(boardState, promotionPiece)
    

    captureRow = 9;
    captureCol = 1;

    while true
        if boardState(captureRow, captureCol) == promotionPiece
            promotionLoc = [captureRow, captureCol]; % first promotion piece in captureArea
            break
        else
            if captureRow == 12
                if captureCol == 8
                    error("No promotion piece found in the capture area!")
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