

% Play against stockfish via command interface!




% Requires ChessMaster MATLAB Addon:

% 1. Install ChessMaster MATLAB Addon
% 2. Download Stockfish and add it to ChessMaster:
%       https://stockfishchess.org/download/
% 3. Place Stockfish folder in 
%       ...AppData\Roaming\MathWorks\MATLAB Add-Ons\Collections\Chess Master\Chess Master v1.6\engines\stockfish
%                                        
% 4. In MATLAB command window, type ChessMaster to open the GUI
% 5. Click Engine -> Add Engine...
%       Name: Stockfish
%       Exe: ./engines\stockfish\stockfish-windows-x86-64-avx2.exe

% Play against yourself: Engine -> New Engine
% Change engine to stockfish, Auto-Black, Start Auto-Play

% ChessMaster code from:
% Brian Moore (2024). Chess Master (https://www.mathworks.com/matlabcentral/fileexchange/47272-chess-master), MATLAB Central File Exchange. Retrieved February 23, 2024.

% INPUT COMMANDS IN ****Long Algebraic Notation**** format, eg. c2c3

% Can extract game state information via commands:
%   FENstr  = CM.GetFENstr();          % Get current FEN string
%   LANstrs = CM.GetLANstrs();         % Get all LAN move strings
%   SANstrs = CM.GetSANstrs();         % Get all SAN move strings



% Requires modified ChessEngine.m and ChessMaster.m

% ChessMaster.m - Move 'Engines' property into 
% "get = public, set = private" parameters section

% ChessEngine.m - Move 'MakeMove' function into public methods section
% Add this function into the public methods of ChessEngine.m 
        % %
        % % Handle search Time value change
        % %
        % function ChangeSearchTime(this,val)
        %     if isnan(val)
        %         % Revert to last used value
        %         val = this.searchVals(idx);
        %     end
        % 
        %     % Save new value
        %     this.searchVals(3) = val;
        % 
        %     % Update GUI search values
        %     this.UpdateSearchVals(3);
        % end
%



% Reset environment
close all
clear all
clc


% Parameters:
    % Thinking time for Stockfish
    time = 0.1;
    % Do you want to play as white or black? (0 or 1)
    turn = 0;

% Construct game and engine objects
CM = ChessMaster();
CE = ChessEngine(CM,CM.engines,'ChessEngine',[300 300]);

% Update engine search time
CE.ChangeSearchTime(time)




gameState = 0;
robot2play = 1;


% Play the game
while gameState == 0
    if turn == 0
    % Your turn
        % Enter command and check if legal
        isLegal = 0;
        while isLegal == 0;
            userMove = input("What is your move?\n","s");
            if strcmp(MakeMove(CM,userMove),'') == 0
                isLegal = 1;
            else
                disp("Illegal Move")
            end
        end

        % Send command to robot

        % Send command to Engine
        CM.MakeMove(userMove);
        turn = 1;

    else
    % Engine's turn
        if robot2play==1
            % Make move
            CE.MakeMove();
            pause(time + 0.1);
            % Get move
            temp = CM.GetLANstrs();
            last = string(temp(end));
            % Print last move
            disp('The robot moved:')
            disp(last);
            % Send command to robot

        
        end
        turn = 0;
    end

    % Check for end of game
    if CM.isGameOver == true
        gameState = 1;
    end
end

disp("Game finished!")