package flixel.sound;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.system.FlxAssets.FlxSoundAsset;
import flixel.tweens.FlxTween;
import flixel.util.FlxStringUtil;
import openfl.events.Event;
import openfl.events.IEventDispatcher;
import openfl.media.Sound;
import openfl.media.SoundChannel;
import openfl.media.SoundTransform;
import openfl.net.URLRequest;
#if CODENAME_ENGINE_COMPAT
import flixel.FlxObject;
import flixel.util.FlxSignal;
import lime.media.AudioBuffer;
import lime.media.AudioSource;
#end
#if flash11
import openfl.utils.ByteArray;
#end

#if hxvlc
import hxvlc.openfl.AudioGroup;
import hxvlc.util.Handle;
#end

/**
 * This is the universal flixel sound object, used for streaming, music, and sound effects.
 */
class FlxSound extends FlxBasic
{
	/**
	 * The x position of this sound in world coordinates.
	 * Only really matters if you are doing proximity/panning stuff.
	 */
	public var x:Float;
	
	/**
	 * The y position of this sound in world coordinates.
	 * Only really matters if you are doing proximity/panning stuff.
	 */
	public var y:Float;
	
	/**
	 * Whether or not this sound should be automatically destroyed when you switch states.
	 */
	public var persist:Bool;
	
	/**
	 * The ID3 song name. Defaults to null. Currently only works for streamed sounds.
	 */
	public var name(default, null):String;
	
	/**
	 * The ID3 artist name. Defaults to null. Currently only works for streamed sounds.
	 */
	public var artist(default, null):String;
	
	/**
	 * Stores the average wave amplitude of both stereo channels
	 */
	public var amplitude(default, null):Float;
	
	/**
	 * Just the amplitude of the left stereo channel
	 */
	public var amplitudeLeft(default, null):Float;
	
	/**
	 * Just the amplitude of the right stereo channel
	 */
	public var amplitudeRight(default, null):Float;
	
	/**
	 * Whether to call `destroy()` when the sound has finished playing.
	 */
	public var autoDestroy:Bool;
	
	/**
	 * Tracker for sound complete callback. If assigned, will be called
	 * each time when sound reaches its end.
	 */
	public var onComplete:Void->Void;
	
	/**
	 * Pan amount. -1 = full left, 1 = full right. Proximity based panning overrides this.
	 * 
	 * Note: On desktop targets this only works with mono sounds, due to limitations of OpenAL.
	 * More info: [OpenFL Forums - SoundTransform.pan does not work](https://community.openfl.org/t/windows-legacy-soundtransform-pan-does-not-work/6616/2?u=geokureli)
	 */
	public var pan(get, set):Float;
	
	/**
	 * Whether or not the sound is currently playing.
	 */
	public var playing(get, never):Bool;
	
	/**
	 * Set volume to a value between 0 and 1 to change how this sound is.
	 */
	public var volume(get, set):Float;

	#if CODENAME_ENGINE_COMPAT
	/** Independent per-sound mute flag used by Codename's charter and scripts. */
	public var muted(default, set):Bool = false;

	/** Whether the pitch should follow `FlxG.timeScale`. Default is true. */
	public var timeScaleBased:Bool = true;
	#end
	
	#if FLX_PITCH
	/**
	 * Set pitch, which also alters the playback speed. Default is 1.
	 */
	public var pitch(get, set):Float;
	#end
	
	/**
	 * The position in runtime of the music playback in milliseconds.
	 * If set while paused, changes only come into effect after a `resume()` call.
	 */
	public var time(get, set):Float;

	#if CODENAME_ENGINE_COMPAT
	/** Playback offset used by Codename music metadata. */
	public var offset:Float = 0;

	/** Whether an OpenFL sound resource is currently attached. */
	public var loaded(get, never):Bool;

	/** The Lime audio buffer backing the OpenFL sound. */
	public var buffer(get, never):AudioBuffer;

	/** The sound's "target" for proximity and panning. */
	public var target(get, set):Null<FlxObject>;

	/** The maximum effective radius of this sound for proximity and panning. */
	public var radius(get, set):Float;

	/** Whether the proximity alters the pan or not. */
	public var proximityPan(get, set):Bool;

	/** Scroll factor used for proximity with cameras. */
	public var scrollFactor(default, null):FlxPoint;

	/** Number of audio channels in the loaded sound. */
	public var channels(get, never):Int;

	/** Whether the sound is stereo (more than 1 channel). */
	public var stereo(get, never):Bool;

