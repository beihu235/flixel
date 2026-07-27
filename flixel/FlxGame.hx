package flixel;

import flixel.graphics.tile.FlxDrawBaseItem;
import flixel.system.FlxSplash;
import flixel.util.FlxArrayUtil;
import flixel.util.FlxDestroyUtil;
import flixel.util.typeLimit.NextState;
import openfl.Assets;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.display.StageAlign;
import openfl.display.StageScaleMode;
import openfl.events.Event;
import openfl.filters.BitmapFilter;
#if desktop
import openfl.events.FocusEvent;
#end
#if FLX_POST_PROCESS
import flixel.effects.postprocess.PostProcess;
import openfl.display.OpenGLView;
#end
#if FLX_DEBUG
import flixel.system.debug.FlxDebugger;
#end
#if FLX_SOUND_TRAY
import flixel.system.ui.FlxSoundTray;
#end
#if FLX_FOCUS_LOST_SCREEN
import flixel.system.ui.FlxFocusLostScreen;
#end
#if FLX_RECORD
import flixel.math.FlxRandom;
import flixel.system.replay.FlxReplay;
#end

/**
 * `FlxGame` is the heart of all Flixel games, and contains a bunch of basic game loops and things.
 * It is a long and sloppy file that you shouldn't have to worry about too much!
 * It is basically only used to create your game object in the first place,
 * after that `FlxG` and `FlxState` have all the useful stuff you actually need.
 */
@:allow(flixel.FlxG)
class FlxGame extends Sprite
{
	#if sys
	static var __novaPerfTrace:Bool = Sys.getEnv("NOVAGC_PERF_TRACE") != null;
	static var __novaUpdateWindowStart:Float = 0.0;
	static var __novaUpdateCount:Int = 0;
	static var __novaUpdateTotal:Float = 0.0;
	static var __novaUpdateState:Float = 0.0;
	static var __novaUpdateMax:Float = 0.0;
	static var __novaDrawWindowStart:Float = 0.0;
	static var __novaDrawCount:Int = 0;
	static var __novaDrawTotal:Float = 0.0;
	static var __novaDrawPrep:Float = 0.0;
	static var __novaDrawState:Float = 0.0;
	static var __novaDrawCameras:Float = 0.0;
	static var __novaDrawPost:Float = 0.0;
	static var __novaDrawMax:Float = 0.0;
	#end
	/**
	 * Framerate to use on focus lost. Default is `10`.
	 */
	public var focusLostFramerate:Int = 10;

	#if FLX_RECORD
	/**
	 * Flag for whether a replay is currently playing.
	 */
	@:allow(flixel.system.frontEnds.VCRFrontEnd)
	public var replaying(default, null):Bool = false;

	/**
	 * Flag for whether a new recording is being made.
	 */
	@:allow(flixel.system.frontEnds.VCRFrontEnd)
	public var recording(default, null):Bool = false;
	#end

	#if FLX_SOUND_TRAY
	/**
	 * The sound tray display container.
	 */
	public var soundTray(default, null):FlxSoundTray;
	#end

	#if FLX_DEBUG
	/**
	 * The debugger overlay object.
	 */
	public var debugger(default, null):FlxDebugger;
	#end

	/**
	 * Time in milliseconds that has passed (amount of "ticks" passed) since the game has started.
	 */
	public var ticks(default, null):Int = 0;

	/**
	 * Enables or disables the filters set via `setFilters()`.
	 */
	public var filtersEnabled:Bool = true;

	/**
	 * A flag for triggering the `preGameStart` and `postGameStart` "events".
	 */
	@:allow(flixel.FlxIntroSplash)
	var _gameJustStarted:Bool = false;

	/**
	 * Class type of the initial/first game state for the game, usually `MenuState` or something like that.
	 */
	var _initialState:NextState;

	/**
	 * Current game state.
	 */
	var _state:FlxState;

	/**
	 * Total number of milliseconds elapsed since game start.
	 */
	var _total:Int = 0;
	/**
	 * Ticks at the last draw call for computing drawElapsed.
	 */
	var _lastDrawTicks:Int = 0;

