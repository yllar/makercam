﻿package com.partkart{

	import flash.display.*;
	import flash.events.*;
	import flash.geom.Point;
	import flash.geom.Matrix;
	import flash.geom.Transform;

	import com.lorentz.SVG.*;

	public class Path extends Sprite{

		// a path is a list of individual segments
		public var seglist:Array = new Array();

		public var dotlist:Array = new Array();

		// document position of path (in user units)
		public var docx = 0;
		public var docy = 0;

		// helper variables used for detecting mouse movement, used for multiple functions
		protected var xstart:Number = 0;
		protected var ystart:Number = 0;

		protected var startpoint:Point; // note: startpoint does not change throughout the dragging operation, it is also in local coordinates
		protected var startdot:Shape;

		public var dragging:Boolean = false;

		protected var linestyle:int = 0;

		public var active:Boolean = false;

		public var coord:coordinates;

		// this flag is activated when the path is moved or one of its points is moved
		// it means that the associated cam operations must be redrawn (only used for unprocessed pockets!)
		public var dirty:Boolean = true;

		// same as the dirty flag, except for processed cutobjects
		public var camdirty:Boolean = true;

		public function Path(){
			this.cacheAsBitmap = true;

			setLineStyle(0);

			attachActions();
		}

		public function addSegment(seg:Segment):void{
			seglist.push(seg);
			addChild(seg);
			if(Global.tool == 1){
				addDots(seg);

				// place all dots on top
				for(var i:int=0; i<numChildren; i++){
					var dot:DisplayObject = getChildAt(i);
					if(dot is Dot){
						dotlist.push(dot);
					}
				}
			}
		}

		public function getSegments():Array{
			var list:Array = new Array();
			list = list.concat(seglist);
			return list;
		}

		// clears all segments and repopulate from the seglist
		public function resetSegments():void{
			var removelist:Array = new Array();
			for(var i:int=0; i<numChildren; i++){
				if(getChildAt(i) is Segment){
					removelist.push(getChildAt(i));
				}
			}

			while(removelist.length > 0){
				removeChild(removelist.shift());
			}

			for each(var seg:* in seglist){
				addChild(seg);
			}
		}

		// if a sprite is given, we will render on to that sprite
		public function render(sprite:Sprite = null):void{
			setLineStyle(linestyle);
			//this.graphics.beginFill(0xcccccc);
			for(var i=0; i<seglist.length; i++){
				if(seglist[i] is CubicBezierSegment){
					renderCubic(seglist[i], sprite);
				}
				else if(seglist[i] is QuadBezierSegment){
					renderQuad(seglist[i], sprite);
				}
				else if(seglist[i] is ArcSegment){
					renderArc(seglist[i], sprite);
				}
				else{
					renderLine(seglist[i], sprite);
				}
			}
			//this.graphics.endFill();
			//renderCollisionArea();
		}

		/*protected function renderCollisionArea():void{
			// just going to render it again, but with an invisible stroke for "collision detection"
			setLineStyle(3);
			//graphics.lineStyle(16, 0xff0000, 0, false, LineScaleMode.NONE, CapsStyle.ROUND);
			for(var i=0; i<seglist.length; i++){
				if(seglist[i] is CubicBezierSegment){
					renderCubic(seglist[i]);
				}
				else if(seglist[i] is QuadBezierSegment){
					renderQuad(seglist[i]);
				}
				else if(seglist[i] is ArcSegment){
					renderArc(seglist[i]);
				}
				else{
					renderLine(seglist[i]);
				}
			}
		}*/

		protected function attachActions():void{
			addEventListener(MouseEvent.MOUSE_OVER, overAction);
			addEventListener(MouseEvent.MOUSE_DOWN, downAction);
			addEventListener(MouseEvent.MOUSE_MOVE, moveAction);
			addEventListener(MouseEvent.MOUSE_UP, upAction);
		}

		protected function getDot(point:Point):Dot{
			/*for(var i:int=0; i<numChildren; i++){
				if(getChildAt(i) is Dot){
					var dot:Dot = getChildAt(i) as Dot;
					if(dot.point == point){
						return dot;
					}
				}
			}*/

			for each(var dot in dotlist){
				if(dot && dot.point == point){
					return dot;
				}
			}
			return null;
		}

		protected function getAttachedSegment(seg1:Segment, point:int):Segment{
			for(var i=0; i<seglist.length; i++){
				var s:Segment = seglist[i];
				if(s != seg1 && ((s.p2.equals(seg1.p1) && point == 1) || (s.p1.equals(seg1.p2) && point == 2))){
					return s;
				}
			}

			return null;
		}

		public function isClosed():Boolean{
			var s:Segment;
			var found1:Boolean;
			var found2:Boolean;
			for(var i=0; i<seglist.length; i++){
				s = seglist[i];
				found1 = false;
				found2 = false;
				for(var j=0; j<seglist.length; j++){
					if(i != j && found1 == false && (s.p1 == seglist[j].p1 || s.p1 == seglist[j].p2)){
						found1 = true;
					}
					if(i != j && found2 == false && (s.p2 == seglist[j].p1 || s.p2 == seglist[j].p2)){
						found2 = true;
					}
				}
				if(!found1 || !found2){
					return false;
				}
			}
			return true;
		}

		// add control dots for segment endpoints and control handles
		protected function addDots(seg:Segment):void{
			var dot:Dot;

			dot = addDot(seg.p1);
			if(dot.s1 == null && dot.s2 != seg){
				dot.s1 = seg;
			}
			else if(dot.s2 == null && dot.s1 != seg){
				dot.s2 = seg;
			}

			dot = addDot(seg.p2);
			if(dot.s1 == null && dot.s2 != seg){
				dot.s1 = seg;
			}
			else if(dot.s2 == null && dot.s1 != seg){
				dot.s2 = seg;
			}

			if(seg is QuadBezierSegment){
				var seg1:QuadBezierSegment = seg as QuadBezierSegment;

				dot = addDot(seg1.c1);
				dot.c1 = seg1;
			}
			if(seg is CubicBezierSegment){
				var seg2:CubicBezierSegment = seg as CubicBezierSegment;

				dot = addDot(seg2.c1);
				dot.c1 = seg2;

				dot = addDot(seg2.c2);
				dot.c2 = seg2;
			}
		}

		protected function addDot(point:Point):Dot{
			var dot:Dot = getDot(point);
			if(dot == null){
				dot = new Dot();
				dot.addEventListener(MouseEvent.MOUSE_OUT, pointOutAction);
				dot.addEventListener(MouseEvent.MOUSE_DOWN, pointDownAction);
				dot.addEventListener(MouseEvent.MOUSE_OVER, pointOverAction);
				dot.x = point.x*Global.zoom;
				dot.y = -point.y*Global.zoom;
				dot.point = point;

				dotlist.push(dot);
				return dot;
			}
			return dot;
		}

		// we check whether a dot should be added based on local mouse position
		// this is much faster than adding all dots beforehand and using visible = true/false
		protected function checkDot(lx:Number, ly:Number):void{

			// check whether we are over a point on the path, and if we are, add a dot to show it
			var sx:Number;
			var sy:Number;

			var dot:Dot;

			for(var i=0; i<seglist.length; i++){
				dot = null;

				sx = seglist[i].p1.x*Global.zoom;
				sy = -seglist[i].p1.y*Global.zoom;
				if((lx>sx-8&&lx<sx+8) && (ly>sy-8&&ly<sy+8)){
					dot = getDot(seglist[i].p1);
				}

				sx = seglist[i].p2.x*Global.zoom;
				sy = -seglist[i].p2.y*Global.zoom;
				if((lx>sx-8&&lx<sx+8) && (ly>sy-8&&ly<sy+8)){
					dot = getDot(seglist[i].p2);
				}
				if(dot != null){
					addChild(dot);
				}

			}
			/*var sx:Number;
			var sy:Number;

			var dot:Dot;

			// add a dot whenever we hover over a point
			for(var i=0; i<seglist.length; i++){
				sx = seglist[i].p1.x*Global.zoom;
				sy = seglist[i].p1.y*Global.zoom;
				if((lx>sx-8&&lx<sx+8) && (ly>sy-8&&ly<sy+8)){

					dot = checkDotExists(seglist[i].p1);
					if(dot == null){
						dot = new Dot();
						dot.addEventListener(MouseEvent.MOUSE_OUT, pointOutAction);
						dot.addEventListener(MouseEvent.MOUSE_DOWN, pointDownAction);
						//dot.addEventListener(MouseEvent.MOUSE_UP, pointUpAction);
						dot.addEventListener(MouseEvent.MOUSE_OVER, pointOverAction);
						dot.x = sx;
						dot.y = sy;
						dot.point = seglist[i].p1;
						addChild(dot);
					}
					dot.point = seglist[i].p1;

					if(!dot.s1){
						dot.s1 = seglist[i];
					}
					else if(!dot.s2 && seglist[i] != dot.s1){
						dot.s2 = seglist[i];
					}
				}

				sx = seglist[i].p2.x*Global.zoom;
				sy = seglist[i].p2.y*Global.zoom;
				if((lx>sx-8&&lx<sx+8) && (ly>sy-8&&ly<sy+8)){

					dot = checkDotExists(seglist[i].p2);
					if(dot == null){
						dot = new Dot();
						dot.addEventListener(MouseEvent.MOUSE_OUT, pointOutAction);
						dot.addEventListener(MouseEvent.MOUSE_DOWN, pointDownAction);
						//dot.addEventListener(MouseEvent.MOUSE_UP, pointUpAction);
						dot.addEventListener(MouseEvent.MOUSE_OVER, pointOverAction);
						dot.x = sx;
						dot.y = sy;
						dot.point = seglist[i].p2;
						addChild(dot);
					}

					dot.point = seglist[i].p2;
					if(!dot.s2){
						dot.s2 = seglist[i];
					}
					else if(!dot.s1 && seglist[i] != dot.s2){
						dot.s1 = seglist[i];
					}
				}

			}*/
		}

		// same function as checkdot, but only for sketch dots
		protected function checkDotSketch(lx:Number, ly:Number):void{
			var sx:Number;
			var sy:Number;

			var dot:Dot;

			var op:Array = openArray();

			for(var i:int=0; i<op.length; i++){
				sx = op[i].x*Global.zoom;
				sy = -op[i].y*Global.zoom;

				if((lx>sx-8&&lx<sx+8) && (ly>sy-8&&ly<sy+8)){
					dot = getDot(op[i]);

					//if(dot == null){
						//dot = new Dot();
						dot.setSketch();
						dot.addEventListener(MouseEvent.MOUSE_DOWN, sketchPointDown);
						dot.addEventListener(MouseEvent.MOUSE_OUT, sketchPointOut);

						//dot.x = sx;
						//dot.y = sy;
						//dot.point = op[i];
						dot.looppath = this;

						addChild(dot);
					//}
				}
			}

		}

		protected function sketchPointDown(e:MouseEvent):void{
			e.stopPropagation();

			var main:* = this.parent.parent;
			main.startSketch(e);

			var sketchdot:Dot = e.target as Dot;
			if(sketchdot != null && contains(sketchdot)){
				removeChild(sketchdot);
			}
		}

		protected function sketchPointOut(e:MouseEvent):void{
			var sketchdot:Dot = e.target as Dot;
			if(sketchdot != null){
				sketchdot.setInactive();
				sketchdot.removeEventListener(MouseEvent.MOUSE_DOWN, sketchPointDown);
				sketchdot.removeEventListener(MouseEvent.MOUSE_OUT, sketchPointOut);
			}
			if(sketchdot != null && contains(sketchdot)){
				removeChild(sketchdot);
			}
		}

		protected function setLineStyle(style:int):void{
			linestyle = style;
			for each(var seg in seglist){
				seg.setLineStyle(style);
			}
		}

		protected function overAction(e:MouseEvent):void{
			if(Global.tool == 3 && Global.dragging == false && Global.space == false){
				checkDot(this.mouseX, this.mouseY);
			}
			else if(Global.tool == 1 && Global.dragging == false && Global.space == false){
				checkDotSketch(this.mouseX, this.mouseY);
			}
		}

		protected function downAction(e:MouseEvent):void{
			if((Global.tool == 0 || Global.tool == 3) && Global.space == false){
				//e.stopPropagation();

				//dragging = true;
				Global.dragging = true;

				//xstart = e.stageX;
				//ystart = e.stageY;

				//this.parent.addChild(this) // add to top of z-stack
			}
		}

		protected function moveAction(e:MouseEvent):void{
			if(Global.tool == 3 && Global.dragging == false && Global.space == false && e.target == this){
				checkDot(this.mouseX, this.mouseY);
			}
			else if(Global.tool == 1 && Global.dragging == false && Global.space == false){
				checkDotSketch(this.mouseX, this.mouseY);
			}
		}

		protected function upAction(e:MouseEvent):void{
			if(Global.tool == 0 || Global.tool == 3){
				//dragging = false;
				Global.dragging = false;
				clearInactive();
			}
		}

		public function setActive():void{
			active = true;
			redraw();
		}

		public function setInactive():void{
			active = false;
			redraw();
		}

		// if segment is given, only redraw given segment
		public function redraw(seg:Segment = null):void{

			var i:int;
			var dot:Dot;

			if(seg == null){
				renderClear();
				if(active == false){
					setLineStyle(0);
				}
				else{
					setLineStyle(1);
				}

				// update control dot positions
				if(Global.tool == 3){
					for each(dot in dotlist){
						dot.x = dot.point.x*Global.zoom;
						dot.y = -dot.point.y*Global.zoom;
					}
				}
				render();
			}
			else{
				seg.graphics.clear();

				var seg1:CubicBezierSegment;
				var seg2:QuadBezierSegment;

				if(active == false){
					seg.setLineStyle(0);
				}
				else{
					seg.setLineStyle(1);
				}
				if(seg is CubicBezierSegment){
					seg1 = seg as CubicBezierSegment;
					renderCubic(seg1);
				}
				else if(seg is QuadBezierSegment){
					seg2 = seg as QuadBezierSegment;
					renderQuad(seg2);
				}
				else if(seg is ArcSegment){
					var seg3:ArcSegment = seg as ArcSegment;
					renderArc(seg3);
				}
				else{
					renderLine(seg);
				}
				if(Global.tool == 3){
					for each(dot in dotlist){
						if(dot != null && (dot.point == seg.p1 || dot.point == seg.p2 || (seg2 && dot.point == seg2.c1) || (seg1 && (dot.point == seg1.c1 || dot.point == seg1.c2)))){
							dot.x = dot.point.x*Global.zoom;
							dot.y = -dot.point.y*Global.zoom;
						}
					}
				}
			}
		}

		public function renderClear():void{
			for each(var seg in seglist){
				seg.graphics.clear();
			}
		}

		public function clearDots():void{
			// remove all helper objects (dots, etc)
			var removelist:Array = new Array();

			for(var i:int=0; i<numChildren; i++){
				var obj:Object = getChildAt(i);
				if(!(obj is Segment)){
					removelist.push(obj);
				}
			}

			for each(var item in removelist){
				removeChild(item);
			}
		}

		protected function clearInactive():void{
			// remove inactive helper objects (dots, etc)
			var removelist:Array = new Array();

			for(var i:int=0; i<numChildren; i++){
				if(getChildAt(i) is Dot){
					var dot:Dot = getChildAt(i) as Dot;
					if(dot.active == false){
						removelist.push(dot);
					}
					else if(dot.c1 && dot.c1.active == false){
						removelist.push(dot);
					}
					else if(dot.c2 && dot.c2.active == false){
						removelist.push(dot);
					}
				}
			}

			for(i=0;i<removelist.length; i++){
				removeChild(removelist[i]);
			}
		}

		public function setDotsInactive():void{
			// make all dots inactive
			/*for(var i=0; i<numChildren; i++){
				if(getChildAt(i) is Dot){
					var dot:Dot = getChildAt(i) as Dot;
					dot.setInactive();
				}
			}
			// also make all segments inactive
			setSegmentsInactive();*/

			// set dots with inactive segments as inactive
			for each(var dot in dotlist){
				if((!dot.s1 || dot.s1.active == false) && (!dot.s2 || dot.s2.active == false) && (!dot.c1 || dot.c1.active == false) && (!dot.c2 || dot.c2.active == false)){
					dot.setInactive();
				}
			}
		}

		public function redrawDots():void{
			// remove all dots and add new dots
			while(dotlist.length > 0){
				var dot = dotlist.shift();
				if(contains(dot)){
					removeChild(dot);
				}
			}

			for each(var seg in seglist){
				addDots(seg);
			}
		}

		protected function deleteDots(seg:Segment):void{
			var dot:Dot;

			dot = getDot(seg.p1);
			if(dot.s2 == null){
				deleteDot(dot);
			}
			else{
				dot.s1 = null;
			}

			dot = getDot(seg.p2);
			if(dot.s1 == null){
				deleteDot(dot);
			}
			else{
				dot.s2 = null;
			}

			if(seg is QuadBezierSegment){
				var seg1:QuadBezierSegment = seg as QuadBezierSegment;
				deleteDot(getDot(seg1.c1));
			}
			if(seg is CubicBezierSegment){
				var seg2:CubicBezierSegment = seg as CubicBezierSegment;
				deleteDot(getDot(seg2.c1));
				deleteDot(getDot(seg2.c2));
			}
		}

		protected function deleteDot(dot:Dot):void{
			if(dot != null && contains(dot)){
				removeChild(dot);
			}

			var index:int = dotlist.indexOf(dot);

			if(index != -1){
				dotlist.splice(index,1);
			}
		}

		public function setSegmentsInactive():void{
			for(var i:int=0; i<seglist.length; i++){
				seglist[i].active = false;
			}
		}

		protected function addQuadControls(seg:QuadBezierSegment):void{
			if(seg.active == true){
				var dot:Dot = getDot(seg.c1);
				/*if(dot == null){
					dot = new Dot();
					dot.x = seg.c1.x*Global.zoom;
					dot.y = seg.c1.y*Global.zoom;
					dot.setActive();
					dot.c1 = seg;
					dot.point = seg.c1;
					renderQuadGuides(seg);
					addChild(dot);
					dot.addEventListener(MouseEvent.MOUSE_DOWN, pointDownAction);
					//dot.addEventListener(MouseEvent.MOUSE_UP, pointUpAction);
				}
				else{*/
					dot.c1.active = true;
					dot.setActive();
					addChild(dot);
				//}
			}
		}

		protected function renderQuadGuides(seg:QuadBezierSegment):void{
			var tempstyle = seg.linestyle;
			seg.setLineStyle(2);
			seg.graphics.moveTo(seg.p1.x*Global.zoom, -seg.p1.y*Global.zoom);
			seg.graphics.lineTo(seg.c1.x*Global.zoom, -seg.c1.y*Global.zoom);
			//graphics.lineTo(seg.p2.x*Global.zoom, seg.p2.y*Global.zoom);
			seg.setLineStyle(tempstyle);
		}

		protected function addCubicControls(seg:CubicBezierSegment):void{
			if(seg.active == true){
				var dot:Dot = getDot(seg.c1);
				/*if(dot == null){
					dot = new Dot();
					dot.x = seg.c1.x*Global.zoom;
					dot.y = seg.c1.y*Global.zoom;
					dot.setActive();
					dot.c1 = seg;
					dot.point = seg.c1;
					renderCubicGuides(seg);
					addChild(dot);
					dot.addEventListener(MouseEvent.MOUSE_DOWN, pointDownAction);
					//dot.addEventListener(MouseEvent.MOUSE_UP, pointUpAction);
				}
				else{*/
					dot.c1.active = true;
					dot.setActive();
					addChild(dot);
				//}

				dot = getDot(seg.c2);
				/*if(dot == null){
					dot = new Dot();
					dot.x = seg.c2.x*Global.zoom;
					dot.y = seg.c2.y*Global.zoom;
					dot.setActive();
					dot.c2 = seg;
					dot.point = seg.c2;
					renderCubicGuides(seg);
					addChild(dot);
					dot.addEventListener(MouseEvent.MOUSE_DOWN, pointDownAction);
					//dot.addEventListener(MouseEvent.MOUSE_UP, pointUpAction);
				}
				else{*/
					dot.c2.active = true;
					dot.setActive();
					addChild(dot);
				//}
			}
		}

		protected function renderCubicGuides(seg:CubicBezierSegment):void{
			var tempstyle = seg.linestyle;
			seg.setLineStyle(2);
			seg.graphics.moveTo(seg.p1.x*Global.zoom, -seg.p1.y*Global.zoom);
			seg.graphics.lineTo(seg.c1.x*Global.zoom, -seg.c1.y*Global.zoom);

			seg.graphics.moveTo(seg.p2.x*Global.zoom, -seg.p2.y*Global.zoom);
			seg.graphics.lineTo(seg.c2.x*Global.zoom, -seg.c2.y*Global.zoom);
			seg.setLineStyle(tempstyle);
		}

		protected function clearControls(dot:Dot):void{

			// remove extraneous inactive controls

			/*var removelist:Array = new Array();
			for(var i:int=0; i<numChildren; i++){
				if(getChildAt(i) is Dot){
					removelist.push(getChildAt(i));
				}
			}

			for each(var item in removelist){
				removeChild(item);
			}*/
		}

		protected function unsetDotsCurrent():void{
			for(var i=0; i<numChildren; i++){
				if(getChildAt(i) is Dot){
					var dot:Dot = getChildAt(i) as Dot;
					dot.unsetCurrent();
				}
			}

			if(coord != null && this.parent.contains(coord)){
				this.parent.removeChild(coord);
			}
		}

		protected function pointOutAction(e:MouseEvent):void{
			clearInactive();
		}

		protected function pointOverAction(e:MouseEvent):void{
			if(Global.tool == 3 && Global.dragging == false){
				e.stopPropagation();

				var dot:Dot = e.target as Dot;
				if(dragging && dot.current){
					pointManipulatorUpdate(dot);
				}
			}
		}

		protected function pointDownAction(e:MouseEvent):void{
			if(Global.tool == 3){

				this.cacheAsBitmap = false;

				e.target.addEventListener(MouseEvent.MOUSE_MOVE, pointMoveAction);
				e.target.addEventListener(MouseEvent.MOUSE_UP, pointUpAction);
				e.target.removeEventListener(MouseEvent.MOUSE_OUT, pointOutAction);

				var dot:Dot = e.target as Dot;

				xstart = this.mouseX;
				ystart = this.mouseY;

				addChild(dot); // put on top of z-index

				// add marker of the start point, so we can go back if necessary
				startpoint = dot.point.clone();

				dragging = true;
				Global.dragging = true;

				e.target.startDrag();

				setSegmentsInactive();
				setInactive();

				if(dot.s1 != null){ dot.s1.active = true;}
				if(dot.s2 != null){ dot.s2.active = true;}
				if(dot.c1 != null){ dot.c1.active = true;}
				if(dot.c2 != null){ dot.c2.active = true;}

				setDotsInactive();

				e.target.setActive();
				e.target.setDragging();

				clearInactive();

				if(e.target.c1 == null && e.target.c2 == null){
					clearControls(dot);
				}

				addCoord(dot);

				if(e.target.s1 is QuadBezierSegment){
					e.target.s1.active = true;
					addQuadControls(e.target.s1);
				}
				if(e.target.s2 is QuadBezierSegment){
					e.target.s2.active = true;
					addQuadControls(e.target.s2);
				}

				if(e.target.s1 is CubicBezierSegment){
					e.target.s1.active = true;
					addCubicControls(e.target.s1);
				}
				if(e.target.s2 is CubicBezierSegment){
					e.target.s2.active = true;
					addCubicControls(e.target.s2);
				}

				pointManipulatorUpdate(dot);

				var main:* = this.parent;
				main.clearDots(this);
				main.addChild(this); // path should be on top while dragging

				startdot = new Shape();
				startdot.graphics.beginFill(0x000000);
				startdot.graphics.drawRect(0,-6,1,13);
				startdot.graphics.drawRect(-6,0,13,1);
				startdot.graphics.endFill();
				startdot.x = startpoint.x*Global.zoom;
				startdot.y = -startpoint.y*Global.zoom;

				addChild(startdot);
			}

		}

		protected function pointUpAction(e:MouseEvent):void{
			e.stopPropagation();
			e.target.stopDrag();

			dragging = false;
			Global.dragging = false;
			e.target.unsetDragging();

			// remove initial point marker

			if(contains(startdot)){
				removeChild(startdot);
			}

			e.target.removeEventListener(MouseEvent.MOUSE_MOVE, pointMoveAction);
			e.target.removeEventListener(MouseEvent.MOUSE_UP, pointUpAction);
			e.target.addEventListener(MouseEvent.MOUSE_OUT, pointOutAction);

			var dot:Dot = e.target as Dot;

			if(dot && dot.loop == true && dot.looppath != null && dot.looppath != this){
				mergePath(dot.looppath);
				dot.active = false;
				setInactive();
				clearInactive();
			}
			else if(dot && dot.loop == true){
				dot.active = false;
				setInactive();
				clearInactive();
			}
			else{
				pointManipulatorUpdate(dot);
			}

			// merge points
			if(dot && dot.loop == true && dot.looppoint){
				if(dot.s1 && Global.withinTolerance(dot.s1.p1,dot.looppoint,0.01)){
					dot.s1.p1 = dot.looppoint;
				}
				else if(dot.s1 && Global.withinTolerance(dot.s1.p2,dot.looppoint,0.01)){
					dot.s1.p2 = dot.looppoint;
				}
				if(dot.s2 && Global.withinTolerance(dot.s2.p1,dot.looppoint,0.01)){
					dot.s2.p1 = dot.looppoint;
				}
				else if(dot.s2 && Global.withinTolerance(dot.s2.p2,dot.looppoint,0.01)){
					dot.s2.p2 = dot.looppoint;
				}
				redrawDots();
			}

			// set undo point
			if(!dot.point.equals(startpoint)){
				var scene:SceneGraph = this.parent as SceneGraph;
				if(scene != null){
					var undo:UndoPointMove = new UndoPointMove(scene);
					undo.point = dot.point;
					undo.path = this;
					undo.undopoint = startpoint.clone();
					undo.redopoint = dot.point.clone();
					Global.undoPush(undo);

					// update cutpaths
					scene.redrawCuts();
				}

				// set dirty flag for cam operations
				dirty = true;
				camdirty = true;


			}

			this.cacheAsBitmap = true;

		}

		public function pubPointUpAction():void{
			// handle an event where the mouse leaves the stage
			for(var i:int=0; i<numChildren; i++){
				if(getChildAt(i) is Dot){
					var dot:Dot = getChildAt(i) as Dot;
					dot.stopDrag();
					dot.removeEventListener(MouseEvent.MOUSE_MOVE, pointMoveAction);
					//clearInactive();
					dragging = false;
					Global.dragging = false;
				}
			}

		}

		protected function pointMoveAction(e:MouseEvent):void{
			e.stopPropagation();

			var dot:Dot = e.target as Dot;

			if(dot.current == true && dot.active == true){
				pointManipulatorUpdate(dot);
			}
			/*var sx:Number;
			var sy:Number;

			var lx:Number = e.stageX;
			var ly:Number = e.stageY;

			for(var i=0; i<seglist.length; i++){
				sx = seglist[i].p1.x*Global.zoom;
				sy = seglist[i].p1.y*Global.zoom;
				if((lx>sx-5&&lx<sx+5) && (ly>sy-5&&ly<sy+5)){
					seglist[i].p1.x += xdelta;
					seglist[i].p1.y += ydelta;
				}

				sx = seglist[i].p2.x*Global.zoom;
				sy = seglist[i].p2.y*Global.zoom;
				if((lx>sx-5&&lx<sx+5) && (ly>sy-5&&ly<sy+5)){
					seglist[i].p2.x += xdelta;
					seglist[i].p2.y += ydelta;
				}
			}*/

		}

		protected function pointManipulatorUpdate(dot:Dot):void{
			var xdelta:Number = (dot.x - xstart)/Global.zoom;
			var ydelta:Number = (dot.y - ystart)/Global.zoom;

			// x/y coordinates to snap to, in local coordinates
			var xsnap:Number;
			var ysnap:Number;

			var xerror:Number = 12;
			var yerror:Number = 12;

			/*if(Global.snap == true){
				var xstartfixed:Number;
				var ystartfixed:Number;

				for(var i:int=0; i<seglist.length; i++){
					if(seglist[i].p2 != dot.point){
						xstartfixed = (seglist[i].p2.x + docx)*Global.zoom;
						ystartfixed = (seglist[i].p2.y + docy)*Global.zoom;
						if(Math.abs(this.mouseX - xstartfixed) < xerror){
							xerror = Math.abs(this.mouseX - xstartfixed);
							xpoint = seglist[i].p2;
						}
						if(Math.abs(this.mouseY - ystartfixed) < yerror){
							yerror = Math.abs(this.mouseY - ystartfixed);
							ypoint = seglist[i].p2;
						}
					}
				}

				if(Math.abs(this.mouseX - xstart) < xerror && Math.abs(e.stageY - ystart) < yerror){
					snap = true;
					snappos = new Point(startpoint.x + docx,startpoint.y + docy);
				}
				else if(Math.abs(this.mouseX - xstart) < xerror){
					snap = true;
					//snappos = new Point(startpoint.x + docx,((e.stageY - Global.yorigin)/Global.zoom));
					xerror = Math.abs(this.mouseX - xstart);
					xpoint = startpoint;
				}
				else if(Math.abs(e.stageY - ystart) < yerror){
					snap = true;
					//snappos = new Point(((e.stageX - Global.xorigin)/Global.zoom),startpoint.y + docy);
					yerror = Math.abs(e.stageY - ystart);
					ypoint = startpoint;
				}

				if(xerror < 12 && yerror < 12){
					snap = true;
					snappos = new Point(xpoint.x + docx,ypoint.y + docy);
				}
				else if(xerror < 12){
					snap = true;
					snappos = new Point(xpoint.x + docx,(this.mouseY/Global.zoom));
				}
				else if(yerror < 12){
					snap = true;
					snappos = new Point((this.mouseX/Global.zoom),ypoint.y + docy);
				}

				var globalpos:Point = new Point(this.mouseX/Global.zoom,this.mouseY/Global.zoom);
				var tempsnappos:Point = new Point(Math.round(globalpos.x), Math.round(globalpos.y));

				var currenterror:Number = Point.distance(globalpos, tempsnappos);
				if(currenterror < 0.15){
					snap = true;
					snappos = tempsnappos;
				}
			}*/

			var xstartfixed:Number;
			var ystartfixed:Number;


			// snap to starting point
			if(Math.abs(this.mouseX - xstart) < xerror){
				xerror = Math.abs(this.mouseX - xstart);
				xsnap = startpoint.x;
			}

			if(Math.abs(this.mouseY - ystart) < yerror){
				yerror = Math.abs(this.mouseY - ystart);
				ysnap = startpoint.y;
			}

			// snap to local points
			if(Global.localsnap == true){
				for(var i:int=0; i<seglist.length; i++){
					if(seglist[i].p2 != dot.point){
						xstartfixed = seglist[i].p2.x*Global.zoom;
						ystartfixed = -seglist[i].p2.y*Global.zoom;
						if(Math.abs(this.mouseX - xstartfixed) < xerror){
							xerror = Math.abs(this.mouseX - xstartfixed);
							xsnap = seglist[i].p2.x;
						}
						if(Math.abs(this.mouseY - ystartfixed) < yerror){
							yerror = Math.abs(this.mouseY - ystartfixed);
							ysnap = seglist[i].p2.y;
						}
						//trace(Math.abs(this.mouseX - xstartfixed), Math.abs(-this.mouseY - ystartfixed));
					}
				}
			}

			// snap to global grid
			if(Global.snap == true){
				var globalx:Number = this.mouseX/Global.zoom + docx;
				var globaly:Number = -this.mouseY/Global.zoom - docy;

				var residualx:Number = Math.abs(globalx - Math.round(globalx))*Global.zoom;
				var residualy:Number = Math.abs(globaly - Math.round(globaly))*Global.zoom;

				trace(residualx, residualy);

				if(residualx < xerror){
					xerror = residualx;
					xsnap = Math.round(globalx) - docx;
				}
				if(residualy < yerror){
					yerror = residualy;
					ysnap = Math.round(globaly) + docy;
				}
			}

			// snap/join open points
			if(dot && ((dot.s1 && !dot.s2) || (dot.s2 && !dot.s1))){ // only open end points can snap to other open end points

				var scene:* = this.parent;
				var looppoint:Point = scene.closeLoop(dot);

				if(looppoint != null){
					xerror = 0;
					yerror = 0;

					xsnap = looppoint.x;
					ysnap = looppoint.y;

					xsnap -= docx;
					ysnap += docy;

					dot.setLoop();
				}
				else{
					dot.unsetLoop();
				}
			}

			var pos:Point;

			if(xerror < 12){
				dot.x = xsnap*Global.zoom;
				dot.point.x = xsnap;
			}
			else{
				dot.x = this.mouseX;
				dot.point.x = this.mouseX/Global.zoom;
			}

			if(yerror < 12){
				dot.y = ysnap*Global.zoom;
				dot.point.y = ysnap;
			}
			else{
				dot.y = this.mouseY;
				dot.point.y = -this.mouseY/Global.zoom;
			}

			pos = new Point(dot.point.x,dot.point.y);

			// redraw nearby paths only
			if(dot.s1 != null){
				redraw(dot.s1);
			}
			if(dot.s2 != null){
				redraw(dot.s2);
			}
			if(dot.c1 != null){
				redraw(dot.c1);
			}
			if(dot.c2 != null){
				redraw(dot.c2);
			}

			coordSetPos(pos);
		}

		protected function addCoord(dot:Dot):void{
			unsetDotsCurrent();
			dot.setCurrent(); // note: "active" dots are related to the currently selected segment (all start/end, and curve control points). While the "current" is the single dot editable by the coordinate box
			coord = new coordinates();
			coord.x = xstart;
			coord.y = -ystart;
			coord.dot = dot;

			coord.xbox.restrict = "0-9.";
			coord.ybox.restrict = "0-9.";

			this.parent.addChild(coord);
			coord.addEventListener(MouseEvent.MOUSE_DOWN, coordDown);
			coord.addEventListener(MouseEvent.MOUSE_MOVE, coordMove);
			coord.addEventListener(MouseEvent.MOUSE_UP, coordUp);
			coord.xbox.addEventListener(Event.CHANGE, coordInput);
			coord.ybox.addEventListener(Event.CHANGE, coordInput);
		}

		protected function coordSetPos(pos:Point):void{
			// now move coordinate box
			if(coord != null && pos != null){
				coord.x = (pos.x + docx)*Global.zoom;
				coord.y = -(pos.y - docy)*Global.zoom;
				coord.xbox.text = Number(docx + pos.x).toFixed(4) + " " + Global.unit;
				coord.ybox.text = Number(-docy + pos.y).toFixed(4) + " " + Global.unit;
			}
		}

		protected function coordInput(e:Event):void{

			var c = e.target.parent;
			var input:String = e.target.text;
			var inputnum:Number = Number(input.replace(/[^0-9-'.']/g,""));

			if(inputnum > 100){
				inputnum = 100;
			}

			if(c.dot.parent != null){
				if(e.target.name == "xbox"){
					inputnum -= c.dot.parent.docx;
					if(c.dot.point.x != inputnum){
						c.dot.x = inputnum*Global.zoom;
						c.dot.point.x = inputnum;
						dirty = true;
						camdirty = true;
					}
				}
				else if(e.target.name == "ybox"){
					inputnum += c.dot.parent.docy;
					if(c.dot.point.y != inputnum){
						c.dot.y = inputnum*Global.zoom;
						c.dot.point.y = inputnum;
						dirty = true;
						camdirty = true;
					}
				}
			}
			redraw();
		}

		protected function coordDown(e:MouseEvent):void{
			e.stopPropagation();
		}

		protected function coordMove(e:MouseEvent):void{
			e.stopPropagation();
		}

		protected function coordUp(e:MouseEvent):void{
			e.stopPropagation();
		}

		// if self is set to "true" render to the path itself
		protected function renderLine(seg:Segment, sprite:Sprite = null):void{
			if(sprite == null){
				sprite = seg;
			}

			sprite.graphics.moveTo(seg.p1.x*Global.zoom, -seg.p1.y*Global.zoom);
			sprite.graphics.lineTo(seg.p2.x*Global.zoom, -seg.p2.y*Global.zoom);

			/*var norm:Point = new Point(-seg.p2.y+seg.p1.y, seg.p2.x-seg.p1.x);

			var distance:Number = Point.distance(seg.p1,seg.p2);

			norm.normalize(distance/5);

			var mid:Point = new Point(0.9*seg.p2.x+0.1*seg.p1.x, 0.9*seg.p2.y+0.1*seg.p1.y);
			var a1:Point = new Point(mid.x + norm.x, mid.y + norm.y);
			var a2:Point = new Point(mid.x - norm.x, mid.y - norm.y);

			seg.graphics.moveTo(seg.p2.x*Global.zoom, -seg.p2.y*Global.zoom);
			seg.graphics.lineTo(a1.x*Global.zoom, -a1.y*Global.zoom);

			seg.graphics.moveTo(seg.p2.x*Global.zoom, -seg.p2.y*Global.zoom);
			seg.graphics.lineTo(a2.x*Global.zoom, -a2.y*Global.zoom);*/
		}

		protected function renderCubic(seg:CubicBezierSegment, sprite:Sprite = null):void{

			if(sprite == null){
				sprite = seg;
			}

			// use Lorentz's bezier class to approximate cubic curve with quad curve
			var bezier:Bezier = new Bezier(seg.p1, seg.c1, seg.c2, seg.p2);
			var tp1:Point = seg.p1;
			var tp2:Point;
			var tc1:Point;

			var quadP:Object

			// first render guides
			if(seg.active){
				renderCubicGuides(seg);
			}

			for each (quadP in bezier.QPts){
				tp2 = new Point(quadP.p.x, quadP.p.y);
				tc1 = new Point(quadP.c.x, quadP.c.y);
				renderQuad(new QuadBezierSegment(tp1, tp2, tc1), sprite);
				tp1 = tp2;
			}
		}

		protected function renderQuad(seg:QuadBezierSegment, sprite:Sprite = null):void{
			if(seg.active){
				renderQuadGuides(seg);
			}

			// sprite is the sprite object that we render to
			// this is necessary because elliptical arcs and cubics also use the quad function for rendering
			if(sprite == null){
				sprite = seg;
			}

			sprite.graphics.moveTo(seg.p1.x*Global.zoom, -seg.p1.y*Global.zoom);
			sprite.graphics.curveTo(seg.c1.x*Global.zoom, -seg.c1.y*Global.zoom, seg.p2.x*Global.zoom, -seg.p2.y*Global.zoom);
		}

		protected function renderArc(seg:ArcSegment, sprite:Sprite = null):void{ // note the inverted sweep flag. This is because our definitions of p1 and p2 are reversed
			//var ellipticalArc:Object = computeSvgArc(seg.rx, seg.ry, seg.angle, seg.lf, !seg.sf, seg.p1.x, seg.p1.y, seg.p2.x, seg.p2.y);
			var ellipticalArc:Object  = seg.computeSvgArc();
			drawEllipticalArc(seg, seg.p2, ellipticalArc.cx, ellipticalArc.cy, ellipticalArc.startAngle, ellipticalArc.arc, ellipticalArc.radius, ellipticalArc.yRadius, ellipticalArc.xAxisRotation, sprite);

			/*var norm:Point = new Point(-seg.p2.y+seg.p1.y, seg.p2.x-seg.p1.x);

			var distance:Number = Point.distance(seg.p1,seg.p2);

			norm.normalize(distance/5);

			var mid:Point = new Point(0.9*seg.p2.x+0.1*seg.p1.x, 0.9*seg.p2.y+0.1*seg.p1.y);
			var a1:Point = new Point(mid.x + norm.x, mid.y + norm.y);
			var a2:Point = new Point(mid.x - norm.x, mid.y - norm.y);

			seg.graphics.moveTo(seg.p2.x*Global.zoom, -seg.p2.y*Global.zoom);
			seg.graphics.lineTo(a1.x*Global.zoom, -a1.y*Global.zoom);

			seg.graphics.moveTo(seg.p2.x*Global.zoom, -seg.p2.y*Global.zoom);
			seg.graphics.lineTo(a2.x*Global.zoom, -a2.y*Global.zoom);*/
		}

		protected static function degreesToRadians(angle:Number):Number{
			return angle*(Math.PI/180);
		}

		protected static function radiansToDegrees(angle:Number):Number{
			return angle*(180/Math.PI);
		}

		protected function drawEllipticalArc(seg:Segment, startpoint:Point, x:Number, y:Number, startAngle:Number, arc:Number, radius:Number,yRadius:Number, xAxisRotation:Number=0, sprite:Sprite = null):void
		{
			if(sprite == null){
				sprite = seg;
			}
			// Circumvent drawing more than is needed
			if (Math.abs(arc)>360)
			{
					arc = 360;
			}

			// Draw in a maximum of 45 degree segments. First we calculate how many
			// segments are needed for our arc.
			var segs:Number = Math.ceil(Math.abs(arc)/45);

			// Now calculate the sweep of each segment
			var segAngle:Number = arc/segs;

			var theta:Number = degreesToRadians(segAngle);
			var angle:Number = degreesToRadians(startAngle);

			// Draw as 45 degree segments
			if (segs>0)
			{
				var beta:Number = degreesToRadians(xAxisRotation);
				var sinbeta:Number = Math.sin(beta);
				var cosbeta:Number = Math.cos(beta);

				var cx:Number;
				var cy:Number;
				var x1:Number;
				var y1:Number;

				var tp1:Point = startpoint; // note that we start at the "end" of the arc as defined in arcSegment
				var tp2:Point;
				var tc1:Point;

				// Loop for drawing arc segments
				for (var i:int = 0; i<segs; i++)
				{
						angle += theta;

						var sinangle:Number = Math.sin(angle-(theta/2));
						var cosangle:Number = Math.cos(angle-(theta/2));

						var div:Number = Math.cos(theta/2);
						cx= x + (radius * cosangle * cosbeta - yRadius * sinangle * sinbeta)/div;
						cy= y + (radius * cosangle * sinbeta + yRadius * sinangle * cosbeta)/div;

						sinangle = Math.sin(angle);
						cosangle = Math.cos(angle);

						x1 = x + (radius * cosangle * cosbeta - yRadius * sinangle * sinbeta);
						y1 = y + (radius * cosangle * sinbeta + yRadius * sinangle * cosbeta);

						tp2 = new Point(x1,y1);
						tc1 = new Point(cx, cy);

						renderQuad(new QuadBezierSegment(tp1, tp2, tc1), sprite);

						tp1 = tp2;
				}
			}
		}

		public function inchToCm():void{
			unitConvert(2.54);
		}

		public function cmToInch():void{
			unitConvert(1/2.54);
		}

		public function unitConvert(factor:Number):void{

			docx = docx*factor;
			docy = docy*factor;

			var seg:Segment;
			var transformed:Array = new Array();

			for(var i:int=0; i<seglist.length; i++){
				seg = seglist[i];

				if(seg.p1 && transformed.indexOf(seg.p1) == -1){
					seg.p1.x = seg.p1.x*factor;
					seg.p1.y = seg.p1.y*factor;
					transformed.push(seg.p1);
				}
				if(seg.p2 && transformed.indexOf(seg.p2) == -1){
					seg.p2.x = seg.p2.x*factor;
					seg.p2.y = seg.p2.y*factor;
					transformed.push(seg.p2);
				}
				if((seg is QuadBezierSegment || seg is CubicBezierSegment) && seglist[i].c1 && transformed.indexOf(seglist[i].c1) == -1){
					seglist[i].c1.x = seglist[i].c1.x*factor;
					seglist[i].c1.y = seglist[i].c1.y*factor;
					transformed.push(seglist[i].c1);
				}
				if(seg is CubicBezierSegment && seglist[i].c2 && transformed.indexOf(seglist[i].c2) == -1){
					seglist[i].c2.x = seglist[i].c2.x*factor;
					seglist[i].c2.y = seglist[i].c2.y*factor;
					transformed.push(seglist[i].c2);
				}
				if(seg is CircularArc){
					seglist[i].center.x *= factor;
					seglist[i].center.y *= factor;

					seglist[i].radius *= factor;
				}
				if(seg is ArcSegment){
					seglist[i].rx *= factor;
					seglist[i].ry *= factor;
				}
			}

			redrawDots();
		}

		public function deleteActive():Boolean{
			// delete active segments
			var i:int = 0;
			while(i<seglist.length){
				if(seglist[i].active == true){
					if(contains(seglist[i])){
						removeChild(seglist[i]);
					}
					seglist.splice(i,1);
					i--;
				}
				i++;
			}
			redrawDots();
			setInactive();

			if(seglist.length == 0){
				return true;
			}
			else{
				return false;
			}
		}

		public function snapPoint(dot:Dot):Point{

			var seg:Segment;
			var globalpoint:Point;
			var snappoint:Point;

			var i:int;
			if(dot){
				var parentpath:Path = dot.parent as Path;
				var globalpos:Point = new Point(parentpath.mouseX/Global.zoom+parentpath.docx,(-parentpath.mouseY/Global.zoom)-parentpath.docy);
				/*if(dot.loop == true){
					if(dot.s1){
						globalpoint = new Point(dot.s1.p1.x + docx, dot.s1.p1.y + docy);
					}
					else if(dot.s2){
						globalpoint = new Point(dot.s2.p2.x + docx, dot.s2.p2.y + docy);
					}
					for(i=0; i<seglist.length; i++){
						if(seglist[i].p1){
							snappoint = new Point(seglist[i].p1.x + docx, seglist[i].p1.y + docy);
							if(Point.distance(snappoint, globalpoint) < .1){
								return globalpoint;
							}
						}
						if(seglist[i].p2){
							snappoint = new Point(seglist[i].p2.x + docx, seglist[i].p2.y + docy);
							if(Point.distance(snappoint, globalpoint) < .1){
								return globalpoint;
							}
						}
					}
				}*/
				//else{
					var op:Array = openArray(dot);

					for(i=0; i<op.length; i++){
						globalpoint = new Point(op[i].x + docx, op[i].y - docy);
						var self:Boolean = false;
						if(dot.point == op[i]){
							self = true;
						}

						var dis:Number = Point.distance(globalpos, globalpoint)*Global.zoom;

						if(Global.unit == "cm"){
							dis *= 2.54;
						}

						// 20 pixel snapping range
						if(self == false &&  dis < 20){
							dot.looppoint = op[i];

							return globalpoint;
						}
					}
				//}
			}

			return null;
		}

		// returns a list of all points that are open (open points do not have any other points attached to them)
		protected function openArray(dot:Dot = null):Array{
			var openarray:Array = new Array();
			for(var i:int=0; i<seglist.length; i++){
				var p1open = true;
				var p2open = true;
				for(var j:int=0; j<seglist.length; j++){
					if((dot == null || dot.looppoint == null || !seglist[i].p1.equals(dot.looppoint)) && ((seglist[i].p1.equals(seglist[j].p1) && i != j) || seglist[i].p1.equals(seglist[j].p2))){
						p1open = false;
					}
					if((dot == null || dot.looppoint == null || !seglist[i].p2.equals(dot.looppoint)) && (seglist[i].p2.equals(seglist[j].p1) || (seglist[i].p2.equals(seglist[j].p2) && i != j))){
						p2open = false;
					}
				}
				if(p1open){
					openarray.push(seglist[i].p1);
				}
				if(p2open){
					openarray.push(seglist[i].p2);
				}
			}

			return openarray;
		}

		public function mergePath(p:Path, point:Point = null, doubles:Boolean = true):void{ // if a point is given, attach the point to the first point of the new seglist (this is for sketch continuation)
			var dx:Number = p.docx;
			var dy:Number = p.docy;

			var newseglist:Array = p.deletePath();

			var transformed:Array = new Array();

			for(var i:int=0; i<newseglist.length; i++){
				if(newseglist[i].p1 && transformed.indexOf(newseglist[i].p1) == -1){
					newseglist[i].p1.x = newseglist[i].p1.x + dx - docx;
					newseglist[i].p1.y = newseglist[i].p1.y - dy + docy;
					transformed.push(newseglist[i].p1);
				}
				if(newseglist[i].p2 && transformed.indexOf(newseglist[i].p2) == -1){
					newseglist[i].p2.x = newseglist[i].p2.x + dx - docx;
					newseglist[i].p2.y = newseglist[i].p2.y - dy + docy;
					transformed.push(newseglist[i].p2);
				}
				if(newseglist[i] is QuadBezierSegment){
					var seg1:QuadBezierSegment = newseglist[i] as QuadBezierSegment;
					seg1.c1.x = seg1.c1.x + dx - docx;
					seg1.c1.y = seg1.c1.y + dy - docy;
				}
				if(newseglist[i] is CubicBezierSegment){
					var seg2:CubicBezierSegment = newseglist[i] as CubicBezierSegment;
					seg2.c1.x = seg2.c1.x + dx - docx;
					seg2.c1.y = seg2.c1.y + dy - docy;

					seg2.c2.x = seg2.c2.x + dx - docx;
					seg2.c2.y = seg2.c2.y + dy - docy;
				}
			}

			if(point){
				newseglist[0].p1 = point;
			}

			for each(var newseg in newseglist){
				addSegment(newseg);
			}

			if(doubles){
				removeDoubles();
			}
		}

		protected function removeDoubles():void{
			var removelist:Array = new Array();

			for(var i:int=0; i<seglist.length; i++){
				for(var j:int=i; j<seglist.length; j++){
					if(i!=j && seglist[i].p1.equals(seglist[j].p1) && seglist[i].p2.equals(seglist[j].p2)){
						if(removelist.indexOf(seglist[i]) == -1){
							removelist.push(j);
						}
					}
				}
			}

			for(i=0; i<removelist.length; i++){
				seglist.splice(removelist[i],1);
			}
		}

		// note: overall tolerance = global.tolerance * tol
		public function joinDoubles(tol:Number = 0.05, rejoin:Boolean = false):void{

			// keep a list of already joined points
			var joined:Array = new Array();

			for(var i:int=0; i<seglist.length; i++){
				for(var j:int=0; j<seglist.length; j++){
					if(i != j){
						if(seglist[i].p1 && seglist[j].p1 && seglist[i].p1 != seglist[j].p1 && joined.indexOf(seglist[i].p1) == -1 && joined.indexOf(seglist[j].p1) == -1 && Global.withinTolerance(seglist[i].p1, seglist[j].p1, tol)){
							seglist[i].p1 = seglist[j].p1;
							joined.push(seglist[i].p1);
						}
						if(seglist[i].p1 && seglist[j].p2 && seglist[i].p1 != seglist[j].p2 && joined.indexOf(seglist[i].p1) == -1 && joined.indexOf(seglist[j].p2) == -1 && Global.withinTolerance(seglist[i].p1, seglist[j].p2, tol)){
							seglist[i].p1 = seglist[j].p2;
							joined.push(seglist[i].p1);
						}
						if(seglist[i].p2 && seglist[j].p1 && seglist[i].p2 != seglist[j].p1 && joined.indexOf(seglist[i].p2) == -1 && joined.indexOf(seglist[j].p1) == -1 && Global.withinTolerance(seglist[i].p2, seglist[j].p1, tol)){
							seglist[i].p2 = seglist[j].p1;
							joined.push(seglist[i].p2);
						}
						if(seglist[i].p2 && seglist[j].p2 && seglist[i].p2 != seglist[j].p2 && joined.indexOf(seglist[i].p2) == -1 && joined.indexOf(seglist[j].p2) == -1 && Global.withinTolerance(seglist[i].p2, seglist[j].p2, tol)){
							seglist[i].p2 = seglist[j].p2;
							joined.push(seglist[i].p2);
						}
					}
				}
			}
		}

		public function deletePath():Array{
			var main:* = this.parent;
			if(main){
				if(main.contains(this)){
					main.removeChild(this);
				}
				var i:int = main.pathlist.indexOf(this);
				if(i != -1){
					main.pathlist.splice(main.pathlist.indexOf(this),1);
				}
			}
			return seglist;
		}

		public function getNumSeg():int{
			return seglist.length;
		}

		public function matrixTransform(m:Matrix):void{

			var id:Matrix = new Matrix();
			id.identity();

			if(id == m){
				return;
			}

			dirty = true;
			camdirty = true;

			var transformed:Array = new Array();

			for(var i:int=0; i<seglist.length; i++){
				var seg:Segment = seglist[i];
				var p:Point;
				if(seg.p1 && transformed.indexOf(seg.p1) == -1){
					p = m.transformPoint(seg.p1);
					seg.p1.x = p.x;
					seg.p1.y = p.y;
					transformed.push(seg.p1);
				}
				if(seg.p2 && transformed.indexOf(seg.p2) == -1){
					p = m.transformPoint(seg.p2);
					seg.p2.x = p.x;
					seg.p2.y = p.y;
					transformed.push(seg.p2);
				}
				if((seglist[i] is QuadBezierSegment || seglist[i] is CubicBezierSegment) && seglist[i].c1){
					p = m.transformPoint(seglist[i].c1);
					seglist[i].c1.x = p.x;
					seglist[i].c1.y = p.y;
				}
				if(seglist[i] is CubicBezierSegment && seglist[i].c2){
					p = m.transformPoint(seglist[i].c2);
					seglist[i].c2.x = p.x;
					seglist[i].c2.y = p.y;
				}
				if(seglist[i] is ArcSegment){
					var sx:Number = Math.sqrt(m.a*m.a + m.b*m.b); // scaling factors in the x and y directions
					var sy:Number = Math.sqrt(m.c*m.c + m.d*m.d);

					//var mrot:Matrix = new Matrix(m.a/sx,m.b/sx,m.c/sy,m.d/sy,m.tx,m.ty); // this is the full rotation matrix, a bit of over kill in this case but may be needed later

					var angle:Number = Math.acos(m.a/sx)*180/Math.PI;

					seglist[i].rx = seglist[i].rx*sx;
					seglist[i].ry = seglist[i].ry*sy;

					seglist[i].angle += angle;
				}
			}
		}

		// get a point with the max x and y point of the path
		public function getMax():Point{
			var maxx:Number = 0;
			var maxy:Number = 0;
			for(var i:int=0; i<seglist.length; i++){

				// x

				if(seglist[i].p1.x > maxx){
					maxx = seglist[i].p1.x;
				}
				if(seglist[i].p2.x > maxx){
					maxx = seglist[i].p2.x;
				}
				if(seglist[i] is QuadBezierSegment || seglist[i] is CubicBezierSegment){
					if(seglist[i].c1.x > maxx){
						maxx = seglist[i].c1.x;
					}
				}
				if(seglist[i] is CubicBezierSegment){
					if(seglist[i].c2.x > maxx){
						maxx = seglist[i].c2.x;
					}
				}

				// y

				if(seglist[i].p1.y > maxy){
					maxy = seglist[i].p1.y;
				}
				if(seglist[i].p2.y > maxy){
					maxy = seglist[i].p2.y;
				}
				if(seglist[i] is QuadBezierSegment || seglist[i] is CubicBezierSegment){
					if(seglist[i].c1.y > maxy){
						maxy = seglist[i].c1.y;
					}
				}
				if(seglist[i] is CubicBezierSegment){
					if(seglist[i].c2.y > maxy){
						maxy = seglist[i].c2.y;
					}
				}
			}

			return new Point(docx + maxx, -docy + maxy);
		}

		// get the min point (no bezier control points!) in global coordinates
		public function getMin():Point{
			var minx:Number = seglist[0].p1.x;
			var miny:Number = seglist[0].p1.y;

			for(var i:int=0; i<seglist.length; i++){
				if(seglist[i].p1.x < minx){
					minx = seglist[i].p1.x;
				}
				if(seglist[i].p2.x < minx){
					minx = seglist[i].p2.x;
				}
				if(seglist[i].p1.y < miny){
					miny = seglist[i].p1.x;
				}
				if(seglist[i].p2.y < miny){
					miny = seglist[i].p2.y;
				}
			}

			return new Point(docx + minx, -docy + miny);
		}

		// get the average point (no bezier control points!) in global coordinates
		public function getAverage():Point{
			var average:Point = new Point(0,0);

			var counted:Array = new Array();

			for(var i:int=0; i<seglist.length; i++){
				if(counted.indexOf(seglist[i].p1) == -1){
					average.x += seglist[i].p1.x + docx;
					average.y += seglist[i].p1.y - docy;

					counted.push(seglist[i].p1);
				}
				if(counted.indexOf(seglist[i].p2) == -1){
					average.x += seglist[i].p2.x + docx;
					average.y += seglist[i].p2.y - docy;

					counted.push(seglist[i].p2);
				}
			}

			average.x = average.x/seglist.length;
			average.y = average.y/seglist.length;

			return average;
		}

		public function clone():Path{ // make deep copy of the current path

			if(seglist.length < 1){
				return null;
			}

			var newpath:Path = new Path();

			newpath.docx = docx;
			newpath.docy = docy;

			for(var i:int=0; i<seglist.length; i++){
				if(seglist[i] is QuadBezierSegment){
					newpath.addSegment(new QuadBezierSegment(seglist[i].p1.clone(), seglist[i].p2.clone(), seglist[i].c1.clone()));
				}
				else if(seglist[i] is CubicBezierSegment){
					newpath.addSegment(new CubicBezierSegment(seglist[i].p1.clone(), seglist[i].p2.clone(), seglist[i].c1.clone(), seglist[i].c2.clone()));
				}
				else if(seglist[i] is ArcSegment){
					newpath.addSegment(new ArcSegment(seglist[i].p1.clone(), seglist[i].p2.clone(),seglist[i].rx, seglist[i].ry, seglist[i].angle, seglist[i].lf, seglist[i].sf));
				}
				else if(seglist[i] is Segment){
					newpath.addSegment(new Segment(seglist[i].p1.clone(), seglist[i].p2.clone()));
				}
			}

			newpath.joinDoubles();

			return newpath;
		}

		// sets the origin of the path (docx/docy) to zero, and shift all segments accordingly
		public function zeroOrigin():void{

			if(docx == 0 && docy == 0){
				return;
			}

			var processed:Array = new Array();

			var p:Point;

			for(var i:int=0; i<seglist.length; i++){
				p = seglist[i].p1;
				if(processed.indexOf(p) == -1){
					p.x += docx;
					p.y -= docy;
					processed.push(p);
				}
				p = seglist[i].p2;
				if(processed.indexOf(p) == -1){
					p.x += docx;
					p.y -= docy;
					processed.push(p);
				}
				if(seglist[i] is CubicBezierSegment){
					seglist[i].c1.x += docx;
					seglist[i].c1.y -= docy;
					seglist[i].c2.x += docx;
					seglist[i].c2.y -= docy;
				}
				else if(seglist[i] is QuadBezierSegment){
					seglist[i].c1.x += docx;
					seglist[i].c1.y -= docy;
				}
				else if(seglist[i] is CircularArc){
					seglist[i].center.x += docx;
					seglist[i].center.y -= docy;
				}
			}

			processed = null;

			docx = 0;
			docy = 0;

			x = 0;
			y = 0;
		}

		// this function creates a linearized version of the path
		// circular arcs and lines remain untouched
		// quad and cubic beziers are subdivided to match a set tolerance value
		public function linearize(circle:Boolean = false):Array{
			var newseglist:Array = new Array();

			var nextindex:int;

			for(var i:int=0; i<seglist.length; i++){
				if(seglist[i] is QuadBezierSegment || seglist[i] is CubicBezierSegment){
					// it is possible for a cubic bezier to form a "singularity", leading to errors in fillmap generation during CAM, the following removes these problem cubics:
					if(seglist[i] is CubicBezierSegment){
						var cub:CubicBezierSegment = seglist[i] as CubicBezierSegment;
						if(Global.withinTolerance(cub.p1,cub.p2)){
							var c1:Point = new Point(cub.c1.x-cub.p1.x,cub.c1.y-cub.p1.y);
							var c2:Point = new Point(cub.c2.x-cub.p2.x,cub.c2.y-cub.p2.y);

							var angle:Number = Global.getAngle(c1,c2);

							if(Math.abs(angle) >= 0.5*Math.PI){
								nextindex = i+1;
								if(nextindex == seglist.length){
									nextindex = 0;
								}
								seglist[nextindex].p1 = cub.p1;
								seglist.splice(i,1);
								i--;
								continue;
							}
						}
					}

					newseglist = newseglist.concat(seglist[i].linearize(circle));
				}
				else if(seglist[i] is CircularArc){
					newseglist.push(new CircularArc(seglist[i].p1, seglist[i].p2, seglist[i].center.clone(), seglist[i].radius));
				}
				else if(seglist[i] is ArcSegment){
					//newseglist.push(new ArcSegment(seglist[i].p1, seglist[i].p2,seglist[i].rx, seglist[i].ry, seglist[i].angle, seglist[i].lf, seglist[i].sf));
					if(seglist[i].lf == false && Global.withinTolerance(seglist[i].p1,seglist[i].p2)){
						nextindex = i+1;
						if(nextindex == seglist.length){
							nextindex = 0;
						}
						seglist[nextindex].p1 = seglist[i].p1;
						seglist.splice(i,1);
						i--;
						continue;
					}
					newseglist = newseglist.concat(seglist[i].linearize(circle));
				}
				else if(seglist[i] is Segment){
					if(Global.withinTolerance(seglist[i].p1,seglist[i].p2)){
						nextindex = i+1;
						if(nextindex == seglist.length){
							nextindex = 0;
						}
						seglist[nextindex].p1 = seglist[i].p1;
						seglist.splice(i,1);
						i--;
						continue;
					}
					newseglist.push(new Segment(seglist[i].p1, seglist[i].p2));
				}
			}

			return newseglist;
		}

		public function invertY():void{
			var len:int = seglist.length;

			if(len == 0){
				return;
			}

			var processed:Array = new Array();

			for(var i:int=0; i<len; i++){
				if(processed.indexOf(seglist[i].p1) == -1){
					seglist[i].p1.y = -seglist[i].p1.y;
					processed.push(seglist[i].p1);
				}
				if(processed.indexOf(seglist[i].p2) == -1){
					seglist[i].p2.y = -seglist[i].p2.y;
					processed.push(seglist[i].p2);
				}
				if(seglist[i] is CubicBezierSegment){
					seglist[i].c1.y = -seglist[i].c1.y;
					seglist[i].c2.y = -seglist[i].c2.y;
				}
				else if(seglist[i] is QuadBezierSegment){
					seglist[i].c1.y = -seglist[i].c1.y;
				}
				else if(seglist[i] is ArcSegment){
					seglist[i].sf = !seglist[i].sf;
					seglist[i].angle = -seglist[i].angle;
				}
			}
		}

		public function reversePath():void{
			for(var i:int=0; i<seglist.length; i++){
				seglist[i] = seglist[i].reverse();
			}
			seglist.reverse();
		}

		// separates non-touching segments into separate paths, and return as new array
		public function separate():Array{
			var paths:Array = new Array(new Path());
			var current:Segment = seglist[0];
			paths[paths.length-1].addSegment(seglist[0]);

			for(var i:int=1; i<seglist.length; i++){
				if(!(seglist[i].p1 == current.p1 || seglist[i].p2 == current.p2 || seglist[i].p1 == current.p2 || seglist[i].p2 == current.p1)){
					paths.push(new Path());
				}

				paths[paths.length-1].addSegment(seglist[i]);
				current = seglist[i];
			}

			for each(var path:Path in paths){
				path.docx = docx;
				path.docy = docy;
			}

			return paths;
		}

		// removes small segments that may cause problems (with offsetting)
		public function cleanup(tol:Number, close:Boolean = true):void{
			if(seglist.length < 2){
				return;
			}
			// deal with strange beziers
			for(var i:int=0; i<seglist.length; i++){
				if(seglist[i] is CubicBezierSegment){
					// replace flat cubics with segments
					if(seglist[i].isflat(seglist[i],Global.tolerance) || Global.withinTolerance(seglist[i].p1,seglist[i].c2) || Global.withinTolerance(seglist[i].p2,seglist[i].c1) || (Global.withinTolerance(seglist[i].p1,seglist[i].c1) && Global.withinTolerance(seglist[i].p2,seglist[i].c2))){
						seglist[i] = new Segment(seglist[i].p1,seglist[i].p2);
					}
					// replace 1-overlap control point with quad bezier
					else if(Global.withinTolerance(seglist[i].p1,seglist[i].c1)){
						seglist[i] = new QuadBezierSegment(seglist[i].p1,seglist[i].p2,seglist[i].c2);
					}
					else if(Global.withinTolerance(seglist[i].p2,seglist[i].c2)){
						seglist[i] = new QuadBezierSegment(seglist[i].p1,seglist[i].p2,seglist[i].c1);
					}
				}
				else if(seglist[i] is QuadBezierSegment){
					if(seglist[i].isflat(seglist[i],Global.tolerance) || Global.withinTolerance(seglist[i].p1,seglist[i].c1) || Global.withinTolerance(seglist[i].p2,seglist[i].c1)){
						seglist[i] = new Segment(seglist[i].p1,seglist[i].p2);
					}
				}
			}

			// remove small segments
			for(i=0; i<seglist.length; i++){
				if((seglist[i] is CircularArc && Global.withinTolerance(seglist[i].p1,seglist[i].p2,tol))
				|| (!(seglist[i] is CircularArc) && seglist[i] is ArcSegment && seglist[i].lf == false && Global.withinTolerance(seglist[i].p1,seglist[i].p2,tol))
				|| (!(seglist[i] is ArcSegment) && Global.withinTolerance(seglist[i].p1,seglist[i].p2,tol))){
					// remove small segments (mainly to deal with near-circular offsets becoming a single point)
					var mid:Point;
					if(!seglist[i].p1 || !seglist[i].p2){
						continue;
					}
					// update original path for joining-circle calculations
					if(close){
						if(i==0 && seglist[i+1].p1 && seglist[seglist.length-1].p2 && (seglist[i].p1 == seglist[seglist.length-1].p2 || Global.withinTolerance(seglist[i].p1,seglist[seglist.length-1].p2,tol))){
							mid = Point.interpolate(seglist[seglist.length-1].p2, seglist[i+1].p1,0.5);

							seglist[seglist.length-1].p2 = mid;
							seglist[i+1].p1 = mid;

							if(seglist[seglist.length-1] is CircularArc){
								seglist[seglist.length-1].recalculateCenter();
							}
							if(seglist[i+1] is CircularArc){
								seglist[i+1].recalculateCenter();
							}
						}
						else if(i==seglist.length-1 && seglist[0].p1 && seglist[i-1].p2 && (seglist[i].p2 == seglist[0].p1 || Global.withinTolerance(seglist[i].p2,seglist[0].p1,tol))){
							mid = Point.interpolate(seglist[i-1].p2, seglist[0].p1,0.5);

							seglist[i-1].p2 = mid;
							seglist[0].p1 = mid;

							if(seglist[i-1] is CircularArc){
								seglist[i-1].recalculateCenter();
							}
							if(seglist[0] is CircularArc){
								seglist[0].recalculateCenter();
							}
						}
						else if(i > 0 && i < seglist.length-1 && seglist[i+1].p1 && seglist[i-1].p2){
							mid = Point.interpolate(seglist[i-1].p2, seglist[i+1].p1,0.5);

							seglist[i-1].p2 = mid;
							seglist[i+1].p1 = mid;

							if(seglist[i-1] is CircularArc){
								seglist[i-1].recalculateCenter();
							}
							if(seglist[i+1] is CircularArc){
								seglist[i+1].recalculateCenter();
							}
						}
					}
					seglist.splice(i,1);
					if(seglist.length < 2){
						return;
					}
					i--;
				}
			}
		}

		// make the path a continuous chain
		// we assume that the path is already a single link
		public function makeContinuous():void{

			if(seglist.length < 2){
				return;
			}

			var newseglist:Array = new Array(seglist.shift());

			for(var i:int=0; i<newseglist.length; i++){
				// find the next segment (segment attached to p2)
				for(var j:int=0; j<seglist.length; j++){
					if(seglist[j].p1 == newseglist[i].p2){
						// already in the correct chain order
						newseglist.push(seglist[j]);
						seglist.splice(j,1);
						break;
					}
					else if(seglist[j].p2 == newseglist[i].p2){
						// must reverse chain order
						seglist[j] = seglist[j].reverse();
						newseglist.push(seglist[j]);
						seglist.splice(j,1);
						break;
					}
				}
			}

			seglist = newseglist;
		}

	}
}