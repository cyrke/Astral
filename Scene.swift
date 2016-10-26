//
//  Scene.swift
//  Strands
//
//  Created by Caspar Wylie on 05/08/2016.
//  Copyright © 2016 Caspar Wylie. All rights reserved.
//

/*
 
 SCENE COMPONENT
 
 */

import Foundation
import SceneKit
import CoreMotion
import MapKit

class Scene{
    
    //MARK: Node initiation
    let lightNode = SCNNode();
    let cameraNode = SCNNode();
    var cubeNode: SCNNode!;
    let scene = SCNScene();
    var strands: [SCNNode] = [];
    
    //MARK: Add scene view to view
    func renderSceneLayer(frameView: UIView) -> Void{
        
        let frameRect = frameView.frame;
        let sceneView = SCNView(frame: frameRect);
        sceneView.backgroundColor = UIColor(white: 1, alpha: 0.0);
        frameView.addSubview(sceneView);
        
        sceneView.scene = scene;
    }
    
    //MARK: values are approximate within tolerance bound
    func isApprox(value1: CGFloat, value2: CGFloat, tol: CGFloat) -> Bool{
        if( ((value1 - tol) <= value2) && ((value1 + tol) >= value2 ) ){
            return true;
        }else{
            return false;
        }
    }
    
    //MARK: Node rendering
    func renderLight(){
        let lightObj = SCNLight();
        lightObj.type = SCNLight.LightType.omni;
        lightNode.light = lightObj;
        lightNode.position = SCNVector3(x: 1.5, y: 1.5, z: 1.5);
    }
    
    func toDegrees(rad: Double) -> Double{
        return rad*57.2958;
    }
    
    func renderCamera(){
        let cameraObj = SCNCamera();
        cameraNode.camera = cameraObj;
        cameraNode.camera!.zNear = 0.1;
        cameraNode.camera!.zFar = 1200.0;
        cameraNode.position = SCNVector3(x: 0.0, y: 15.0, z: 0.0);
       
    }
    
    //MARK: rotate virtual 3D atmosphere around current coordinates
    func rotateAroundPoint(pointXY: (x: Double,y: Double),angle: Double) -> (x: Double, y: Double){
        let angle = angle * 0.0174533;
        let pX = (pointXY.x * cos(angle)) + (pointXY.y * sin(angle));
        let pY = -(pointXY.x * sin(angle)) + (pointXY.y * cos(angle));
        return (x: pX, y: pY);
    }
    