	/**
	 * Time stamp of game startup. Needed on JS where `Lib.getTimer()`
	 * returns time stamp of current date, not the time passed since app start.
	 */
	var _startTime:Int = 0;

	/**
	 * Total number of milliseconds elapsed since last update loop.
	 * Counts down as we step through the game loop.
	 */
	var _accumulator:Float;

	/**
	 * Milliseconds of time since last step.
	 */
	var _elapsedMS:Float;

	/**
	 * Milliseconds of time per step of the game loop. e.g. 60 fps = 16ms.
	 */
	var _stepMS:Float;

	/**
	 * Optimization so we don't have to divide step by 1000 to get its value in seconds every frame.
	 */
	var _stepSeconds:Float;

	/**
	 * Max allowable accumulation (see `_accumulator`).
	 * Should always (and automatically) be set to roughly 2x the stage framerate.
	 */
	var _maxAccumulation:Float;

	/**
	 * Whether the game lost focus.
	 */
	var _lostFocus:Bool = false;

	/**
	 * The filters array to be applied to the game.
	 */
	var _filters:Array<BitmapFilter>;

	#if (desktop && lime_legacy)
	/**
	 * Ugly workaround to ensure consistent behaviour between flash and cpp
	 * (the focus event should not fire when the game starts up!)
	 */
	var _onFocusFiredOnce:Bool = false;
	#end

	#if FLX_FOCUS_LOST_SCREEN
	/**
	 * The "focus lost" screen.
	 */
	var _focusLostScreen:FlxFocusLostScreen;
	#end

	/**
	 * Mouse cursor.
	 */
	@:allow(flixel.FlxG)
	@:allow(flixel.system.frontEnds.CameraFrontEnd)
	var _inputContainer:Sprite;

	#if FLX_SOUND_TRAY
	/**
	 * Change this after calling `super()` in the `FlxGame` constructor
	 * to use a customized sound tray based on `FlxSoundTray`.
	 */
	var _customSoundTray:Class<FlxSoundTray> = FlxSoundTray;
	#end

	#if FLX_FOCUS_LOST_SCREEN
	/**
	 * Change this after calling `super()` in the `FlxGame` constructor
	 * to use a customized screen which will be show when the application lost focus.
	 */
	var _customFocusLostScreen:Class<FlxFocusLostScreen> = FlxFocusLostScreen;
	#end

	/**
	 * Whether the splash screen should be skipped.
	 */
	var _skipSplash:Bool = false;

	#if desktop
	/**
	 * Should we start fullscreen or not? This is useful if you want to load fullscreen settings from a
	 * `FlxSave` and set it when the game starts, instead of having it hard-set in your `Project.xml`.
	 */
	var _startFullscreen:Bool = false;
	#end

	/**
	 * If a state change was requested, the new state object is stored here until we switch to it.
	 */
	var _nextState:NextState;

	/**
	 * A flag for keeping track of whether a game reset was requested or not.
	 */
	var _resetGame:Bool = false;

	#if FLX_RECORD
	/**
	 * Container for a game replay object.
	 */
	@:allow(flixel.system.frontEnds.VCRFrontEnd)
	var _replay:FlxReplay;

	/**
	 * Flag for whether a playback of a recording was requested.
	 */
	@:allow(flixel.system.frontEnds.VCRFrontEnd)
	var _replayRequested:Bool = false;

	/**
	 * Flag for whether a new recording was requested.
	 */
	@:allow(flixel.system.frontEnds.VCRFrontEnd)
	var _recordingRequested:Bool = false;
	#end

	#if FLX_POST_PROCESS
	/**
	 * `Sprite` for postprocessing effects
	 */
	var postProcessLayer:Sprite = new Sprite();

	/**
	 * Post process effects active on the `postProcessLayer`.
	 */
	var postProcesses:Array<PostProcess> = [];
	#end

