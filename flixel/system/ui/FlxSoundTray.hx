package flixel.system.ui;

#if FLX_SOUND_SYSTEM
import flixel.FlxG;
import flixel.system.FlxAssets;
import flixel.system.frontEnds.SoundFrontEnd;
import flixel.util.FlxColor;
import openfl.Lib;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
#if flash
import openfl.text.AntiAliasType;
import openfl.text.GridFitType;
#end

/**
 * The flixel sound tray, the little volume meter that pops down sometimes.
 * Accessed via `FlxG.game.soundTray` or `FlxG.sound.soundTray`.
 */
class FlxSoundTray extends Sprite
{
	/** The fallback sound played whenever the volume changes. */
	public static var volumeChangeSFX:String = "flixel/sounds/beep";

	/** Optional sound played when increasing an already-maxed volume. */
	public static var volumeMaxChangeSFX:String = null;

	/** Optional sound played when increasing the volume. */
	public static var volumeUpChangeSFX:String = null;

	/** Optional sound played when decreasing the volume. */
	public static var volumeDownChangeSFX:String = null;

	/** The text displayed by the tray. */
	public var text:TextField = new TextField();

	/** The default format assigned to {@link text}. */
	var _dtf:TextFormat;

	/**
	 * Because reading any data from DisplayObject is insanely expensive in hxcpp, keep track of whether we need to update it or not.
	 */
	public var active:Bool;

	/**
	 * Helps us auto-hide the sound tray after a volume change.
	 */
	var _timer:Float;

	/**
	 * Helps display the volume bars on the sound tray.
	 */
	var _bars:Array<Bitmap>;

	var _bx:Int = 10;

	var _by:Int = 14;

	/**
	 * Number of volume bars. Assigning this regenerates the bar display.
	 */
	public var barsAmount(default, set):Int = 10;

	@:dox(hide)
	public function set_barsAmount(value:Int):Int
	{
		barsAmount = value;
		regenerateBars();
		return value;
	}

	/** The tray background bitmap. */
	public var background:Bitmap;

	/**
	 * How wide the sound tray background is.
	 */
	@:isVar var _width(get, set):Int = 80;

	@:dox(hide)
	public function get__width():Int
	{
		if (background != null)
			_width = Math.round(background.width);
		return _width;
	}

	@:dox(hide)
	public function set__width(value:Int):Int
	{
		if (background != null)
			background.width = value;
		return _width = value;
	}

	/** How tall the tray background is. */
	@:isVar var _height(get, set):Int = 30;

	@:dox(hide)
	public function get__height():Int
	{
		if (background != null)
			_height = Math.round(background.height);
		return _height;
	}

	@:dox(hide)
	public function set__height(value:Int):Int
	{
		if (background != null)
			background.height = value;
		return _height = value;
	}

	var _defaultScale:Float = 2.0;

	/**
	 * The sound used when increasing the volume by subclasses using the
	 * Flixel 5.9 sound-tray API.
	 */
	public var volumeUpSound:String = "flixel/sounds/beep";

	/**
	 * The sound used when decreasing the volume by subclasses using the
	 * Flixel 5.9 sound-tray API.
	 */
	public var volumeDownSound:String = 'flixel/sounds/beep';

	/** Whether changing the volume should play a sound. */
	public var silent:Bool = false;

	/**
	 * Sets up the "sound tray", the little volume meter that pops down sometimes.
	 */
	@:keep
	public function new()
	{
		super();

		background = new Bitmap(new BitmapData(_width, _height, true, 0x7F000000));
		screenCenter();
		addChild(background);

		reloadText(false);
		regenerateBars();

		y = -height;
		visible = false;
	}

