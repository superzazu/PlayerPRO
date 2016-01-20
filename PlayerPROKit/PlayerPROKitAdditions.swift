//
//  OSX-Specific-Extensions.swift
//  PPMacho
//
//  Created by C.W. Betts on 8/11/14.
//
//

import CoreFoundation
import Foundation
import PlayerPROCore
import CoreGraphics
import SwiftAdditions
#if os(OSX)
	import Cocoa
#else
	import UIKit
#endif

public func ==(lhs: PPMadCommandObject, rhs: Cmd) -> Bool {
	return lhs.theCommand == rhs
}

public func ==(lhs: PPEnvelopeObject, rhs: EnvRec) -> Bool {
	return lhs.envelopeRec == rhs
}

public func ==(lhs: PPFXBusObject, rhs: FXBus) -> Bool {
	return lhs.theBus == rhs
}

public func ==(lhs: PPFXSetObject, rhs: FXSets) -> Bool {
	return lhs.theSet == rhs
}

public func getCommand(position: Int16, channel: Int16, aPat: PPPatternObject) -> Cmd {
	let aCmd = aPat.getCommandFromPosition(position, channel: channel)
	return aCmd.theCommand
}

public func ReplaceCmd(position: Int16, channel: Int16, command: Cmd, aPat: PPPatternObject) {
	aPat.replaceCommandAtPosition(position, channel: channel, cmd: command)
}

public func ModifyCmdAtRow(position: Int16, channel: Int16, aPat: PPPatternObject, commandBlock: (inout Cmd)-> ()) {
	aPat.modifyCommandAtPosition(position, channel: channel, commandBlock: { (aCmd) -> Void in
		var tmpCmd = aCmd.memory
		commandBlock(&tmpCmd)
		aCmd.memory = tmpCmd
	})
}

extension MADErr: ErrorType {
	/// PlayerPROKit's `PPMADErrorDomain`
	public var _domain: String {
		return PPMADErrorDomain
	}
	
	/// PlayerPROCore's `MADErr` raw value
	public var _code: Int {
		return Int(rawValue)
	}
	
	/// Throws `self` if `self` is anything other than `.NoErr`.
	public func throwIfNotNoErr() throws {
		if self != .NoErr {
			throw self
		}
	}
	
