package flixel;

import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.tile.FlxDrawBaseItem;
import flixel.graphics.tile.FlxDrawBaseItem.FlxDrawItemType;
import flixel.graphics.tile.FlxDrawQuadsItem;
import flixel.graphics.tile.FlxDrawTrianglesItem;
import flixel.math.FlxMatrix;
import flixel.system.FlxAssets.FlxShader;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.geom.ColorTransform;

using flixel.util.FlxColorTransformUtil;

/**
 * A deferred sprite batching layer compatible with Codename Engine's Flixel
 * extension. Sprites assigned to this layer queue their draw items here; the
 * layer inserts the complete queue at its own position in the draw order.
 */
@:access(flixel.FlxCamera)
class FlxLayer extends FlxBasic
{
	var _currentDrawItem:FlxDrawBaseItem<Dynamic>;
	var _headOfDrawStack:FlxDrawBaseItem<Dynamic>;
	var _headTiles:FlxDrawQuadsItem;
	var _headTriangles:FlxDrawTrianglesItem;
	var _targetCamera:FlxCamera;
	var _warnedMultipleCameras:Bool;

	public function new()
	{
		super();
		FlxG.signals.preDraw.add(clearDrawStack);
	}

	override public function destroy():Void
	{
		FlxG.signals.preDraw.remove(clearDrawStack);
		clearDrawStack();
		super.destroy();
	}

	@:noCompletion
	public function startQuadBatch(graphic:FlxGraphic, colored:Bool, hasColorOffsets:Bool = false, ?blend:BlendMode, smooth:Bool = false,
			?shader:FlxShader)
	{
		#if FLX_RENDER_TRIANGLE
		return startTrianglesBatch(graphic, smooth, colored, blend, hasColorOffsets, shader);
		#else
		if (_targetCamera == null)
			_targetCamera = camera;

		var blendInt = FlxDrawBaseItem.blendToInt(blend);
		if (_currentDrawItem != null
			&& _currentDrawItem.type == FlxDrawItemType.TILES
			&& _headTiles.graphics == graphic
			&& _headTiles.colored == colored
			&& _headTiles.hasColorOffsets == hasColorOffsets
			&& _headTiles.blending == blendInt
			&& _headTiles.blend == blend
			&& _headTiles.antialiasing == smooth
			&& _headTiles.shader == shader)
		{
			return _headTiles;
		}

		var item:FlxDrawQuadsItem;
		if (FlxCamera._storageTilesHead != null)
		{
			item = FlxCamera._storageTilesHead;
			FlxCamera._storageTilesHead = item.nextTyped;
			item.reset();
		}
		else
		{
			item = new FlxDrawQuadsItem();
		}

		if (graphic == null || graphic.isDestroyed)
			throw 'Attempted to queue an invalid FlxDrawItem in FlxLayer';

		item.graphics = graphic;
		item.antialiasing = smooth;
		item.colored = colored;
		item.hasColorOffsets = hasColorOffsets;
		item.blending = blendInt;
		item.blend = blend;
		item.shader = shader;
		item.nextTyped = _headTiles;
		_headTiles = item;
		appendDrawItem(item);
		return item;
		#end
	}

