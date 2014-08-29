//
//  PPMIDIImporter.swift
//  PPMacho
//
//  Created by C.W. Betts on 8/18/14.
//
//

import Cocoa
import PlayerPROCore
import PlayerPROKit

@objc(PPMIDIImporter) final public class MIDIImporter: NSObject, PPComplexImportPlugInterface {

	public func beginImportOfURL(theURL: NSURL, withHandler handler: PPComplexImportHandler) {
		var conn = NSXPCConnection(serviceName: "net.sourceforge.playerpro.MIDI-Import")
		conn.remoteObjectInterface = NSXPCInterface(`protocol`: PPMIDIImportHelper.self)

		conn.resume()
		
		conn.remoteObjectProxy.importMIDIFileAtURL(theURL, numberOfTracks: 8, useQTInstruments: true, withReply:{ (aDat, aErr) -> Void in
			if aErr == MADErr.NoErr {
				let tmpObj = MIDIReadFromData(aDat)
				handler(tmpObj, aErr)
			} else {
				handler(nil, aErr)
			}
		})
	}
	
	public func canImportURL(theURL: NSURL, error outErr: NSErrorPointer) -> Bool {
		var myErr = MADErr.NoErr;
		let fileData = NSData(contentsOfURL: theURL, options: .DataReadingMappedIfSafe, error: nil)
		
		let sig = "MThd"
		if memcmp(fileData.bytes, sig, 4) == 0 {
			return true
		} else {
			if outErr != nil {
				outErr.memory = CreateErrorFromMADErrorType(.FileNotSupportedByThisPlug)
			}
			return false
		}
	}
	
	public override init() {
		
		super.init()
	}
	
}