	/// Converts to an error to one in the built-in Cocoa error domains, if possible.
	@warn_unused_result public func convertToCocoaType() -> NSError {
		guard let anErr = PPCreateErrorFromMADErrorTypeConvertingToCocoa(self, true) else {
			return NSError(domain: PPMADErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Throwing MADNoErr! This shouldn't happen!"])
		}
		return anErr
	}
	
	///Creates an `NSError` from `self`, optionally converting the error type to an error in the Cocoa error domain.
	///
	///- parameter customUserDictionary: A dictionary with additional information. May be `nil`, default is `nil`.
	///- parameter convertToCocoa: Converts `self` into a comparable error in Cocoa's error types. Default is `true`.
	///- returns: An `NSError` value, or `nil` if `self` is `.NoErr`
	@warn_unused_result public func toNSError(customUserDictionary cud: [String: NSObject]? = nil, convertToCocoa: Bool = true) -> NSError? {
		if self == .NoErr {
			return nil
		}
		
		func populateErrors(error: NSError) -> NSError {
			if let cud = cud {
				var errDict: [NSObject: AnyObject] = error.userInfo
				errDict[NSLocalizedDescriptionKey] = error.localizedDescription
				if let aFailReason = error.localizedFailureReason {
					errDict[NSLocalizedFailureReasonErrorKey] = aFailReason
				}
				
				if let aRecoverySuggestion = error.localizedRecoverySuggestion {
					errDict[NSLocalizedRecoverySuggestionErrorKey] = aRecoverySuggestion
				}
				
				errDict += cud
				
				return NSError(domain: error.domain, code: error.code, userInfo: errDict)
			} else {
				return error
			}
		}
		
		if convertToCocoa {
			let cocoaErr = PPCreateErrorFromMADErrorTypeConvertingToCocoa(self, true)!
			return populateErrors(cocoaErr)
		}
		
		do {
			throw self
		} catch let error as NSError {
			return populateErrors(error)
		}
	}
}

///Creates an `NSError` from a `MADErr`, optionally converting the error type to an error in the Cocoa error domain.
///
///- parameter theErr: The `MADErr` to convert to an `NSError`
///- parameter customUserDictionary: A dictionary with additional information. May be `nil`, defaults to `nil`.
///- parameter convertToCocoa: Converts the `MADErr` code into a compatible error in Cocoa's error types. defaults to `false`.
///- returns: An `NSError` value, or `nil` if passed `.NoErr`
public func createErrorFromMADErrorType(theErr: MADErr, customUserDictionary: [String: NSObject]? = nil, convertToCocoa: Bool = false) -> NSError? {
	return theErr.toNSError(customUserDictionary: customUserDictionary, convertToCocoa: convertToCocoa)
}

public func noteFromString(myTT: String) -> Int16?
{
	if myTT == "" || myTT == "---" || myTT.characters.count < 2 {
		return nil
	}
	
	let idx = myTT.endIndex.predecessor()
	let lastChar = myTT[idx]
	guard let octMaybe = Int(String(lastChar)) else {
		return nil
	}
	//	0	1	 2	 3	 4	 5	 6	 7 	 8	 9	 10	 11
	//	C-  C#   D-  D#  E-  F-  F#  G-  G#  A-  A#  B-
	
	var Oct = Int16(octMaybe)
	Oct *= 12
	
	let theRest = myTT[myTT.startIndex ..< idx]
	
	let theRet: (outString: String, sharp: Bool) = {
		let idx2 = idx.predecessor()
		let maybeSign = myTT[idx2]
		let maybeStr = myTT[myTT.startIndex ..< idx2]
		switch maybeSign {
		case "#", "♯"/*Unicode sharp sign, just in case*/:
			return (maybeStr, true)
			
		case " ", "-":
			return (maybeStr, false)
			
		default:
			return (theRest, false)
		}
	}()
	
	let val1 = theRet.outString.lowercaseString
	switch val1 {
	case "c", "do":
		Oct += 0
		
	case "d", "ré", "re":
		Oct += 2
		
	case "e", "mi":
		Oct += 4
		
	case "f", "fa":
		Oct += 5
		
	case "g", "sol", "so":
		Oct += 7
		
	case "a", "la":
		Oct += 9
		
	case "b", "si", "ti":
		Oct += 11
		
	default:
		return nil
	}
	
	if theRet.sharp {
		Oct++
	}
	
	if Oct > 95 {
		return nil
	} else if Oct < 0 {
		return nil
	}
	
	return Oct
}

public func octaveNameFromNote(octNote: UInt8, letters isUseLetters: Bool = true) -> String? {
	return octaveNameFromNote(Int16(octNote), letters: isUseLetters)
}

public func octaveNameFromNote(octNote: Int16, letters isUseLetters: Bool = true) -> String? {
	if (octNote > 95 || octNote < 0) {
		return nil
	}
	
	let NNames: [String]
	
	if isUseLetters {
		NNames = ["C ", "C#", "D ", "D#", "E ", "F ", "F#", "G ", "G#", "A ", "A#", "B "]
	} else {
		NNames = ["Do", "Do#", "Ré", "Ré#", "Mi", "Fa", "Fa#", "Sol", "Sol#", "La", "La#", "Si"]
	}
	return "\(NNames[Int(octNote % 12)])\(octNote / 12)"
}

extension PPSampleObject {

#if os(OSX)
	@objc(waveformImageUsingView:) final public func waveformImage(view view: NSView) -> NSImage? {
		return PPSampleObject.waveFormImage(sample: self, view: view)
	}
	
