﻿package com.partkart{

	import flash.display.Sprite;
	import com.greenthreads.*;
	import flash.geom.Point;

	public class ProcessFile extends GreenThread{
		private var pathlist:Array;
		private var separated:Boolean = false;
		private var current:int = 0;
		private var scene:SceneGraph;
		private var len:int;

		// we'll need to preserve this for cutobject loading
		public var svgxml:XML;

		public function ProcessFile(inputscene:SceneGraph, inputpaths:Array, inputsvgxml:XML):void{
			scene = inputscene;
			pathlist = inputpaths;
			svgxml = inputsvgxml;
		}

		protected override function initialize():void{
			_progress = 0;
			_maximum = 0;
			for each(var path:Path in pathlist){
				if(path.active == true){
					_maximum += 2;
				}
			}
			len = pathlist.length;
		}

		protected override function run():Boolean{
			// separate
			if(!separated){
				if(current == len){
					current = 0;
					separated = true;
					return true;
				}
				else{
					if(pathlist[current].active == true){
						var paths:Array = pathlist[current].separate();
						if(paths.length > 0){
							for each(var p:Path in paths){
								p.name = pathlist[current].name;
								p.active = true;
							}
							_maximum += paths.length-1;

							pathlist.splice(current,1);
							scene.addPaths(paths);
							current--;
							len--;
						}
						_progress++;
					}
				}
			}
			// merge
			else{
				if(current == pathlist.length){
					return false;
				}
				var path:Path = pathlist[current];
				if(path.active == true){
					_progress++;

					// cleanup short segments
					path.cleanup(0.0001,true);
					path.resetSegments();

					// check for overlapping points between this and every other path
					for(var j:int = current+1; j<pathlist.length; j++){
						var path2:Path = pathlist[j];
						if(path != path2 && path.active == true && path2.active == true){
							if(Global.withinTolerance(path.seglist[0].p1,path2.seglist[0].p1,0.1)){
								path.reversePath();
								path.resetSegments();
								path.mergePath(path2,path.seglist[path.seglist.length-1].p2,false);
								j = current;
							}
							else if(Global.withinTolerance(path.seglist[0].p1,path2.seglist[path2.seglist.length-1].p2,0.1)){
								path2.mergePath(path,path2.seglist[path2.seglist.length-1].p2,false);
								current--;
								break;
							}
							else if(Global.withinTolerance(path.seglist[path.seglist.length-1].p2,path2.seglist[0].p1,0.1)){
								path.mergePath(path2,path.seglist[path.seglist.length-1].p2,false);
								j = current;
							}
							else if(Global.withinTolerance(path.seglist[path.seglist.length-1].p2,path2.seglist[path2.seglist.length-1].p2,0.1)){
								path2.reversePath();
								path.mergePath(path2,path.seglist[path.seglist.length-1].p2,false);
								j = current;
							}
						}
					}
				}
			}
			current++;
			return true;
		}
	}
}