//
//  OperationPriorityQueue.swift
//  DiscoParty
//
//  Created by Luke Brody on 11/6/16.
//  Copyright © 2016 Luke Brody. All rights reserved.
//

import Foundation

/*
 This data structure implements a 1-buffer operations cycle.
 SingleBufferQueue executes the first operation given. While said operation is executing, only the most recent operation submitted to the queue is stored. When the first operation completes, the queue removes from storage and executes the stored operation, if it exists.
 */

class SingleBufferQueue {
    
    typealias Block = ()->Void

    private let queue = DispatchQueue(label: "SingleBufferQueue")
    
    private let semaphore = DispatchSemaphore(value: 0)
    
    private var buffer : Block?
    private let bufferMutex = PThreadMutex()
    
    private func pushBuffer(block: @escaping Block) {
        bufferMutex.sync {
            buffer = block
        }
        semaphore.signal()
    }
    
    private func popBuffer() -> Block? {
        return bufferMutex.sync {
            let result = buffer
            buffer = nil
            return result
        }
    }
    
    init() {
        queue.async {
            while true {
                var op = self.popBuffer()
                
                if op == nil {
                    self.semaphore.wait()
                    op = self.popBuffer()
                }
                
                op?()
            }
        }
    }
    
    func async(operation: @escaping Block) {
        pushBuffer(block: operation)
    }
    
}