	/** Whether the sound is a vorbis stream. */
	public var streamed(get, never):Bool;

	/** Signal dispatched on sound completion, separate from onComplete/looping. */
	public final onFinish:FlxSignal = new FlxSignal();
	#end
	
	/**
	 * The length of the sound in milliseconds.
	 * @since 4.2.0
	 */
	public var length(get, never):Float;
	
	/**
	 * The sound group this sound belongs to, can only be in one group.
	 * NOTE: This setter is deprecated, use `group.add(sound)` or `group.remove(sound)`.
	 */
	public var group(default, set):FlxSoundGroup;
	
	/**
	 * Whether or not this sound should loop.
	 */
	public var looped:Bool;
	
	/**
	 * In case of looping, the point (in milliseconds) from where to restart the sound when it loops back
	 * @since 4.1.0
	 */
	public var loopTime:Float = 0;
	
	/**
	 * At which point to stop playing the sound, in milliseconds.
	 * If not set / `null`, the sound completes normally.
	 * @since 4.2.0
	 */
	public var endTime:Null<Float>;
	
	/**
	 * The tween used to fade this sound's volume in and out (set via `fadeIn()` and `fadeOut()`)
	 * @since 4.1.0
	 */
	public var fadeTween:FlxTween;
	
	/**
	 * Internal tracker for a Flash sound object.
	 */
	@:allow(flixel.system.frontEnds.SoundFrontEnd.load)
	var _sound:Sound;
	
	/**
	 * Internal tracker for a Flash sound channel object.
	 */
	var _channel:SoundChannel;

	#if CODENAME_ENGINE_COMPAT
	/** Compatibility view of OpenFL's active Lime audio source. */
	var _source(get, never):AudioSource;
	#end
	
	/**
	 * Internal tracker for a Flash sound transform object.
	 */
	var _transform:SoundTransform;
	
	/**
	 * Internal tracker for whether the sound is paused or not (not the same as stopped).
	 */
	var _paused:Bool;
	
	/**
	 * Internal tracker for volume.
	 */
	var _volume:Float;
	
	/**
	 * Internal tracker for sound channel position.
	 */
	var _time:Float = 0;
	
	/**
	 * Internal tracker for sound length, so that length can still be obtained while a sound is paused, because _sound becomes null.
	 */
	var _length:Float = 0;
	
	#if FLX_PITCH
	/**
	 * Internal tracker for pitch.
	 */
	var _pitch:Float = 1.0;
	#if CODENAME_ENGINE_COMPAT
	var _timeScaleAdjust:Float = 1.0;
	var _realPitch:Float = 1.0;
	#end
	#end
	
	/**
	 * Internal tracker for total volume adjustment.
	 */
	var _volumeAdjust:Float = 1.0;
	
	/**
	 * Internal tracker for the sound's "target" (for proximity and panning).
	 */
	var _target:FlxObject;
	
	/**
	 * Internal tracker for the maximum effective radius of this sound (for proximity and panning).
	 */
	var _radius:Float;
	
	/**
	 * Internal tracker for whether to pan the sound left and right.  Default is false.
	 */
	var _proximityPan:Bool;
	
	/**
	 * Helper var to prevent the sound from playing after focus was regained when it was already paused.
	 */
	var _alreadyPaused:Bool = false;

	#if hxvlc
	public var _vlcPlayer:AudioGroup;
	private var _onVLC:Bool = false;
	private var _vlcClockPollElapsed:Float = 0;
	private var _lastVlcTransformVolume:Float = Math.NaN;
	#end

	/**
	 * The FlxSound constructor gets all the variables initialized, but NOT ready to play a sound yet.
	 */
	public function new()
	{
		super();
		reset();
	}

	#if hxvlc
	private function _initVlc():Void
	{
		if (_vlcPlayer != null) return;

		try {
			Handle.init();
			_vlcPlayer = new AudioGroup();
			_vlcClockPollElapsed = 0;
			// A freshly-created AudioGroup must receive the current FlxSound
			// transform even when the previous player happened to use the same
			// volume. Otherwise the cached transform can leave the new OpenAL
			// source at a stale gain.
			_lastVlcTransformVolume = Math.NaN;
			
			_vlcPlayer.onEndReached.add(function() {
				FlxG.signals.postUpdate.addOnce(function() {
					if (_onVLC) stopped();
				});
			});
			_vlcPlayer.onEncounteredError.add(function(_) {
				FlxG.signals.postUpdate.addOnce(function() {
					if (_onVLC) cleanup(true);
				});
			});
		} catch (e:Dynamic) {
			FlxG.log.warn("FlxStreamSound: VLC init failed (will retry on load): " + e);
		}
	}
	#end
	
