classdef ChessEngine < handle
%
% Class that spawns and coordinates a chess engine with a ChessMaster GUI
%
% NOTE: This class is used internally by the ChessMaster GUI and is not
%       intended for public invocation
%
% Brian Moore
% brimoor@umich.edu
%

    %
    % Private constants
    %
    properties (GetAccess = private, Constant = true)
        % CPU usage
        MAX_CPU = 1;                    % Max CPU in [0 1] given to engine
        
        % Engine execution mode "enum"
        MANUAL = 1;                     % Manual execution mode
        AUTO_WHITE = 2;                 % Auto-white mode
        AUTO_BLACK = 3;                 % Auto-black mode
        AUTO_BOTH = 4;                  % Auto-play both colors
        
        % Engine play mode "enum"
        PLAY_MODE = 1;                  % Engine play move
        ANALYSIS_MODE = 2;              % Engine analyze mode
        
        % Engine search mode "enum"
        NODES_SEARCH = 1;               % Nodes-based search
        DEPTH_SEARCH = 2;               % Depth-based search
        TIME_SEARCH = 3;                % Time-based search
        
        % GUI formatting 
        FBORDER = 7;                    % Figure border width, in pixels
        CONTROL_GAP = 4;                % Inter-object spacing, in pixels
        CONTROL_WIDTH = 200;            % Object panel widths, in pixels
        CONTROL_HEIGHT = 20;            % Object panel heights, in pixels
        POPUP_DX = 0.95;                % Popup relative width
        BUTTON_DX = 0.7;                % Button relative width
        MOVE_DX = [0.1 0.25 0.4 0.25];  % Move group relative widths
        PA_DX = [0.1 0.4 0.1 0.4];      % Play/analysis relative widths
        STATS_DX = [0.35 0.65];         % Stats group relative widths
        
        % Font sizes
        LABEL_SIZE = 12 - 2 * ispc;     % UI panel font size
        FONT_SIZE = 10 - 2 * ispc;      % GUI font size
        
        % Background colors
        ACTIVE = [252 252 252] / 255;   % Active color
        INACTIVE = ([236 236 236] + 4 * ispc) / 255; % Inactive color
        RUNNING = [51 51 204] / 255;    % Running color
        STOP = [204 51 51] / 255;       % Stop color
    end
    
    %
    % Public GetAccess properties
    %
    properties (GetAccess = public, SetAccess = private)
        % Auto-engine settings
        autoplay = false;               % Auto-play flag
        autoanalyze = false;            % Auto-analysis flag
        autocolor = ChessPiece.NULL;    % Auto move/analysis color
        alock = false;                  % Auto-play lock
        tlock = false;                  % Thinking lock
        qlock = false;                  % Quiet lock
        
        % Engine variables
        engineList;                     % List of supported engines
        engineBook;                     % Path to opening book
        engineIdx;                      % Current engine index
        engineStats;                    % Engine stats to be displayed
        nStats;                         % Number of engine stats
        
        % Figure handle
        fig;                            % Figure handle
    end

    %
    % Public properties
    %
    properties (Access = public)
        searchVals = [1e7 20 3];              % Search values
    end
    
    %
    % Private properties
    %
    properties (Access = private)
        % Chess Master GUI
        CM;                                   % ChessMaster handle
        
        % Engine interface
        EI = [];                              % EngineInterface object
        
        % Internal variables
        newGame = true;                       % New game flag
        isRandom;                             % Random engine flag
        execMode = ChessEngine.MANUAL;        % Execution mode
        playMode = ChessEngine.PLAY_MODE;     % Play mode state
        searchMode = ChessEngine.TIME_SEARCH; % Search mode state
        statInds;                             % Display stats indices
        lastAnalyzedMove = -1;                % Last analyzed move
        
        % GUI variables
        eh;                                   % Engine group handles
        mh;                                   % Move-search group handles
        sh;                                   % Stats group handles
    end
    
    %
    % Public methods
    %
    methods (Access = public)
        %
        % Constructor
        %
        function this = ChessEngine(CM,engines,tag,xyc)
            % Save ChessMaster object
            this.CM = CM;
            
            % Save engine info
            this.engineList = engines.list;
            this.engineBook = engines.book;
            this.engineIdx = engines.idx;
            this.engineStats = engines.stats;
            this.nStats = length(this.engineStats);
            this.isRandom = (this.engineIdx == 0);
            
            % Initialize GUI
            this.InitializeGUI(tag,xyc);
            
            % Initialize stats display
            this.InitializeStatsDisplay();
            
            % Initialize engine
            this.ChangeEngine();
        end

        %
        % Make move
        %
        function MakeMove(this)
            % Process based on execution mode
            if (this.isRandom == true)
                % Random move
                this.RandomMove();
                return;
            end
            
            % If we're in analysis mode
            if (this.playMode == ChessEngine.ANALYSIS_MODE)
                % Make sure we haven't already analyzed this position
                currentMove = this.CM.currentMove;
                if (currentMove == this.lastAnalyzedMove)
                    % Quick return
                    return;
                end
                this.lastAnalyzedMove = currentMove;
            end
            
            % Engine move
            this.EngineMove();
        end
        
        %
        % Auto-play engine (if valid)
        %
        function AutoPlay(this,color)
            % If auto move is valid
            if ((this.CM.isGameOver == false) && ...
                (this.alock == true) && (this.tlock == false) && ...
               ((this.autocolor == color) || ...
                (this.autocolor == ChessPiece.BOTH)))
                % Make move
                this.MakeMove();
            end
        end
        
        %
        % Turn off auto-play for the given color
        %
        function TurnOffAutoPlay(this,color)
            % If auto-move is valid
            if ((this.alock == true) && (this.autoplay == true) && ...
               ((this.autocolor == color) || ...
                (this.autocolor == ChessPiece.BOTH)))
                % Release auto lock
                this.ReleaseAutoLock();
            end
        end
        
        %
        % Update engine state
        %
        function UpdateEngineState(this)
            % If moves can't be made
            if (this.CM.isGameOver == true)
                % Release auto-lock
                this.ReleaseAutoLock();      
            else
                % Update search button state
                this.UpdateSearchButtonState();
            end
            
            % If the engine is thinking
            if ((this.tlock == true) && (this.isRandom == false))                
                % Force engine to stop immediately
                this.qlock = true; % Block in-proess analysis from posting
                this.EI.SendCommand('stop');
            end
        end
        
        %
        % Stop analysis engine search
        %
        function StopAnalysisEngine(this)
            % If an analysis engine is thinking
            if ((this.tlock == true) && ...
                (this.playMode == ChessEngine.ANALYSIS_MODE))
                % Force engine to stop immediately
                this.EI.SendCommand('stop');
            end
        end
        
        %
        % Update stats group
        %
        function UpdateStats(this,varargin)
            % If new game flag is set
            if (this.newGame == true)
                % Quick return
                return;
            end
            
            % Get turn color string, if necessary
            turnColor = this.CM.turnColor;
            if ((this.execMode == ChessEngine.MANUAL) && ...
                (this.playMode == ChessEngine.PLAY_MODE))
                % Manual move triggered, so append color info
                switch turnColor
                    case ChessPiece.WHITE
                        % Black moved last
                        colorStr = ' (Black)';
                    case ChessPiece.BLACK
                        % White moved last
                        colorStr = ' (White)';
                end
            else
                % Auto-play, so no need to append color info
                colorStr = '';
            end
            
            % Update best move
            if ischar(varargin{1})
                % Update best move entry
                str = [varargin{1} colorStr];
                set(this.sh(this.nStats + 1,2),'String',str); % Always top
                this.FlushGraphics();
                return;
            end
            
            % Update stats
            info = varargin{1};
            fields = fieldnames(info);
            sInds = this.statInds; % Local copy to improve performance
            sH = this.sh; % Local copy to improve performance
            for j = 1:numel(fields)
                % Process based on field name
                switch fields{j}
                    case 'pv'
                        if (this.playMode == ChessEngine.ANALYSIS_MODE)
                            % Update principal variation entry
                            pv = info.pv(1:min(end,4));
                            str = [' ' sprintf('%s ',pv{:})];
                            idx = this.nStats + 1; % Always top
                            set(sH(idx,2),'String',str);
                        end
                    case 'score'
                        if any(sInds.score)
                            % Update score entry
                            sobj = info.score;
                            if isfield(sobj,'mate')
                                val = str2double(sobj.mate);
                                if (turnColor == ChessPiece.BLACK)
                                    % White's point of view
                                    val = -1 * val;
                                end
                                str = sprintf(' Mate in %.0f ',val);
                            elseif isfield(sobj,'cp')
                                val = 0.01 * str2double(sobj.cp);
                                if (turnColor == ChessPiece.BLACK)
                                    % White's point of view
                                    val = -1 * val;
                                end
                                str = sprintf(' %.2f ',val);
                            else
                                str = '??????';
                            end
                            set(sH(sInds.score,2),'String',str);
                        end
                    case 'depth'
                        if any(sInds.depth)
                            % Update depth entry
                            plies = info.depth;
                            str = sprintf(' %s plies ',plies);
                            set(sH(sInds.depth,2),'String',str);
                        end
                    case 'nodes'
                        if any(sInds.nodes)
                            % Update nodes entry
                            nodes = str2double(info.nodes);
                            if (nodes == 0)
                                % Engine in opening book(?)
                                str = ' [Opening Book] ';
                                inds = (sInds.score | sInds.depth);
                                set(sH(inds,2),'String',str);
                            end
                            str = sprintf(' %.0f nodes ',nodes);
                            set(sH(sInds.nodes,2),'String',str);
                        end
                    case 'nps'
                        if any(sInds.nps)
                            % Update nodes/sec entry (in kn/s)
                            rawStr = info.nps;
                            kNs = 0.001 * str2double(rawStr);
                            str = sprintf(' %.0f kn/s ',kNs);
                            set(sH(sInds.nps,2),'String',str);
                        end
                    case 'time'
                        if any(sInds.time)
                            % Update search time entry
                            msec = str2double(info.time);
                            str = sprintf(' %.2f s ',0.001 * msec);
                            set(sH(sInds.time,2),'String',str);
                        end
                    case 'hashfull'
                        if any(sInds.hashfull)
                            % Update hash %full entry
                            permill = str2double(info.hashfull);
                            str = sprintf(' %.1f%% ',0.1 * permill);
                            set(sH(sInds.hashfull,2),'String',str);
                        end
                    case 'cpuload'
                        if any(sInds.cpuload)
                            % Update cpu usage entry
                            permill = str2double(info.cpuload);
                            str = sprintf(' %.1f%% ',0.1 * permill);
                            set(sH(sInds.cpuload,2),'String',str);
                        end
                end
            end
            
            % Flush graphics
            this.FlushGraphics();
        end
        
        %
        % Update engine book
        %
        function UpdateEngineBook(this,book)
            % Save book file path
            this.engineBook = book;
        end
        
        %
        % Reset engine
        %
        function Reset(this)
            % If an external engine exists
            if (this.isRandom == false)
                % Update engine state
                this.UpdateEngineState();
                
                % Tell the engine to start a new game internally
                this.EI.SendCommand('ucinewgame');
            end
            
            % Reset all non-analysis engines
            if (this.playMode ~= ChessEngine.ANALYSIS_MODE)
                % Reset GUI
                this.ResetGUI();
            else
                % Only reset last analyzed move
                this.lastAnalyzedMove = -1;
            end
        end

        %
        % Handle search Time value change
        %
        function ChangeSearchTime(this,val)
            if isnan(val)
                % Revert to last used value
                val = this.searchVals(idx);
            end
            
            % Save new value
            this.searchVals(3) = val;
            
            % Update GUI search values
            this.UpdateSearchVals(3);
        end
        
        %
        % Close engine
        %
        function Close(this)
            try
                % Delete engine from list
                this.CM.DeleteEngine(this);
                
                % Release locks
                this.ReleaseAutoLock(false);
                this.ReleaseThinkingLock(false);
            catch %#ok
                % Graceful exit
            end
            
            try
                % Close engine interface
                delete(this.EI);
            catch %#ok
                % Graceful exit
            end
            
            try
                % Close GUI
                delete(this.fig);
            catch %#ok
                % Graceful exit
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
        % Set auto lock
        %
        function SetAutoLock(this,drawflag)
            % Turn on auto-play
            if ((this.alock == false) && (this.autoplay == true))
                this.CM.IncNauto(this.autocolor,1);
            end
            this.alock = true;
            
            % Update search panel (unless specifically told not to)
            if ((nargin < 2) || (drawflag == true))
                this.UpdateSearchPanel();
            end
        end
        
        %
        % Release auto lock
        %
        function ReleaseAutoLock(this,drawflag)
            % Release autoplay lock
            if ((this.alock == true) && (this.autoplay == true))
                this.CM.IncNauto(this.autocolor,-1);
            end
            this.alock = false;
            
            % Update search panel (unless specifically told not to)
            if ((nargin < 2) || (drawflag == true))
                this.UpdateSearchPanel();
            end
        end
        
        %
        % Set thinking lock
        %
        function SetThinkingLock(this,drawflag)
            % Set thinking lock
            if (this.playMode == ChessEngine.PLAY_MODE)
                % Block ChessMaster GUI
                this.CM.BlockGUI(true);
            end
            this.tlock = true;
            
            % Update search panel (unless specifically told not to)
            if ((nargin < 2) || (drawflag == true))
                this.UpdateSearchPanel();
            end
        end
        
        %
        % Release thinking lock
        %
        function ReleaseThinkingLock(this,drawflag)
            % Release thinking lock
            if (this.playMode == ChessEngine.PLAY_MODE)
                % Unblock ChessMaster GUI 
                this.CM.BlockGUI(false);
            end
            this.tlock = false;
            
            % Update search panel (unless specifically told not to)
            if ((nargin < 2) || (drawflag == true))
                this.UpdateSearchPanel();
            end
        end
        
        %
        % Change the active engine
        %
        function ChangeEngine(this)
            % Get new engine index
            idx = get(this.eh(1),'Value') - 1;
            
            try
                % Initialize engine
                this.InitializeEngine(idx);
            catch ME
                % Show the orginal error as a warning
                warning(ME.identifier,ME.message);
                
                % Warn the user that the desired engine failed
                msgid = 'CE:ENGINE_INIT:FAIL';
                msg = ['\n\n***** Failed to initialize "%s" *****\n' ...
                           '***** Using "Random Moves" instead *****\n'];
                warning(msgid,msg,this.engineList(idx).name);
                
                % Initialize the "Random Moves" engine instead
                this.InitializeEngine(0);
            end
        end
        
        %
        % Open engine options GUI
        %
        function OpenEngineOptions(this)
            % If no valid engine interface exists
            if isempty(this.EI)
                % Quick return
                return;
            end
            
            % Open engine options GUI
            xyc = this.GetCenterCoordinates();
            figh = this.EI.EO.OpenGUI(xyc);
            
            % Save figure to FigureManager, if necessary
            if ~isempty(figh)
                this.CM.FM.AddFigure(figh);
            end
        end
        
        %
        % Open engine log
        %
        function OpenEngineLog(this)
            % If no valid engine interface exists
            if isempty(this.EI)
                % Quick return
                return;
            end
            
            % Open engine log
            xyc = this.GetCenterCoordinates();
            figh = this.EI.EL.OpenGUI(xyc);
            
            % Save figure to FigureManager, if necessary
            if ~isempty(figh)
                this.CM.FM.AddFigure(figh);
            end
        end
        
        %
        % Change the execution mode
        %
        function ChangeExecMode(this)
            % Get new execution type
            this.execMode = get(this.mh(5,1),'Value');
            
            % Update engine state variables
            switch this.execMode
                case ChessEngine.MANUAL
                    % Manual move mode
                    this.autoplay = false;
                    this.autoanalyze = false;
                    this.autocolor = ChessPiece.NULL;
                case ChessEngine.AUTO_WHITE
                    % Auto-white moves
                    this.UpdateAutoFlags();
                    this.autocolor = ChessPiece.WHITE;
                case ChessEngine.AUTO_BLACK
                    % Auto-black moves
                    this.UpdateAutoFlags();
                    this.autocolor = ChessPiece.BLACK;
                case ChessEngine.AUTO_BOTH
                    % Auto-play both colors
                    this.UpdateAutoFlags();
                    this.autocolor = ChessPiece.BOTH;
            end
            
            % Update search panel
            this.UpdateSearchPanel();
        end
        
        %
        % Change play mode
        %
        function ChangePlayMode(this,idx)
            % Update (mutually exclusive) play/analysis checkboxes
            set(this.mh(4,idx),'Value',1);
            set(this.mh(4,~(idx - 1) + 1),'Value',0);
            
            % If mode didn't change
            if (idx == this.playMode)
                % Quick return
                return;
            end
            
            % Save new play mode
            this.playMode = idx;
            
            % Update auto flags, if necessary
            if (this.execMode ~= ChessEngine.MANUAL)
                this.UpdateAutoFlags();
            end
            
            % Update play mode uicontrols
            this.UpdatePlayMode();
            
            % Update search panel
            this.UpdateSearchPanel();
        end
        
        %
        % Handle search mode change
        %
        function ChangeSearchMode(this,i)
            % Save new search mode
            this.searchMode = i;
            
            % Update search mode uicontrols
            this.UpdateSearchMode();
        end
        
        %
        % Handle search value change
        %
        function ChangeSearchVal(this,idx)
            % Get new search value
            val = str2double(get(this.mh(idx,3),'String'));
            if isnan(val)
                % Revert to last used value
                val = this.searchVals(idx);
            end
            
            % Apply formatting
            switch idx
                case ChessEngine.NODES_SEARCH
                    % Round and clip from below
                    val = max(0,round(val));
                case ChessEngine.DEPTH_SEARCH
                    % Round and clip from below
                    val = max(0,round(val));
                case ChessEngine.TIME_SEARCH
                    % Clip from below
                    val = max(0,val);
            end
        end

        %
        % Update auto flags
        %
        function UpdateAutoFlags(this)
            % Update auto flags
            mode = this.playMode;
            this.autoplay = (mode == ChessEngine.PLAY_MODE);
            this.autoanalyze = (mode == ChessEngine.ANALYSIS_MODE);
        end
        
        %
        % Update play mode uicontrols
        %
        function UpdatePlayMode(this)
            % Clear pv/best-move string
            set(this.sh(this.nStats + 1,2),'String','');
            
            % Process based on analysis mode
            switch this.playMode
                case ChessEngine.PLAY_MODE
                    % Play mode
                    set(this.sh(this.nStats + 1,1),'String',' Best Move');
                case ChessEngine.ANALYSIS_MODE
                    % Analysis mode
                    set(this.sh(this.nStats + 1,1),'String',' PV');
            end
        end
        
        %
        % Update the search mode uicontrols
        %
        function UpdateSearchMode(this)
            % Update (mutually exclusive) uicontrols
            idx = this.searchMode;
            set(this.mh(idx,1),'Value',1);
            set(this.mh(setdiff(1:3,idx),1),'Value',0);
        end
        
        %
        % Update search values on GUI
        %
        function UpdateSearchVals(this,inds)
            % Parse input args
            if (nargin < 2)
                inds = 1:3;
            end
            
            % Loop over value fields
            for idx = inds
                % Update value box
                val = this.searchVals(idx);
                set(this.mh(idx,3),'String',num2str(val));
            end
        end
        
        %
        % Handle search button press
        %
        function SearchButtonPress(this)
            % Release new game flag
            this.newGame = false;
            
            % Handle button press
            if ((this.tlock == true) && (this.isRandom == false))
                % Tell engine to stop searching immediately
                this.EI.SendCommand('stop');
                return;
            elseif (this.alock == true)
                % Release auto lock
                this.ReleaseAutoLock();
                return
            end
            
            % If analysis mode
            if (this.playMode == ChessEngine.ANALYSIS_MODE)
                % Reset last analyzed move
                this.lastAnalyzedMove = -1;
            end
            
            % If manual mode
            if (this.execMode == ChessEngine.MANUAL)
                % If in analysis mode
                if ((this.playMode == ChessEngine.ANALYSIS_MODE) || ...
                    (this.CM.block == false))
                    % Make move
                    this.MakeMove();
                end
                return;
            end
            
            % If an AutoPlay engine for this color already exists
            if ((this.playMode == ChessEngine.PLAY_MODE) && ...
                (this.CM.GetNauto(this.autocolor) > 0))
                % Quick return
                return;
            end
            
            % Set auto lock
            this.SetAutoLock();
            
            % Handle engine auto-plays
            this.CM.EngineAutoPlay();
        end
                
        %
        % Make a random move
        %
        function RandomMove(this)
            % Random move
            SANstr = this.CM.RandomMove(false);
            this.UpdateStats(SANstr);
            
            % Handle engine auto-plays
            this.CM.EngineAutoPlay();
        end
        
        %
        % Ask the engine to make a move
        %
        function EngineMove(this)
            % Set thinking lock
            this.SetThinkingLock();
            
            % Clear leftover info in engine's memory
            this.EI.ClearInfo();
            
            % Clear stats panel
            this.ClearStats();
            
            % Ready handshake
            this.EI.ReadyHandshake();
            
            % Tell the engine about current position
            args = struct();
            moves = this.CM.GetLANstrs();
            if (this.CM.isStdStartPos == true)
                % Standard starting position
                args.startpos = true;
            else
                % Custom starting position
                args.fen = this.CM.startingFENstr;
            end
            if ~isempty(moves)
                % Add move info 
                args.moves = moves;
            end
            this.EI.SendCommand('position',args);
            
            % Tell the engine to kick-off the search
            args = struct();
            switch this.searchMode
                case ChessEngine.NODES_SEARCH
                    % Nodes-based search
                    args.nodes = get(this.mh(1,3),'String');
                case ChessEngine.DEPTH_SEARCH
                    % Depth-based search
                    args.depth = get(this.mh(2,3),'String');
                case ChessEngine.TIME_SEARCH
                    % Time-based search
                    msec = 1000 * str2double(get(this.mh(3,3),'String'));
                    args.movetime = num2str(round(msec));
            end
            this.EI.SendCommand('go',args);
            
            % Read *asynchronously* until 'bestmove' is received, and then
            % make the returned move
            fcn = @(args) MakeEngineMove(this,args.move);
            this.EI.ReadUntilCMDa('bestmove',inf,fcn);
        end
        
        %
        % Make move with given LAN string
        %
        function MakeEngineMove(this,LANstr)
            % If engine is in play mode and quiet flag isn't set
            if ((this.playMode == ChessEngine.PLAY_MODE) && ~this.qlock)
                % Play mode, so *do* make the move
                SANstr = this.CM.MakeMove(LANstr);
                
                % Update stats panel with best move SAN string
                this.UpdateStats(SANstr);
            end
            
            % Release locks
            this.qlock = false;
            this.ReleaseThinkingLock();
            
            % Handle engine auto-plays
            this.CM.EngineAutoPlay();
        end
        
        %
        % Initialize the given engine
        %
        function InitializeEngine(this,idx)
            % Close existing engine interface
            delete(this.EI);
            
            % Open new interface
            if (idx ~= 0)
                % Spawn new engine interface
                path = this.engineList(idx).path;
                book = this.engineBook;
                maxCPU = ChessEngine.MAX_CPU;
                this.EI = EngineInterface(this,path,book,maxCPU);
            else
                % Random moves
                this.EI = [];
            end
            
            % Save current engine index
            this.engineIdx = idx;
            this.isRandom = (this.engineIdx == 0);
            
            % Reset engine
            this.ResetGUI();
        end
        
        %
        % Update GUI search panel
        %
        function UpdateSearchPanel(this)
            % Process based on execution mode
            if ((this.tlock == true) || (this.alock == true))
                % Don't allow spurious clicks while playing
                if (this.isRandom == true)
                    set(this.eh(3),'Enable','off');
                else
                    % Allow log but no options GUI
                    set(this.eh(3),'Enable','on');
                    this.EI.EO.CloseGUI();
                end
                set(this.eh(1:2),'Enable','off');
                set(this.mh(1:4,:),'Enable','off');
                set(this.mh(5,1),'Enable','off');
                set(this.mh(5,2),'Enable','on');
            else
                % Manual moves
                if (this.isRandom == true)
                    % Clear/disable UCI engine fields
                    set(this.eh(2:3),'Enable','off');
                    set(this.mh(1:3,:),'Enable','off');
                    set(this.mh(4,[2 4]),'Enable','off');
                    set(this.sh(1:(this.nStats),1),'Enable','off');
                    set(this.mh(1:3,1),'Value',0);
                    set(this.mh(1:3,3),'String','');
                    
                    % Force play mode
                    this.ChangePlayMode(ChessEngine.PLAY_MODE);
                else
                    % Restore/enable UCI engine fields
                    nS = this.nStats;
                    set(this.eh(2:3),'Enable','on');
                    set(this.mh([1:3 9]),'Enable','on');
                    this.EnableUIcontrol(this.mh(1:3,3),'on');
                    this.EnableUIcontrol(this.mh([6:8 16:19]),'inactive');
                    this.EnableUIcontrol(this.sh(1:nS,1),'inactive');
                    this.UpdateSearchMode();
                    this.UpdateSearchVals();
                end
                
                % Restore idle controls
                set([this.mh(4,1) this.mh(5,2)],'Enable','on');
                this.EnableUIcontrol([this.eh(1) this.mh(5,1)],'on');
                this.EnableUIcontrol(this.mh(4,3),'inactive');
            end
            
            % Process based on playing state
            if (this.tlock == true)
                % "Stop search" button
                set(this.mh(5,2),'String','Stop Search', ...
                                 'BackgroundColor',ChessEngine.STOP, ...
                                 'ForegroundColor',[1 1 1]);
            elseif (this.alock == true)
                % "Stop Auto-Play" button
                switch this.playMode
                    case ChessEngine.PLAY_MODE
                        % Play mode
                        bstr = 'Stop Auto-Play';
                    case ChessEngine.ANALYSIS_MODE
                        % Analysis mode
                        bstr = 'Stop Auto-Analysis';
                end
                set(this.mh(5,2),'String',bstr, ...
                                 'BackgroundColor',ChessEngine.RUNNING, ...
                                 'ForegroundColor',[1 1 1]);
            else
                % Process based on execution mode
                if (this.execMode ~= ChessEngine.MANUAL)
                    % "Start Auto-Play" button
                    switch this.playMode
                        case ChessEngine.PLAY_MODE
                            % Play mode
                            bstr = 'Start Auto-Play';
                        case ChessEngine.ANALYSIS_MODE
                            % Analysis mode
                            bstr = 'Start Auto-Analysis';
                    end
                else
                    % "Start" button
                    switch this.playMode
                        case ChessEngine.PLAY_MODE
                            % Play mode
                            bstr = 'Make Move';
                        case ChessEngine.ANALYSIS_MODE
                            % Analysis mode
                            bstr = 'Analyze Position';
                    end
                end
                set(this.mh(5,2),'String',bstr, ...
                                 'BackgroundColor',ChessEngine.INACTIVE,...
                                 'ForegroundColor',[0 0 0]);
            end
            
            % Update search button state
            this.UpdateSearchButtonState();
        end
        
        %
        % Update search button (enable) state
        %
        function UpdateSearchButtonState(this)
            % Process based on game state
            if (this.CM.isGameOver == true)
                % Disable search button
                set(this.mh(5,2),'Enable','off');
            else
                % Enable search button
                set(this.mh(5,2),'Enable','on');
            end
        end
        
        %
        % Initialize GUI
        %
        function InitializeGUI(this,tag,xyc)
            % Load constants
            ns = this.nStats;
            labelSize = ChessEngine.LABEL_SIZE;
            fontSize = ChessEngine.FONT_SIZE;
            db = ChessEngine.FBORDER;
            dt = ChessEngine.CONTROL_GAP;
            dx = ChessEngine.CONTROL_WIDTH;
            dy = ChessEngine.CONTROL_HEIGHT;
            dxb = dx * ChessEngine.BUTTON_DX;
            dxp = dx * ChessEngine.POPUP_DX;
            dxm = (dx - 3 * dt) * ChessEngine.MOVE_DX;
            dxa = (dx - 3 * dt) * ChessEngine.PA_DX;
            dxs = (dx - dt) * ChessEngine.STATS_DX;
            
            % Compute static panel dimensions
            epxy = [(dx + 2.45 * dt) (3.85 * dy + 4 * dt)];
            mpxy = [(dx + 2.45 * dt) (6.85 * dy + 7 * dt)];
            spxy = [(dx + 2.45 * dt) ((ns + 1.85) * dy + (ns + 2) * dt)];
            
            % Create a nice figure
            dim = [(2 * db + max([epxy(1) mpxy(1) spxy(1)])) ...
                   (4 * db + epxy(2) + mpxy(2) + spxy(2))] - 2;
            this.fig = figure('MenuBar','None', ...
                      'NumberTitle','off', ...
                      'DockControl','off', ...
                      'name','Chess Engine', ...
                      'tag',tag, ...
                      'Position',[(xyc - 0.5 * dim) dim], ...
                      'Resize','off', ...
                      'Interruptible','on', ...
                      'WindowKeyPressFcn',@(s,e)HandleKeyPress(this,e), ...
                      'CloseRequestFcn',@(s,e)Close(this), ...
                      'Visible','off');
            
            %--------------------------------------------------------------
            % Engine panel
            %--------------------------------------------------------------
            % Create engine uipanel
            xy0 = [db (3 * db + spxy(2) + mpxy(2))];
            uiph1 = uipanel('Parent',this.fig, ...
                              'Units','pixels', ...
                              'Position',[xy0 epxy], ...
                              'FontSize',labelSize, ...
                              'TitlePosition','centertop', ...
                              'Title','Engine');
            
            % Engine selection popup
            pos = [(dt + 0.5 * (dx - dxp)) (2 * dy + 3.5 * dt) dxp dy];
            strs = {'Random Moves' this.engineList.name};
            this.eh(1) = uicontrol('Parent',uiph1,...
                              'Units','pixels', ...
                              'Position',pos, ...
                              'FontSize',fontSize, ...
                              'Style','popup',...
                              'Callback',@(s,e)ChangeEngine(this), ...
                              'String',strs, ...
                              'Value',this.engineIdx + 1);
            
            % Engine options pushbutton
            pos = [dt (dy + 2 * dt) dx dy] + (dx - dxb) * [0.5 0 -1 0];
            this.eh(2) = uicontrol('Parent',uiph1,...
                              'Units','pixels', ...
                              'Position',pos, ...
                              'FontSize',fontSize, ...
                              'Style','pushbutton',...
                              'Callback',@(s,e)OpenEngineOptions(this), ...
                              'String','Options');
            
            % Engine log pushbutton
            pos = [dt dt dx dy] + (dx - dxb) * [0.5 0 -1 0];
            this.eh(3) = uicontrol('Parent',uiph1,...
                              'Units','pixels', ...
                              'Position',pos, ...
                              'FontSize',fontSize, ...
                              'Style','pushbutton',...
                              'Callback',@(s,e)OpenEngineLog(this), ...
                              'String','Log');
            %--------------------------------------------------------------
            
            %--------------------------------------------------------------
            % Search panel
            %--------------------------------------------------------------
            % Create search uipanel
            xy0 = [db (2 * db + spxy(2))];
            uiph2 = uipanel('Parent',this.fig, ...
                           'Units','pixels', ...
                           'Position',[xy0 mpxy], ...
                           'FontSize',labelSize, ...
                           'TitlePosition','centertop', ...
                           'Title','Search');
            
            % Search types
            strs = {' Nodes',' nodes';' Depth',' plies';' Time',' sec'};
            pos = @(i,j) [(j * dt + sum(dxm(1:(j - 1)))) ...
                          (i * dy + (i + 1) * dt) dxm(j) dy];
            for i = 1:3
                % Search mode selection
                this.mh(i,1) = uicontrol('Parent',uiph2,...
                           'Units','pixels', ...
                           'Position',pos(i,1), ...
                           'Style','checkbox',...
                           'Callback',@(s,e)ChangeSearchMode(this,i), ...
                           'FontSize',fontSize);
                
                % Field name
                this.mh(i,2) = uicontrol('Parent',uiph2,...
                           'Units','pixels', ...
                           'Position',pos(i,2), ...
                           'Style','edit',...
                           'FontSize',fontSize, ...
                           'HorizontalAlignment','left', ...
                           'String',strs{i,1});
                
                % Field edit box
                this.mh(i,3) = uicontrol('Parent',uiph2,...
                           'Units','pixels', ...
                           'Position',pos(i,3), ...
                           'Style','edit',...
                           'Callback',@(s,e)ChangeSearchVal(this,i), ...
                           'FontSize',fontSize, ...
                           'HorizontalAlignment','center');
                
                % Field units
                this.mh(i,4) = uicontrol('Parent',uiph2,...
                           'Units','pixels', ...
                           'Position',pos(i,4), ...
                           'Style','edit',...
                           'FontSize',fontSize, ...
                           'HorizontalAlignment','left', ...
                           'String',strs{i,2});
            end
            
            % Play/analysis modes
            pos = @(j) [(j * dt + sum(dxa(1:(j - 1)))) ...
                        (4 * dy + 5 * dt) dxa(j) dy];
            strs = {' Play',' Analyze'};
            for j = 1:2
                % Checkboxes
                this.mh(4,j) = uicontrol('Parent',uiph2,...
                          'Units','pixels', ...
                          'Position',pos(2 * j - 1), ...
                          'Style','checkbox',...
                          'Callback',@(s,e)ChangePlayMode(this,j), ...
                          'FontSize',fontSize, ...
                          'Value',(this.playMode == j));
                
                % Text
                this.mh(4,j + 2) = uicontrol('Parent',uiph2,...
                          'Units','pixels', ...
                          'Position',pos(2 * j), ...
                          'HorizontalAlignment','left', ...
                          'Style','edit',...
                          'String',strs{j}, ...
                          'FontSize',fontSize);
            end
            
            % Execution mode popup
            pos = [(dt + 0.5 * (dx - dxp)) (5 * dy + 6.5 * dt) dxp dy];
            strs = {'Manual','Auto-White','Auto-Black','Auto-Both'};
            this.mh(5,1) = uicontrol('Parent',uiph2,...
                          'Units','pixels', ...
                          'Position',pos, ...
                          'FontSize',fontSize, ...
                          'Style','popup',...
                          'Callback',@(s,e)ChangeExecMode(this), ...
                          'String',strs, ...
                          'Value',this.execMode);
            
            % Move pushbutton
            pos = [dt dt dx dy] + (dx - dxb) * [0.5 0 -1 0];
            this.mh(5,2) = uicontrol('Parent',uiph2,...
                          'Units','pixels', ...
                          'Position',pos, ...
                          'FontSize',fontSize, ...
                          'Style','pushbutton', ...
                          'Callback',@(s,e)SearchButtonPress(this));
            %--------------------------------------------------------------
            
            %--------------------------------------------------------------
            % Stats panel
            %--------------------------------------------------------------
            % Create stats uipanel
            xy0 = [db db];
            uiph3 = uipanel('Parent',this.fig, ...
                                'Units','pixels', ...
                                'Position',[xy0 spxy], ...
                                'FontSize',labelSize, ...
                                'TitlePosition','centertop', ...
                                'Title','Stats');
            
            % Stats fields
            strs = {this.engineStats.str ''};
            pos = @(i,j) [(j * dt + sum(dxs(1:(j - 1)))) ...
                          (i * dt + (i - 1) * dy) dxs(j) dy];
            for i = 1:(ns + 1)
                % Field label
                this.sh(i,1) = uicontrol('Parent',uiph3,...
                                'Units','pixels', ...
                                'Position',pos(i,1), ...
                                'Style','edit',...
                                'FontSize',fontSize, ...
                                'HorizontalAlignment','left', ...
                                'Enable','inactive', ...
                                'String',[' ' strs{i}]);
                
                % Field edit box
                this.sh(i,2) = uicontrol('Parent',uiph3,...
                                'Units','pixels', ...
                                'Position',pos(i,2), ...
                                'Style','edit',...
                                'FontSize',fontSize, ...
                                'HorizontalAlignment','center', ...
                                'Enable','inactive');
            end
            %--------------------------------------------------------------
            
            % Initialize search panel
            this.UpdatePlayMode();
            this.UpdateSearchPanel();
            
            % Set figure to visible
            set(this.fig,'Visible','on');
        end
        
        %
        % Reset GUI
        %
        function ResetGUI(this)
            % Reset internal variables
            this.newGame = true;
            this.lastAnalyzedMove = -1;
            
            % Release locks
            this.qlock = false;
            this.ReleaseThinkingLock(false);
            this.ReleaseAutoLock();
            
            % Reset execution mode
            set(this.eh(1),'Value',this.engineIdx + 1);
            
            % Reset stats panel
            this.ClearStats();
        end
        
        %
        % Initialize stats display
        %
        function InitializeStatsDisplay(this)
            % Save display indices for supported stats
            % NOTE: Must match switch cases from this.UpdateStats()
            stats = {this.engineStats.name};
            this.statInds = struct('score',ismember(stats,'score'), ...
                                 'depth',ismember(stats,'depth'), ...
                                 'nodes',ismember(stats,'nodes'), ...
                                 'nps',ismember(stats,'nps'), ...
                                 'time',ismember(stats,'time'), ...
                                 'hashfull',ismember(stats,'hashfull'), ...
                                 'cpuload',ismember(stats,'cpuload'));
        end
        
        %
        % Clear stats panel
        %
        function ClearStats(this)
            % Clear stats entries
            set(this.sh(:,2),'String','');
        end
        
        %
        % Handle key press
        %
        function HandleKeyPress(this,event)
            % Get keypress
            key = double(event.Character);
            modifiers = event.Modifier;
            
            % Check for ctrl + w
            if (any(ismember(modifiers,{'command','control'})) && ...
                any(ismember(key,[23 87 119])))
                % Close GUI
                this.Close();
                return;
            end
        end
        
        %
        % Get center coordinates of GUI
        %
        function xyc = GetCenterCoordinates(this)
            % Infer center coordinates from GUI position
            pos = get(this.fig,'Position');
            xyc = pos(1:2) + 0.5 * pos(3:4);
        end
        
        %
        % Flush graphics
        %
        function FlushGraphics(this,varargin) %#ok
            if ((nargin < 2) || (varargin{1} == true))
                % Flush graphics
                drawnow;
            end
        end
    end
    
    %
    % Static methods
    %
    methods (Access = private, Static = true)
        %
        % Change the enable state and color of the given uicontrols
        %
        function EnableUIcontrol(uih,str)
            % Make the enable change
            set(uih,'Enable',str);
            
            % ***** HACK: Force background color application on mac *****
            switch str
                case 'on'
                    % change to active color
                    set(uih,'BackgroundColor',[0 0 0]);
                    set(uih,'BackgroundColor',ChessEngine.ACTIVE);
                case 'inactive'
                    % Change to inactive color
                    set(uih,'BackgroundColor',[0 0 0]);
                    set(uih,'BackgroundColor',ChessEngine.INACTIVE);
                %case 'off'
                    % Empty
            end
        end
    end
end