	@objc(waveformImageFromSample:usingView:) final public class func waveFormImage(sample theDat: PPSampleObject, view: NSView) -> NSImage? {
		let imageSize: NSSize = {
			var aimageSize = view.convertSizeToBacking(view.frame.size)
			aimageSize.height *= 2
			aimageSize.width *= 2
			
			return aimageSize
			}()
		let datIsStereo = theDat.stereo
		let aRect = CGRect(origin: CGPoint.zero, size: imageSize)
		let rowBytes = 4 * Int(imageSize.width)
		let bitMapFormat: CGBitmapInfo = [CGBitmapInfo.ByteOrder32Host, CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedLast.rawValue)]
		let bitmapContext = CGBitmapContextCreate(nil, Int(imageSize.width), Int(imageSize.height), 8, rowBytes, CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB)!, bitMapFormat.rawValue)!
		
		CGContextClearRect(bitmapContext, aRect)
		CGContextSetLineWidth(bitmapContext, 1)
		let stereoTrans: CGFloat = datIsStereo ? 0.75 : 1
		if (datIsStereo) {
			CGContextSetStrokeColorWithColor(bitmapContext, CGColorCreateGenericRGB(0, 0, 1, stereoTrans))
			drawSample(rectangle: aRect, channel: 1, currentData: theDat, context: bitmapContext)
		}
		
		CGContextSetStrokeColorWithColor(bitmapContext, CGColorCreateGenericRGB(1, 0, 0, stereoTrans));
		drawSample(rectangle: aRect, channel: 0, currentData: theDat, context: bitmapContext)
		
		if (theDat.loopSize != 0) {
			CGContextSetStrokeColorWithColor(bitmapContext, CGColorCreateGenericRGB(0.2, 0.1, 0.5, 0.8))
			var loopRect = aRect
			let lineSize = view.convertSizeToBacking(NSSize(width: 2, height: 2)).width * 2
			let padSize = view.convertSizeToBacking(NSSize(width: 1, height: 1)).width * 2
			CGContextSetLineWidth(bitmapContext, lineSize)
			loopRect.origin.x =  CGFloat(theDat.loopBegin) * imageSize.width / CGFloat(theDat.data.length)
			loopRect.origin.y += padSize
			loopRect.size.width = CGFloat(theDat.loopSize) * imageSize.width / CGFloat(theDat.data.length)
			loopRect.size.height -= padSize * 2
			CGContextStrokeRect(bitmapContext, loopRect)
		}
		
		if let theCGimg = CGBitmapContextCreateImage(bitmapContext) {
			return NSImage(CGImage: theCGimg, size: view.frame.size)
		} else {
			return nil
		}
	}
#elseif os(iOS)
	@objc(waveformImageUsingView:) final public func waveformImage(view view: UIView) -> UIImage? {
		return PPSampleObject.waveFormImage(sample: self, view: view)
	}
	
	@objc(waveformImageFromSample:usingView:) final public class func waveFormImage(sample theDat: PPSampleObject, view: UIView) -> UIImage? {
		let scale = view.contentScaleFactor
		let imageSize: CGSize = {
			var viewSize = view.bounds.size
			viewSize.width *= scale
			viewSize.height *= scale
			return viewSize
			}()
		let datIsStereo = theDat.stereo;
		let aRect = CGRect(origin: CGPoint.zero, size: imageSize)
		let rowBytes = 4 * Int(imageSize.width)
		//let bitMapFormat = CGBitmapInfo(alphaInfo: .PremultipliedLast, additionalInfo: .ByteOrder32Host)
		let bitMapFormat: CGBitmapInfo = [CGBitmapInfo.ByteOrder32Host, CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedLast.rawValue)]
		let bitmapContext = CGBitmapContextCreate(nil, Int(imageSize.width), Int(imageSize.height), 8, rowBytes, CGColorSpaceCreateDeviceRGB(), bitMapFormat.rawValue)
		CGContextClearRect(bitmapContext, aRect)
		CGContextSetLineWidth(bitmapContext, 1)
		var colorRef: UIColor
		let stereoTrans: CGFloat = datIsStereo ? 0.75 : 1
		if (datIsStereo) {
			colorRef = UIColor(red: 0, green: 0, blue: 1, alpha: stereoTrans)
			CGContextSetStrokeColorWithColor(bitmapContext, colorRef.CGColor)
			drawSample(rectangle: aRect, channel: 1, currentData: theDat, context: bitmapContext)
		}
		
		colorRef = UIColor(red: 1, green: 0, blue: 0, alpha: stereoTrans)
		CGContextSetStrokeColorWithColor(bitmapContext, colorRef.CGColor)
		drawSample(rectangle: aRect, channel: 0, currentData: theDat, context: bitmapContext)
		
		if (theDat.loopSize != 0) {
			colorRef = UIColor(red: 0.2, green: 0.1, blue: 0.5, alpha: 0.8)
			CGContextSetStrokeColorWithColor(bitmapContext, colorRef.CGColor)
			var loopRect = aRect
			let lineSize = 2 * scale
			let padSize = 1 * scale
			CGContextSetLineWidth(bitmapContext, lineSize)
			loopRect.origin.x =  CGFloat(theDat.loopBegin) * imageSize.width / CGFloat(theDat.data.length)
			loopRect.origin.y += padSize
			loopRect.size.width = CGFloat(theDat.loopSize) * imageSize.width / CGFloat(theDat.data.length)
			loopRect.size.height -= padSize * 2
			CGContextStrokeRect(bitmapContext, loopRect)
		}
		
		if let theCGimg = CGBitmapContextCreateImage(bitmapContext) {
			return UIImage(CGImage: theCGimg, scale: scale, orientation: .Up)
		} else {
			return nil
		}
	}