	/**
	 * An internal function for clearing all the variables used by sounds.
	 */
	#if CODENAME_ENGINE_COMPAT public #end function reset():Void
	{
		destroy();
		
		x = 0;
		y = 0;
		
		_time = 0;
		_paused = false;
		_volume = 1.0;
		#if CODENAME_ENGINE_COMPAT
		@:bypassAccessor muted = false;
		#end
		_volumeAdjust = 1.0;
		looped = false;
		loopTime = 0.0;
		endTime = 0.0;
		_target = null;
		_radius = 0;
		_proximityPan = false;
		visible = false;
		amplitude = 0;
		amplitudeLeft = 0;
		amplitudeRight = 0;
		autoDestroy = false;
		
		if (_transform == null)
			_transform = new SoundTransform();
		_transform.pan = 0;
	}
	
	override public function destroy():Void
	{
		// Prevents double destroy
		if (group != null)
			group.remove(this);
		
		_transform = null;
		exists = false;
		active = false;
		_target = null;
		name = null;
		artist = null;
		
		if (_channel != null)
		{
			_channel.removeEventListener(Event.SOUND_COMPLETE, stopped);
			_channel.stop();
			_channel = null;
		}
		
		if (_sound != null)
		{
			_sound.removeEventListener(Event.ID3, gotID3);
			_sound = null;
		}

		#if hxvlc
		_onVLC = false;
		if (_vlcPlayer != null)
		{
			try
			{
				_vlcPlayer.dispose();
			}
			catch (e:Dynamic) {}
			_vlcPlayer = null;
		}
		#end
		
		onComplete = null;
		
		super.destroy();
	}
	
	/**
	 * Handles fade out, fade in, panning, proximity, and amplitude operations each frame.
	 */
	override public function update(elapsed:Float):Void
	{
		#if hxvlc
		if (_onVLC)
		{
			// Playback lives in VLC/OpenAL. Advance a smooth engine-side clock and
			// reconcile it periodically instead of crossing into LibVLC twice on
			// every native (up to 2 kHz) update.
			if (_channel != null && !_paused)
				_time += elapsed * 1000;

			_vlcClockPollElapsed += elapsed;
			if (_vlcPlayer != null && _vlcClockPollElapsed >= 0.05)
			{
				_vlcClockPollElapsed = 0;
				final actualTime:Int = haxe.Int64.toInt(_vlcPlayer.time);
				if (actualTime >= 0 && (Math.abs(actualTime - _time) > 8 || _channel == null))
					_time = actualTime;
			}

			updateTransform();
			
			if (endTime != null && _time >= endTime)
			{
				stopped();
			}
			return;
		}
		#end

		if (!playing)
			return;
			
		_time = _channel.position;
		
		var radialMultiplier:Float = 1.0;
		
		// Distance-based volume control
		if (_target != null)
		{
			var targetPosition = _target.getPosition();
			radialMultiplier = targetPosition.distanceTo(FlxPoint.weak(x, y)) / _radius;
			targetPosition.put();
			radialMultiplier = 1 - FlxMath.bound(radialMultiplier, 0, 1);
			
			if (_proximityPan)
			{
				var d:Float = (x - _target.x) / _radius;
				_transform.pan = FlxMath.bound(d, -1, 1);
			}
		}
		
		_volumeAdjust = radialMultiplier;
		updateTransform();
		
		if (_transform.volume > 0)
		{
			amplitudeLeft = _channel.leftPeak / _transform.volume;
			amplitudeRight = _channel.rightPeak / _transform.volume;
			amplitude = (amplitudeLeft + amplitudeRight) * 0.5;
		}
		else
		{
			amplitudeLeft = 0;
			amplitudeRight = 0;
			amplitude = 0;
		}
		
		if (endTime != null && _time >= endTime)
			stopped();
	}
	
	override public function kill():Void
	{
		super.kill();
		cleanup(false);
	}
	