	@:noCompletion
	public function startTrianglesBatch(graphic:FlxGraphic, smoothing:Bool = false, isColored:Bool = false, ?blend:BlendMode,
			?hasColorOffsets:Bool, ?shader:FlxShader):FlxDrawTrianglesItem
	{
		if (_targetCamera == null)
			_targetCamera = camera;

		var blendInt = FlxDrawBaseItem.blendToInt(blend);
		if (_currentDrawItem != null
			&& _currentDrawItem.type == FlxDrawItemType.TRIANGLES
			&& _headTriangles.graphics == graphic
			&& _headTriangles.antialiasing == smoothing
			&& _headTriangles.colored == isColored
			&& _headTriangles.blending == blendInt
			&& _headTriangles.blend == blend
			#if !flash
			&& _headTriangles.hasColorOffsets == hasColorOffsets
			&& _headTriangles.shader == shader
			#end)
		{
			return _headTriangles;
		}

		return getNewDrawTrianglesItem(graphic, smoothing, isColored, blend, hasColorOffsets, shader);
	}

	@:noCompletion
	public function getNewDrawTrianglesItem(graphic:FlxGraphic, smoothing:Bool = false, isColored:Bool = false, ?blend:BlendMode,
			?hasColorOffsets:Bool, ?shader:FlxShader):FlxDrawTrianglesItem
	{
		var item:FlxDrawTrianglesItem;
		if (FlxCamera._storageTrianglesHead != null)
		{
			item = FlxCamera._storageTrianglesHead;
			FlxCamera._storageTrianglesHead = item.nextTyped;
			item.reset();
		}
		else
		{
			item = new FlxDrawTrianglesItem();
		}

		if (graphic == null || graphic.isDestroyed)
			throw 'Attempted to queue an invalid FlxDrawTrianglesItem in FlxLayer';

		item.graphics = graphic;
		item.antialiasing = smoothing;
		item.colored = isColored;
		item.blending = FlxDrawBaseItem.blendToInt(blend);
		item.blend = blend;
		#if !flash
		item.hasColorOffsets = hasColorOffsets;
		item.shader = shader;
		#end
		item.nextTyped = _headTriangles;
		_headTriangles = item;
		appendDrawItem(item);
		return item;
	}

	inline function appendDrawItem(item:FlxDrawBaseItem<Dynamic>):Void
	{
		if (_headOfDrawStack == null)
			_headOfDrawStack = item;
		else
			_currentDrawItem.next = item;
		_currentDrawItem = item;
	}

	function recycleUnsubmittedDrawStack():Void
	{
		var tile = _headTiles;
		while (tile != null)
		{
			var next = tile.nextTyped;
			tile.reset();
			tile.nextTyped = FlxCamera._storageTilesHead;
			FlxCamera._storageTilesHead = tile;
			tile = next;
		}

		var triangle = _headTriangles;
		while (triangle != null)
		{
			var next = triangle.nextTyped;
			triangle.reset();
			triangle.nextTyped = FlxCamera._storageTrianglesHead;
			FlxCamera._storageTrianglesHead = triangle;
			triangle = next;
		}
	}

	@:allow(flixel.system.frontEnds.CameraFrontEnd)
	function clearDrawStack():Void
	{
		if (_headOfDrawStack != null)
			recycleUnsubmittedDrawStack();
		forgetDrawStack();
	}

	inline function forgetDrawStack():Void
	{
		_currentDrawItem = null;
		_headOfDrawStack = null;
		_headTiles = null;
		_headTriangles = null;
		_targetCamera = null;
		_warnedMultipleCameras = false;
	}

	public function drawPixels(sprite:FlxSprite, camera:FlxCamera, ?frame:FlxFrame, ?pixels:BitmapData, matrix:FlxMatrix,
			?transform:ColorTransform, ?blend:BlendMode, ?smoothing:Bool = false, ?shader:FlxShader):Void
	{
		if (getCamerasLegacy().indexOf(camera) == -1)
		{
			FlxG.log.warn('Camera ${camera} is not assigned to this FlxLayer; drawing normally');
			camera.drawPixels(frame, pixels, matrix, transform, blend, smoothing, shader);
			return;
		}

		if (_targetCamera != null && _targetCamera != camera)
		{
			if (!_warnedMultipleCameras)
			{
				FlxG.log.warn('FlxLayer currently batches one camera; additional cameras draw normally');
				_warnedMultipleCameras = true;
			}
			camera.drawPixels(frame, pixels, matrix, transform, blend, smoothing, shader);
			return;
		}
		_targetCamera = camera;

		if (FlxG.renderBlit)
		{
			camera.drawPixels(frame, pixels, matrix, transform, blend, smoothing, shader);
			return;
		}

		var colored = transform != null && transform.hasRGBMultipliers();
		var colorOffsets = transform != null && transform.hasRGBAOffsets();
		#if CODENAME_ENGINE_COMPAT
		if (!camera.rotateSprite && camera.angle != 0)
		{
			matrix.translate(-camera.width / 2, -camera.height / 2);
			matrix.rotateWithTrig(camera._cosAngle, camera._sinAngle);
			matrix.translate(camera.width / 2, camera.height / 2);
		}
		#end

		#if FLX_RENDER_TRIANGLE
		var item = startTrianglesBatch(frame.parent, smoothing, colored, blend, colorOffsets, shader);
		#else
		var item = startQuadBatch(frame.parent, colored, colorOffsets, blend, smoothing, shader);
		#end
		item.addQuad(frame, matrix, transform);
	}

	/** Inserts one already prepared quad batch at the end of a camera's draw stack. */
	public function injectDrawCall(camera:FlxCamera, drawItem:FlxDrawQuadsItem):Void
	{
		if (drawItem == null)
			return;
		drawItem.next = null;
		if (camera._headOfDrawStack == null)
			camera._headOfDrawStack = drawItem;
		else
			camera._currentDrawItem.next = drawItem;
		camera._currentDrawItem = drawItem;
		drawItem.nextTyped = camera._headTiles;
		camera._headTiles = drawItem;
	}

	function injectDrawStack(camera:FlxCamera):Void
	{
		if (_headOfDrawStack == null)
			return;

		if (camera._headOfDrawStack == null)
			camera._headOfDrawStack = _headOfDrawStack;
		else
			camera._currentDrawItem.next = _headOfDrawStack;
		camera._currentDrawItem = _currentDrawItem;

		if (_headTiles != null)
		{
			var oldest = _headTiles;
			while (oldest.nextTyped != null)
				oldest = oldest.nextTyped;
			oldest.nextTyped = camera._headTiles;
			camera._headTiles = _headTiles;
		}

		if (_headTriangles != null)
		{
			var oldest = _headTriangles;
			while (oldest.nextTyped != null)
				oldest = oldest.nextTyped;
			oldest.nextTyped = camera._headTriangles;
			camera._headTriangles = _headTriangles;
		}
	}

	override public function draw():Void
	{
		super.draw();
		if (_headOfDrawStack == null)
			return;

		var target = _targetCamera != null ? _targetCamera : camera;
		if (target != null && target.exists && target.visible)
		{
			injectDrawStack(target);
			// Ownership is transferred to FlxCamera, which recycles the batches.
			forgetDrawStack();
		}
	}
}