	/** Recreates the text field used by the sound tray. */
	public function reloadText(checkIfNull:Bool = true, reloadDefaultTextFormat:Bool = true, displayTxt:String = "VOLUME", y:Float = 16):Void
	{
		if (checkIfNull && text != null)
		{
			removeChild(text);
			@:privateAccess
			text.__cleanup();
		}

		text = new TextField();
		text.width = _width;
		text.height = _height;
		text.multiline = true;
		text.wordWrap = true;
		text.selectable = false;

		#if flash
		text.embedFonts = true;
		text.antiAliasType = AntiAliasType.NORMAL;
		text.gridFitType = GridFitType.PIXEL;
		#end
		if (reloadDefaultTextFormat)
			reloadDtf();
		text.defaultTextFormat = _dtf;
		addChild(text);
		text.text = displayTxt;
		text.y = y;
	}

	/** Recreates the default text format used by the sound tray. */
	public function reloadDtf():Void
	{
		_dtf = new TextFormat(FlxAssets.FONT_DEFAULT, 10, 0xffffff);
		_dtf.align = TextFormatAlign.CENTER;
	}

	/** Clears and recreates the backing array for the volume bars. */
	public function regenerateBarsArray():Void
	{
		if (_bars == null)
		{
			_bars = [];
			return;
		}

		for (bar in _bars)
		{
			if (bar == null)
				continue;
			if (bar.parent == this)
				removeChild(bar);
			if (bar.bitmapData != null)
				bar.bitmapData.dispose();
		}
		_bars.resize(0);
	}

	/** Rebuilds the volume bars according to {@link barsAmount}. */
	public function regenerateBars():Void
	{
		var tmp:Bitmap;
		var bx:Int = _bx;
		var by:Int = _by;

		regenerateBarsArray();

		for (i in 0...barsAmount)
		{
			tmp = new Bitmap(new BitmapData(4, i + 1, false, FlxColor.WHITE));
			tmp.x = bx;
			tmp.y = by;
			addChild(tmp);
			_bars.push(tmp);
			bx += 6;
			by--;
		}
	}

	/**
	 * This function updates the soundtray object.
	 */
	public function update(MS:Float):Void
	{
		// Animate sound tray thing
		if (_timer > 0)
		{
			_timer -= (MS / 1000);
		}
		else if (y > -height)
		{
			y -= (MS / 1000) * height * 0.5;

			if (y <= -height)
			{
				visible = false;
				active = false;

				saveSoundPreferences();
			}
		}
	}

	/** Persists the global sound settings when save support is enabled. */
	public function saveSoundPreferences():Void
	{
		#if FLX_SAVE
		var save = SoundFrontEnd.save;
		if (save != null && save.isBound)
		{
			save.data.mute = FlxG.sound.muted;
			save.data.volume = FlxG.sound.volume;
			save.flush();
		}
		#end
	}

	/**
	 * Makes the little volume tray slide out.
	 *
	 * @param	up Whether the volume is increasing.
	 */
	public function show(up:Bool = false):Void
	{
		_timer = 1;
		y = 0;
		visible = true;
		active = true;
		var globalVolume:Int = FlxG.sound.muted ? 0 : Math.round(FlxG.sound.volume * barsAmount);

		if (!silent)
		{
			var soundId = up ? (globalVolume >= barsAmount && volumeMaxChangeSFX != null ? volumeMaxChangeSFX : volumeUpChangeSFX) : volumeDownChangeSFX;
			if (soundId == null)
			{
				var directionSound = up ? volumeUpSound : volumeDownSound;
				soundId = volumeChangeSFX == "flixel/sounds/beep" && directionSound != null ? directionSound : volumeChangeSFX;
			}
			if (soundId != null)
			{
				var sound = FlxAssets.getSoundAddExtension(soundId);
				if (sound != null)
					FlxG.sound.load(sound).play();
			}
		}

		for (i in 0..._bars.length)
		{
			if (i < globalVolume)
			{
				_bars[i].alpha = 1;
			}
			else
			{
				_bars[i].alpha = 0.5;
			}
		}
	}

	public function screenCenter():Void
	{
		scaleX = _defaultScale;
		scaleY = _defaultScale;

		x = (0.5 * (Lib.current.stage.stageWidth - _width * _defaultScale) - FlxG.game.x);
	}
}
#end