	/**
	 * One of the main setup functions for sounds, this function loads a sound from an embedded MP3.
	 *
	 * **Note:** If the `FLX_SOUND_ADD_EXT` flag is enabled, you may omit the file extension
	 *
	 * @param	EmbeddedSound	An embedded Class object representing an MP3 file.
	 * @param	Looped			Whether or not this sound should loop endlessly.
	 * @param	AutoDestroy		Whether or not this FlxSound instance should be destroyed when the sound finishes playing.
	 * 							Default value is false, but `FlxG.sound.play()` and `FlxG.sound.stream()` will set it to true by default.
	 * @param	OnComplete		Called when the sound finished playing
	 * @return	This FlxSound instance (nice for chaining stuff together, if you're into that).
	 */
	public function loadEmbedded(EmbeddedSound:FlxSoundAsset, Looped:Bool = false, AutoDestroy:Bool = false, ?OnComplete:Void->Void):FlxSound
	{
		if (EmbeddedSound == null)
			return this;
			
		cleanup(true);

		#if hxvlc
		_onVLC = false;
		if (_vlcPlayer != null)
		{
			_vlcPlayer.dispose();
			_vlcPlayer = null;
		}
		#end
		
		if ((EmbeddedSound is Sound))
		{
			_sound = EmbeddedSound;
		}
		else if ((EmbeddedSound is Class))
		{
			_sound = Type.createInstance(EmbeddedSound, []);
		}
		else if ((EmbeddedSound is String))
		{
			if (FlxG.assets.exists(EmbeddedSound, SOUND))
				_sound = FlxG.assets.getSoundUnsafe(EmbeddedSound);
			else
				FlxG.log.error('Could not find a Sound asset with an ID of \'$EmbeddedSound\'.');
		}
		
		// NOTE: can't pull ID3 info from embedded sound currently
		return init(Looped, AutoDestroy, OnComplete);
	}
	
	/**
	 * One of the main setup functions for sounds, this function loads a sound from a URL.
	 *
	 * @param	SoundURL		A string representing the URL of the MP3 file you want to play.
	 * @param	Looped			Whether or not this sound should loop endlessly.
	 * @param	AutoDestroy		Whether or not this FlxSound instance should be destroyed when the sound finishes playing.
	 * 							Default value is false, but `FlxG.sound.play()` and `FlxG.sound.stream()` will set it to true by default.
	 * @param	OnComplete		Called when the sound finished playing
	 * @param	OnLoad			Called when the sound finished loading.
	 * @return	This FlxSound instance (nice for chaining stuff together, if you're into that).
	 */
	public function loadStream(SoundURL:String, Looped:Bool = false, AutoDestroy:Bool = false, ?OnComplete:Void->Void, ?OnLoad:Void->Void):FlxSound
	{
		#if hxvlc
		cleanup(true);
		// cleanup(true) calls reset()->destroy(), which deliberately clears
		// _onVLC and disposes the previous AudioGroup. Set the backend flag
		// after cleanup so play(), length and addTrack() use the new VLC stream.
		_onVLC = true;
		init(Looped, AutoDestroy, OnComplete);
		
		_initVlc();
		updateTransform();
		
		if (_vlcPlayer != null && _vlcPlayer.addTrack(SoundURL, null, 1))
		{
			if (OnLoad != null) OnLoad();
			_vlcPlayer.autoDestroy = AutoDestroy;
		}
		else 
		{
			FlxG.log.error("FlxStreamSound: Failed to load VLC stream (Player is null or Load failed): " + SoundURL);
		}
		return this;
		#else
		cleanup(true);
		
		_sound = new Sound();
		_sound.addEventListener(Event.ID3, gotID3);
		var loadCallback:Event->Void = null;
		loadCallback = function(e:Event)
		{
			(e.target : IEventDispatcher).removeEventListener(e.type, loadCallback);
			// Check if the sound was destroyed before calling. Weak ref doesn't guarantee GC.
			if (_sound == e.target)
			{
				_length = _sound.length;
				if (OnLoad != null)
					OnLoad();
			}
		}
		// Use a weak reference so this can be garbage collected if destroyed before loading.
		_sound.addEventListener(Event.COMPLETE, loadCallback, false, 0, true);
		_sound.load(new URLRequest(SoundURL));
		
		return init(Looped, AutoDestroy, OnComplete);
		#end
	}

