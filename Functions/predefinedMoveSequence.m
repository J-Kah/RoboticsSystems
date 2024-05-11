function moves = predefinedMoveSequence()
    % Provides the list of moves given by the demonstration requirements
    % in long algebraid notation (LAN)
    %
    % The first row are white"s moves, second row are black"s.

    moves = ["e2e4", "e7e5";
        "g1f3", "b8c6";
        "f1b5", "g8f6";
        "b1c3", "f8c5";
        "e1g1", "d7d5";
        "e4d5", "f6d5";
        "c3d5", "d8d5";
        "b5c6", "b7c6";
        "c2c3", "e8g8";
        "f3g5", "e5e4";
        "d2d4", "e4d3"; % En passant
        "d1f3", "d3d2";
        "f3d5", "d2c1q"; % Queen promotion
        "a1c1", "c6d5";
        "g1h1", "c8b7";
        "f2f4", "f8e8";
        "g5h3", "a8d8";
        "g2g3", "c5e3";
        "c1d1", "f7f6";
        "f1e1", "d5d4"]; % Checkmate
end