    func DAEtoSCNNodeWithText(filepath:String) -> SCNNode {
        
        //setup text nodes
        let singNode = SCNNode();
        let localScene = SCNScene(named: filepath);
        let singNodeArray = localScene!.rootNode.childNodes;
        let nodeTextString = "Hello, and welcome to a Strand Sign Post prototype, version 1.0. A geographic social network for anyone. Information and opinion is everywhere, and now you can see it anywhere. Created By Caspar Wylie, Founded By Arthur James";
        let textRenderFront = SCNText(string: nodeTextString, extrusionDepth:1);
        let textRenderBack = SCNText(string: nodeTextString, extrusionDepth:1);
        
        //attribute option setting
        let textContainerFrame = CGRect(x: 0,y: 0, width: 270, height: 100);
        let textIsWrapped = true;
        let textColor = UIColor.black;
        let textNodeScale = SCNVector3(0.07,0.07,0.07);
        
        //setting attributes
        textRenderFront.isWrapped = textIsWrapped;
        textRenderFront.firstMaterial?.diffuse.contents = textColor;
        textRenderFront.containerFrame = textContainerFrame;
        textRenderFront.alignmentMode = kCAAlignmentCenter;
        textRenderBack.isWrapped = textIsWrapped;
        textRenderBack.firstMaterial?.diffuse.contents = textColor;
        textRenderBack.containerFrame = textContainerFrame;
        textRenderBack.alignmentMode = kCAAlignmentCenter;
        
        //build DAE scene as node by each component
        for childNode in singNodeArray {
            
            let textNodeFront = SCNNode(geometry: textRenderFront);
            let textNodeBack = SCNNode(geometry: textRenderBack);
            
            textNodeFront.scale = textNodeScale;
            textNodeFront.position = SCNVector3(x: 1, y: 23, z: -4); //x = depth , z = lateral
            textNodeFront.eulerAngles = SCNVector3(x: 0, y: 1.5708, z: 0);
            
            textNodeBack.scale = textNodeScale;
            textNodeBack.position = SCNVector3(x: -1.5, y: 23, z: -23);
            textNodeBack.eulerAngles = SCNVector3(x: 0, y: -1.5708, z: 0);
            
            singNode.addChildNode(textNodeFront);
            singNode.addChildNode(textNodeBack);
            singNode.addChildNode(childNode as SCNNode);
            
        }
        return singNode;
    }
    
    
    //MARK: render or update strand within 3D atmosphere
    func renderStrands(mapPoints: [MKMapPoint], currMapPoint: MKMapPoint, render: Bool, currentHeading: CLHeading, toHide: String){
        
        let toHideAsArr = toHide.components(separatedBy: ",");
        
        //remove previous area / region data
        if(render==true){
            if (strands.count != 0) {
                for var oldStrandID in 0...strands.count-1{
                    strands[oldStrandID].removeFromParentNode()
                }
                strands = [];
            }
        }
        
        //render or move new strands
        var i = 0;
        for mPoint in mapPoints{
            var strandCoord = (x: mPoint.x - currMapPoint.x, y: mPoint.y - currMapPoint.y);
                strandCoord = rotateAroundPoint(pointXY: strandCoord, angle: -90);
            if(render==true){
                //initiate strands
                let strand = DAEtoSCNNodeWithText(filepath: "strandpost.dae");
                strand.position = SCNVector3(x: Float(strandCoord.x), y: 0, z:  Float(strandCoord.y));
                strands.append(strand);
                
            }else{
                //update strand position
                let newPos = SCNVector3(x: Float(strandCoord.x), y: 0.0, z:  Float(strandCoord.y));
                let moveToAction = SCNAction.move(to: newPos, duration: 1);
                strands[i].runAction(moveToAction);
            }
            
            //hide non-street visible strands
            for var hideID in toHideAsArr{
                if (hideID == String(i)){
                    strands[i].isHidden = true;
                    break;
                }else{
                    strands[i].isHidden = false;
                }
            }
            i += 1;
        }
    }
    
    //MARK: gyro to scene camera mapping, on new gyro/motion data (delegated call from ViewController)
    func rotateCamera(gyroData: CMAttitude){
        
        let qData: CMQuaternion = gyroData.quaternion;
        
        //quaternion data to eulerAngles (prevention of gimbal lock!)
        let attitudeRoll = atan2((2 * qData.y * qData.w) - (2 * qData.x * qData.z),
                                 1 - (2 * qData.y * qData.y) - (2 * qData.z * qData.z) );
        let attitudePitch = atan2((2 * qData.x * qData.w) - (2 * qData.y * qData.z),
                                  1 - (2 * qData.x * qData.x) - (2 * qData.z * qData.z) );
        let attitudeYaw = asin((2 * qData.x * qData.y) + (2 * qData.z * qData.w));

       cameraNode.eulerAngles = SCNVector3(x: Float(attitudePitch - 1.5708),y: Float(attitudeYaw),z: Float(-attitudeRoll));
    }


    //MARK: Add all nodes to scene
    func runScene(){
        renderLight();
        renderCamera();

        scene.rootNode.addChildNode(lightNode);
        scene.rootNode.addChildNode(cameraNode);
        for strand in strands{
            scene.rootNode.addChildNode(strand);
        }
    }

}
