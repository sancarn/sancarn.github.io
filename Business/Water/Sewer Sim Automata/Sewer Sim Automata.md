# SewerSimAutomata.js

## Idea

Modular 1D hydraulic simulation engine.

## Motivation

A simulation engine which can be hacked to it's core to be completely intergratable with user systems.

## Structure

```js
    //Base class - core automata element.
    // This element has a series of callbacks which are triggered at different parts of the simulation.
    // Callbacks of special types can be assigned by calling special methods
    class HydraulicNode {
        //...
    }

    //Geographic objects extending HydraulicNode
    class Point extends HydraulicNode {}
    class Polyline extends HydraulicNode {}
    class Polygon extends HydraulicNode {}

    //Extensions can be added on top:
    class Subcatchment extends Polygon {
        constructor(){
            this.onTimestepBegin(function(){
                this.simDepth  += this.sim.rainEvent.currentDepth;
                this.simVolume = this.simDepth * this.area;
                this.children.forEach(child=>child.scheduleUpdate())
            });
        };
    };
    class Node extends Point {
        this.onTimestep(function(){
            this.drivingPressure = 0
            const This = this;
            this.parents.forEach(function(parent){
                const parentPressure = this._calcDrivingPressure(parent);
                This.drivingPressure += parentPressure;
                const inFlow         = this._calcFlow();
                const inVolume       = inFlow * parent.area;
                
            });
        });
    };
    class Outfall extends Node {
        constructor(){
            this.onTimestepEnd(function(){
                this.simDepth = 0
                this.drivingPressure = 0
            });
        };
    };

    //Built like an automata to allow for infinite multithreading.
```