	/**
	 * One of the main setup functions for sounds, this function loads a sound from a URL.
	 *
	 * @param	SoundURL		A string representing the URL of the MP3 file you want to play.
	 * @param	Looped			Whether or not this sound should loop endlessly.
	 * @param	AutoDestroy		Whether or not this FlxSound instance should be destroyed when the sound finishes playing.
	 * 							Default value is false, but `FlxG.sound.play()` and `FlxG.sound.stream()` will set it to true by default.
	 * @param	OnComplete		Called when the sound finished playing
	 * @param	OnLoad			Called when the sound finished loading.
	 * @return	This FlxSound instance (nice for chaining stuff together, if you're into that).
	 */
	public function loadStreamAsync(SoundURL:String, Looped:Bool = false, AutoDestroy:Bool = false, ?OnComplete:Void->Void, ?OnLoad:Void->Void):FlxSound
	{
		#if hxvlc
		cleanup(true);
		_onVLC = true;
		init(Looped, AutoDestroy, OnComplete);
		
		_initVlc();
		updateTransform();
		
		if (_vlcPlayer != null && _vlcPlayer.addTrackAsync(SoundURL, null, 1))
		{
			if (OnLoad != null) OnLoad();
			_vlcPlayer.autoDestroy = AutoDestroy;
		}
		else 
		{
			FlxG.log.error("FlxStreamSound: Failed to load VLC stream (Player is null or Load failed): " + SoundURL);
		}
		return this;
		#else
		cleanup(true);
		
		_sound = new Sound();
		_sound.addEventListener(Event.ID3, gotID3);
		var loadCallback:Event->Void = null;
		loadCallback = function(e:Event)
		{
			(e.target : IEventDispatcher).removeEventListener(e.type, loadCallback);
			// Check if the sound was destroyed before calling. Weak ref doesn't guarantee GC.
			if (_sound == e.target)
			{
				_length = _sound.length;
				if (OnLoad != null)
					OnLoad();
			}
		}
		// Use a weak reference so this can be garbage collected if destroyed before loading.
		_sound.addEventListener(Event.COMPLETE, loadCallback, false, 0, true);
		_sound.load(new URLRequest(SoundURL));
		
		return init(Looped, AutoDestroy, OnComplete);
		#end
	}

	public function addTrack(url:String, ?options:Array<String>, id:Int = 9999) {
		#if hxvlc
		if (!_onVLC || _vlcPlayer == null) return;
		_vlcPlayer.addTrack(url, options, id);
		#end
	}

	public function addTrackAsync(url:String, ?options:Array<String>, id:Int = 9999) {
		#if hxvlc
		if (!_onVLC || _vlcPlayer == null) return;
		_vlcPlayer.addTrackAsync(url, options, id);
		#end
	}

	public function releaseMedia(id:Int) {
		#if hxvlc
		if (!_onVLC || _vlcPlayer == null) return;
		_vlcPlayer.releaseMedia(id);
		#end
	}
	
	#if flash11
	/**
	 * One of the main setup functions for sounds, this function loads a sound from a ByteArray.
	 *
	 * @param	Bytes 			A ByteArray object.
	 * @param	Looped			Whether or not this sound should loop endlessly.
	 * @param	AutoDestroy		Whether or not this FlxSound instance should be destroyed when the sound finishes playing.
	 * 							Default value is false, but `FlxG.sound.play()` and `FlxG.sound.stream()` will set it to true by default.
	 * @return	This FlxSound instance (nice for chaining stuff together, if you're into that).
	 */
	public function loadByteArray(Bytes:ByteArray, Looped:Bool = false, AutoDestroy:Bool = false, ?OnComplete:Void->Void):FlxSound
	{
		cleanup(true);
		
		_sound = new Sound();
		_sound.addEventListener(Event.ID3, gotID3);
		_sound.loadCompressedDataFromByteArray(Bytes, Bytes.length);
		
		return init(Looped, AutoDestroy, OnComplete);
	}
	#end
	
	function init(Looped:Bool = false, AutoDestroy:Bool = false, ?OnComplete:Void->Void):FlxSound
	{
		looped = Looped;
		autoDestroy = AutoDestroy;
		updateTransform();
		exists = true;
		onComplete = OnComplete;
		#if FLX_PITCH
		pitch = 1;
		#end
		_length = (_sound == null) ? 0 : _sound.length;
		endTime = _length;
		return this;
	}
	
	/**
	 * Call this function if you want this sound's volume to change
	 * based on distance from a particular FlxObject.
	 *
	 * @param	X			The X position of the sound.
	 * @param	Y			The Y position of the sound.
	 * @param	TargetObject		The object you want to track.
	 * @param	Radius			The maximum distance this sound can travel.
	 * @param	Pan			Whether panning should be used in addition to the volume changes.
	 * @return	This FlxSound instance (nice for chaining stuff together, if you're into that).
	 */
	public function proximity(X:Float, Y:Float, TargetObject:FlxObject, Radius:Float, Pan:Bool = true):FlxSound
	{
		x = X;
		y = Y;
		_target = TargetObject;
		_radius = Radius;
		_proximityPan = Pan;
		return this;
	}
	
