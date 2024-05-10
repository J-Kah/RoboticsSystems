classdef ChessMaster < handle
%--------------------------------------------------------------------------
% Syntax:       ChessMaster();
%               ChessMaster(figSize);
%               ChessMaster('last');
%               CM = ChessMaster();
%               CM = ChessMaster(figSize);
%               CM = ChessMaster('last');
%               
% Inputs:       [OPTIONAL] figSize in [0 1] is the desired size of the GUI
%               relative to the smallest screen dimension. The default
%               value is figSize = 0.75
%               
%               [OPTIONAL] 'last' loads the ChessMaster figures as they
%               were (i.e., same size/position) when the GUI last closed
%               
% Outputs:      CM is a ChessMaster object with public methods:
%               
%             SANstr  = CM.MakeMove(LANstr);     % Make specified move
%             SANstr  = CM.RandomMove();         % Make random legal move
%                       CM.Undo();               % Undo last halfmove/edit
%                       CM.UndoAll();            % Undo all halfmoves/edits
%                       CM.Redo();               % Redo last halfmove/edit
%                       CM.RedoAll();            % Redo all halfmoves/edits
%                       CM.GoToHalfmove(n);      % Go to given halfmove
%             success = CM.LoadPosition(FENstr); % Load position from FEN
%             FENstr  = CM.GetFENstr();          % Get current FEN string
%             LANstrs = CM.GetLANstrs();         % Get all LAN move strings
%             SANstrs = CM.GetSANstrs();         % Get all SAN move strings
%                       CM.FlipBoard();          % Flip board orientation
%                       CM.RefreshBoard();       % Refresh board graphics
%                       CM.BlockGUI(bool);       % Set GUI-block state
%                       CM.LoadGame(path,start); % Load game from PGN file
%                       CM.SaveGame(path);       % Save game to PGN file
%                       CM.ResetBoard();         % Reset board
%                       CM.Close();              % Close GUI
%               
% Note:         All of the necessary public properties/methods are exposed
%               for you to write your own external auto-move engine.
%               Alternatively, you can download any chess engine that
%               supports the Universal Chess Interface (UCI) communication
%               protocol and connect it to the ChessEngine objects spawned
%               by a ChessMaster GUI. See README.txt for more information
%               
% Author:       Brian Moore
%               brimoor@umich.edu
%               
% Release:      Version 1.6
%               January 5, 2015
%--------------------------------------------------------------------------
    
    %
    % Public constants
    %
    properties (GetAccess = public, Constant = true)
        % Gameplay mode "enum"
        LEGAL = 1;                          % Legal moves
        EDIT = 2;                           % Editing mode
        
        % Keypress "enum"
        DELETE = 8;                         % Delete keycode
        LEFT = 28;                          % Left arrow
        RIGHT = 29;                         % Right arrow
        UP = 30;                            % Up arrow
        DOWN = 31;                          % Down arrow
    end
    
    %
    % Private constants
    %
    properties (GetAccess = private, Constant = true)
        % Constants
        DEFAULT_FIG_SIZE = 0.75;            % Default relative figure size
        AUTOPLAY_APS = 10;                  % Engine autoplay attempts/sec
    end
    
    %
    % Public properties
    %
    properties (Access = public)
        % Options (default values overwritten by ChessOptions)
        whiteName;                          % Name of white player
        blackName;                          % Name of black player
        defTimeControl;                     % Default time control string
    end
    
    %
    % Public GetAccess properties
    %
    properties (SetAccess = private, GetAccess = public)
        %   1 ==> white
        %   2 ==> black
        turnColor = ChessPiece.WHITE;       % Turn color
        
        %   0 ==> draw
        %   1 ==> white
        %   2 ==> black
        % NaN ==> in progess
        winner = ChessPiece.NULL;           % Winning side value
        
        %   1 ==> legal moves (standard gameplay)
        %   2 ==> editing mode (no moves recorded)
        gameplayMode = ChessMaster.LEGAL;   % Gameplay mode
        
        % Locks
        alock = false;                      % Engine autoplay lock
        block = false;                      % GUI block lock
        elock = false;                      % Execution lock
        glock = false;                      % Graphics lock
        mlock = false;                      % Mouse lock
        
        % Game over status
        isGameOver = false;                 % Game over flag
        
        % Move animation
        animateMoves;                       % Animation flag
        animationPeriod;                    % Animation period (1 / fps)
        
        % Miscellaneous info
        FM;                                 % FigureManager object
        tag = 'ChessMaster';                % ChessMaster GUI tag
        dir;                                % Base directory path
        version;                            % Version structure

        % Engines
        engines;                            % Engines data structure
    end
    
    %
    % Public GetAccess properties (dependent)
    %
    properties (GetAccess = public, SetAccess = private, Dependent = true)
        % Nonnegative integer
        currentMove;                        % Current halfmove count
        
        % false ==> white on bottom
        %  true ==> black on bottom
        boardFlipped;                       % Board flipped flag
        
        %  true ==> standard game
        % false ==> custom game
        isStdStartPos;                      % Starting position type flag
        
        % FEN string
        startingFENstr;                     % Starting position FEN string
        
        % 1 ==> white
        % 2 ==> black
        firstColorToMove;                   % First color to move

    end
    
    %
    % Private properties
    %
    properties (Access = private)
        % Child objects
        BG;                                 % BoardGeometry object
        BE;                                 % BoardEditor object
        BS;                                 % BoardState object
        CC;                                 % ChessClock object
        CO;                                 % ChessOptions object
        GA;                                 % GameAnalyzer object
        ML;                                 % MoveList object
        
        % Square highlights
        CHf;                                % From square highlight
        CHt;                                % To square highlight
        CHc;                                % Current square highlight
        
        % Game/board info
        pieces;                             % Piece sprite structure
        themes;                             % Theme structure
        currentColor;                       % Current theme color
        activeSquare;                       % Active square structure
        activePiece;                        % Active piece object
        ptimer;                             % Piece movement timer
        
        % Options (defaults overwritten by ChessOptions)
        enableLastMoveMenu = false;         % Last move menu enable flag
        enableTurnMarker = false;           % Turn marker enable flag
        enableCheckText = false;            % Check text enable flag
        enableStatusMenu = false;           % Status menu enable flag
        enableUndoRedoDialog;               % Undo/Redo dialog enable flag
        enablePopups;                       % Popup dialog enable flag
        enableMoveList;                     % MoveList enable flag 
        enableGameAnalyzer;                 % GameAnalyzer enable flag
        enableChessClock;                   % ChessClock enable flag
        movesThresh;                        % Undo/Redo dialog threshold
        
        % Engines
        CElist;                             % ChessEngine object array
        nwauto = 0;                         % # white autoplay engines
        nbauto = 0;                         % # black autoplay engines
        atimer;                             % Autoplay timer
        
        % GUI handles
        fig;                                % Figure handle
        ax;                                 % Axis handles
        bh;                                 % Board handle
        tch;                                % Time control menu handle
        mlh;                                % Move list menu handle
        gah;                                % Game analyzer menu handle
        undoh;                              % Undo move menu handle
        undoallh;                           % Undo all moves menu handle
        redoh;                              % Redo move menu handle
        redoallh;                           % Redo all moves menu handle
        drawh1;                             % Offer draw menu handle
        drawh2;                             % Fifty-move rule menu handle
        drawh3;                             % Threefold rep. menu handle
        resignh;                            % Resign menu handle
        movewh;                             % Last white move menu handle
        movebh;                             % Last black move menu handle
        filetexth;                          % File text handles
        ranktexth;                          % Rank text handles
        checkh;                             % Check text handle
        markerh;                            % Turn marker handle
        statush;                            % Status menu handle
    end
    
    %
    % Getter/Setter methods
    %
    methods % Dependent methods only
        %
        % currentMove getter
        %
        function n = get.currentMove(this)
            % Get move number from underlying board state 
            n = this.BS.currentMove;
        end
        
        %
        % boardFlipped getter
        %
        function bool = get.boardFlipped(this)
            % Get orientation from underlying board state 
            bool = this.BS.flipped;
        end
        
        %
        % isStdStartPos getter
        %
        function bool = get.isStdStartPos(this)
            % Get standard starting position flag
            bool = this.BS.startPos.isStdStartPos;
        end
        
        %
        % startingFENstr getter
        %
        function FENstr = get.startingFENstr(this)
            % Get starting position FEN string
            FENstr = this.BS.startPos.FENstr;
        end
        
        %
        % firstColorToMove getter
        %
        function color = get.firstColorToMove(this)
            % Get first color to move
            color = this.BS.startPos.colorToMove;
        end
    end
    
    %
    % Public methods
    %
    methods (Access = public)
        %
        % Constructor
        %
        function this = ChessMaster(arg1)
        % Type "help ChessMaster" for more information
        
            % Save base directory
            this.dir = this.GetBaseDir();
            
            % Load data
            data = load([this.dir '/data.mat']);
            this.engines = data.engines;    % Installed engine info
            this.pieces = data.pieces;      % Chess piece sprites
            this.themes = data.themes;      % Board themes
            this.version = data.version;    % Version info
            
            % Parse inputs
            if ((nargin == 1) && ischar(arg1) && strcmpi(arg1,'last'))
                % Load previous state
                xyc = data.windows.xyc;
                dim = mean(data.windows.pos(3:4));
                loadChildren = true;
            else
                % Compute starting GUI position
                if (nargin == 1)
                    % User-specifed size
                    figSize = arg1;
                else
                    % Default figure size
                    figSize = ChessMaster.DEFAULT_FIG_SIZE;
                end
                [xyc scrsz] = ChessMaster.GetScreenCenter();
                dim = round(figSize * min(scrsz));
                
                % Don't load children
                loadChildren = false;
            end
            
            % Initialize autoplay timer
            this.atimer = timer('Name','AutoPlayTimer', ...
                                'ExecutionMode','FixedRate', ...
                                'StartDelay',0, ...
                                'Period',1 / ChessMaster.AUTOPLAY_APS, ...
                                'TasksToExecute',Inf, ...
                                'TimerFcn',@(s,e)AutoPlay(this));
            
            % Initialize piece movement timer
            this.ptimer = timer('Name','PieceMoveTimer', ...
                                'ExecutionMode','FixedRate', ...
                                'TasksToExecute',Inf, ...
                                'TimerFcn',@(s,e)MouseMove(this));
            
            % Create board geometry object
            this.BG = BoardGeometry(this.pieces);
            
            % Create board state container
            this.BS = BoardState();
            
            % Initialize chess engine array
            this.CElist = ChessEngine.empty(1,0);
            
            % Spawn figure manager
            this.FM = FigureManager();
            
            % Initialize GUI
            this.InitializeGUI(xyc,dim);
            
            % Spawn options manager
            this.CO = ChessOptions(this,data.options);
            
            % Restore last children windows, if necessary
            if (loadChildren == true)
                this.RestoreChildWindows(data.windows.children);
            end
        end
        
        %
        % Make move
        %
        function SANstr = MakeMove(this,LANstr,autoFlag)
        %------------------------------------------------------------------
        % Syntax:       SANstr = CM.MakeMove(LANstr);
        %               SANstr = MakeMove(CM,LANstr);
        %               
        % Inputs:       CM is a ChessMaster object
        %               
        %               LANstr is a string in long algebraic notation (LAN)
        %               
        % Outputs:      SANstr is a string in standard algebraic notation
        %               (SAN) describing the move just performed. If the
        %               move was illegal, SANstr = '' is returned
        %               
        % LAN Standard:                Syntax
        %               '<file><rank><file><rank>[promotion]'
        %               
        %                             Examples                             
        %               'e2e4'
        %               'e7e5'
        %               'e1g1'  - White kingside castling
        %               'e7e8q' - Promotion to queen
        %               
        % Description:  This function performs the move described by the
        %               given LAN string
        %------------------------------------------------------------------
            
            % Parse inputs
            SANstr = '';
            if (nargin < 3)
                autoFlag = true;
            end
            
            % (Try to) parse LAN string
            try
                [fromi fromj toi toj pID] = Move.ParseLAN(LANstr);
            catch %#ok
                % Quick return
                return;
            end
            
            % Process based on gamplay mode
            switch this.gameplayMode
                case ChessMaster.LEGAL
                    % If game is over
                    if (this.isGameOver == true)
                        % Quick return
                        return;
                    end
                    
                    % Perform legal move
                    [SANstr eog] = this.LegalMove(fromi,fromj,toi,toj,pID);
                    
                    % Check for engine autoplays, if necessary
                    if ((autoFlag == true) && (eog == false))
                        this.EngineAutoPlay();
                    end
                case ChessMaster.EDIT
                    % Perform editing move
                    success = this.EditingMove(fromi,fromj,toi,toj);
                    
                    % If edit was successful
                    if (success == true)
                        % Use LANstr as proxy for SANstr
                        SANstr = LANstr;
                    end
            end
        end
        
        %
        % Make a random move for current color
        %
        function SANstr = RandomMove(this,varargin)
        %------------------------------------------------------------------
        % Syntax:       SANstr = CM.RandomMove();
        %               SANstr = RandomMove(CM);
        %               
        % Inputs:       CM is a ChessMaster object
        %               
        % Outputs:      SANstr is a string in standard algebraic notation
        %               (SAN) describing the move just performed
        %               
        % Description:  This function performs a randomly selected move for
        %               the current color-to-move 
        %------------------------------------------------------------------
        
            % Query board state for a random move
            LANstr = this.BS.GetRandomMove(this.turnColor);
            
            % Make the move
            SANstr = this.MakeMove(LANstr,varargin{:});
        end
        
        %
        % Undo last halfmove/eidt
        %
        function Undo(this)
        %------------------------------------------------------------------
        % Syntax:       CM.Undo();
        %               Undo(CM);
        %               
        % Inputs:       CM is a ChessMaster object
        %               
        % Description:  This function undoes the last halfmove/edit
        %------------------------------------------------------------------
            
            % Process based on gameplay mode
            switch this.gameplayMode
                case ChessMaster.LEGAL
                    % Undo move
                    this.UndoMove();
                case ChessMaster.EDIT
                    % Undo edit
                    this.UndoEdit();
            end
        end
        
        %
        % Undo all halfmoves/edits
        %
        function UndoAll(this)
        %------------------------------------------------------------------
        % Syntax:       CM.UndoAll();
        %               UndoAll(CM);
        %               
        % Inputs:       CM is a ChessMaster object
        %               
        % Description:  This function undoes all halfmoves/edits
        %------------------------------------------------------------------
        
            % Process based on gameplay mode
            switch this.gameplayMode
                case ChessMaster.LEGAL
                    % Undo all moves
                    this.UndoAllMoves();
                case ChessMaster.EDIT
                    % Undo all edits
                    this.UndoAllEdits();
            end
        end
        
        %
        % Redo next halfmove/edit
        %
        function Redo(this)
        %------------------------------------------------------------------
        % Syntax:       CM.Redo();
        %               Redo(CM);
        %               
        % Inputs:       CM is a ChessMaster object
        %               
        % Description:  This function redoes the next halfmove/edit
        %------------------------------------------------------------------
        
            % Process based on gameplay mode
            switch this.gameplayMode
                case ChessMaster.LEGAL
                    % Redo move
                    this.RedoMove();
                case ChessMaster.EDIT
                    % Redo edit
                    this.RedoEdit();
            end
        end
        
        %
        % Redo all halfmoves/edits
        %
        function RedoAll(this)
        %------------------------------------------------------------------
        % Syntax:       CM.RedoAll();
        %               RedoAll(CM);
        %               
        % Inputs:       CM is a ChessMaster object
        %               
        % Description:  This function redoes all halfmoves/edits
        %------------------------------------------------------------------
        
            % Process based on gameplay mode
            switch this.gameplayMode
                case ChessMaster.LEGAL
                    % Redo all moves
                    this.RedoAllMoves();
                case ChessMaster.EDIT
                    % Redo all edits
                    this.RedoAllEdits();
            end
        end
        
        %
        % Go to given halfmove number
        %
        function GoToHalfmove(this,n)
        %------------------------------------------------------------------
        % Syntax:       CM.GoToHalfmove(n);
        %               GoToHalfmove(CM,n);
        %               
        % Inputs:       CM is a ChessMaster object
        %               
        % Outputs:      n is the desired halfmove (nonnegative integer)
        %               
        % Description:  This function reverts/progresses the game state to
        %               the given halfmove number, where n = 0 returns to
        %               the starting position
        %------------------------------------------------------------------
        
            % Clip target to valid range
            n = min(max(n,0),length(this.BS.moveList));
            
            % Go to target halfmove
            dm = n - this.BS.currentMove;
            absdm = abs(dm);
            switch sign(dm)
                case -1
                    % Undo the requisite number of moves
                    this.UndoMoves(absdm);
                case 1
                    % Redo the requisite number of moves
                    this.RedoMoves(absdm);
            end
        end
        
        %
        % Load board position
        %
        function success = LoadPosition(this,FENstr,varargin)
        %------------------------------------------------------------------
        % Syntax:       success = CM.LoadPosition(FENstr);
        %               success = LoadPosition(CM,FENstr);
        %               
        % Inputs:       CM is a ChessMaster object
        %               
        %               FENstr is the Forsyth–Edwards Notation (FEN) string
        %               describing a desired board position
        %               
        % Outputs:      success = {true,false} indicates whether the input
        %               FEN string was valid
        %               
        % Description:  This function loads the board position specified by
        %               the given FEN string
        %------------------------------------------------------------------
            
            % If no FEN provided
            if (nargin < 2)
                % Ask user for a FEN to load
                FENstr = inputdlg({'Enter a FEN string:'}, ...
                                   'Load position',[1 85], ...
                                   {this.GetFENstr()});
                drawnow; % Hack to avoid MATLAB freeze + crash
                
                % If user pressed cancel
                if isempty(FENstr)
                    % Quick return
                    success = false;
                    return;
                end
                FENstr = FENstr{1};
            end
            
            % Initialize board
            success = this.InitializeBoard(FENstr,varargin{:});
        end
        
        %
        % Get FEN string for current position
        %
        function FENstr = GetFENstr(this)
        %------------------------------------------------------------------
        % Syntax:       FENstr = CM.GetFENstr();
        %               FENstr = GetFENstr(CM);
        %               
        % Inputs:       CM is a ChessMaster object
        %               
        % Outputs:      FENstr is the Forsyth-–Edwards Notation (FEN) string
        %               describing the *current* board position
        %               
        % Description:  This function returns the FEN string that encodes
        %               the current board position
        %------------------------------------------------------------------
            
            % Query board state for current FEN string
            FENstr = this.BS.GetCurrentFENstr(this.turnColor);
        end
        
        %
        % Get list of all LAN strings up until current position 
        %
        function LANstrs = GetLANstrs(this)
        %------------------------------------------------------------------
        % Syntax:       LANstrs = CM.GetLANstrs();
        %               LANstrs = GetLANstrs(CM);
        %               
        % Inputs:       CM is a ChessMaster object
        %               
        % Outputs:      LANstrs is a cell array containing the long
        %               algebraic notation (LAN) strings describing each
        %               move up until the current position
        %               
        % Description:  This function returns the LAN strings for each move
        %               up until the current position
        %------------------------------------------------------------------
        
            % Get LAN strings from move list
            LANstrs = {this.BS.moveList(1:this.BS.currentMove).LANstr};
        end
        
        %
        % Get list of all SAN strings up until current position 
        %
        function SANstrs = GetSANstrs(this)
        %------------------------------------------------------------------
        % Syntax:       SANstrs = CM.GetSANstrs();
        %               SANstrs = GetSANstrs(CM);
        %               
        % Inputs:       CM is a ChessMaster object
        %               
        % Outputs:      SANstrs is a cell array containing the standard
        %               algebraic notation (SAN) strings describing each
        %               move up until the current position
        %               
        % Description:  This function returns the SAN strings for each move
        %               up until the current position
        %------------------------------------------------------------------
        
            % Get SAN strings from move list
            SANstrs = {this.BS.moveList(1:this.BS.currentMove).SANstr};
        end
        
        %
        % Flip board orientation
        %
        function FlipBoard(this)
        %------------------------------------------------------------------
        % Syntax:       CM.FlipBoard();
        %               FlipBoard(CM);
        %               
        % Inputs:       CM is a ChessMaster object
        %               
        % Description:  Flips the board orientation (i.e., toggles between
        %               white-on-bottom and black-on-bottom)
        %------------------------------------------------------------------
        
            % Toggle board orientation
            this.BS.flipped = ~this.BS.flipped;
            
            % Refresh board
            this.RefreshBoard();
        end
        
        %
        % Refresh board
        %
        function RefreshBoard(this)
        %------------------------------------------------------------------
        % Syntax:       CM.RefreshBoard();
        %               RefreshBoard(CM);
        %               
        % Inputs:       CM is a ChessMaster object
        %               
        % Description:  Refreshes the game board (garbage collects orphan
        %               image handles and redraws board graphics) 
        %------------------------------------------------------------------
        
            % Update axis orientation
            if (this.BS.flipped == true)
                % Black on bottom
                set(this.ax,'XDir','Reverse','YDir','Reverse');
            else
                % White on bottom
                set(this.ax,'XDir','Normal','YDir','Normal');
            end
            
            % Refresh pieces
            this.BS.RefreshPieces();
            
            % Update turn marker
            this.UpdateTurnMarker();
            
            % Update check text
            this.UpdateCheckText();
            
            % Update chess clock orientation, if necessary
            if ~isempty(this.CC)
                this.CC.UpdateClockOrientation();
            end
        end
        
        %
        % Set GUI-block state
        %
        function BlockGUI(this,bool)
        %------------------------------------------------------------------
        % Syntax:       CM.BlockGUI(bool);
        %               BlockGUI(CM,bool);
        %               
        % Inputs:       CM is a ChessMaster object
        %               
        %               bool = {true,false} is the desired GUI-block state
        %               
        % Description:  When bool == true, all GUI mouse/keyboard events
        %               are ignored. This is useful, for instance, to
        %               prevent the user from trying to make a move while
        %               an engine is thinking
        %------------------------------------------------------------------
        
            % Update GUI-block state
            this.block = bool;
        end
        
        %
        % Load game from PGN file
        %
        function LoadGame(this,varargin)
        %------------------------------------------------------------------
        % Syntax:       CM.LoadGame();
        %               CM.LoadGame(path);
        %               CM.LoadGame(path,start);
        %               LoadGame(CM);
        %               LoadGame(CM,path);
        %               LoadGame(CM,path,start);
        %               
        % Inputs:       CM is a ChessMaster object
        %               
        %               [OPTIONAL] path is a string containing the input
        %               PGN path. When path isn't specified, a dialog box
        %               appears asking the user to provide it
        %               
        %               [OPTIONAL] start = {'Beginning','End'} specifies
        %               where you'd like to resume the loaded game. When
        %               start isn't specified, a dialog box appears asking
        %               the user to provide it
        %               
        % Description:  This function loads a game from the specified PGN
        %               file
        %------------------------------------------------------------------
            
            % Call internal PGN reader
            this.ReadPGN(varargin{:});
        end
        
        %
        % Save game to PGN file
        %
        function SaveGame(this,varargin)
        %------------------------------------------------------------------
        % Syntax:       CM.SaveGame();
        %               CM.SaveGame(path);
        %               SaveGame(CM);
        %               SaveGame(CM,path);
        %               
        % Inputs:       CM is a ChessMaster object
        %               
        %               [OPTIONAL] path is a string containing the input
        %               PGN path. When path isn't specified, a dialog box
        %               appears asking the user to provide it
        %               
        % Description:  This function writes the current game to a PGN file
        %               at the specified path
        %------------------------------------------------------------------
            
            % Call internal PGN writer
            this.WritePGN(varargin{:});
        end
        
        %
        % Reset board
        %
        function ResetBoard(this)
        %------------------------------------------------------------------
        % Syntax:       CM.ResetBoard();
        %               ResetBoard(CM);
        %               
        % Inputs:       CM is a ChessMaster object
        %               
        % Description:  This function resets the board to the standard
        %               starting position
        %------------------------------------------------------------------
            
            % Initialize board
            this.InitializeBoard();
        end
        
        %
        % Close GUI
        %
        function Close(this)
        %------------------------------------------------------------------
        % Syntax:       CM.Close();
        %               Close(CM);
        %               
        % Inputs:       CM is a ChessMaster object
        %               
        % Description:  This function gracefully closes the GUI and deletes
        %               the ChessMaster object
        %------------------------------------------------------------------
        
            try
                % Stop autoplay timer, if necessary
                if strcmpi(this.atimer.Running,'on')
                    % Stop timer
                    stop(this.atimer);
                end
                
                % Delete autoplay timer
                delete(this.atimer);
            catch %#ok
                % Graceful exit
            end
            
            try
                % Stop piece movement timer, if necessary
                if strcmpi(this.ptimer.Running,'on')
                    % Stop timer
                    stop(this.ptimer);
                end
                
                % Delete piece movement timer
                delete(this.ptimer);
            catch %#ok
                % Graceful exit
            end
            
            try
                % Save current window positions
                windows.children = this.FM.GetChildWindowInfo(this.tag);
                pos = get(this.fig,'Position');
                windows.xyc = pos(1:2) + 0.5 * pos(3:4);
                windows.pos = pos; %#ok
                
                % Close all figures except main GUI
                this.FM.CloseAllExcept(this.tag);
            catch %#ok
                % Graceful exit
            end
            
            try
                % Save updated info
                engines = this.engines; %#ok
                options = this.CO.Close(); %#ok
                themes = this.themes; %#ok
                save([this.dir '/data.mat'],'-append', ...
                                            'engines','options', ...
                                            'themes','windows');
            catch %#ok
                % Graceful exit
            end
            
            try
                % Force close the main GUI
                delete(this.fig);
            catch %#ok
                % Something strange happened, so delete gcf
                delete(gcf);
            end
            
            try
                % Delete this object
                delete(this);
            catch %#ok
                % Graceful exit
            end
        end
    end
    
    %
    % Private methods
    %
    methods (Access = private)
        %
        % Get mouse location in axis units
        %
        function [x y] = GetMouseLocation(this)
            % Get absolute pointer location (wrt screen)
            mpos = get(0,'PointerLocation');
            
            % Compute pointer location in axis units
            fpos = get(this.fig,'Position');
            xy = mpos - fpos(1:2);
            if (this.BS.flipped == true)
                % Flip coordinates to account for board orientation
                xy = this.BG.boardDim + 1 - xy;
            end
            x = xy(1);
            y = xy(2);
        end
        
        %
        % Get (rank,file) coordinates of (x,y) axis location
        %
        function [i j] = LocateClick(this,x,y)
            % Get file
            i = find(x < this.BG.file,1,'first') - 1;
            if isempty(i)
                i = 0; % off board
            end
            
            % Get rank
            j = find(y < this.BG.rank,1,'first') - 1;
            if isempty(j)
                j = 0; % off board
            end
        end
        
        %
        % Get click coordinates
        %
        function [i j] = GetClickCoordinates(this)
            % Get click coordinates
            xy = get(this.ax(3),'CurrentPoint');
            [i j] = this.LocateClick(xy(1,1),xy(1,2));
            %[x y] = this.GetMouseLocation();
            %[i j] = this.LocateClick(x,y);
        end
        
        %
        % Get active square coordinates
        %
        function [i j] = GetActiveCoordinates(this)
            % Look for active piece/square
            if ~isnan(this.activePiece)
                % Active piece coordinates
                i = this.activePiece.i;
                j = this.activePiece.j;
            elseif ~isempty(this.activeSquare)
                % Active square coordinates
                i = this.activeSquare.i;
                j = this.activeSquare.j;
            else
                % No active coordinates
                i = 0;
                j = 0;
            end
        end
        
        %
        % Handle keypress
        %
        function HandleKeyPress(this,event)
            % If not processing keypress events
            if (this.block || this.animateMoves || this.mlock || ...
               (this.gameplayMode ~= ChessMaster.EDIT))
                % Quick return
                return;
            end
            
            % Get active coordinates
            [i j] = this.GetActiveCoordinates();
            if ((i == 0) || (j == 0))
                % Quick return
                return;
            end
            
            % Parse keypress
            keyChar = event.Character;
            if isempty(keyChar)
                % Quick return
                return;
            end
            key = double(keyChar);
            
            % Handle keypress
            switch key
                case ChessMaster.DELETE
                    % Delete piece
                    this.EditingDelete(i,j);
                    this.SelectSquare(i,j,false);
                case ChessMaster.LEFT
                    % Move marker left
                    if (i > 1)
                        % Select left square
                        this.SelectSquare(i - 1,j);
                    end
                case ChessMaster.RIGHT
                    % Move marker right
                    if (i < 8)
                        % Select right square
                        this.SelectSquare(i + 1,j);
                    end
                case ChessMaster.UP
                    % Move marker up
                    jnew = j + (1 - 2 * this.BS.flipped);
                    if ((jnew >= 1) && (jnew <= 8))
                        % Select above square
                        this.SelectSquare(i,jnew);
                    end
                case ChessMaster.DOWN
                    % Move marker down
                    jnew = j - (1 - 2 * this.BS.flipped);
                    if ((jnew >= 1) && (jnew <= 8))
                        % Select below square
                        this.SelectSquare(i,jnew);
                    end
                otherwise
                    % Check for piece addition
                    keyStri = upper(keyChar);
                    if strcmp(keyChar,keyStri)
                        color = ChessPiece.WHITE;
                    else
                        color = ChessPiece.BLACK;                
                    end
                    ID = find(keyStri == Move.SYMBOLS);
                    if ~isempty(ID)
                        % Add piece
                        this.EditingAdd(ID,color,i,j);
                        this.SelectSquare(i,j,false);
                    end
            end
        end
        
        %
        % Handle mouse down
        %
        function MouseDown(this)
            % If not processing mouse down events
            editMode = (this.gameplayMode == ChessMaster.EDIT);
            if (this.block || this.mlock || (~editMode && this.isGameOver))
                % Quick return
                return;
            end
            
            % Get coordinates
            [i j] = this.GetClickCoordinates();
            [iActive jActive] = this.GetActiveCoordinates();
            validClick = ((i >= 1) && (i <= 8) && (j >= 1) && (j <= 8));
            
            % If piece is already selected
            if ~isnan(this.activePiece)
                if (~validClick || ((i == iActive) && (j == jActive)))
                    % Clear square selection
                    this.ClearSquareSelection();
                else
                    % Process move in MouseUp()
                    this.mlock = true;                    
                end
                return;
            end
            
            % If empty square is already selected
            if ~isempty(this.activeSquare)
                if (~validClick || ((i == iActive) && (j == jActive)))
                    % Clear square selection
                    this.ClearSquareSelection();
                else
                    % Select new square
                    this.SelectSquare(i,j);
                end
                return;
            end
            
            % Click validity
            if (validClick == false)
                % Quick return
                return;
            end
            
            % Process based on gameplay mode
            if (editMode == true)
                % Edit mode
                this.SelectSquare(i,j);
            else
                % Legal mode
                if (this.BS.ColorAt(i,j) == this.turnColor)
                    % Select square
                    this.SelectSquare(i,j);
                end
            end
        end
        
        %
        % Handle mouse move
        %
        function MouseMove(this)
            % If not ready to process mouse movement
            if ((this.mlock == false) || (this.glock == true))
                % Quick return;
                return;
            end
            
            % Update active piece location
            this.glock = true;
            [x y] = this.GetMouseLocation();
            this.activePiece.DrawPieceAt(x,y);
            this.glock = false;
        end
        
        %
        % Handle mouse release
        %
        function MouseUp(this)
            % If mouse lock isn't set
            if (this.mlock == false)
                % Quick return
                return;
            end
            
            % If piece animation is running
            if strcmpi(this.ptimer.Running,'on')
                % Stop timer
                stop(this.ptimer);
            end
            
            % If processing mouse release events
            success = false;
            piece = this.activePiece;
            editMode = (this.gameplayMode == ChessMaster.EDIT);
            if (~this.block && (editMode || ~this.isGameOver))
                % Get click coordinates
                [toi toj] = this.GetClickCoordinates();
                
                % Perform action
                if ((editMode == true) && ((toi == 0) || (toj == 0)))
                    % Delete active piece
                    success = this.EditingDelete(piece.i,piece.j);
                else
                    % Piece movement
                    LANstr = Move.GenerateLAN(piece.i,piece.j,toi,toj);
                    SANstr = this.MakeMove(LANstr,false);
                    success = ~isempty(SANstr);
                end
            end
            
            % Handle success flag
            if (success == false)
                % Return piece to home
                piece.DrawPiece();
            elseif (editMode == true)
                % Quick return
                return;
            end
            
            % Clear square selection
            this.ClearSquareSelection();
            
            % Release mouse lock
            this.mlock = false;
            
            % Flush graphics
            this.FlushGraphics();
            
            % Check for engine auto-plays
            this.EngineAutoPlay();
        end
        
        %
        % Select square
        %
        function SelectSquare(this,i,j,addFlag)
            % Parse addition check flag
            addFlag = ((nargin < 4) || (addFlag == true));
            
            % If square is occupied
            piece = this.BS.PieceAt(i,j);
            if ~isnan(piece)
                % Select piece
                this.activeSquare = [];
                this.activePiece = piece;
                this.activePiece.MakeActive();
                this.CHc.SetLocation(i,j);
                
                % If move animation is on
                if (this.animateMoves == true)
                    % Start piece animation
                    this.mlock = true;
                    start(this.ptimer);
                end
            elseif (this.animateMoves == false)
                % Select empty square
                this.activeSquare = struct('i',i,'j',j);
                this.activePiece = nan;
                this.CHc.SetLocation(i,j);
            end
            
            % If we should check for piece addition
            if (~isempty(this.BE) && (addFlag == true))
                % Get active piece from BoardEditor
                [ID color] = this.BE.GetActivePiece();
                
                % If a piece is active
                if (~isnan(ID) && (color ~= ChessPiece.NULL))
                    % Add piece to board
                    this.EditingAdd(ID,color,i,j);
                end
            end
        end
        
        %
        % Clear square selection
        %
        function ClearSquareSelection(this)
            % Clear square selection
            this.CHc.Off();
            this.activeSquare = [];
            this.activePiece = nan;
            this.glock = false;
        end
        
        %
        % Add piece (editing mode)
        %
        function success = EditingAdd(this,ID,color,i,j)
            % Remove existing piece, if necessary
            oldPiece = this.BS.PieceAt(i,j);
            if ~isnan(oldPiece)
                % Don't allow king captures
                if (oldPiece.ID == King.ID)
                    % Quick return
                    success = false;
                    return;
                end
                
                % Capture old piece
                oldPiece.CapturePiece();
            end
            
            % Add piece to board
            success = true;
            this.InsertPiece(ID,color,i,j);
            
            % Update BoardEditor
            this.BE.UpdatePosition();
        end
        
        %
        % Delete piece (editing mode)
        %
        function success = EditingDelete(this,i,j)
            % Get target piece
            piece = this.BS.PieceAt(i,j);
            if (isnan(piece) || (piece.ID == King.ID))
                % Quick return
                success = false;
                return;
            end
            
            % Capture piece
            success = true;
            piece.CapturePiece();
            
            % Update BoardEditor
            this.BE.UpdatePosition();
        end
        
        %
        % Move piece (editing mode)
        %
        function success = EditingMove(this,fromi,fromj,toi,toj)
            % Get active piece
            piece = this.BS.PieceAt(fromi,fromj);
            if (isnan(piece) || ((fromi == toi) && (fromj == toj)))
                % Quick return
                success = false;
                return;
            end
            
            % Vet capture, if any
            cPiece = this.BS.PieceAt(toi,toj);
            if (~isnan(cPiece) && (cPiece.ID == King.ID))
                % No king captures allowed!
                success = false;
                return;
            end
            
            % Perform move
            success = true;
            piece.MovePiece(toi,toj,true,true);
            
            % Update BoardEditor
            this.BE.UpdatePosition();
        end
        
        %
        % Fast move (don't check legality)
        %
        function FastMove(this,fromi,fromj,toi,toj,pID,mateFlag)
            % Move piece
            piece = this.BS.PieceAt(fromi,fromj);
            move = piece.MovePiece(toi,toj);
            
            % Check for promotion
            if ~isempty(pID)
                % Promote pawn
                prom = this.PromotePawn(piece,pID);
                move.AddPromotion(piece,prom);
            end
            
            % Toggle turn color
            this.ToggleTurnColor();
            
            % Save move
            this.SaveMove(move,mateFlag);
        end
        
        %
        % Legal move
        %
        function [SANstr eog] = LegalMove(this,fromi,fromj,toi,toj,pID)
            % Set execution lock
            this.elock = true;
            
            % Get active piece
            piece = this.BS.PieceAt(fromi,fromj);
            
            % Check if move is valid
            SANstr = '';
            eog = false;
            if (isnan(piece) || (piece.color ~= this.turnColor) || ...
               (piece.IsValidMove(toi,toj) == false))
                % Invalid move
                return;
            end
            
            % Perform move
            [move isprom] = piece.MovePiece(toi,toj);
            
            % Check if move is legal
            this.BS.UpdateCheckStatus(this.turnColor);
            if this.BS.GetCheckStatus(this.turnColor)
                % A check was ignored, so undo move
                ChessPiece.UndoMovePiece(move,this.BS);
                this.BS.UpdateCheckStatus(this.turnColor);
                return;
            end
            
            % Check for promotions
            if (isprom == true)
                if ~isempty(pID)
                    % Apply specified promotion
                    prom = PromotePawn(this,piece,pID);
                else
                    % Ask user for promotion choice
                    prom = this.GetPromotion(piece);
                end
                
                % Record promotion
                if ~isnan(prom)
                    move.AddPromotion(piece,prom);
                end
            end
            
            % Toggle turn color
            this.ToggleTurnColor();
            
            % Save move
            SANstr = this.SaveMove(move);
            
            % Update GUI
            this.UpdateGUI();
            
            % Update analysis engines
            this.UpdateAnalysisEngines();
            
            % Handle game over scenarios
            eog = this.HandleGameOverScenarios();
            
            % Release execution lock
            this.elock = false;
        end
        
        %
        % Handle game over scenarios
        %
        function endOfGame = HandleGameOverScenarios(this)
            % Handle edit mode
            if (this.gameplayMode == ChessMaster.EDIT)
                % Quick return
                endOfGame = false;
                return;
            end
            
            % Handle illegal positions
            activeColor = this.turnColor;
            opposingColor = ChessPiece.Toggle(activeColor);
            if (this.BS.GetCheckStatus(opposingColor) == true)
                % Illegal position
                endOfGame = true;
                this.GameOver(ChessPiece.NULL,'Illegal position...');
                return;
            end
            
            % Handle mates
            switch this.BS.GetMateStatus(activeColor)
                case BoardState.CHECKMATE
                    % Checkmate!
                    endOfGame = true;
                    this.GameOver(opposingColor,'Checkmate!');
                case BoardState.STALEMATE
                    % Stalemate...
                    endOfGame = true;
                    this.GameOver(ChessPiece.DRAW,'Stalemate...');
                otherwise
                    % No mate
                    endOfGame = false;
            end
        end
        
        %
        % Save move within board state
        %
        function SANstr = SaveMove(this,move,mateFlag)
            % Parse mate flag
            mateFlag = ((nargin < 3) || (mateFlag == true));
            
            % Update checks
            this.BS.UpdateChecks();
            if this.BS.GetCheckStatus(this.turnColor)
                % Add check to move
                move.AddCheck();
            end
            
            % If mate flag is set
            if (mateFlag == true)
                % Update mate status
                this.BS.UpdateMateStatus(this.turnColor);
                mate = this.BS.GetMateStatus(this.turnColor);
                if (mate == BoardState.CHECKMATE)
                    % Add checkmate to move
                    move.AddCheckmate();
                end
            end
            
            % If move was reversible
            if (move.reversible == true)
                % Increment counter
                move.IncRevMoves();
            end
            
            % Save encoded board state
            move.EncodeBoardState();
            
            % Record move
            this.BS.RecordMove(move);
            SANstr = move.SANstr;
            
            % Add to GameAnalyzer, if necessary
            if ~isempty(this.GA)
                idx = this.BS.currentMove - 1;
                this.GA.AppendMoves({move.LANstr},{SANstr},idx);
            end
            
            % Add to MoveList, if necessary
            if ~isempty(this.ML)
                idx = this.BS.currentMove - 1;
                this.ML.AppendMoves({SANstr},idx);
            end
            
            % Toggle chess clock, if necessary
            if ~isempty(this.CC)
                this.CC.ToggleClock();
            end
        end
        
        %
        % Load edit position
        %
        function LoadEditPosition(this,idx)
            % Load specified position
            this.BS.currentEdit = idx;
            FENstr = this.BS.editList{idx};
            this.LoadPosition(FENstr,false);
        end
        
        %
        % Undo move
        %
        function UndoMove(this,drawflag)
            % Set execution lock
            this.elock = true;
            
            % Parse drawflag
            drawflag = ((nargin < 2) || (drawflag == true));
            
            % Undo move
            lastMove = (this.BS.currentMove == length(this.BS.moveList));
            this.BS.UndoMove();
            
            % If last move was undone
            if (lastMove == true)
                % Update mate status
                this.BS.UpdateMateStatus(this.turnColor);
                
                % Never have game over
                this.winner = ChessPiece.NULL;
                this.isGameOver = false;
            end
            
            % Toggle turn color
            this.ToggleTurnColor();
            
            % Update checks
            this.BS.UpdateChecks();
            
            % Update GUI, if necessary
            if (drawflag == true)
                this.UpdateGUI();
            end
            
            % Update engines, if necessary
            if (drawflag == true)
                % Update engine states
                this.UpdateEngineStates();
                
                % Turn off engine autoplay for current color
                this.TurnOffEngineAutoPlay(this.turnColor);
            end
            
            % Release execution lock
            this.elock = false;
            
            % Handle engine autoplay, if necessary
            if (drawflag == true)
                this.EngineAutoPlay();
            end
        end
        
        %
        % Undo halfmoves
        %
        function UndoMoves(this,n,varargin)
            % Get dialog box flag
            showDB = (((nargin == 2) || (varargin{1} == true)) && ...
                     this.enableUndoRedoDialog && (n >= this.movesThresh));
            
            % Create undoing dialog box, if necessary
            if (showDB == true)
                udh = this.DialogBox('Undoing...');
            end
            
            % Undo all but one move without flushing graphics
            for i = 1:(n - 1)
                this.UndoMove(false);
            end
            
            % Close undoing dialog box, if necessary
            if (showDB == true)
                this.CloseDialogBox(udh);
            end
            
            % Undo last move with graphics flush
            if (n > 0)
                this.UndoMove();
            end
        end
        
        %
        % Undo all halfmoves
        %
        function UndoAllMoves(this,varargin)
            % Undo all moves
            n = this.BS.currentMove;
            this.UndoMoves(n,varargin{:});
        end
        
        %
        % Redo move
        %
        function RedoMove(this,drawflag)
            % Set execution lock
            this.elock = true;
            
            % Parse drawflag
            drawflag = ((nargin < 2) || (drawflag == true));
            
            % Redo move
            this.BS.RedoMove();
            lastMove = (this.BS.currentMove == length(this.BS.moveList));
            
            % Toggle turn color
            this.ToggleTurnColor();
            
            % Update checks
            this.BS.UpdateChecks();
            
            % Update mate status, if necessary
            if (lastMove == true)
                this.BS.UpdateMateStatus(this.turnColor);
            end
            
            % Update GUI, if necessary
            if (drawflag == true)
                this.UpdateGUI();
            end
            
            % Handle game over scenarios, if necessary
            if (lastMove == true)
                eog = this.HandleGameOverScenarios();
                if (eog == true)
                    % Quick return
                    return;
                end
            end
            
            % Update engines, if necessary
            if (drawflag == true)
                % Update engine states
                this.UpdateEngineStates();
                
                % Turn off engine autoplay for current color
                this.TurnOffEngineAutoPlay(this.turnColor);
            end
            
            % Release execution lock
            this.elock = false;
            
            % Handle engine autoplay, if necessary
            if (drawflag == true)
                this.EngineAutoPlay();
            end
        end
        
        %
        % Redo halfmoves
        %
        function RedoMoves(this,n,varargin)
            % Get dialog box flag
            showDB = (((nargin == 2) || (varargin{1} == true)) && ...
                     this.enableUndoRedoDialog && (n >= this.movesThresh));
            
            % Create redoing dialog box, if necessary
            if (showDB == true)
                rdh = this.DialogBox('Redoing...');
            end
            
            % Redo all but one move without flushing graphics
            for i = 1:(n - 1)
                this.RedoMove(false);
            end
            
            % Close redoing dialog box, if necessary
            if (showDB == true)
                this.CloseDialogBox(rdh);
            end
            
            % Redo last move with graphics flush
            if (n > 0)
                this.RedoMove();
            end
        end
        
        %
        % Redo all halfmoves
        %
        function RedoAllMoves(this,varargin)
            % Redo all moves
            n = length(this.BS.moveList) - this.BS.currentMove;
            this.RedoMoves(n,varargin{:});
        end
        
        %
        % Redo edit
        %
        function RedoEdit(this)
            % Load desired position
            this.LoadEditPosition(this.BS.currentEdit + 1);
        end
        
        %
        % Redo edits
        %
        function RedoEdits(this,n)
            % Load desired position
            this.LoadEditPosition(this.BS.currentEdit + n);
        end
        
        %
        % Redo all edits
        %
        function RedoAllEdits(this)
            % Load desired position
            this.LoadEditPosition(length(this.BS.editList));
        end
        
        %
        % Undo edit
        %
        function UndoEdit(this)
            % Load desired position
            this.LoadEditPosition(this.BS.currentEdit - 1);
        end
        
        %
        % Undo edits
        %
        function UndoEdits(this,n)
            % Load desired position
            this.LoadEditPosition(this.BS.currentEdit - n);
        end
        
        %
        % Undo all edits
        %
        function UndoAllEdits(this)
            % Load first position
            this.LoadEditPosition(1);
        end
        
        %
        % Offer draw
        %
        function OfferDraw(this)
            % Get color of team to accept the draw
            switch this.turnColor
                case ChessPiece.WHITE
                    % White offers draw
                    color = 'White';
                case ChessPiece.BLACK
                    % Black offers draw
                    color = 'Black';
            end
            
            % Offer draw to opponent
            selection = questdlg([color ' offers a draw. Accept?'], ...
                                 this.version.name,'Yes','No','Yes');
            drawnow; % Hack to avoid MATLAB freeze + crash
            
            % Handle request
            if strcmp(selection,'Yes')
                % Game ends in draw
                winningColor = ChessPiece.DRAW;
                this.GameOver(winningColor,'Draw...');
            end
        end
        
        %
        % Draw based on Fifty-move rule
        %
        function FiftyMovesDraw(this)
            % Game ends in draw
            winningColor = ChessPiece.DRAW;
            this.GameOver(winningColor,'Fity-move rule draw...');
        end
        
        %
        % Draw based on threefold repetition
        %
        function Rep3FoldDraw(this)
            % Game ends in draw
            winningColor = ChessPiece.DRAW;
            this.GameOver(winningColor,'Threefold repetition draw...');
        end
        
        %
        % Resign from the game
        %
        function Resign(this)
            % Handle turn color
            switch this.turnColor
                case ChessPiece.WHITE
                    % White resigns
                    winningColor = ChessPiece.BLACK;
                    str = 'White resigns...';
                case ChessPiece.BLACK
                    % Black resigns
                    winningColor = ChessPiece.WHITE;
                    str = 'Black resigns...';
            end
            
            % Game over
            this.GameOver(winningColor,str);
        end
        
        %
        % Get a promotion from user
        %
        function prom = GetPromotion(this,pawn)
            % Flush graphics
            this.FlushGraphics();
            
            % Ask user for promotion
            %
            % NOTE: strings *must* match class names 
            %
            liststr = {'Pawn';'Knight';'Bishop';'Rook';'Queen'};
            idx = listdlg('PromptString','Select a piece:', ...
                          'SelectionMode','single', ...
                          'InitialValue',5, ...
                          'Name','Pawn promotion', ...
                          'ListSize',[200 100], ...
                          'ListString',liststr);
            drawnow; % Hack to avoid MATLAB freeze + crash
            
            % Make sure the user didn't press cancel or choose pawn
            if (~isempty(idx) && (idx > 1))
                % Promote pawn
                ID = eval([liststr{idx} '.ID']); % hack
                prom = this.PromotePawn(pawn,ID);
            else
                % No promotion selected
                prom = nan;
            end
        end
        
        %
        % Promote pawn to the piece with given ID
        %
        function prom = PromotePawn(this,pawn,ID)
            % Capture pawn
            pawn.CapturePiece();
            
            % Insert promoted piece
            prom = this.InsertPiece(ID,pawn.color,pawn.i,pawn.j);
        end
        
        %
        % Read game from PGN file
        %
        function ReadPGN(this,path,startAt)
            % Flush graphics
            this.FlushGraphics();
            
            % If no path was specified
            if ((nargin < 2) || isempty(path))
                % Ask the user what file to load
                path = inputdlg({['Enter a path (plus extension) to ' ...
                                  'an existing PGN file:']}, ...
                                  'Load game from file',1, ...
                                 {'./game.pgn'},'on');
                drawnow; % Hack to avoid MATLAB freeze + crash
                
                % Make sure user didn't press cancel
                if isempty(path)
                    % Quick return
                    return;
                end
                path = path{1};
            end
            
            % If no selection was specified
            if ((nargin < 3) || isempty(startAt))
                % Ask user where to begin play
                startAt = questdlg('Where should we resume play?', ...
                                this.version.name,'Beginning','End','End'); 
                drawnow; % Hack to avoid MATLAB freeze + crash
                
                % Make sure user didn't press cancel
                if isempty(startAt)
                    % Quick return
                    return;
                end
            end
            
            % Save game analyzer position and close it, if applicable
            GApos = this.FM.GetPosition('GameAnalyzer');
            this.CloseGameAnalyzer();
            
            % Save move list position and close it, if applicable
            MLpos = this.FM.GetPosition('MoveList');
            this.CloseMoveList();
            
            % Save chess clock position and close it, if applicable
            TCpos = this.FM.GetPosition('ChessClock');
            this.CloseChessClock();
            
            % Create loading dialog box
            ldh = this.DialogBox('Loading...');
            
            % Parse PGN file
            PGNinfo = ChessMaster.ParsePGN(path);
            tcStr = PGNinfo.timeControl; % Time control string
            SANstrs = {PGNinfo.moves.SAN};
            Nmoves = length(SANstrs);
            
            % Parse time control
            isTimeControl = false;
            try
                % Parse time control string
                per = ChessClock.ParseTimeControl(tcStr);
                
                % If time control exists
                if ~isempty(per)
                    % Set time control flag
                    isTimeControl = true;
                end
            catch ME
                % Warn user that time control wasn't supported
                warning(ME.identifier,ME.message);
            end
            
            % Initialize board
            FENstr = PGNinfo.startpos;
            this.InitializeBoard(FENstr);
            
            % Perform moves
            for i = 1:Nmoves
                % If move is empty
                if isempty(SANstrs{i})
                    % Skip to next move
                    continue;
                end
                
                % Parse move
                [fromi fromj toi toj pID] = ...
                          Move.ParseSAN(SANstrs{i},this.BS,this.turnColor);
                
                % Perform move
                mateFlag = (i == Nmoves);
                this.FastMove(fromi,fromj,toi,toj,pID,mateFlag);
            end
            
            % Go to user's desired position
            if (Nmoves > 0)
                if strcmpi(startAt,'beginning')
                    % Undo all moves
                    this.UndoAllMoves(false);
                elseif strcmpi(startAt,'end')
                    % Handle game over scenarios
                    eog = this.HandleGameOverScenarios();
                    
                    % Handle draws/resignations
                    if (eog == false)
                        outcome = PGNinfo.outcome;
                        if strcmp(outcome,'1/2-1/2')
                            % Game ended in a draw
                            winningColor = ChessPiece.DRAW;
                            this.GameOver(winningColor,'Draw...');
                        elseif strcmp(outcome,'1-0')
                            % Black resigned
                            winningColor = ChessPiece.WHITE;
                            this.GameOver(winningColor,'Black resigns...');
                        elseif strcmp(outcome,'0-1')
                            % White resigned
                            winningColor = ChessPiece.BLACK;
                            this.GameOver(winningColor,'White resigns...');
                        end
                    end
                end
            end
            
            % Close loading dialog box
            this.CloseDialogBox(ldh);
            
            % Update GUI
            this.UpdateGUI();
            
            % If in edit mode
            if (this.gameplayMode == ChessMaster.EDIT)
                % Update BoardEditor
                this.BE.UpdatePosition();
            elseif (this.enablePopups == true)
                % If any engines are installed
                if ~isempty(this.engines.list)
                    try
                        % Spawn game analyzer
                        this.SpawnGameAnalyzer('pos',GApos);
                    catch %#ok
                        % Graceful exit
                    end
                end
                
                try
                    % Spawn move list
                    this.SpawnMoveList('pos',MLpos);
                catch %#ok
                    % Graceful exit
                end
            end
            
            % If time control exists
            if (isTimeControl == true)
                % Spawn chess clock
                times = [PGNinfo.moves.time]; % Clock times
                this.SpawnChessClock(tcStr,times,'pos',TCpos);
            end
        end
        
        %
        % Write curent game to PGN file
        %
        function WritePGN(this,path)
            % Flush graphics
            this.FlushGraphics();
            
            % If no path was specified
            if ((nargin < 2) || isempty(path))
                % Ask the user what file to save to
                path = inputdlg({['Enter a path (plus extension) for ' ...
                                  'the output pgn file:']}, ...
                                  'Save game to file',1, ...
                                 {'./game.pgn'},'on');
                drawnow; % Hack to avoid MATLAB freeze + crash
                
                % Make sure user didn't press cancel
                if isempty(path)
                    % Quick return
                    return;
                end
                path = path{1};
            end
            
            % Parse starting position
            if (this.BS.startPos.isStdStartPos == true)
                % Standard starting position
                startPosTags = '';
            else
                % Record custom starting position
                FENstr = this.BS.startPos.FENstr;
                startPosTags = sprintf(['[SetUp "1"]\n' ...
                                        '[FEN "%s"]\n'],FENstr);
            end
            
            % Parse winner
            switch this.winner
                case ChessPiece.WHITE
                    % White won
                    outcome = '1-0';
                case ChessPiece.BLACK
                    % Black won
                    outcome = '0-1';
                case ChessPiece.DRAW
                    % Game was drawn
                    outcome = '1/2-1/2';
                otherwise
                    % Game is still in progress
                    outcome = '*';
            end

            % Get game data
            Nmoves = this.BS.currentMove;
            moves = {this.BS.moveList(1:Nmoves).SANstr};
            [tcStr times] = this.GetClockData();
            Ntimes = length(times);
            
            % Open file
            fid = fopen(path,'w');
            
            % Construct preamble
            fprintf(fid,['[Event "?"]\n' ...
                         '[Site "%s v%s"]\n' ...
                         '[Date "%s"]\n' ...
                         '[Round "-"]\n', ...
                         '[White "%s"]\n', ...
                         '[Black "%s"]\n', ...
                          startPosTags, ...
                         '[Result "%s"]\n', ...
                         '[TimeControl "%s"]\n', ...
                         '[PlyCount "%i"]\n\n'], ...
                          this.version.name, ...
                          this.version.release, ...
                          datestr(date(),'yyyy.mm.dd'), ...
                          this.whiteName, ...
                          this.blackName, ...
                          outcome, ...
                          tcStr, ...
                          this.BS.currentMove);
            
            % Record moves/times
            lineLength = 65; % Approx. # characters per line
            line = '';
            for i = 1:2:Nmoves
                % Append turn number
                appendBite(sprintf('%i.',0.5 * (i + 1)));
                
                % Append white move
                appendBite(moves{i});
                
                % Append white time, if available
                if ((Ntimes >= i) && (times(i) >= 0))
                    appendBite(sec2clk(times(i)));
                end
                
                % If we haven't reached the end of the game
                if (i < Nmoves)
                    % Append black move
                    appendBite(moves{i + 1}); 

                    % Append black time, if available
                    if ((Ntimes >= (i + 1)) && (times(i + 1) >= 0))
                        appendBite(sec2clk(times(i + 1)));
                    end
                end
            end
            
            % Append game outcome
            if ~strcmp(outcome,'*')
                line = sprintf('%s%s',line,outcome);
            end
            
            % Print last line to file
            if ~isempty(line)
                fprintf(fid,'%s',line);
            end
            
            % Close file
            fclose(fid);
            
            %
            % Nested function: Append bite to line
            %
            function appendBite(bite)            
                % Append bite string
                line = sprintf('%s%s ',line,bite);
                
                % If line is long enough
                if (length(line) >= lineLength)
                    % Append line to file
                    fprintf(fid,'%s\n',line);
                    line = '';
                end
            end
            
            %
            % Nested function: Construct clock time comment
            %
            function clk = sec2clk(time)
                % Convert to pretty time string
                timeStr = ChessClock.PrettyTime(time);
                
                % Generate comment
                clk = sprintf('{[%%clk %s]}',timeStr);
            end
        end
        
        %
        % Create dialog box with given string
        %
        function ldh = DialogBox(this,str)
            % Dialog box dimensions
            dim = [220 30];
            
            % Create centered dialog box
            xyc = this.GetCenterCoordinates();
            ldh = dialog('WindowStyle','Modal', ...
                         'Name',this.version.name, ...
                         'Position',[(xyc - 0.5 * dim) dim]);
            
            % Add loading text
            uicontrol(ldh,'Style','text', ...
                          'String',str, ...
                          'Units','Normalized', ...
                          'Position',[0.1 0 0.8 0.8]);
            
            % Flush graphics
            this.FlushGraphics();
        end
        
        %
        % Close dialog box
        %
        function CloseDialogBox(this,dh) %#ok
            try
                % Delete the figure
                delete(dh);
            catch %#ok
                % Graceful exit
            end
        end
        
        %
        % Toggle turn color
        %
        function ToggleTurnColor(this)
            % Toggle turn color
            this.turnColor = ChessPiece.Toggle(this.turnColor);
        end
        
        %
        % Handle game over
        %
        function GameOver(this,winner,str)
            % Set game state
            this.winner = winner;
            this.isGameOver = true;
            
            % Stop chess timer, if necessary
            if ~isempty(this.CC)
                this.CC.StopTimer();
            end
            
            % Update GUI
            this.UpdateGUI();
            
            % Update engine states
            this.UpdateEngineStates();
            
            % Update game analyzer state
            this.UpdateGameAnalyzerState();
            
            % Flush graphics
            this.FlushGraphics();
            
            % If popup dialogs aren't enabled
            if (this.enablePopups == false)
                % Quick return
                return;
            end
            
            % Parse winner
            switch this.winner
                case ChessPiece.WHITE
                    % White won
                    str = [str ' White wins!'];
                case ChessPiece.BLACK
                    % Black won
                    str = [str ' Black wins!'];
            end
            
            % Ask user what to do
            selection = questdlg([str ' Play again?'], ...
                                 this.version.name,'Yes','No','Yes');
            drawnow; % Hack to avoid MATLAB freeze + crash
            
            % Handle user selection
            switch selection
                case 'Yes'
                    % Reset board
                    this.ResetBoard();
                case 'No'
                    % If any engines are installed
                    if ~isempty(this.engines.list)
                        try
                            % Spawn game analyzer
                            this.SpawnGameAnalyzer();
                        catch %#ok
                            % Graceful exit
                        end
                    end
                    
                    try
                        % Spawn move list
                        this.SpawnMoveList();
                    catch %#ok
                        % Graceful exit
                    end
            end
        end
        
        %
        % Manage engine list
        %
        function ManageEngines(this)
            % Spawn an engine manager
            elements = {this.engines.list.name};
            initVal = double(~isempty(elements));
            name = 'Engine Manager';
            xyc = this.GetCenterCoordinates();
            [names idx] = MutableList.Instance(elements,initVal,name,xyc);
            
            % If selection wasn't cancelled
            if ~isempty(idx)
                % Update engine list
                [~,inds] = ismember(names,elements);
                this.engines.list = this.engines.list(inds);
                
                % Update current engine index
                this.engines.idx = sum(find(inds == this.engines.idx));
            end
        end
        
        %
        % Add an external engine to engine list
        %
        function AddEngine(this)
            % Get engine name/path from user
            strs = {'UCI Engine (Windows)', ...
                    './engines/UCIengine.exe'};
            response = inputdlg({'Name','Path'},'Add UCI Engine', ...
                                [1 50],strs);
            drawnow; % Hack to avoid MATLAB freeze + crash
            
            % Process user responses
            if ~isempty(response)
                name = response{1};
                path = response{2};
                try
                    % Attempt a connection with the specified engine
                    delete(EngineInterface([],path,'',1,false));
                    
                    % The connection succeeded, so save the engine
                    idx = find(ismember({this.engines.list.name},name));
                    if isempty(idx)
                        % Append engine to list
                        idx = length(this.engines.list) + 1;
                    end
                    this.engines.list(idx).name = name;
                    this.engines.list(idx).path = path;
                catch ME
                    % Show the orginal error as a warning
                    warning(ME.identifier,ME.message);
                    
                    % Warn the user know that engine addition failed
                    msgid = 'CM:ADDENGINE:FAIL';
                    msg = '\n\n*** Unable to connect to engine "%s" ***\n';
                    warning(msgid,msg,path);
                end
            end
        end
        
        %
        % Update engine states
        %
        function UpdateEngineStates(this)
            % Loop over active engines
            for i = 1:length(this.CElist)
                % Update engine state
                this.CElist(i).UpdateEngineState();
            end
        end
        
        %
        % Update analysis engine states
        %
        function UpdateAnalysisEngines(this)
            % Loop over active engines
            for i = 1:length(this.CElist)
                % Update analysis engine state
                this.CElist(i).StopAnalysisEngine();
            end
        end
        
        %
        % Turn off engine autoplay for current color
        %
        function TurnOffEngineAutoPlay(this,color)
            % Loop over active engines
            for i = 1:length(this.CElist)
                % Turn-off autoplay for given color
                this.CElist(i).TurnOffAutoPlay(color);
            end
        end
        
        %
        % Get time control string
        %
        function [tcStr times] = GetClockData(this)
            % If a chess clock exists
            if ~isempty(this.CC)
                % Get clock data
                [tcStr times] = this.CC.GetClockData();
            else
                % Unknown time control
                tcStr = '?';
                times = [];
            end
        end
        
        %
        % Reset chess clock
        %
        function ResetChessClock(this)
            % If a chess clock exists
            if ~isempty(this.CC)
                % Reset clock
                this.CC.Reset();
            end
        end
        
        %
        % Close chess clock
        %
        function CloseChessClock(this)
            % If a chess clock exists
            if ~isempty(this.CC)
                % Close clock
                this.CC.Close();
            end
        end
        
        %
        % Reset all engines
        %
        function ResetEngines(this)
            % Loop over engines
            for i = length(this.CElist):-1:1
                % Reset engine
                this.CElist(i).Reset();
            end
            
            % Let analysis engines continue to think
            this.EngineAutoPlay();
        end
        
        %
        % Close all engines
        %
        function CloseEngines(this)
            % Loop over engines
            for i = length(this.CElist):-1:1
                % Close engine
                this.CElist(i).Close();
            end
        end
        
        %
        % Reset move list
        %
        function ResetMoveList(this)
            % If a move list exists
            if ~isempty(this.ML)
                % Reset the list
                this.ML.Reset();
            end
        end
        
        %
        % Close move list
        %
        function CloseMoveList(this)
            % If a move list exists
            if ~isempty(this.ML)
                % Close the list
                this.ML.Close();
            end
        end
        
        %
        % Tell GameAnalyzer about current game state
        %
        function UpdateGameAnalyzerState(this)
            % If a GameAnalyzer exists
            if ~isempty(this.GA)
                % Update GameAnalyzer based on current game state
                this.GA.HandleGameState();
            end
        end
        
        %
        % Reset game analyzer
        %
        function ResetGameAnalyzer(this)
            % If a game analyzer exists
            if ~isempty(this.GA)
                % Reset the analyzer
                this.GA.Reset();
            end
        end
        
        %
        % Close game analyzer
        %
        function CloseGameAnalyzer(this)
            % If a game analyzer exists
            if ~isempty(this.GA)
                % Close the analyzer
                this.GA.Close();
            end
        end
        
        %
        % Initialize board
        %
        function success = InitializeBoard(this,FENstr,saveFlag)
        % Syntax:   success = InitializeBoard(this);
        %           success = InitializeBoard(this,FENstr);
        %           success = InitializeBoard(this,FENstr,saveFlag);
        
            % Parse inputs
            if (nargin < 2)
                FENstr = '';
            end
            if (nargin < 3)
                saveFlag = true;
            end
            
            % Reset board state
            success = this.BS.Reset(FENstr);
            if (success == false)
                % Invalid FEN
                return;
            end
            
            % Release locks
            this.alock = false;
            this.block = false;
            this.elock = false;
            this.glock = false;
            this.mlock = false;
            
            % Reset state
            this.isGameOver = false;
            this.winner = ChessPiece.NULL;
            
            % Stop piece movement timer, if necessary
            if strcmpi(this.ptimer.Running,'on')
                stop(this.ptimer);
            end
            
            % Get starting position info
            state = this.BS.startPos.state;
            ID = bitand(state,7); % Extract piece IDs
            color = ChessPiece.WHITE * ones(8); % Extract piece colors
            color(logical(bitget(state,8))) = ChessPiece.BLACK;
            
            % Set turn color
            if (this.turnColor ~= this.BS.startPos.colorToMove)
                this.ToggleTurnColor();
            end
            
            % Insert pieces
            [files ranks] = find(ID ~= 0);
            for idx = 1:length(files)
                % Insert piece
                i = files(idx);
                j = ranks(idx);
                this.InsertPiece(ID(i,j),color(i,j),i,j);
            end
            
            % Update checks
            this.BS.UpdateChecks();
            
            % Update mate status
            this.BS.UpdateMateStatus(this.turnColor);
            
            % Update board editor
            this.UpdateBoardEditor(saveFlag);
            
            % Update GUI
            this.UpdateGUI();
            
            % Reset chess clock
            this.ResetChessClock();
            
            % Reset move list
            this.ResetMoveList();
            
            % Reset game analyzer
            this.ResetGameAnalyzer();
            
            % Reset engines
            this.ResetEngines();
            
            % Handle game over scenarios
            this.HandleGameOverScenarios();
        end
        
        %
        % Insert piece
        %
        function piece = InsertPiece(this,ID,color,i,j)
            % Create piece
            piece = this.CreatePiece(ID,color);
            
            % Assign board location
            piece.AssignPiece(i,j);
        end
        
        %
        % Create piece
        %
        function piece = CreatePiece(this,ID,color)
            % Process based on piece ID
            switch ID
                case Pawn.ID
                    % Create pawn
                    piece = Pawn(this.ax(2),this.BS,color,this.BG.CPD);
                case Knight.ID
                    % Create knight
                    piece = Knight(this.ax(2),this.BS,color,this.BG.CPD);
                case Bishop.ID
                    % Create bishop
                    piece = Bishop(this.ax(2),this.BS,color,this.BG.CPD);
                case Rook.ID
                    % Create rook
                    piece = Rook(this.ax(2),this.BS,color,this.BG.CPD);
                case Queen.ID
                    % Create queen
                    piece = Queen(this.ax(2),this.BS,color,this.BG.CPD);
                case King.ID
                    % Create king
                    piece = King(this.ax(2),this.BS,color,this.BG.CPD);
                otherwise
                    % Invalid piece ID
                    piece = nan;
            end
        end
        
        %
        % Initialize GUI
        %
        function InitializeGUI(this,xyc,dim)
            % Figure
            this.fig = figure('MenuBar','None', ...
                           'NumberTitle','off', ...
                           'DockControl','off', ...
                           'name',this.version.name, ...
                           'tag',this.tag, ...
                           'Position',[(xyc - 0.5 * dim) dim dim], ...
                           'PaperPositionMode','auto', ...
                           'RendererMode','manual', ...
                           'Renderer','opengl', ...
                           'Resize','on', ...
                           'ResizeFcn',@(s,e)DrawBoard(this), ...
                           'WindowButtonDownFcn',@(s,e)MouseDown(this), ...
                           'WindowButtonUpFcn',@(s,e)MouseUp(this), ...
                           'KeyPressFcn',@(s,e)HandleKeyPress(this,e), ...
                           'CloseRequestFcn',@(s,e)Close(this), ...
                           'Interruptible','off', ...
                           'Visible','off');
            
            % Menus
            gamem = uimenu(this.fig,'Label','Game');
            uimenu(gamem,'Label','Preferences', ...
                              'Callback',@(s,e)SpawnChessOptions(this), ...
                              'Accelerator','P');
            uimenu(gamem,'Label','New Game', ...
                              'Callback',@(s,e)ResetBoard(this), ...
                              'Separator','on', ...
                              'Accelerator','N');
            uimenu(gamem,'Label','Open Game', ...
                              'Callback',@(s,e)ReadPGN(this), ...
                              'Accelerator','O');
            uimenu(gamem,'Label','Save Game', ...
                              'Callback',@(s,e)WritePGN(this), ...
                              'Accelerator','S');
            uimenu(gamem,'Label','Load Position...', ...
                              'Callback',@(s,e)LoadPosition(this), ...
                              'Separator','on');
            uimenu(gamem,'Label','Edit Position...', ...
                              'Callback',@(s,e)SpawnBoardEditor(this));
            this.mlh = uimenu(gamem,'Label','Move List', ...
                              'Callback',@(s,e)SpawnMoveList(this), ...
                              'Separator','on', ...
                              'Accelerator','L');
            this.tch = uimenu(gamem,'Label','Time Control', ...
                          'Callback',@(s,e)SpawnChessClock(this,'',[]), ...
                              'Accelerator','T');
            uimenu(gamem,'Label','Close', ...
                              'Callback',@(s,e)Close(this), ...
                              'Separator','on', ...
                              'Accelerator','W');
            boardm = uimenu(this.fig,'Label','Board');
            uimenu(boardm,'Label','Refresh Board', ...
                              'Callback',@(s,e)RefreshBoard(this), ...
                              'Accelerator','R');
            uimenu(boardm,'Label','Flip Board', ...
                              'Callback',@(s,e)FlipBoard(this), ...
                              'Accelerator','F');
            uimenu(boardm,'Label','Change Theme...', ...
                              'Callback',@(s,e)ChangeTheme(this), ...
                              'Separator','on');
            uimenu(boardm,'Label','Edit Theme...', ...
                              'Callback',@(s,e)SpawnThemeEditor(this));
            uimenu(boardm,'Label','Screenshot...', ...
                              'Callback',@(s,e)TakeScreenshot(this), ...
                              'Separator','on');
            enginem = uimenu(this.fig,'Label','Engine');   
            uimenu(enginem,'Label','New Engine', ...
                              'Callback',@(s,e)SpawnChessEngine(this), ...
                              'Accelerator','E');
            this.gah = uimenu(enginem,'Label','Analyze Game', ...
                              'Callback',@(s,e)SpawnGameAnalyzer(this), ...
                              'Accelerator','A');
            uimenu(enginem,'Label','Manage Engines...', ...
                              'Callback',@(s,e)ManageEngines(this), ...
                              'Separator','on');
            uimenu(enginem,'Label','Add Engine...', ...
                              'Callback',@(s,e)AddEngine(this));
            undom = uimenu(this.fig,'Label','Undo'); 
            this.undoh = uimenu(undom,'Callback',@(s,e)Undo(this), ...
                              'Accelerator','Z');
            this.undoallh = uimenu(undom,'Label','Undo All', ...
                              'Callback',@(s,e)UndoAll(this), ...
                              'Accelerator','X');
            redom = uimenu(this.fig,'Label','Redo');
            this.redoh = uimenu(redom,'Callback',@(s,e)Redo(this), ...
                              'Accelerator','Y');
            this.redoallh = uimenu(redom,'Label','Redo All', ...
                              'Callback',@(s,e)RedoAll(this), ...
                              'Accelerator','V');
            drawm = uimenu(this.fig,'Label','Draw');     
            this.drawh1 = uimenu(drawm,'Label','Offer Draw', ...
                              'Callback',@(s,e)OfferDraw(this), ...
                              'Accelerator','D');
            this.drawh2 = uimenu(drawm,'Label','Fifty-Move Rule', ...
                              'Callback',@(s,e)FiftyMovesDraw(this), ...
                              'Separator','on');
            this.drawh3 = uimenu(drawm,'Label','Threefold Repetition', ...
                              'Callback',@(s,e)Rep3FoldDraw(this));
            resignm = uimenu(this.fig,'Label','Resign');
            this.resignh = uimenu(resignm,'Label','Resign', ...
                              'Callback',@(s,e)Resign(this), ...
                              'Accelerator','B');
            helpm = uimenu(this.fig,'Label','Help');
            uimenu(helpm,'Label','Help...', ...
                              'Callback',@(s,e)SpawnHelpWindow(this));
            uimenu(helpm,'Label','About', ...
                              'Separator','on', ...
                              'Callback',@(s,e)SpawnAboutWindow(this));
            this.movewh = uimenu(this.fig,'Label','W:      ', ...
                              'Enable','off');
            this.movebh = uimenu(this.fig,'Label','B:      ', ...
                              'Enable','off');
            this.statush = uimenu(this.fig,'Enable','off', ...
                              'Visible','off');
            %--------------------------------------------------------------
            
            % Board axis
            this.ax(1) = axes('Position',[0 0 1 1]);
            set(this.ax(1),'DrawMode','fast');
            axis(this.ax(1),'off');
            hold(this.ax(1),'on');
            this.bh = image(0,'Parent',this.ax(1));
            
            % Piece axis
            this.ax(2) = axes('Position',[0 0 1 1]);
            set(this.ax(2),'DrawMode','fast');
            axis(this.ax(2),'off');
            hold(this.ax(2),'on');
            
            % Check axis
            this.ax(3) = axes('Position',[0 0 1 1]);
            set(this.ax(3),'DrawMode','fast');
            axis(this.ax(3),'off');
            hold(this.ax(3),'on');
            
            % Order axes
            uistack(this.ax(2),'bottom');
            uistack(this.ax(1),'bottom');
            
            % File/rank labels
            for i = 1:8
                for j = 1:2
                    % File labels
                    this.filetexth(i,j) = text('Parent',this.ax(1), ...
                                        'FontUnits','pixels', ...
                                        'FontWeight','normal', ...
                                        'HorizontalAlignment','center', ...
                                        'VerticalAlignment','middle', ...
                                        'Visible','off');
                    
                    % Rank labels
                    this.ranktexth(i,j) = text('Parent',this.ax(1), ...
                                        'FontUnits','pixels', ...
                                        'FontWeight','normal', ...
                                        'HorizontalAlignment','center', ...
                                        'VerticalAlignment','middle', ...
                                        'Visible','off');
                end
            end
            
            % Check text
            this.checkh = text(1,1,'','FontUnits','pixels', ...
                                      'FontWeight','bold', ...
                                      'HorizontalAlignment','center', ...
                                      'VerticalAlignment','middle', ...
                                      'Parent',this.ax(3), ...
                                      'Visible','off');
            
            % Square highlights
            this.CHf = ChessHighlight(this.ax(1),this.BS);
            this.CHt = ChessHighlight(this.ax(1),this.BS);
            this.CHc = ChessHighlight(this.ax(1),this.BS);
            
            % Turn marker
            this.markerh = rectangle('Curvature',[0.4 0.4], ...
                                     'Parent',this.ax(1), ...
                                     'Visible','off');
            
            % Draw board
            this.currentColor = this.themes.color(this.themes.ID);
            this.DrawBoard();
            
            % Initialize board
            this.InitializeBoard();
            
            % Make GUI visible
            set(this.fig,'Visible','on');
            
            % Add figure to FigureManager
            this.FM.AddFigure(this.fig);
        end
        
        %
        % Draw board
        %
        function DrawBoard(this)            
            % Get figure position
            pos = get(this.fig,'Position');
            xyc = pos(1:2) + 0.5 * pos(3:4);
            targetDim = mean(pos(3:4));
            
            % Set board geometry
            this.BG.SetBoardGeometry(targetDim);
            
            % Update axes
            axis(this.ax,this.BG.axLim);
        	
            % Update file/rank labels
            fpos = @(i,j) [this.BG.filec(i) this.BG.rank_textc(j)];
            rpos = @(i,j) [this.BG.file_textc(j) this.BG.rankc(i)];
            for i = 1:8
                for j = 1:2
                    set(this.filetexth(i,j),'FontSize',this.BG.bfont, ...
                                            'Position',fpos(i,j));
                    set(this.ranktexth(i,j),'FontSize',this.BG.bfont, ...
                                            'Position',rpos(i,j));
                end
            end
            
            % Paint board
            this.PaintBoard();
            
            % Refresh board
            this.RefreshBoard();
            
            % Set figure position
            dim = this.BG.boardDim * [1 1];
            set(this.fig,'Position',[(xyc - 0.5 * dim) dim]);
        end
        
        %
        % Let user pick new board theme
        %
        function ChangeTheme(this)
            % Delete any existing ThemeEditor
            this.FM.CloseFigs('ThemeEditor');
            
            % Spawn a theme manager
            elements = {this.themes.color.name};
            initVal = this.themes.ID;
            name = 'Theme Manager';
            xyc = this.GetCenterCoordinates();
            [names idx] = MutableList.Instance(elements,initVal,name,xyc);
            
            % If cancel wasn't selected
            if ~isempty(idx)
                if isempty(names)
                    % Retain current theme
                    this.themes.color = this.themes.color(this.themes.ID);
                    this.themes.ID = 1;
                else
                    % Apply user changes
                    [~,inds] = ismember(names,elements);
                    this.themes.color = this.themes.color(inds);
                    
                    % Set board theme
                    this.SetBoardTheme(idx);
                end
            end
        end
        
        %
        % Set board theme
        %
        function SetBoardTheme(this,idx)
            % Set theme ID
            this.themes.ID = idx;
            
            % Paint board
            color = this.themes.color(idx);
            this.PaintBoard(color);
        end
        
        %
        % Take screenshot of current board
        %
        function TakeScreenshot(this)
            % Construct unique default filename
            ext = '.png';
            str = ['./board_' regexprep(date(),'-','')];
            len = length(str);
            str = [str ext];
            num = 1;
            while (exist(str,'file') == 2)
                num = num + 1;
                str = [str(1:len) '_' num2str(num) ext];
            end
            
            % Ask the user for a filename
            path = inputdlg({['Enter a path (plus extension) for the ' ...
                              'screenshot:']}, ...
                              'Take a screenshot',1, ...
                              {str},'on');
            drawnow; % Hack to avoid MATLAB freeze + crash
            
            % Make sure the user didn't press cancel
            if ~isempty(path)
                % Take the screenshot
                saveas(this.fig,path{1});
            end
        end
        
        %
        % Set gamplay mode
        %
        function SetGameplayMode(this,gameplayMode)
            % If no change is required
            if (gameplayMode == this.gameplayMode)
                % Quick return
                return;
            end
            
            % Set gameplay mode
            this.gameplayMode = gameplayMode;
            this.BS.ClearEditList();
            
            % Process based on gameplay mode
            switch gameplayMode
                case ChessMaster.LEGAL
                    % Switch to legal mode
                    this.UpdateGUI();
                    
                    % Handle game over scenarios
                    this.HandleGameOverScenarios();
                case ChessMaster.EDIT
                    % Switch to edit mode
                    this.LoadPosition(this.GetFENstr());
            end
        end
        
        %
        % Update board editor
        %
        function UpdateBoardEditor(this,saveFlag)
        % Syntax:   UpdateBoardEditor(this);
        %           UpdateBoardEditor(this,saveFlag);
        
            % Make sure board editor exists
            if isempty(this.BE)
                % Quick return
                return;
            end
            
            % Update BoardEditor GUI
            FENstr = this.GetFENstr();
            this.BE.UpdateSetupPanel(FENstr);
            
            % If no move save is requested
            if ((nargin >= 2) && (saveFlag == false))
                % Quick return
                return;
            end
            
            % Record edit
            this.BS.RecordEdit(FENstr);
        end
        
        %
        % Update GUI state based on the current board position
        %
        function UpdateGUI(this)
            % Get current move index
            currMove = this.BS.currentMove;
            
            % Update square highlights
            if ((currMove == 0) || (this.isGameOver == true))
                % No last-move highlights
                this.CHf.Off();
                this.CHt.Off();
            else
                % Highlight last move locations
                move = this.BS.moveList(currMove);
                this.CHf.SetLocation(move.fromi,move.fromj);
                this.CHt.SetLocation(move.toi,move.toj);
            end
            this.ClearSquareSelection();
            
            % Update check text
            this.UpdateCheckText();
            
            % Update turn marker
            this.UpdateTurnMarker();
            
            % Update undo/redo menus
            this.UpdateUndoRedoMenus();
            
            % Update draw/resign menus
            this.UpdateDrawResignMenus();
            
            % Update last move menu
            this.UpdateLastMoveMenu();
            
            % Update status menu
            this.UpdateStatusMenu();
            
            % Set chess clock state, if necessary
            if ~isempty(this.CC)
                this.CC.SetClockState(currMove);
            end
            
            % Set analyzer move label position, if necessary
            if ~isempty(this.GA)
                this.GA.SetMoveLabelPosition(currMove);
            end
            
            % Flush graphics
            this.FlushGraphics();
            
            % Update move list, if necessary
            if ~isempty(this.ML)
                this.ML.SetPosition(currMove);
            end
        end
        
        %
        % Update check text
        %
        function UpdateCheckText(this)
            % If check text isn't allowed
            if (this.enableCheckText == false)
                % Turn off check text
                set(this.checkh,'Visible','off');
                return;
            end
            
            % Get check text
            activeColor = this.turnColor;
            opposingColor = ChessPiece.Toggle(activeColor);
            vis = 'on';
            if (this.BS.GetCheckStatus(opposingColor) == true)
                % Illegal position
                str = 'ILLEGAL';
                king = this.BS.KingOfColor(opposingColor);
            else
                % Process based on mate status
                switch this.BS.GetMateStatus(activeColor)
                    case BoardState.CHECKMATE
                        % Checkmate
                        str = 'CHECKMATE';
                    case BoardState.STALEMATE
                        % Stalemate
                        str = 'STALEMATE';
                    otherwise
                        % No mates
                        if (this.BS.GetCheckStatus(activeColor) == true)
                            % Active color in check
                            str = 'CHECK';
                        else
                            % No checks
                            str = '';
                            vis = 'off';
                        end
                end
                
                % Get king handle
                king = this.BS.KingOfColor(activeColor);
            end
            
            % If king exists
            if ~isnan(king)
                % Update text position
                dy = this.BG.squareSize / 6; % 1/6th of square
                sgn = 2 * this.BS.flipped - 1; % Orientation-based sign
                x = this.BG.filec(king.i);
                y = this.BG.rankc(king.j) + sgn * dy;
                pos = [x y];
            else
                % No king
                pos = [0 0];
                vis = 'off';
            end
            
            % Update check text
            set(this.checkh,'Position',pos, ...
                            'String',str, ...
                            'FontSize',this.BG.cfont, ...
                            'Visible',vis);
        end
        
        %
        % Update turn marker
        %
        function UpdateTurnMarker(this)
            % Update coordinates
            b = this.BS.flipped; % board orientation flag
            switch this.turnColor
                case ChessPiece.WHITE
                    % White's turn
                    pos = this.BG.tcpos_white(b + 1,:);
                case ChessPiece.BLACK
                    % Black's turn
                    pos = this.BG.tcpos_black(b + 1,:);
                otherwise
                    % Don't change
                    pos = get(this.markerh,'Position');
            end
            
            % Update visibility
            if (~this.enableTurnMarker || this.isGameOver)
                % Turn off marker
                vis = 'off';
            else
                % Turn on marker
                vis = 'on';
            end
            
            % Update turn marker
            set(this.markerh,'Position',pos','Visible',vis);
        end
        
        %
        % Update undo/redo menus
        %
        function UpdateUndoRedoMenus(this)
            % Get position index
            switch this.gameplayMode
                case ChessMaster.LEGAL
                    % Legal moves mode
                    posIdx = this.BS.currentMove;
                    Npos = length(this.BS.moveList);
                case ChessMaster.EDIT
                    % Edit mode
                    posIdx = this.BS.currentEdit - 1;
                    Npos = length(this.BS.editList) - 1;
            end
            
            % Handle gameplay mode
            switch this.gameplayMode
                case ChessMaster.LEGAL
                    % Legal mode
                    undoLabel = 'Undo Move';
                    redoLabel = 'Redo Move';
                case ChessMaster.EDIT
                    % Edit mode
                    undoLabel = 'Undo Edit';
                    redoLabel = 'Redo Edit';
            end
            
            % Update undo menu
            if (posIdx == 0)
                % No undos allowed
                set(this.undoh,'Enable','off','Label',undoLabel);
                set(this.undoallh,'Enable','off');
            else
                % Undos allowed
                set(this.undoh,'Enable','on','Label',undoLabel);
                set(this.undoallh,'Enable','on');
            end
            
            % Update redo menu
            if (posIdx == Npos)
                % No redos allowed
                set(this.redoh,'Enable','off','Label',redoLabel);
                set(this.redoallh,'Enable','off');
            else
                % Redos allowed
                set(this.redoh,'Enable','on','Label',redoLabel);
                set(this.redoallh,'Enable','on');
            end
        end
        
        %
        % Update draw/resign menus
        %
        function UpdateDrawResignMenus(this)
            % Check game status
            if ((this.gameplayMode == ChessMaster.EDIT) || ...
                (this.isGameOver == true))
                % Don't allow draw offers or resignations
                set(this.drawh1,'Enable','off');
                set(this.drawh2,'Enable','off');
                set(this.drawh3,'Enable','off');
                set(this.resignh,'Enable','off');
            else
                % Allow draws/resignations
                set(this.drawh1,'Enable','on');
                set(this.resignh,'Enable','on');
                
                % If >= 50 turns since last pawn movement or capture
                if (this.BS.GetReversibleMoves() >= 100)
                    % Can claim fifty-move rule
                    set(this.drawh2,'Enable','on');
                else
                    % Cannot claim fifty-move rule
                    set(this.drawh2,'Enable','off');
                end
                
                % If current state has been repeated 3x without progress
                if (this.BS.Is3FoldRep() == true)
                    % Threefold repetition has just occured
                    set(this.drawh3,'Enable','on');
                else
                    % Cannot claim threefold repetition draw
                    set(this.drawh3,'Enable','off');
                end
            end
        end
        
        %
        % Update last move menu
        %
        function UpdateLastMoveMenu(this)
            % Process based on turn color
            switch this.turnColor
                case ChessPiece.WHITE
                    % Currently white's turn
                    widx = this.BS.currentMove - 1;
                    bidx = this.BS.currentMove;
                case ChessPiece.BLACK
                    % Currently black's turn
                    widx = this.BS.currentMove;
                    bidx = this.BS.currentMove - 1;
            end
            
            % Update last white move
            if (widx > 0)
                % Get last move's SAN
                wSANstr = this.BS.moveList(widx).SANstr;
            else
                % Empty string
                wSANstr = '     ';
            end
            set(this.movewh,'Label',['W: ' wSANstr]);
            
            % Update last black move
            if (bidx > 0)
                % Get last move's SAN
                bSANstr = this.BS.moveList(bidx).SANstr;
            else
                % Empty string
                bSANstr = '     ';
            end
            set(this.movebh,'Label',['B: ' bSANstr]);
            
            % Update menu visibility
            if ((this.enableLastMoveMenu == true) && ...
                (this.gameplayMode ~= ChessMaster.EDIT))
                set(this.movewh,'Visible','on');
                set(this.movebh,'Visible','on');
            else
                set(this.movewh,'Visible','off');
                set(this.movebh,'Visible','off');
            end
        end
        
        %
        % Update status menu
        %
        function UpdateStatusMenu(this)
            % If check text isn't allowed
            if (this.enableStatusMenu == false)
                % Turn off status menu
                set(this.statush,'Visible','off');
                return;
            end
            
            % Process based on game status
            if (this.gameplayMode == ChessMaster.EDIT)
                % Editing mode
                label = 'EDITING';
                vis = 'on';
            elseif (this.isGameOver == true)
                % Game over
                label = 'GAMEOVER';
                vis = 'on';
            else
                % No status
                label = '';
                vis = 'off';
            end
            
            % Update status menu
            set(this.statush,'Label',label,'Visible',vis);
        end
        
        %
        % Spawn chess engine GUI
        %
        function SpawnChessEngine(this,xyc)
            % Spawn new ChessEngine object
            etag = 'ChessEngine';
            if ((nargin < 2) || isempty(xyc))
                xyc = this.GetCenterCoordinates();
            end
            CE = ChessEngine(this,this.engines,etag,xyc);
            
            % Save to engine list
            this.CElist(end + 1) = CE;
            
            % Add figure to FigureManager
            this.FM.AddFigure(CE.fig);
        end
        
        %
        % Spawn chess options GUI
        %
        function SpawnChessOptions(this,xyc)
            % Spawn a ChessOptions GUI
            if ((nargin < 2) || isempty(xyc))
                xyc = this.GetCenterCoordinates();
            end
            figh = this.CO.OpenGUI(xyc);
            
            % If ChessOptions GUI didn't already exist
            if ~isempty(figh)
                % Add figure to FigureManager
                this.FM.AddFigure(figh);
            end
        end
        
        %
        % Spawn chess clock
        %
        function SpawnChessClock(this,tcStr,times,varargin)
            % If ChessClocks are disabled
            if (this.enableChessClock == false)
                % Quick return
                return;
            end
            
            % Get handle to existing ChessClock
            ctag = 'ChessClock';
            figh = this.FM.GetFigHandle(ctag);
            if ~isempty(figh)
                % Give focus to the existing ChessClock
                figure(figh(1));
                return;
            end
            
            % Spawn a ChessClock GUI
            if (isempty(varargin) || isempty(varargin{2}))
                % Spawn GUI centered on ChessMaster figure
                args = {'xyc',this.GetCenterCoordinates()};
            else
                % Use supplied arguments
                args = varargin;
            end
            if isempty(tcStr)
                % Use default time control
                tcStr = this.defTimeControl;
            end
            this.CC = ChessClock(this,tcStr,times,ctag,args{:});
            
            % Add figure to FigureManager
            this.FM.AddFigure(this.CC.fig);
        end
        
        %
        % Spawn a move list
        %
        function SpawnMoveList(this,varargin)
            % If MoveLists are disabled
            if (this.enableMoveList == false)
                % Quick return
                return;
            end
            
            % Get handle to existing MoveList
            mtag = 'MoveList';
            figh = this.FM.GetFigHandle(mtag);
            if ~isempty(figh)
                % Give focus to the existing MoveList
                figure(figh(1));
                return;
            end
            
            % Spawn a MoveList GUI
            if (isempty(varargin) || isempty(varargin{2}))
                % Spawn GUI centered on ChessMaster figure
                args = {'xyc',this.GetCenterCoordinates()};
            else
                % Use supplied arguments
                args = varargin;
            end
            this.ML = MoveList(this,mtag,args{:});
            
            % Load current moves
            this.ML.AppendMoves({this.BS.moveList.SANstr},0);
            this.ML.SetPosition(this.BS.currentMove);
            
            % Add figure to FigureManager
            this.FM.AddFigure(this.ML.fig);
        end
        
        %
        % Spawn a game analyzer GUI
        %
        function SpawnGameAnalyzer(this,varargin)
            % If GameAnalzyers are disabled
            if (this.enableGameAnalyzer == false)
                % Quick return
                return;
            end
            
            % Get handle to existing GameAnalyzer
            gtag = 'GameAnalyzer';
            figh = this.FM.GetFigHandle(gtag);
            if ~isempty(figh)
                % Give focus to the existing GameAnalyzer
                figure(figh(1));
                return;
            end
            
            % Spawn a GameAnalyzer GUI
            if (isempty(varargin) || isempty(varargin{2}))
                % Spawn GUI centered on ChessMaster figure
                args = {'xyc',this.GetCenterCoordinates()};
            else
                % Use supplied arguments
                args = varargin;
            end
            this.GA = GameAnalyzer(this,this.engines,gtag,args{:});
            
            % Append current moves
            LANstrs = {this.BS.moveList.LANstr};
            SANstrs = {this.BS.moveList.SANstr};
            this.GA.AppendMoves(LANstrs,SANstrs,0);
            
            % Add figure to FigureManager
            this.FM.AddFigure(this.GA.fig);                
        end
        
        %
        % Spawn board position editor GUI
        %
        function SpawnBoardEditor(this,varargin)
            % If a BoardEditor already exists
            etag = 'BoardEditor';
            figh = this.FM.GetFigHandle(etag);
            if ~isempty(figh)
                % Give focus to the existing BoardEditor
                figure(figh(1));
                return;
            end
            
            % Spawn a BoardEditor GUI
            if (isempty(varargin) || isempty(varargin{2}))
                % Spawn GUI centered on ChessMaster figure
                args = {'xyc',this.GetCenterCoordinates()};
            else
                % Use supplied arguments
                args = varargin;
            end
            this.BE = BoardEditor(this,this.pieces,etag,args{:});
            this.BE.SetHighlightSprite(this.CHc.color);
            
            % Add figure to FigureManager
            this.FM.AddFigure(this.BE.fig);
            
            % Update gameplay mode
            this.SetGameplayMode(ChessMaster.EDIT);
        end
        
        %
        % Spawn board theme editor GUI
        %
        function SpawnThemeEditor(this,varargin)
            % If a ThemeEditor GUI already exists
            ttag = 'ThemeEditor';
            figh = this.FM.GetFigHandle(ttag);
            if ~isempty(figh)
                % Give focus to the existing ThemeEditor
                figure(figh(1));
                return;
            end
            
            % Spawn a ThemeEditor GUI based on current theme
            color = this.themes.color(this.themes.ID);
            if (isempty(varargin) || isempty(varargin{2}))
                % Spawn GUI centered on ChessMaster figure
                args = {'xyc',this.GetCenterCoordinates()};
            else
                % Use supplied arguments
                args = varargin;
            end
            TE = ThemeEditor(this,color,ttag,args{:});
            
            % Add figure to FigureManager
            this.FM.AddFigure(TE.fig);
        end
        
        %
        % Spawn help window
        %
        function SpawnHelpWindow(this,xyc)
            % If help window already exists
            htag = 'ChessMasterHelp';
            figh = this.FM.GetFigHandle(htag);
            if ~isempty(figh)
                % Give focus to existing help window
                figure(figh(1));
                return;
            end
            
            % Spawn help window
            help = this.version.help;
            if ((nargin < 2) || isempty(xyc))
                xyc = this.GetCenterCoordinates();
            end
            name = [this.version.name ' Help'];
            HW = HelpWindow(help,name,htag,xyc);
            
            % Add figure to FigureManager
            this.FM.AddFigure(HW.fig);                
        end
        
        %
        % Spawn about window
        %
        function SpawnAboutWindow(this,xyc)
            % If about window already exists
            atag = 'ChessMasterAbout';
            figh = this.FM.GetFigHandle(atag);
            if ~isempty(figh)
                % Give focus to existing about window
                figure(figh(1));
                return;
            end
            
            % Load version info
            name = this.version.name;
            release = this.version.release;
            date = this.version.date;
            author = this.version.author;
            contact = this.version.contact;
            
            % Spawn about window
            help.name = 'About';
            help.text = {[name ' v' release],'', ...
                          date,'', ...
                          author, ...
                          contact};
            if ((nargin < 2) || isempty(xyc))
                xyc = this.GetCenterCoordinates();
            end
            name = 'About';
            HW = HelpWindow(help,name,atag,xyc);
            
            % Add figure to FigureManager
            this.FM.AddFigure(HW.fig);
        end
        
        %
        % Restore child windows
        %
        function RestoreChildWindows(this,cwindows)
            % Loop through children
            Nwindows = length(cwindows);
            for i = 1:Nwindows
                % Process based on window tag
                switch cwindows(i).tag
                    case 'ChessEngine'
                        % Spawn a ChessEngine object
                        this.SpawnChessEngine(cwindows(i).xyc);
                    case 'ChessOptions'
                        % Spawn a ChessOptions object
                        this.SpawnChessOptions(cwindows(i).xyc);
                    case 'GameAnalyzer'
                        % Spawn a GameAnalyzer object
                        this.SpawnGameAnalyzer('pos',cwindows(i).pos);
                    case 'ChessClock'
                        % Spawn a ChessClock object
                        this.SpawnChessClock('',[],'pos',cwindows(i).pos);
                    case 'MoveList'
                        % Spawn a MoveList object
                        this.SpawnMoveList('pos',cwindows(i).pos);
                    case 'BoardEditor'
                        % Spawn a BoardEditor object
                        this.SpawnBoardEditor('pos',cwindows(i).pos);
                    case 'ThemeEditor'
                        % Spawn a ThemeEditor object
                        this.SpawnThemeEditor('pos',cwindows(i).pos);
                    case 'ChessMasterHelp'
                        % Spawn a "help" window
                        this.SpawnHelpWindow(cwindows(i).xyc);
                    case 'ChessMasterAbout'
                        % Spawn an "about" window
                        this.SpawnAboutWindow(cwindows(i).xyc);
                end
            end
        end
        
        %
        % Get GUI center coordinates
        %
        function xyc = GetCenterCoordinates(this)
            % Infer center coordinates from GUI position
            pos = get(this.fig,'Position');
            xyc = pos(1:2) + 0.5 * pos(3:4);
        end
        
        %
        % Flush graphics
        %
        function FlushGraphics(this) %#ok
            % Flush graphics
            drawnow;
        end
    end
    
    %
    % Private static methods
    %
    methods (Access = private, Static = true)
        %
        % Parse PGN file
        %
        % PGNinfo.startpos    = Starting position FEN string
        % PGNinfo.timeControl = Time control string
        % PGNinfo.outcome     = Game outcome string
        % PGNinfo.moves       = Move structure array w/ fields {SAN time}
        %
        function PGNinfo = ParsePGN(path)
            % Read pgn file
            fid = fopen(path,'r');
            pgn = '';
            while true
                % Get line
                line = fgetl(fid);
                if ~ischar(line)
                    break;
                end
                
                % Remove "rest of line" comments
                line = regexprep(line,';.+','');
                
                % Append line to PGN string
                pgn = [pgn ' ' line]; %#ok
            end
            fclose(fid);
            
            % Extract tags
            tagpat = '\[[^%\[\]]+\]';
            tags = regexp(pgn,tagpat,'match');
            pgn = regexprep(pgn,tagpat,'');
            
            % Process FEN tag
            FENstr = extractTagInfo(tags,'FEN');
            if isempty(FENstr)
                % Normal starting position 
                PGNinfo.startpos = 'startpos';
            else
                % Custom starting position
                PGNinfo.startpos = FENstr;
            end
            
            % Process TimeControl tag
            PGNinfo.timeControl = extractTagInfo(tags,'TimeControl');
            
            % Split body into bites
            pgn = regexprep(pgn,'e.p.',''); % Remove tricy en passant
            bites = regexp(pgn,'[^\s{}\.]+|{[^{}]*}','match');
            
            % Delete turn numbers
            bites(cellfun(@(str)~isnan(str2double(str)),bites)) = [];
            
            % Extract outcome
            outcomes = {'1-0','0-1','1/2-1/2'};
            if (~isempty(bites) && ismember(bites{end},outcomes))
                % Pop outcome from bites
                PGNinfo.outcome = bites{end};
                bites(end) = [];
            else
                % No outcome
                PGNinfo.outcome = '';
            end
            
            % Process move/time info
            moves = repmat(struct('SAN',[],'time',[]),[1 0]);
            timepat = '{\s*\[%\s*clk\s+(?<time>[^\s\]]+)\s*\][^{}]*}';
            for i = 1:length(bites)
                % If bite is a comment
                if (bites{i}(1) == '{')
                    % Check comment for time info
                    move = regexp(bites{i},timepat,'names');
                    if ~isempty(move)
                        % Record clock time, in seconds
                        moves(end).time = str2sec(move.time);
                    else
                        % No time info given
                        moves(end).time = -1;
                    end
                else
                    % Record base SAN string (w/ "P"s prepended)
                    SAN = regexprep(bites{i},{'[+#x!?]','e.p.'},'');
                    if ~isempty(SAN)
                        if isstrprop(SAN(1),'lower')
                            SAN = ['P' SAN]; %#ok
                        end
                        moves(end + 1).SAN = SAN; %#ok
                    end
                end
            end
            PGNinfo.moves = moves;
            
            %
            % Nested function: Extract info string from tag
            %
            function info = extractTagInfo(tags,name)            
                % Parse tags
                pat = ['\[\s*' name '\s*"(?<info>[^"]*)"\s*]'];
                infos = regexp(tags,pat,'names');
                
                % Check for desired tag name
                idx = find(cellfun(@(info)~isempty(info),infos),1,'last');
                if ~isempty(idx)
                    % Found desired info
                    info = infos{idx}.info;
                else
                    % No info
                    info = '';
                end
            end
            
            %
            % Nested function: Convert HH:MM:SS.T to seconds
            %
            function sec = str2sec(str)            
                % Split at colons
                strs = regexp(str,':','split');
                
                % Convert to seconds
                times = [zeros(1,3 - length(strs)) str2double(strs)];
                sec = [3600 60 1] * times';
            end
        end
        
        %
        % Get base directory of this class
        %
        function dir = GetBaseDir()
            % Extract base directory from location of current .m file
            [dir name ext] = fileparts(mfilename('fullpath')); %#ok
            
            % Convert to forward slashes for platform independence
            dir = regexprep(dir,'\','/');
        end
        
        %
        % Get coordinates of screen center
        %
        function [xyc scrsz] = GetScreenCenter()
            % Get center coordinates of screen
            scrsz = get(0,'ScreenSize');
            scrsz = scrsz(3:4);
            xyc = 0.5 * scrsz;
        end
    end
    
    %
    % Hidden public methods
    %
    methods (Hidden = true, Access = public)
        %
        % Create floating piece (editing mode)
        %
        function CreateFloatingPiece(this,ID,color)
            % If we're not in editing mode
            if (this.gameplayMode ~= ChessMaster.EDIT)
                % Quick return
                return;
            end
            
            % Set mouse lock
            this.mlock = true;
            
            % Create floating piece
            this.activeSquare = [];
            this.activePiece = this.CreatePiece(ID,color);
            this.MouseMove(); % Set location once before making active
            this.activePiece.MakeActive();
            
            % Start piece animation
            start(this.ptimer);
        end
        
        %
        % Delete floating piece (editing mode)
        %
        function [i j] = DeleteFloatingPiece(this)
            % If we're not in editing mode
            i = 0; j = 0;
            if (this.gameplayMode ~= ChessMaster.EDIT)
                % Quick return
                return;
            end
            
            % Stop animation
            this.mlock = false;
            if strcmpi(this.ptimer.Running,'on')
                stop(this.ptimer);
            end
            
            % If floating piece exists
            if ~isnan(this.activePiece)
                % Return last coordinates
                [x y] = this.GetMouseLocation();
                [i j] = this.LocateClick(x,y);
                
                % Delete piece
                this.activePiece.Delete();
            end
            
            % Clear selection
            this.ClearSquareSelection();
        end
        
        %
        % Add piece to board (editing mode)
        %
        function AddPiece(this,ID,color,i,j)
            % If we're not in editing mode
            if (this.gameplayMode ~= ChessMaster.EDIT)
                % Quick return
                return;
            end
            
            % Add piece to board
            this.EditingAdd(ID,color,i,j);
        end
        
        %
        % Get active square coordinates (editing mode)
        %
        function [i j] = GetActiveSquare(this)
            % If we're not in editing mode
            i = 0; j = 0;
            if (this.gameplayMode ~= ChessMaster.EDIT)
                % Quick return
                return;
            end
            
            % Get active square coordinates
            [i j] = this.GetActiveCoordinates();
        end
        
        %
        % Handle time-based win
        %
        function WinOnTime(this,winner)
            % Check mating material
            if (this.BS.SufficientMatingMaterial(winner) == false)
                % Insufficient mating material
                winner = ChessPiece.DRAW;
            end
            
            % Process game over
            switch winner
                case ChessPiece.WHITE
                    % Black forfeited
                    str = 'Black forfeits on time.';
                case ChessPiece.BLACK
                    % White forfeited
                    str = 'White forfeits on time.';
                case ChessPiece.DRAW
                    % Insufficient mating material
                    str = 'Draw... (insufficient mating material).';
            end
            this.GameOver(winner,str);
        end
        
        %
        % Perform engine autoplay(s)
        %
        function EngineAutoPlay(this)
            % If engine autoplay is needed
            if ((this.nwauto > 0) && (this.nbauto > 0) && ...
                strcmpi(this.atimer.Running,'off'))
                % Start autoplay timer
                start(this.atimer);
            else
                % Kick-off a single autoplay session
                this.AutoPlay();
            end
        end
        
        %
        % Autoplay all (valid) engines
        %
        function AutoPlay(this)
            % If autoplay isn't already in progress
            if (this.alock == false)
                % Set autoplay lock
                this.alock = true;
                
                % Loop over engines
                idx = 1;
                while (idx <= length(this.CElist))
                    % If auto-play is valid
                    if ((this.elock == false) && isvalid(this.CElist(idx)))
                        % Auto-play engine
                        this.CElist(idx).AutoPlay(this.turnColor);
                    end
                    idx = idx + 1;
                end
                
                % Stop autoplay timer, if necessary
                if (((this.nwauto < 1) || (this.nbauto < 1)) && ...
                    strcmpi(this.atimer.Running,'on'))
                    % Stop autoplay timer
                    stop(this.atimer);
                end
                
                % Release autoplay lock
                this.alock = false;
                
                % Flush graphics
                this.FlushGraphics();
            end
        end
        
        %
        % Update number of engines of given color on autoplay
        %
        function IncNauto(this,color,inc)
            % Increment count for given color
            switch color
                case ChessPiece.WHITE
                    % White pieces
                    this.nwauto = this.nwauto + inc;
                case ChessPiece.BLACK
                    % Black pieces
                    this.nbauto = this.nbauto + inc;
                case ChessPiece.BOTH
                    % Both colors
                    this.nwauto = this.nwauto + inc;
                    this.nbauto = this.nbauto + inc;
            end
        end
        
        %
        % Get number of engines of given color on autoplay
        %
        function nauto = GetNauto(this,color)
            % Get count for given color
            switch color
                case ChessPiece.WHITE
                    % White pieces
                    nauto = this.nwauto;
                case ChessPiece.BLACK
                    % Black pieces
                    nauto = this.nbauto;
                case ChessPiece.BOTH
                    % Both colors
                    nauto = this.nwauto + this.nbauto;
            end
        end
        
        %
        % Get base (piece positions only) board encoding 
        %
        function state = GetBaseEncoding(this)
            % Encode board state
            state = this.BS.BaseEncoding(false);
        end
        
        %
        % Delete given engine from engine list
        %
        function DeleteEngine(this,engine)
            % Loop over engines
            for i = length(this.CElist):-1:1
                if (this.CElist(i) == engine)
                    % Save persistent engine variables
                    this.engines.book = this.CElist(i).engineBook;
                    this.engines.idx = this.CElist(i).engineIdx;
                    
                    % Delete the specified engine
                    this.CElist(i) = [];
                end
            end
        end
        
        %
        % Delete board editor
        %
        function DeleteBoardEditor(this)
            % Delete BoardEditor object
            this.BE = [];
            
            % Update gameplay mode
            this.SetGameplayMode(ChessMaster.LEGAL);
        end
        
        %
        % Delete chess clock
        %
        function DeleteChessClock(this)
            % Clear ChessClock object
            this.CC = [];
        end
        
        %
        % Delete move list
        %
        function DeleteMoveList(this)
            % Clear MoveList object
            this.ML = [];
        end
        
        %
        % Delete game analyzer
        %
        function DeleteGameAnalyzer(this)
            % Save current engine state
            this.engines.idx = this.GA.engineIdx;
            
            % Clear GameAnalyzer object
            this.GA = [];
        end
        
        %
        % Update move animation
        %
        function UpdateMoveAnimation(this,bool)
            % Set move animation flag
            this.animateMoves = bool;
        end
        
        %
        % Update move animation FPS
        %
        function SetAnimationFPS(this,val)
            % Update period (ms precision)
            period = round(1000 / val) / 1000;
            this.animationPeriod = period;
            
            % Update timers
            set(this.ptimer,'StartDelay',period,'Period',period);
            if ~isempty(this.BE)
                set(this.BE.ptimer,'StartDelay',period,'Period',period);
            end
        end
        
        %
        % Update last move highlight states
        %
        function UpdateLastMoveHighlights(this,bool)
            % Set "on" state of last move highlights
            this.CHf.SetOnState(bool);
            this.CHt.SetOnState(bool);
        end
        
        %
        % Update current move highlight states
        %
        function UpdateCurrentMoveHighlights(this,bool)
            % Set "on" state of current move highlights
            this.CHc.SetOnState(bool);
        end
        
        %
        % Update last move menu state
        %
        function UpdateLastMoveMenuState(this,bool)
            % Set move menu visibility flag
            this.enableLastMoveMenu = bool;
            
            % Update last move menus
            this.UpdateLastMoveMenu();
        end
        
        %
        % Update turn marker state
        %
        function UpdateTurnMarkerState(this,bool)
            % Set turn marker visibility flag
            this.enableTurnMarker = bool;
            
            % Update turn marker
            this.UpdateTurnMarker();
        end
        
        %
        % Update check text enable state
        %
        function UpdateCheckTextState(this,bool)
            % Set check text state
            this.enableCheckText = bool;
            
            % Update check text
            this.UpdateCheckText();
        end
        
        %
        % Update status menu enable state
        %
        function UpdateStatusMenuState(this,bool)
            % Set status menu state
            this.enableStatusMenu = bool;
            
            % Update status menu
            this.UpdateStatusMenu();
        end
        
        %
        % Update undo/redo dialog state
        %
        function UpdateUndoRedoDialogState(this,bool)
            % Set undo/redo dialog flag
            this.enableUndoRedoDialog = bool;
        end
        
        %
        % Update dialog moves threshold
        %
        function UpdateMoveThreshold(this,val)
            % Set moves threshold
            this.movesThresh = val;
        end
        
        %
        % Update file/rank text
        %
        function UpdateFileRankLabels(this,str)
            % Process based on option string
            switch str
                case 'Lowercase'
                    % Turn on text
                    letters = 'abcdefgh';
                    numbers = '12345678';
                    visible = 'on';
                case 'Uppercase'
                    % Turn on text
                    letters = 'ABCDEFGH';
                    numbers = '12345678';
                    visible = 'on';
                case 'None'
                    % Turn off text
                    visible = 'off';
            end
            
            % Update text, if necessary
            if strcmpi(visible,'on')
                for i = 1:8
                    % Update file text
                    set(this.filetexth(i,:),'String',letters(i));
                    
                    % Update rank text
                    set(this.ranktexth(i,:),'String',numbers(i));
                end
            end
            
            % Update file/rank text visibility
            set([this.filetexth; this.ranktexth],'Visible',visible);
        end
        
        %
        % Update GameAnalyzer enable state
        %
        function UpdateGameAnalyzerEnableState(this,bool)
            % Set GameAnalyzer enable state
            this.enableGameAnalyzer = bool;
            if (this.enableGameAnalyzer == true)
                % Enable game analyzer menu option
                set(this.gah,'Enable','on');
            else
                % Disable game analyzer menu option
                set(this.gah,'Enable','off');
                
                % Close existing game analyzer, if any
                this.CloseGameAnalyzer();
            end            
        end
        
        %
        % Update MoveList enable state
        %
        function UpdateMoveListEnableState(this,bool)
            % Set MoveList enable state
            this.enableMoveList = bool;
            if (this.enableMoveList == true)
                % Enable move list menu option
                set(this.mlh,'Enable','on');
            else
                % Disable move list menu option
                set(this.mlh,'Enable','off');
                
                % Close existing move list, if any
                this.CloseMoveList();
            end
        end
        
        %
        % Update ChessClock enable state
        %
        function UpdateChessClockEnableState(this,bool)
            % Set ChessClock enable state
            this.enableChessClock = bool;
            if (this.enableChessClock == true)
                % Enable chess clock menu option
                set(this.tch,'Enable','on');
            else
                % Disable chess clock menu option
                set(this.tch,'Enable','off');
                
                % Close existing chess clock, if any
                this.CloseChessClock();
            end
        end
        
        %
        % Update popup state
        %
        function UpdatePopupState(this,bool)
            % Set popup state
            this.enablePopups = bool;
        end
        
        %
        % Paint board
        %
        function PaintBoard(this,color)
            % Parse color theme
            if (nargin == 2)
                % Update current color
                this.currentColor = color;
            else
                % Apply last-saved color 
                color = this.currentColor;
            end
            
            % Update board image
            set(this.bh,'CData',this.BG.GenerateBoardImage(color), ...
                        'XData',this.BG.bdLim, ...
                        'YData',this.BG.bdLim);
            
            % Update file/rank text
            textColor = color.text / 255;
            set(this.filetexth,'Color',textColor);
            set(this.ranktexth,'Color',textColor);
            
            % Update check text
            set(this.checkh,'Color',textColor, ...
                            'EdgeColor',color.boundary / 255, ...
                            'BackgroundColor',color.border / 255);
            
            % Update turn marker
            set(this.markerh,'FaceColor',color.turnMarker / 255);
            
            % Update square highlights
            this.CHf.SetSprite(this.BG.CHD,color.lastMove);
            this.CHt.SetSprite(this.BG.CHD,color.lastMove);
            this.CHc.SetSprite(this.BG.CHD,color.currentMove);
            if ~isempty(this.BE)
                this.BE.SetHighlightSprite(color.currentMove);
            end
        end
        
        %
        % Save given color theme
        %
        function success = SaveTheme(this)
            % Get current color theme
            color = this.currentColor;
            
            % Determine theme index
            success = true; % Assume successful save, by default
            idx = find(ismember({this.themes.color.name},color.name));
            if isempty(idx)
                % Add new theme to list
                idx = length(this.themes.color) + 1;
            else
                % Make sure the user intends to overwrite an existing theme
                qStr = sprintf('Theme "%s" already exists. Overwrite?', ...
                                color.name);
                selection = questdlg(qStr,this.version.name,'Yes','No', ...
                                    'No');
                drawnow; % Hack to avoid MATLAB freeze + crash
                
                % Handle request
                if ~strcmp(selection,'Yes')
                    % User changed their mind
                    success = false;
                    return;
                end
            end
            
            % Save theme
            this.themes.color(idx) = color;
            this.themes.ID = idx; % Update current theme ID
        end
        
        %
        % Revert board to last used theme
        %
        function LoadLastTheme(this)
            % Set board theme to current ID
            this.SetBoardTheme(this.themes.ID);
        end
        
        % Custom (empty) display method
        function display(varargin)
            % Empty
        end
        
        % Hide handle's addlistener() method
        function out = addlistener(varargin)
            out = addlistener@handle(varargin{:});
        end
        
        % Hide handle's eq() method
        function out = eq(varargin)
            out = eq@handle(varargin{:});
        end
        
        % Hide handle's findobj() method
        function out = findobj(varargin)
            out = findobj@handle(varargin{:});
        end
        
        % Hide handle's findprop() method
        function out = findprop(varargin)
            out = findprop@handle(varargin{:});
        end
        
        % Hide handle's ge() method
        function out = ge(varargin)
            out = ge@handle(varargin{:});
        end
        
        % Hide handle's gt() method
        function out = gt(varargin)
            out = gt@handle(varargin{:});
        end
        
        % Hide handle's le() method
        function out = le(varargin)
            out = le@handle(varargin{:});
        end
        
        % Hide handle's lt() method
        function out = lt(varargin)
            out = lt@handle(varargin{:});
        end
        
        % Hide handle's ne() method
        function out = ne(varargin)
            out = ne@handle(varargin{:});
        end
        
        % Hide handle's notify() method
        function notify(varargin)
            notify@handle(varargin{:});
        end
    end
end