	/**
	 * Instantiate a new game object.
	 *
	 * @param gameWidth        The width of your game in pixels. If `0`, the `Project.xml` width is used.
	 *                         If the demensions don't match the `Project.xml`, 
	 *                         [`scaleMode`](https://api.haxeflixel.com/flixel/system/scaleModes/index.html)
	 *                         will determine the actual display size of the game.
	 * @param gameHeight       The height of your game in pixels. If `0`, the `Project.xml` height is used.
	 *                         If the demensions don't match the `Project.xml`, 
	 *                         [`scaleMode`](https://api.haxeflixel.com/flixel/system/scaleModes/index.html)
	 *                         will determine the actual display size of the game.
	 * @param initialState     A constructor for the initial state, ex: `PlayState.new` or `()->new PlayState()`.
	 *                         Note: Also allows `Class<FlxState>` for backwards compatibility.
	 * @param updateFramerate  How frequently the game should update. Default is 60 fps.
	 * @param drawFramerate    Sets the actual display / draw framerate for the game. Default is 60 fps.
	 * @param skipSplash       Whether you want to skip the flixel splash screen with `FLX_NO_DEBUG`.
	 * @param startFullscreen  Whether to start the game in fullscreen mode (desktop targets only).
	 *
	 * @see [scale modes](https://api.haxeflixel.com/flixel/system/scaleModes/index.html)
	 */
	public function new(gameWidth = 0, gameHeight = 0, ?initialState:InitialState, updateFramerate = 60, drawFramerate = 60, skipSplash = false,
			startFullscreen = false)
	{
		super();

		#if desktop
		_startFullscreen = startFullscreen;
		#end

		// Super high priority init stuff
		_inputContainer = new Sprite();

		if (gameWidth == 0)
			gameWidth = FlxG.stage.stageWidth;
		if (gameHeight == 0)
			gameHeight = FlxG.stage.stageHeight;

		// Basic display and update setup stuff
		FlxG.init(this, gameWidth, gameHeight);

		FlxG.fixedStepMS = FlxG.fixedStepMS;
		FlxG.updateFramerate = updateFramerate;
		FlxG.drawFramerate = drawFramerate;
		_accumulator = _stepMS;
		_skipSplash = skipSplash;

		#if FLX_RECORD
		_replay = new FlxReplay();
		#end

		// Then get ready to create the game object for real
		_initialState = (initialState == null) ? FlxState.new : initialState.toNextState();

		addEventListener(Event.ADDED_TO_STAGE, create);
	}

	public function setInitialState(initialState:InitialState):Void
	{
		_initialState = initialState.toNextState();
	}

	/**
	 * Sets the filter array to be applied to the game.
	 */
	public function setFilters(filters:Array<BitmapFilter>):Void
	{
		_filters = filters;
	}

	/**
	 * Used to instantiate the guts of the flixel game object once we have a valid reference to the root.
	 */
	function create(_):Void
	{
		if (stage == null)
			return;

		removeEventListener(Event.ADDED_TO_STAGE, create);

		_startTime = getTimer();
		_total = getTicks();

		#if desktop
		FlxG.fullscreen = _startFullscreen;
		#end

		// Set up the view window and double buffering
		stage.scaleMode = StageScaleMode.NO_SCALE;
		stage.align = StageAlign.TOP_LEFT;
		#if !flash
		if (stage.window != null)
		{
			stage.window.lockRender = true;
			stage.window.drawFrameRate = FlxG.drawFramerate;
			stage.window.frameRate = FlxG.fixedTimestep ? Std.int(1000 / FlxG.fixedStepMS) : FlxG.updateFramerate;
		}
		else
		{
			stage.frameRate = FlxG.drawFramerate;
		}
		#else
		stage.frameRate = FlxG.drawFramerate;
		#end

		addChild(_inputContainer);

		#if FLX_POST_PROCESS
		if (OpenGLView.isSupported)
			addChild(postProcessLayer);
		#end

		// Creating the debugger overlay
		#if FLX_DEBUG
		debugger = new FlxDebugger(FlxG.stage.stageWidth, FlxG.stage.stageHeight);
		addChild(debugger);
		#end

		// No need for overlays on mobile.
		#if !mobile
		// Volume display tab
		#if FLX_SOUND_TRAY
		soundTray = Type.createInstance(_customSoundTray, []);
		addChild(soundTray);
		#end

		#if FLX_FOCUS_LOST_SCREEN
		_focusLostScreen = Type.createInstance(_customFocusLostScreen, []);
		addChild(_focusLostScreen);
		#end
		#end

		// Focus gained/lost monitoring
		#if (desktop && openfl <= "4.0.0")
		stage.addEventListener(FocusEvent.FOCUS_OUT, onFocusLost);
		stage.addEventListener(FocusEvent.FOCUS_IN, onFocus);
		#elseif (sys && openfl >= "9.3.0")
		stage.nativeWindow.addEventListener(Event.DEACTIVATE, onFocusLost);
		stage.nativeWindow.addEventListener(Event.ACTIVATE, onFocus);
		#else
		stage.addEventListener(Event.DEACTIVATE, onFocusLost);
		stage.addEventListener(Event.ACTIVATE, onFocus);
		#end

		// Instantiate the initial state
		resetGame();
		switchState();

		if (FlxG.updateFramerate < FlxG.drawFramerate)
			FlxG.log.warn("FlxG.updateFramerate: The update framerate shouldn't be smaller" + " than the draw framerate, since it can slow down your game.");

		// Finally, set up an event for the actual game loop stuff.
		stage.addEventListener(Event.ENTER_UPDATE, onEnterUpdate);
		stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);