	/**
	 * Call this function to play the sound - also works on paused sounds.
	 *
	 * @param   ForceRestart   Whether to start the sound over or not.
	 *                         Default value is false, meaning if the sound is already playing or was
	 *                         paused when you call play(), it will continue playing from its current
	 *                         position, NOT start again from the beginning.
	 * @param   StartTime      At which point to start playing the sound, in milliseconds.
	 * @param   EndTime        At which point to stop playing the sound, in milliseconds.
	 *                         If not set / `null`, the sound completes normally.
	 */
	public function play(ForceRestart:Bool = false, StartTime:Float = 0.0, ?EndTime:Float):FlxSound
	{
		#if hxvlc
		if (_onVLC)
		{
			if (!exists) return this;
			if (ForceRestart) cleanup(false, true);
			else if (playing) return this;

			if (_paused)
			{
				resume();
			}
			else if (_vlcPlayer != null)
			{
				_vlcPlayer.play();
				if (StartTime > 0) _vlcPlayer.time = Std.int(StartTime);
				_paused = false;
				_channel = @:privateAccess new SoundChannel(null, null, null);
				active = true;
			}
			endTime = EndTime;
			return this;
		}
		#end

		if (!exists)
			return this;
			
		if (ForceRestart)
			cleanup(false, true);
		else if (playing) // Already playing sound
			return this;
			
		if (_paused)
			resume();
		else
			startSound(StartTime);
			
		endTime = EndTime;
		return this;
	}
	
	/**
	 * Unpause a sound. Only works on sounds that have been paused.
	 */
	public function resume():FlxSound
	{
		#if hxvlc
		if (_onVLC)
		{
			if (_paused && _vlcPlayer != null)
			{
				_vlcPlayer.resume();
				_paused = false;
				if (_channel == null) 
					_channel = @:privateAccess new SoundChannel(null, null, null);
				active = true;
			}
			return this;
		}
		#end

		if (_paused)
			startSound(_time);
		return this;
	}
	
	/**
	 * Call this function to pause this sound.
	 */
	public function pause():FlxSound
	{
		#if hxvlc
		if (_onVLC)
		{
			if (_vlcPlayer != null)
			{
				_vlcPlayer.pause();
				_paused = true;
				active = false;
				_channel = null;
			}
			return this;
		}
		#end

		if (!playing)
			return this;
			
		_time = _channel.position;
		_paused = true;
		cleanup(false, false);
		return this;
	}
	
	/**
	 * Call this function to stop this sound.
	 */
	public inline function stop():FlxSound
	{
		cleanup(autoDestroy, true);
		return this;
	}
	
	/**
	 * Helper function that tweens this sound's volume.
	 *
	 * @param	Duration	The amount of time the fade-out operation should take.
	 * @param	To			The volume to tween to, 0 by default.
	 */
	public inline function fadeOut(Duration:Float = 1, ?To:Float = 0, ?onComplete:FlxTween->Void):FlxSound
	{
		if (fadeTween != null)
			fadeTween.cancel();
		fadeTween = FlxTween.num(volume, To, Duration, {onComplete: onComplete}, volumeTween);
		
		return this;
	}
	
	/**
	 * Helper function that tweens this sound's volume.
	 *
	 * @param	Duration	The amount of time the fade-in operation should take.
	 * @param	From		The volume to tween from, 0 by default.
	 * @param	To			The volume to tween to, 1 by default.
	 */
	public inline function fadeIn(Duration:Float = 1, From:Float = 0, To:Float = 1, ?onComplete:FlxTween->Void):FlxSound
	{
		if (!playing)
			play();
			
		if (fadeTween != null)
			fadeTween.cancel();
			
		fadeTween = FlxTween.num(From, To, Duration, {onComplete: onComplete}, volumeTween);
		return this;
	}
	
	function volumeTween(f:Float):Void
	{
		volume = f;
	}
	
	/**
	 * Returns the currently selected "real" volume of the sound (takes fades and proximity into account).
	 *
	 * @return	The adjusted volume of the sound.
	 */
	public inline function getActualVolume():Float
	{
		return #if CODENAME_ENGINE_COMPAT (group != null ? group.getVolume() : 1.0) * #end _volume * _volumeAdjust;
	}
	
