﻿package com.partkart{
	public class Pen extends Path{
		import flash.display.*;
		import flash.events.*;
		import flash.geom.Point;

		// we keep a list of points as well as the seglist, for cases where we have a singular point
		private var pointlist:Array;
		private var inithandle:Point;
		private var currentpoint:Point;
		private var closedot:Dot;

		public var mousedown:Boolean = false;

		//private var currentsegment:*;

		public function Pen(inputpoint:Point):void{
			pointlist = new Array();
			currentpoint = inputpoint;
			pointlist.push(inputpoint);
			addEventListener(MouseEvent.MOUSE_OVER, penOver);
		}

		public function startPoint(pivot:Point){
			var handle:Point;

			if(seglist.length > 0 && seglist[seglist.length-1] is CubicBezierSegment){
				var cubic:CubicBezierSegment = seglist[seglist.length-1];
				handle = new Point(cubic.p2.x+(cubic.p2.x-cubic.c2.x),cubic.p2.y+(cubic.p2.y-cubic.c2.y));
			}
			else if(inithandle){
				handle = inithandle;
				inithandle = null;
			}
			else{
				handle = currentpoint.clone();
			}

			cubic = new CubicBezierSegment(currentpoint, pivot, handle, pivot.clone());
			addSegment(cubic);

			currentpoint = pivot;
		}

		public function finishPoint():void{
			if(seglist.length > 0){
				var cubic:CubicBezierSegment = seglist[seglist.length-1];
				if(Point.distance(cubic.c2, cubic.p2)*Global.zoom < 1){
					// mouse up and down at same spot, add line instead
					seglist[seglist.length-1] = new Segment(cubic.p1,cubic.p2);
					resetSegments();
				}
				redraw();
			}
			else{
				inithandle = new Point(this.mouseX/Global.zoom, -this.mouseY/Global.zoom);
			}
		}

		public function setPosition():void{
			this.graphics.clear();
			if(currentpoint != null){
				if(!mousedown){
					this.graphics.lineStyle(1,0xcccccc,1);
					this.graphics.moveTo(currentpoint.x*Global.zoom, -currentpoint.y*Global.zoom);
					this.graphics.lineTo(this.mouseX, this.mouseY);
				}
				else{
					if(seglist.length > 0){
						// the last segment must be cubic, because we just did a startpoint()
						var cubic:CubicBezierSegment = seglist[seglist.length-1];
						var handle:Point = new Point(this.mouseX/Global.zoom, -this.mouseY/Global.zoom);

						cubic.c2.x = cubic.p2.x + (cubic.p2.x-handle.x);
						cubic.c2.y = cubic.p2.y + (cubic.p2.y-handle.y);
						redraw(cubic);

						// display handles
						this.graphics.lineStyle(1,0xcccccc,1);
						this.graphics.moveTo(cubic.c2.x*Global.zoom, -cubic.c2.y*Global.zoom);
						this.graphics.lineTo(this.mouseX, this.mouseY);

						graphics.beginFill(0xaaaaaa);
						graphics.drawCircle(cubic.c2.x*Global.zoom, -cubic.c2.y*Global.zoom, 5);
						graphics.drawCircle(this.mouseX, this.mouseY,5);
						graphics.endFill();
					}
					else{
						var invert:Point = new Point(currentpoint.x + currentpoint.x-this.mouseX/Global.zoom,currentpoint.y + currentpoint.y+this.mouseY/Global.zoom);
						// display handles
						this.graphics.lineStyle(1,0xcccccc,1);
						this.graphics.moveTo(invert.x*Global.zoom, -invert.y*Global.zoom);
						this.graphics.lineTo(this.mouseX, this.mouseY);

						graphics.beginFill(0xaaaaaa);
						graphics.drawCircle(invert.x*Global.zoom, -invert.y*Global.zoom, 5);
						graphics.drawCircle(this.mouseX, this.mouseY,5);
						graphics.endFill();
					}
				}
			}
		}

		private function penOver(e:MouseEvent):void{
			if(seglist.length > 0){
				var point:Point = new Point(this.mouseX/Global.zoom, -this.mouseY/Global.zoom);
				if(closedot == null){
					if(Point.distance(point,seglist[0].p1)*Global.zoom < 8){
						var dot:Dot = new Dot();
						dot.point = seglist[0].p1;
						dot.x = dot.point.x*Global.zoom;
						dot.y = -dot.point.y*Global.zoom;
						dot.setLoop();
						closedot = dot;
						addChild(dot);

						dot.addEventListener(MouseEvent.MOUSE_DOWN, dotDown);
					}
				}
				else{
					if(Point.distance(point,closedot.point)*Global.zoom < 8){
						closedot.x = closedot.point.x*Global.zoom;
						closedot.y = -closedot.point.y*Global.zoom;
						closedot.setLoop();
						addChild(closedot);
					}
					else{
						if(contains(closedot)){
							removeChild(closedot);
						}
					}
				}
			}
		}

		public function dotDown(e:MouseEvent):void{
			e.stopPropagation();
			var dot:Dot = e.target as Dot;
			if(dot){
				startPoint(dot.point);

				graphics.clear();

				if(contains(dot)){
					removeChild(dot);
				}

				removeEventListener(MouseEvent.MOUSE_OVER, penOver);

				var main:* = this.parent.parent;
				main.finishPen();
			}
		}
	}
}