#endif
	
	final public func drawSample(start: Int = 0, tSS: Int = 0, rectangle rect: CGRect, channel: Int16 = 0, context ctxRef: CGContext?) {
		PPSampleObject.drawSample(start: start, tSS: tSS, tSE: Int(rect.size.width), high: Int(rect.size.height), larg: Int(rect.size.width), trueV: Int(rect.origin.x), trueH: Int(rect.origin.y), channel: channel, currentData: self, context:ctxRef)
	}
	
	final public func drawSample(start startI: Int = 0, tSS: Int = 0, tSE: Int, high: Int, larg: Int, trueV: Int = 0, trueH: Int = 0, channel: Int16 = 0, context ctxRef: CGContext?) {
		PPSampleObject.drawSample(start: startI, tSS: tSS, tSE: tSE, high: high, larg: larg, trueV: trueV, trueH: trueH, channel: channel, currentData: self, context: ctxRef)
	}
	
	final public class func drawSample(start: Int = 0, tSS: Int = 0, rectangle rect: CGRect, channel: Int16 = 0, currentData curData: PPSampleObject, context ctxRef: CGContext?) {
		drawSample(start: start, tSS: tSS, tSE: Int(rect.size.width), high: Int(rect.size.height), larg: Int(rect.size.width), trueV: Int(rect.origin.x), trueH: Int(rect.origin.y), channel: channel, currentData: curData, context:ctxRef)
	}

	final public class func drawSample(var start start: Int = 0, tSS: Int = 0, tSE: Int, high: Int, larg: Int, trueV: Int = 0, trueH: Int = 0, channel: Int16 = 0, currentData curData: PPSampleObject, context ctxRef: CGContext?) {
		CGContextSaveGState(ctxRef);
		
		var temp: CGFloat = 0.0
		let isStereo = curData.stereo
		var minY: CGFloat = 0.0
		var maxY: CGFloat = 0.0
		let oneShiftedBy16 = 1 / CGFloat(1 << 16)
		let oneShiftedBy8 = 1 / CGFloat(1 << 8)

		if (curData.amplitude == 16) {
			let theShortSample = UnsafePointer<UInt16>(curData.data.bytes)
			let sampleSize = curData.data.length / 2
			start /= 2
			
			var BS = start + (tSS * sampleSize) / larg
			if (isStereo) {
				BS /= 2; BS *= 2;
				BS += Int(channel)
			}
			temp = CGFloat(theShortSample[BS] &+ 0x8000)
			temp *= CGFloat(high) * oneShiftedBy16
			CGContextMoveToPoint(ctxRef, CGFloat(trueH) + CGFloat(tSS), CGFloat(trueV) + temp)
			
			for i in tSS ..< tSE {
				BS = start + (i * sampleSize) / larg
				var BE = start + ((i + 1) * sampleSize) / larg
				
				if (isStereo) {
					BS /= 2; BS *= 2;
					BE /= 2; BE *= 2;
					
					BS += Int(channel)
					BE += Int(channel)
				}
				
				temp = CGFloat(theShortSample[BS] &+ 0x8000)
				minY = temp; maxY = temp;
				temp *= CGFloat(high) * oneShiftedBy16
				CGContextAddLineToPoint(ctxRef, CGFloat(trueH + i), temp + CGFloat(trueV))
				
				if (BS != BE) {
					for (var x = BS; x < BE; x++) {
						temp = CGFloat(theShortSample[x] &+ 0x8000)
						
						maxY = max(temp, maxY)
						minY = min(temp, minY)
						
						if (isStereo) {
							x++
						}
					}
					
					maxY *= CGFloat(high) * oneShiftedBy16
					minY *= CGFloat(high) * oneShiftedBy16
					
					CGContextMoveToPoint(ctxRef, CGFloat(trueH + i), minY + CGFloat(trueV))
					CGContextAddLineToPoint(ctxRef, CGFloat(trueH + i), maxY + CGFloat(trueV))
				}
			}
		} else {
			let sampleSize = curData.data.length
			let theSample = UnsafePointer<UInt8>(curData.data.bytes)

			var BS = start + (tSS * sampleSize) / larg;
			if (isStereo) {
				BS /= 2; BS *= 2;
				BS += Int(channel)
			}
			
			temp = CGFloat(theSample[BS] &- 0x80)
			temp *= CGFloat(high) * oneShiftedBy8
			
			CGContextMoveToPoint(ctxRef, CGFloat(trueH + tSS), CGFloat(trueV) + temp)
			
			for i in tSS ..< tSE {
				BS = start + (i * sampleSize) / larg
				var BE = start + ((i + 1) * sampleSize) / larg
				
				if (isStereo) {
					BS /= 2; BS *= 2;
					BE /= 2; BE *= 2;
					
					BS += Int(channel);
					BE += Int(channel);
				}
				
				temp = CGFloat(theSample[BS] &- 0x80);
				minY = temp; maxY = temp;
				temp *= CGFloat(high) * oneShiftedBy8
				CGContextAddLineToPoint(ctxRef, CGFloat(trueH + i), temp + CGFloat(trueV))
				
				if (BS != BE) {
					for (var x = BS; x < BE; x++) {
						temp = CGFloat(theSample[x] &- 0x80)
						
						maxY = max(temp, maxY)
						minY = min(temp, minY)
						
						if (isStereo) {
							x++;
						}
					}
					maxY *= CGFloat(high) * oneShiftedBy8
					minY *= CGFloat(high) * oneShiftedBy8
					
					CGContextMoveToPoint(ctxRef, CGFloat(trueH) + CGFloat(i), minY + CGFloat(trueV))
					CGContextAddLineToPoint(ctxRef, CGFloat(trueH) + CGFloat(i), maxY + CGFloat(trueV))
				}
			}
		}
		CGContextStrokePath(ctxRef);
		CGContextRestoreGState(ctxRef);
	}
	
	@objc final public class func octaveNameFromNote(octNote: Int16) -> String {
		return octaveNameFromNote(octNote) ?? "---"
	}

	@objc final public class func octaveNameFromNote(octNote: Int16, usingSingularLetter: Bool) -> String {
		return PlayerPROKit.octaveNameFromNote(octNote, letters: usingSingularLetter) ?? "---"
	}

	@objc final public class func noteFromString(myTT: String) -> Int16 {
		return noteFromString(myTT) ?? 0xFF
	}
}