		// We need to listen for resize event which means new context
		// it means that we need to recreate BitmapDatas of dumped tilesheets
		stage.addEventListener(Event.RESIZE, onResize);

		// make sure the cursor etc are properly scaled from the start
		resizeGame(FlxG.stage.stageWidth, FlxG.stage.stageHeight);

		Assets.addEventListener(Event.CHANGE, FlxG.bitmap.onAssetsReload);
	}

	function onFocus(_):Void
	{
		#if flash
		if (!_lostFocus)
			return; // Don't run this function twice (bug in standalone flash player)
		#end

		#if (desktop && lime_legacy)
		// make sure the on focus event doesn't fire on startup
		if (!_onFocusFiredOnce)
		{
			_onFocusFiredOnce = true;
			return;
		}
		#end

		#if mobile
		// just check if device orientation has been changed
		onResize(_);
		#end

		_lostFocus = false;
		FlxG.signals.focusGained.dispatch();
		_state.onFocus();

		if (!FlxG.autoPause)
			return;

		#if FLX_FOCUS_LOST_SCREEN
		if (_focusLostScreen != null)
			_focusLostScreen.visible = false;
		#end

		#if FLX_DEBUG
		debugger.stats.onFocus();
		#end

		#if !flash
		if (stage.window != null)
		{
			// ENTER_UPDATE and ENTER_FRAME are independent in this fork. Restoring
			// only Stage.frameRate overwrote the update clock with the render rate
			// every time the window regained focus.
			stage.window.frameRate = FlxG.fixedTimestep ? Std.int(1000 / FlxG.fixedStepMS) : FlxG.updateFramerate;
			stage.window.drawFrameRate = FlxG.drawFramerate;
			stage.window.lockRender = true;
		}
		else
			stage.frameRate = FlxG.drawFramerate;
		#else
		stage.frameRate = FlxG.drawFramerate;
		#end
		#if FLX_SOUND_SYSTEM
		FlxG.sound.onFocus();
		#end
		FlxG.inputs.onFocus();
	}

	function onFocusLost(event:Event):Void
	{
		#if next
		if (event != null && event.target != FlxG.stage)
			return;
		#end

		#if flash
		if (_lostFocus)
			return; // Don't run this function twice (bug in standalone flash player)
		#end

		_lostFocus = true;
		FlxG.signals.focusLost.dispatch();
		_state.onFocusLost();

		if (!FlxG.autoPause)
			return;

		#if FLX_FOCUS_LOST_SCREEN
		if (_focusLostScreen != null)
			_focusLostScreen.visible = true;
		#end

		#if FLX_DEBUG
		debugger.stats.onFocusLost();
		#end

		stage.frameRate = focusLostFramerate;
		#if FLX_SOUND_SYSTEM
		FlxG.sound.onFocusLost();
		#end
		FlxG.inputs.onFocusLost();
	}

	@:allow(flixel.FlxG)
	function onResize(_):Void
	{
		var width:Int = FlxG.stage.stageWidth;
		var height:Int = FlxG.stage.stageHeight;

		#if !flash
		if (FlxG.renderTile)
			FlxG.bitmap.onContext();
		#end

		resizeGame(width, height);
	}

	function resizeGame(width:Int, height:Int):Void
	{
		FlxG.resizeGame(width, height);

		_state.onResize(width, height);

		FlxG.cameras.resize();
		FlxG.signals.gameResized.dispatch(width, height);

		#if FLX_DEBUG
		debugger.onResize(width, height);
		#end

		#if FLX_FOCUS_LOST_SCREEN
		if (_focusLostScreen != null)
			_focusLostScreen.draw();
		#end

		#if FLX_SOUND_TRAY
		if (soundTray != null)
			soundTray.screenCenter();
		#end

		#if FLX_POST_PROCESS
		for (postProcess in postProcesses)
			postProcess.rebuild();
		#end
	}

	/**
	 * Handles the `onEnterFrame` call and figures out how many updates and draw calls to do.
	 */
	function onEnterFrame(_):Void
	{
		#if FLX_DEBUG
		FlxBasic.visibleCount = 0;
		#end

		// Rebuild every frame so the draw clock represents actual scene traversal
		// and GPU submission, not repeated presentation of a retained 60 Hz image.
		draw();

		#if FLX_DEBUG
		debugger.stats.visibleObjects(FlxBasic.visibleCount);
		debugger.update();
		#end
	}

	/**
	 * Dedicated update handler extracted from `onEnterFrame`.
	 * Responsible for ticking timers, handling input, and advancing game logic.
	 */
	function onEnterUpdate(_):Void
	{
		ticks = getTicks();
		_elapsedMS = ticks - _total;
		_total = ticks;

		#if FLX_SOUND_TRAY
		if (soundTray != null && soundTray.active)
			soundTray.update(_elapsedMS);
		#end

		if (!_lostFocus || !FlxG.autoPause)
		{
			if (FlxG.vcr.paused)
			{
				if (FlxG.vcr.stepRequested)
				{
					FlxG.vcr.stepRequested = false;
				}
				else if (_nextState == null) // don't pause a state switch request
				{
					#if FLX_DEBUG
					debugger.update();
					#end
					return;
				}
			}

			if (FlxG.fixedTimestep)
			{
				_stepMS = FlxG.fixedStepMS;
				_stepSeconds = _stepMS / 1000;
				_accumulator += _elapsedMS;
				_accumulator = (_accumulator > _maxAccumulation) ? _maxAccumulation : _accumulator;

				while (_accumulator >= _stepMS)
				{
					step();
					_accumulator -= _stepMS;
				}
			}
			else
			{
				step();
			}
		}
	}

	/**
	 * Internal method to create a new instance of `_initialState` and reset the game.
	 * This gets called when the game is created, as well as when a new state is requested.
	 */
	inline function resetGame():Void
	{
		FlxG.signals.preGameReset.dispatch();

		#if FLX_DEBUG
		_skipSplash = true;
		#end
		
		if (_skipSplash)
		{
			_nextState = _initialState;
			_gameJustStarted = true;
		}
		else
		{
			_nextState = ()->new FlxIntroSplash(_initialState);
			_skipSplash = true; // only play it once
		}

		FlxG.reset();

		FlxG.signals.postGameReset.dispatch();
	}

	/**
	 * If there is a state change requested during the update loop,
	 * this function handles actual destroying the old state and related processes,
	 * and calls creates on the new state and plugs it into the game object.
	 */
	function switchState():Void
	{
		// Basic reset stuff
		FlxG.cameras.reset();
		FlxG.inputs.onStateSwitch();
		#if FLX_SOUND_SYSTEM
		FlxG.sound.destroy();
		#end

		FlxG.signals.preStateSwitch.dispatch();

		#if FLX_RECORD
		FlxRandom.updateStateSeed();
		#end

		// Destroy the old state (if there is an old state)
		if (_state != null)
			_state.destroy();

		// we need to clear bitmap cache only after previous state is destroyed, which will reset useCount for FlxGraphic objects
		FlxG.bitmap.clearCache();

		// Finally assign and create the new state
		_state = _nextState.createInstance();
		_state._constructor = _nextState;
		_nextState = null;

		if (_gameJustStarted)
			FlxG.signals.preGameStart.dispatch();

		FlxG.signals.preStateCreate.dispatch(_state);

		_state.create();

		if (_gameJustStarted)
			gameStart();

		#if FLX_DEBUG
		debugger.console.registerObject("state", _state);
		#end

		FlxG.signals.postStateSwitch.dispatch();
	}

	function gameStart():Void
	{
		FlxG.signals.postGameStart.dispatch();
		_gameJustStarted = false;
	}

	/**
	 * This is the main game update logic section.
	 * The `onEnterFrame()` handler is in charge of calling this
	 * the appropriate number of times each frame.
	 * This block handles state changes, replays, all that good stuff.
	 */
	function step():Void
	{
		// Handle game reset request
		if (_resetGame)
		{
			resetGame();
			_resetGame = false;
		}

		handleReplayRequests();

		#if FLX_DEBUG
		// Finally actually step through the game physics
		FlxBasic.activeCount = 0;
		#end

		update();

		#if FLX_DEBUG
		debugger.stats.activeObjects(FlxBasic.activeCount);
		#end
	}

	function handleReplayRequests():Void
	{
		#if FLX_RECORD
		// Handle replay-related requests
		if (_recordingRequested)
		{
			_recordingRequested = false;
			_replay.create(FlxRandom.getRecordingSeed());
			recording = true;

			#if FLX_DEBUG
			debugger.vcr.recording();
			FlxG.log.notice("Starting new flixel gameplay record.");
			#end
		}
		else if (_replayRequested)
		{
			_replayRequested = false;
			_replay.rewind();
			FlxG.random.initialSeed = _replay.seed;

			#if FLX_DEBUG
			debugger.vcr.playingReplay();
			#end

			replaying = true;
		}
		#end
	}

	/**
	 * This function is called by `step()` and updates the actual game state.
	 * May be called multiple times per "frame" or draw call.
	 */
	function update():Void
	{
		if (!_state.active || !_state.exists)
			return;
		#if sys
		var __novaStarted = __novaPerfTrace ? haxe.Timer.stamp() : 0.0;
		var __novaBeforeState = 0.0;
		var __novaAfterState = 0.0;
		#end

		if (_nextState != null)
			switchState();

		#if FLX_DEBUG
		if (FlxG.debugger.visible)
			ticks = getTicks();
		#end

		updateElapsed();

		var fixedElapsed = FlxG.timeScale * (FlxG.fixedStepMS / 1000);
		_state.tryFixedStepUpdate(fixedElapsed);

		FlxG.signals.preUpdate.dispatch();

		_state.tryHandleInput(FlxG.elapsed);
		updateInput();

		#if FLX_SOUND_SYSTEM
		FlxG.sound.update(FlxG.elapsed);
		#end

		#if FLX_POST_PROCESS
		if (postProcesses[0] != null)
			postProcesses[0].update(FlxG.elapsed);
		#end

		FlxG.plugins.update(FlxG.elapsed);

		#if sys
		if (__novaPerfTrace) __novaBeforeState = haxe.Timer.stamp();
		#end
		_state.tryUpdate(FlxG.elapsed);
		#if sys
		if (__novaPerfTrace) __novaAfterState = haxe.Timer.stamp();
		#end

		FlxG.cameras.update(FlxG.elapsed);
		FlxG.signals.postUpdate.dispatch();

		#if FLX_DEBUG
		debugger.stats.flixelUpdate(getTicks() - ticks);
		#end

		#if FLX_POINTER_INPUT
		var len = FlxG.swipes.length;
		while(len-- > 0)
		{
			final swipe = FlxG.swipes.pop();
			if (swipe != null)
				swipe.destroy();
		}
		#end

		filters = filtersEnabled ? _filters : null;
		#if sys
		if (__novaPerfTrace)
		{
			var __novaEnded = haxe.Timer.stamp();
			var __novaTotal = __novaEnded - __novaStarted;
			var __novaState = __novaAfterState - __novaBeforeState;
			if (__novaTotal >= 0.02)
				Sys.println('perf:FlxGame.update.slow total_ms=${Math.round(__novaTotal * 1000)} state_ms=${Math.round(__novaState * 1000)} state=${Type.getClassName(Type.getClass(_state))}');

			if (__novaUpdateWindowStart == 0.0) __novaUpdateWindowStart = __novaStarted;
			__novaUpdateCount++;
			__novaUpdateTotal += __novaTotal;
			__novaUpdateState += __novaState;
			if (__novaTotal > __novaUpdateMax) __novaUpdateMax = __novaTotal;
			if (__novaEnded - __novaUpdateWindowStart >= 1.0)
			{
				var __novaScale = 1000000.0 / __novaUpdateCount;
				Sys.println('perf:FlxGame.update.avg frames=$__novaUpdateCount total_us=${Math.round(__novaUpdateTotal * __novaScale)} state_us=${Math.round(__novaUpdateState * __novaScale)} other_us=${Math.round((__novaUpdateTotal - __novaUpdateState) * __novaScale)} max_us=${Math.round(__novaUpdateMax * 1000000)} state=${Type.getClassName(Type.getClass(_state))}');
				__novaUpdateWindowStart = __novaEnded;
				__novaUpdateCount = 0;
				__novaUpdateTotal = __novaUpdateState = __novaUpdateMax = 0.0;
			}
		}
		#end
	}

	function updateElapsed():Void
	{
		if (FlxG.fixedTimestep)
		{
			FlxG.elapsed = FlxG.timeScale * _stepSeconds; // fixed timestep
		}
		else
		{
			var e = FlxG.timeScale * (_elapsedMS / 1000); // variable timestep
			var max = FlxG.maxElapsed * FlxG.timeScale;
			if (e > max)
				e = max;

			FlxG.elapsed = e;
		}
	}

	function updateDrawElapsed():Void
	{
		var now = getTicks();
		if (_lastDrawTicks == 0)
		{
			_lastDrawTicks = now;
			FlxG.drawElapsed = 0;
			return;
		}
		var dtMS = now - _lastDrawTicks;
		_lastDrawTicks = now;

		var e = FlxG.timeScale * (dtMS / 1000);
		var max = FlxG.maxElapsed * FlxG.timeScale;
		if (e > max)
			e = max;

		FlxG.drawElapsed = e;
	}

	function updateInput():Void
	{
		#if FLX_RECORD
		if (replaying)
		{
			_replay.playNextFrame();

			if (FlxG.vcr.timeout > 0)
			{
				FlxG.vcr.timeout -= _stepMS;

				if (FlxG.vcr.timeout <= 0)
				{
					if (FlxG.vcr.replayCallback != null)
					{
						FlxG.vcr.replayCallback();
						FlxG.vcr.replayCallback = null;
					}
					else
					{
						FlxG.vcr.stopReplay();
					}
				}
			}

			if (replaying && _replay.finished)
			{
				FlxG.vcr.stopReplay();

				if (FlxG.vcr.replayCallback != null)
				{
					FlxG.vcr.replayCallback();
					FlxG.vcr.replayCallback = null;
				}
			}

			#if FLX_DEBUG
			debugger.vcr.updateRuntime(_stepMS);
			#end
		}
		else
		{
			FlxG.inputs.handleInput();
		}
		#else
		FlxG.inputs.handleInput();
		#end

		#if FLX_RECORD
		if (recording)
		{
			_replay.recordFrame();

			#if FLX_DEBUG
			debugger.vcr.updateRuntime(_stepMS);
			#end
		}
		#end
	}

	/**
	 * Goes through the game state and draws all the game objects and special effects.
	 */
	function draw():Void
	{
		if (!_state.visible || !_state.exists)
			return;
		#if sys
		var __novaStarted = __novaPerfTrace ? haxe.Timer.stamp() : 0.0;
		var __novaBeforeState = 0.0;
		var __novaAfterState = 0.0;
		var __novaAfterCameras = 0.0;
		#end

		#if FLX_DEBUG
		if (FlxG.debugger.visible)
			ticks = getTicks();
		#end

		updateDrawElapsed();
		_state.tryDrawUpdate(FlxG.drawElapsed);
		FlxG.signals.preDraw.dispatch();

		if (FlxG.renderTile)
			FlxDrawBaseItem.drawCalls = 0;

		#if FLX_POST_PROCESS
		if (postProcesses[0] != null)
			postProcesses[0].capture();
		#end

		FlxG.cameras.lock();
		#if sys
		if (__novaPerfTrace) __novaBeforeState = haxe.Timer.stamp();
		#end

		if (FlxG.plugins.drawOnTop)
		{
			_state.draw();
			FlxG.plugins.draw();
		}
		else
		{
			FlxG.plugins.draw();
			_state.draw();
		}
		#if sys
		if (__novaPerfTrace) __novaAfterState = haxe.Timer.stamp();
		#end

		if (FlxG.renderTile)
		{
			FlxG.cameras.render();
			#if sys
			if (__novaPerfTrace) __novaAfterCameras = haxe.Timer.stamp();
			#end

			#if FLX_DEBUG
			debugger.stats.drawCalls(FlxDrawBaseItem.drawCalls);
			#end
		}

		FlxG.cameras.unlock();

		FlxG.signals.postDraw.dispatch();
		#if sys
		if (__novaPerfTrace)
		{
			var __novaEnded = haxe.Timer.stamp();
			var __novaTotal = __novaEnded - __novaStarted;
			var __novaPrep = __novaBeforeState - __novaStarted;
			var __novaState = __novaAfterState - __novaBeforeState;
			var __novaCameras = __novaAfterCameras > 0.0 ? __novaAfterCameras - __novaAfterState : 0.0;
			var __novaPostStart = __novaAfterCameras > 0.0 ? __novaAfterCameras : __novaAfterState;
			var __novaPost = __novaEnded - __novaPostStart;
			if (__novaTotal >= 0.02)
				Sys.println('perf:FlxGame.draw.slow total_ms=${Math.round(__novaTotal * 1000)} state_ms=${Math.round(__novaState * 1000)} cameras_ms=${Math.round(__novaCameras * 1000)} state=${Type.getClassName(Type.getClass(_state))}');

			if (__novaDrawWindowStart == 0.0) __novaDrawWindowStart = __novaStarted;
			__novaDrawCount++;
			__novaDrawTotal += __novaTotal;
			__novaDrawPrep += __novaPrep;
			__novaDrawState += __novaState;
			__novaDrawCameras += __novaCameras;
			__novaDrawPost += __novaPost;
			if (__novaTotal > __novaDrawMax) __novaDrawMax = __novaTotal;
			if (__novaEnded - __novaDrawWindowStart >= 1.0)
			{
				var __novaScale = 1000000.0 / __novaDrawCount;
				Sys.println('perf:FlxGame.draw.avg frames=$__novaDrawCount total_us=${Math.round(__novaDrawTotal * __novaScale)} prep_us=${Math.round(__novaDrawPrep * __novaScale)} state_us=${Math.round(__novaDrawState * __novaScale)} cameras_us=${Math.round(__novaDrawCameras * __novaScale)} post_us=${Math.round(__novaDrawPost * __novaScale)} max_us=${Math.round(__novaDrawMax * 1000000)} state=${Type.getClassName(Type.getClass(_state))}');
				__novaDrawWindowStart = __novaEnded;
				__novaDrawCount = 0;
				__novaDrawTotal = __novaDrawPrep = __novaDrawState = __novaDrawCameras = __novaDrawPost = __novaDrawMax = 0.0;
			}
		}
		#end

		#if FLX_DEBUG
		debugger.stats.flixelDraw(getTicks() - ticks);
		#end
	}

	inline function getTicks()
	{
		return getTimer() - _startTime;
	}

	dynamic function getTimer():Int
	{
		// expensive, only call if necessary
		return Lib.getTimer();
	}
}

private class FlxIntroSplash extends FlxSplash
{
	override function startOutro(onOutroComplete:() -> Void)
	{
		FlxG.game._gameJustStarted = true;
		super.startOutro(onOutroComplete);
	}
}
