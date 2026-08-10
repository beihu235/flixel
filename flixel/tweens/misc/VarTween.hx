package flixel.tweens.misc;

import flixel.tweens.FlxTween;
import flixel.tweens.FlxTween.TweenField;
#if (CODENAME_ENGINE_COMPAT && hscript_improved)
import hscript.IHScriptCustomBehaviour;
#end

/**
 * Tweens multiple numeric properties of an object simultaneously.
 */
class VarTween extends FlxTween
{
	var _object:Dynamic;
	var _properties:Dynamic;
	var _propertyInfos:Array<VarTweenProperty>;

	function new(options:TweenOptions, ?manager:FlxTweenManager)
	{
		super(options, manager);
	}

	/**
	 * Tweens multiple numeric public properties.
	 *
	 * @param	object		The object containing the properties.
	 * @param	properties	An object containing key/value pairs of properties and target values.
	 * @param	duration	Duration of the tween.
	 */
	public function tween(object:Dynamic, properties:Dynamic, duration:Float):VarTween
	{
		#if FLX_DEBUG
		if (object == null)
			throw "Cannot tween variables of an object that is null.";
		else if (properties == null)
			throw "Cannot tween null properties.";
		#end

		_object = object;
		_properties = properties;
		_propertyInfos = [];
		this.duration = duration;
		start();
		initializeVars();
		return this;
	}

	override function update(elapsed:Float):Void
	{
		var delay:Float = (executions > 0) ? loopDelay : startDelay;

		// Leave properties alone until delay is over
		if (_secondsSinceStart < delay)
			super.update(elapsed);
		else
		{
			// Wait until the delay is done to set the starting values of tweens
			if (Math.isNaN(_propertyInfos[0].startValue))
				setStartValues();

			super.update(elapsed);

			if (active)
				for (info in _propertyInfos)
					#if CODENAME_ENGINE_COMPAT
					info.setField(info.startValue + info.range * scale);
					#else
					setTweenProperty(info.object, info.field, info.startValue + info.range * scale);
					#end
		}
	}

	function initializeVars():Void
	{
		var fieldPaths:Array<String>;
		if (Reflect.isObject(_properties))
			fieldPaths = Reflect.fields(_properties);
		else
			throw "Unsupported properties container - use an object containing key/value pairs.";

		for (fieldPath in fieldPaths)
		{
			var target:Dynamic = _object;
			#if CODENAME_ENGINE_COMPAT
			var path = FlxTween.parseFieldString(fieldPath);
			#else
			var path:Array<TweenField> = fieldPath.split(".");
			#end
			var field = path.pop();
			for (component in path)
			{
				target = getTweenProperty(target, component);
				if (!Reflect.isObject(target) && !(target is Array))
					throw 'The object does not have the property "$component" in "$fieldPath"';
			}

			_propertyInfos.push({
				object: target,
				field: field,
				startValue: Math.NaN, // gets set after delay
				range: Reflect.getProperty(_properties, fieldPath)
			});
		}
	}

	function setStartValues()
	{
		for (info in _propertyInfos)
		{
			var value:Dynamic = #if CODENAME_ENGINE_COMPAT info.getField() #else getTweenProperty(info.object, info.field) #end;
			if (value == null)
				throw 'The object does not have the property "${info.field}"';

			if (Math.isNaN(value))
				throw 'The property "${info.field}" is not numeric.';

			info.startValue = value;
			info.range = info.range - value;
		}
	}

	static inline function getTweenProperty(object:Dynamic, field:TweenField):Dynamic
	{
		#if CODENAME_ENGINE_COMPAT
		if (Type.typeof(field) == TInt)
		{
			if (object is Array)
			{
				final index:Int = cast field;
				final array:Array<Dynamic> = cast object;
				return array[index];
			}
			return null;
		}
		final stringField:String = cast field;
		#else
		final stringField:String = field;
		#end
		#if (CODENAME_ENGINE_COMPAT && hscript_improved)
		if (object is IHScriptCustomBehaviour)
			return (cast object:IHScriptCustomBehaviour).hget(stringField);
		#end
		return Reflect.getProperty(object, stringField);
	}

	static inline function setTweenProperty(object:Dynamic, field:TweenField, value:Dynamic):Dynamic
	{
		#if CODENAME_ENGINE_COMPAT
		if (Type.typeof(field) == TInt)
		{
			if (object is Array)
			{
				final index:Int = cast field;
				final array:Array<Dynamic> = cast object;
				array[index] = value;
			}
			return value;
		}
		final stringField:String = cast field;
		#else
		final stringField:String = field;
		#end
		#if (CODENAME_ENGINE_COMPAT && hscript_improved)
		if (object is IHScriptCustomBehaviour)
			return (cast object:IHScriptCustomBehaviour).hset(stringField, value);
		#end
		Reflect.setProperty(object, stringField, value);
		return value;
	}

	override public function destroy():Void
	{
		super.destroy();
		_object = null;
		_properties = null;
		_propertyInfos = null;
	}

	override function isTweenOf(object:Dynamic, ?field:TweenField):Bool
	{
		if (object == _object && field == null)
			return true;
		
		for (property in _propertyInfos)
		{
			if (object == property.object && (field == property.field || field == null))
				return true;
		}

		return false;
	}
}

#if CODENAME_ENGINE_COMPAT
@:structInit
class VarTweenProperty
{
	public var object:Dynamic;
	public var field:TweenField;
	public var startValue:Float;
	public var range:Float;

	public function getField():Dynamic
	{
		if (Type.typeof(field) == TInt)
		{
			final index:Int = cast field;
			final array:Array<Dynamic> = cast object;
			return array[index];
		}

		final stringField:String = cast field;
		#if hscript_improved
		if (object is IHScriptCustomBehaviour)
			return (cast object:IHScriptCustomBehaviour).hget(stringField);
		#end
		return Reflect.getProperty(object, stringField);
	}

	public function setField(value:Dynamic):Void
	{
		if (Type.typeof(field) == TInt)
		{
			final index:Int = cast field;
			final array:Array<Dynamic> = cast object;
			array[index] = value;
			return;
		}

		final stringField:String = cast field;
		#if hscript_improved
		if (object is IHScriptCustomBehaviour)
		{
			(cast object:IHScriptCustomBehaviour).hset(stringField, value);
			return;
		}
		#end
		Reflect.setProperty(object, stringField, value);
	}
}
#else
private typedef VarTweenProperty =
{
	object:Dynamic,
	field:TweenField,
	startValue:Float,
	range:Float
}
#end