extension PPPatternObject: SequenceType {
	public func generate() -> AnyGenerator<PPMadCommandObject> {
		var index = 0
		return anyGenerator {
			if index < self.lengthOfCommands {
				return self[index++]
			}
			
			return nil
		}
	}
}

extension PPInstrumentObject: SequenceType {
	public func generate() -> AnyGenerator<PPSampleObject> {
		var index = 0
		return anyGenerator {
			if index < self.samples.count {
				return self[index++]
			}
			return nil
		}
	}
}

extension PPDriver {
	public func playSoundData(pointer theSnd: UnsafePointer<()>, size sndSize: Int, channel theChan: Int32, amplitude amp: Int16, bitRate rate: UInt32, stereo: Bool, note theNote: MADByte = 0xFF, loopStartingAt iloopStart: Int = 0, loopLength iloopLen: Int = 0) -> MADErr {
		var loopStart = iloopStart
		var loopLen = iloopLen
		if (loopLen == 0) {
			loopStart = 0
			loopLen = 0
		}
		return self.playSoundDataFromPointer(theSnd, withSize: UInt(sndSize), fromChannel: theChan, amplitude: amp, bitRate: rate, isStereo: stereo, withNote: theNote, withLoopStartingAt: UInt(loopStart), andLoopLength: UInt(loopLen))
	}