	/**
	 * Helper function to set the coordinates of this object.
	 * Sound positioning is used in conjunction with proximity/panning.
	 *
	 * @param        X        The new x position
	 * @param        Y        The new y position
	 */
	public inline function setPosition(X:Float = 0, Y:Float = 0):Void
	{
		x = X;
		y = Y;
	}
	
	/**
	 * Call after adjusting the volume to update the sound channel's settings.
	 */
	@:allow(flixel.sound.FlxSoundGroup)
	@:allow(flixel.system.frontEnds.SoundFrontEnd)
	function updateTransform():Void
	{
		_transform.volume = #if CODENAME_ENGINE_COMPAT (muted ? 0 : 1) * #end #if FLX_SOUND_SYSTEM (FlxG.sound.muted ? 0 : 1) * FlxG.sound.volume * #end
			(group != null ? #if CODENAME_ENGINE_COMPAT group.getVolume() #else group.volume #end : 1) * _volume * _volumeAdjust;
			
		if (_channel != null)
			_channel.soundTransform = _transform;
		
		#if hxvlc
		if (_vlcPlayer != null && _onVLC)
		{
			// Group volume performs one OpenAL call per VLC track. Do it only when
			// the effective volume actually changes.
			if (Math.isNaN(_lastVlcTransformVolume) || Math.abs(_lastVlcTransformVolume - _transform.volume) > 0.000001)
			{
				_vlcPlayer.volume = _transform.volume;
				_lastVlcTransformVolume = _transform.volume;
			}
		}
		#end
	}
	
	/**
	 * An internal helper function used to attempt to start playing
	 * the sound and populate the _channel variable.
	 */
	function startSound(StartTime:Float):Void
	{
		if (_sound == null)
			return;
			
		_time = StartTime;
		_paused = false;
		_channel = _sound.play(_time, 0, _transform);
		if (_channel != null)
		{
			#if FLX_PITCH
			pitch = _pitch;
			#end
			_channel.addEventListener(Event.SOUND_COMPLETE, stopped);
			active = true;
		}
		else
		{
			exists = false;
			active = false;
		}
	}
	
	/**
	 * An internal helper function used to help Flash
	 * clean up finished sounds or restart looped sounds.
	 */
	function stopped(?_):Void
	{
		#if CODENAME_ENGINE_COMPAT
			onFinish.dispatch();
		#end
		if (onComplete != null)
			onComplete();
			
		if (looped)
		{
			cleanup(false);
			play(false, loopTime, endTime);
		}
		else
			cleanup(autoDestroy);
	}
	
	/**
	 * An internal helper function used to help Flash clean up (and potentially re-use) finished sounds.
	 * Will stop the current sound and destroy the associated SoundChannel, plus,
	 * any other commands ordered by the passed in parameters.
	 *
	 * @param  destroySound    Whether or not to destroy the sound. If this is true,
	 *                         the position and fading will be reset as well.
	 * @param  resetPosition   Whether or not to reset the position of the sound.
	 */
	function cleanup(destroySound:Bool, resetPosition:Bool = true):Void
	{
		#if hxvlc
		if (_vlcPlayer != null) 
		{
			try { _vlcPlayer.stop(); } catch(e:Dynamic) {}
		}
		#end

		if (destroySound)
		{
			reset();
			return;
		}
		
		if (_channel != null)
		{
			_channel.removeEventListener(Event.SOUND_COMPLETE, stopped);
			_channel.stop();
			_channel = null;
		}
		
		active = false;
		
		if (resetPosition)
		{
			_time = 0;
			_paused = false;
		}
	}

	#if CODENAME_ENGINE_COMPAT
	// ---- public property accessors ----
	inline function get_target():Null<FlxObject> { return _target; }
	inline function set_target(v:Null<FlxObject>):Null<FlxObject> { return _target = v; }

	inline function get_radius():Float { return _radius; }
	inline function set_radius(v:Float):Float { return _radius = v; }

	inline function get_proximityPan():Bool { return _proximityPan; }
	inline function set_proximityPan(v:Bool):Bool { return _proximityPan = v; }

	inline function get_channels():Int {
		@:privateAccess
		return (buffer != null) ? buffer.channels : 0;
	}

	inline function get_stereo():Bool { return channels > 1; }

	inline function get_streamed():Bool {
		@:privateAccess return #if lime_vorbis (_sound != null && _sound.__buffer.__srcVorbisFile != null) #else false #end;
	}

	// ---- CNE utility methods ----
	public inline function getActualTime():Float
	{
		return time;
	}

	#if FLX_PITCH
	public inline function getActualPitch():Float
	{
		return _realPitch;
	}
	#end

	public inline function calcTransformVolume():Float
	{
		if (muted) return 0.0;
		#if FLX_SOUND_SYSTEM
		if (FlxG.sound.muted) return 0.0;
		return FlxG.sound.volume * getActualVolume();
		#else
		return getActualVolume();
		#end
	}

	public function getPosition(?result:FlxPoint):FlxPoint
	{
		if (result == null) result = FlxPoint.get();
		return result.set(x, y);
	}

	// ---- CNE amplitude (uses public SoundChannel peaks) ----
	inline function update_amplitude():Void {
		if (_channel != null && _transform != null && _transform.volume > 0) {
			amplitudeLeft = _channel.leftPeak / _transform.volume;
			amplitudeRight = _channel.rightPeak / _transform.volume;
			amplitude = Math.max(amplitudeLeft, amplitudeRight);
		}
	}

	// ---- Internal helpers ----
	inline function get_loaded():Bool
	{
		return buffer != null;
	}

	inline function get_buffer():AudioBuffer
	{
		@:privateAccess
		return _sound != null ? _sound.__buffer : null;
	}

	inline function get__source():AudioSource
	{
		@:privateAccess
		return _channel != null ? _channel.__audioSource : null;
	}
	#end
	
	/**
	 * Internal event handler for ID3 info (i.e. fetching the song name).
	 */
	function gotID3(_):Void
	{
		name = _sound.id3.songName;
		artist = _sound.id3.artist;
		_sound.removeEventListener(Event.ID3, gotID3);
	}
	
	#if FLX_SOUND_SYSTEM
	@:allow(flixel.system.frontEnds.SoundFrontEnd)
	function onFocus():Void
	{
		if (!_alreadyPaused)
			resume();
	}
	
	@:allow(flixel.system.frontEnds.SoundFrontEnd)
	function onFocusLost():Void
	{
		_alreadyPaused = _paused;
		pause();
	}
	#end
	
	@:deprecated("sound.group = myGroup is deprecated, use myGroup.add(sound)") // 5.7.0
	function set_group(value:FlxSoundGroup):FlxSoundGroup
	{
		if (value != null)
		{
			// add to new group, also removes from prev and calls updateTransform
			value.add(this);
		}
		else
		{
			// remove from prev group, also calls updateTransform
			group.remove(this);
		}
		return value;
	}
	
	inline function get_playing():Bool
	{
		return _channel != null;
	}
	
	inline function get_volume():Float
	{
		return _volume;
	}
	
	function set_volume(Volume:Float):Float
	{
		_volume = FlxMath.bound(Volume, 0, 1);
		updateTransform();
		return Volume;
	}

	#if CODENAME_ENGINE_COMPAT
	function set_muted(value:Bool):Bool
	{
		muted = value;
		updateTransform();
		return value;
	}
	#end
	
	#if FLX_PITCH
	inline function get_pitch():Float
	{
		return _pitch;
	}
	
	function set_pitch(v:Float):Float
	{
		if (_channel != null)
		{
			#if (openfl < "9.3.2")
			@:privateAccess
			if (_channel.__source != null)
				_channel.__source.pitch = v;
			#else
			@:privateAccess
			if (_channel.__audioSource != null)
				_channel.__audioSource.pitch = v;
			#end
		}
			
		return _pitch = v;
	}
	#end
	
	inline function get_pan():Float
	{
		return _transform.pan;
	}
	
	inline function set_pan(pan:Float):Float
	{
		_transform.pan = pan;
		updateTransform();
		return pan;
	}
	
	inline function get_time():Float
	{
		return _time;
	}
	
	function set_time(time:Float):Float
	{
		if (playing)
		{
			cleanup(false, true);
			startSound(time);
		}
		return _time = time;
	}
	
	function get_length():Float
	{
		#if hxvlc
		if (_onVLC && _vlcPlayer != null)
		{
			return haxe.Int64.toInt(_vlcPlayer.length);
		}
		#end
		return _length;
	}
	
	override public function toString():String
	{
		return FlxStringUtil.getDebugString([
			LabelValuePair.weak("playing", playing),
			LabelValuePair.weak("time", time),
			LabelValuePair.weak("length", length),
			LabelValuePair.weak("volume", volume)
		]);
	}
}
