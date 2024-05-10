function out = FEN2Board(FENstr)
    % converts FEN string notation into an 8x8 array with chess piece names
    % on it. 'e' = empty

    out = [];
    row = 8;
    col = 1;
  
    i = 1;
    while FENstr(i) ~= ' '
        temp = FENstr(i);
        if temp == '/'
            row = row - 1;
            col = 1;
        else 
            if isstrprop(temp,'digit')
                spaces = str2num(temp);
                for j = 1:spaces
                    out(row,col) = 'e';
                    col = col+1;
                end
            else
                out(row,col) = temp;
                col = col+1;
            end
        end
        i = i + 1;
    end

    out = char(out);
end