	public func playSoundData(pointer theSnd: UnsafePointer<()>, size sndSize: Int, channel theChan: Int32, amplitude amp: Int16, bitRate rate: UInt32, stereo: Bool, note theNote: MADByte = 0xFF, loopInRange loopRange: NSRange) -> MADErr {
		return self.playSoundDataFromPointer(theSnd, withSize: UInt(sndSize), fromChannel: theChan, amplitude: amp, bitRate: rate, isStereo: stereo, withNote: theNote, withLoopInRange: loopRange)
	}
	
	public func playSoundData(pointer theSnd: UnsafePointer<()>, size sndSize: Int, channel theChan: Int32, amplitude amp: Int16, bitRate rate: UInt32, stereo: Bool, note theNote: MADByte = 0xFF, loopInRange loopRange: Range<Int>) -> MADErr {
		return playSoundData(pointer: theSnd, size: sndSize, channel: theChan, amplitude: amp, bitRate: rate, stereo: stereo, note: theNote, loopInRange: NSRange(loopRange))
	}
	
	public func playSoundData(data theSnd: NSData, channel theChan: Int32, amplitude amp: Int16, bitRate rate: UInt32, stereo: Bool, note theNote: MADByte = 0xFF, loopStartingAt iloopStart: Int = 0, loopLength iloopLen: Int = 0) -> MADErr {
		var loopStart = iloopStart
		var loopLen = iloopLen
		if (loopLen == 0) {
			loopStart = 0
			loopLen = 0
		}
		return self.playSoundDataFromPointer(theSnd.bytes, withSize: UInt(theSnd.length), fromChannel: theChan, amplitude: amp, bitRate: rate, isStereo: stereo, withNote: theNote, withLoopStartingAt: UInt(loopStart), andLoopLength: UInt(loopLen))
	}
	
	public func playSoundData(data theSnd: NSData, channel theChan: Int32, amplitude amp: Int16, bitRate rate: UInt32, stereo: Bool, note theNote: MADByte = 0xFF, loopInRange loopRange: NSRange) -> MADErr {
		return self.playSoundDataFromPointer(theSnd.bytes, withSize: UInt(theSnd.length), fromChannel: theChan, amplitude: amp, bitRate: rate, isStereo: stereo, withNote: theNote, withLoopInRange: loopRange)
	}
	
	public func playSoundData(data theSnd: NSData, channel theChan: Int32, amplitude amp: Int16, bitRate rate: UInt32, stereo: Bool, note theNote: MADByte = 0xFF, loopInRange loopRange: Range<Int>) -> MADErr {
		return playSoundData(data: theSnd, channel: theChan, amplitude: amp, bitRate: rate, stereo: stereo, note: theNote, loopInRange: NSRange(loopRange))
	}
	
	///Returns nil on error.
	///The time values are in 1/60th of a second.
	public var musicStatusTime: (current: Int, total: Int)? {
		var cT = 0
		var tT = 0
		let anErr = getMusicStatusWithCurrentTime(&cT, totalTime: &tT)
		if anErr == .NoErr {
			return (cT, tT)
		} else {
			return nil
		}
	}
	
	public var oscilloscope: (size: size_t, pointer: UnsafePointer<Void>) {
		return (oscilloscopeSize, UnsafePointer<Void>(oscilloscopePointer))
	}
}
