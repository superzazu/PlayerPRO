//
//  CommandIterator.swift
//  PPMacho
//
//  Created by C.W. Betts on 11/5/14.
//
//

import Foundation
//import PlayerPROCore

public protocol CommandIterator {
	func getCommand(row: Int16, track: Int16) -> Cmd
	mutating func modifyCommand(row: Int16, track: Int16, commandBlock: (inout Cmd) -> ())
	mutating func replaceCommand(row: Int16, track: Int16, command: Cmd)
	
	var commandLength: Int16 {get}
	var commandTracks: Int16 {get}
}

extension CommandIterator {
	public mutating func iterateCommands(commandBlock block: (command: inout Cmd, row: Int16, track: Int16) -> Bool) {
		for i in 0 ..< commandLength {
			for x in 0 ..< commandTracks {
				var aCmd = getCommand(row: i, track: x)
				if block(command: &aCmd, row: i, track: x) {
					replaceCommand(row: i, track: x, command: aCmd)
				}
			}
		}
	}
}

public func getCommand<X where X: CommandIterator>(row: Int16, track: Int16, aIntPcmd: X) -> Cmd {
	return aIntPcmd.getCommand(row: row, track: track)
}

public func replaceCommand<X where X: CommandIterator>(row: Int16, track: Int16, command: Cmd, aPcmd: inout X) {
	aPcmd.replaceCommand(row: row, track: track, command: command)
}

public func modifyCommand<X where X: CommandIterator>(row: Int16, track: Int16, aPcmd: inout X, commandBlock: (inout Cmd) -> ()) {
	aPcmd.modifyCommand(row: row, track: track, commandBlock: commandBlock)
}

public func iterateCommands<X where X: CommandIterator>( aPcmd: inout X, commandBlock block: (command: inout Cmd, row: Int16, track: Int16) -> Bool) {
	aPcmd.iterateCommands(commandBlock: block)
}
