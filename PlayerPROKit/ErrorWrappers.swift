//
//  ErrorWrappers.swift
//  PPMacho
//
//  Created by C.W. Betts on 1/22/16.
//
//

import Foundation
import PlayerPROCore
import SwiftAdditions

extension PPMADError {
	public init(madErr: MADErr, userInfo: [String: Any] = [:]) {
		self.init(PPMADError.Code(madErr), userInfo: userInfo)
	}
}

extension PPMADError.Code {
	public init(_ madErr: MADErr) {
		self = PPMADError.Code(rawValue: Int(madErr.rawValue))!
	}

	public var madErr: MADErr {
		return MADErr(rawValue: Int16(rawValue))!
	}
}

extension MADErr {
	/// Throws `self` if `self` is anything other than `.NoErr`.
	@available(*, deprecated, message: "Wrap in PPMADError, then throw")
	public func throwIfNotNoErr() throws {
		if self != .noErr {
			throw PPMADError(madErr: self)
		}
	}
	
	/// Converts to an error to one in the built-in Cocoa error domains, if possible.
	public func convertToCocoaType() -> Error {
		guard let anErr = __PPCreateErrorFromMADErrorTypeConvertingToCocoa(self, true) else {
			return PPMADError(.none, userInfo: [NSLocalizedDescriptionKey: "Throwing MADNoErr! This shouldn't happen!"])
		}
		return anErr
	}
	
	/// Creates an `NSError` from `self`, optionally converting the error type to an error in the Cocoa error domain.
	///
	/// - parameter customUserDictionary: A dictionary with additional information. May be `nil`, default is `nil`.
	/// - parameter convertToCocoa: Converts `self` into a comparable error in Cocoa's error types. Default is `true`.
	/// - returns: An `NSError` value, or `nil` if `self` is `.NoErr`
	public func toNSError(customUserDictionary cud: [String: Any]? = nil, convertToCocoa: Bool = true) -> NSError? {
		guard self != .noErr else {
			return nil
		}
		
		func populate(error: NSError) -> NSError {
			if let cud = cud {
				var errDict: [String: Any] = error.userInfo
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
			let cocoaErr = __PPCreateErrorFromMADErrorTypeConvertingToCocoa(self, true)!
			return populate(error: cocoaErr as NSError)
		}
		
		return populate(error: PPMADError(madErr: self) as NSError)
	}
	
	/// Creates a `MADErr` from the provided `NSError`.
	/// Is `nil` if the error isn't in the `PPMADErrorDomain` or
	/// the error code isn't in `MADErr`.
	@available(*, deprecated, message: "Use `catch let error as PPMADError` instead")
	public init?(error anErr: NSError) {
		guard anErr.domain == PPMADErrorDomain,
			let exact = MADErr.RawValue(exactly: anErr.code),
			let errVal = MADErr(rawValue: exact) else {
				return nil
		}
		
		self = errVal
	}
}


extension MADErr: CustomStringConvertible, CustomDebugStringConvertible {
	public var description: String {
		switch self {
		case .noErr:
			return "MADErr.noErr"
			
		case .needMemory:
			return "MADErr.needMemory"
			
		case .readingErr:
			return "MADErr.readingErr"
			
		case .incompatibleFile:
			return "MADErr.incompatibleFile"
			
		case .libraryNotInitialized:
			return "MADErr.libraryNotInitialized"
			
		case .parametersErr:
			return "MADErr.parametersErr"
			
		case .unknownErr:
			return "MADErr.unknownErr"
			
		case .soundManagerErr:
			return "MADErr.soundManagerErr"
			
		case .orderNotImplemented:
			return "MADErr.orderNotImplemented"
			
		case .fileNotSupportedByThisPlug:
			return "MADErr.fileNotSupportedByThisPlug"
			
		case .cannotFindPlug:
			return "MADErr.cannotFindPlug"
			
		case .musicHasNoDriver:
			return "MADErr.musicHasNoDriver"
			
		case .driverHasNoMusic:
			return "MADErr.driverHasNoMusic"
			
		case .soundSystemUnavailable:
			return "MADErr.soundSystemUnavailable"
			
		case .writingErr:
			return "MADErr.writingErr"
			
		case .userCancelledErr:
			return "MADErr.userCancelledErr"
		}
	}
	
	public var debugDescription: String {
		return "\(description), (\(rawValue))"
	}
}

/// Creates an `NSError` from a `MADErr`, optionally converting the error type to an error in the Cocoa error domain.
///
/// - parameter theErr: The `MADErr` to convert to an `NSError`
/// - parameter customUserDictionary: A dictionary with additional information. May be `nil`, defaults to `nil`.
/// - parameter convertToCocoa: Converts the `MADErr` code into a compatible error in Cocoa's error types. defaults to `false`.
/// - returns: An `NSError` value, or `nil` if passed `.noErr`
public func createNSError(from theErr: MADErr, customUserDictionary: [String: Any]? = nil, convertToCocoa: Bool = false) -> NSError? {
	return theErr.toNSError(customUserDictionary: customUserDictionary, convertToCocoa: convertToCocoa)
}
