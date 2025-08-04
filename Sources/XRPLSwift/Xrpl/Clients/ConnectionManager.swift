//
//  ConnectionManager.swift
//
//
//  Created by Denis Angell on 7/27/22.
//

// https://github.com/XRPLF/xrpl.js/blob/main/packages/xrpl/src/client/ConnectionManager.ts

import Foundation
import NIO
import NIOCore

let eventGroup = MultiThreadedEventLoopGroup(numberOfThreads: 4)

// struct PromiseResolveMap {
//    var resolve: (value?: void | PromiseLike<void>) => void
//    var reject: (value?: Error) => void
// }

/**
 * Manage all the requests made to the websocket, and their async responses
 * that come in from the WebSocket. Because they come in over the WS connection
 * after-the-fact.
 */
public class ConnectionManager {
    private var promisesAwaitingConnection: [EventLoopPromise<Any>] = []

    /**
     * Resolves all awaiting connections.
     */
    public func resolveAllAwaiting() async {
        _ = self.promisesAwaitingConnection.map { resolve in
            resolve.succeed("")
        }
        self.promisesAwaitingConnection.removeAll()
    }

    /**
     * Rejects all awaiting connections.
     *
     * @param error - Error to throw in the rejection.
     */
    public func rejectAllAwaiting(error: Error) async {
        _ = self.promisesAwaitingConnection.map { resolve in
            resolve.fail(error)
        }
        self.promisesAwaitingConnection.removeAll()
    }
    
    /**
     * Check for awaiting connection
     *
     */
    public func hasAwaitingConnection() -> Bool {
        return self.promisesAwaitingConnection.count > 0
    }

    /**
     * Await a new connection.
     *
     * @returns A promise for resolving the connection.
     */
    public func awaitConnection() async -> EventLoopFuture<Any> {
        let future = eventGroup.next().makePromise(of: Any.self)
        
        let timeoutFuture = future.futureResult.timeout(
            after: .seconds(2),
            on: eventLoop
        )
        
        self.promisesAwaitingConnection.append(future)
        return future.futureResult
    }
}

extension EventLoopFuture {
    func timeout(
        after time: TimeAmount,
        on eventLoop: EventLoop,
        timeoutError: Error = TimeoutError()
    ) -> EventLoopFuture<T> {
        let promise = eventLoop.makePromise(of: T.self)
        
        // Schedule a task to fail the promise after the timeout period
        eventLoop.scheduleTask(in: time) {
            promise.fail(timeoutError)
        }
        
        // Return the first future to complete (either the original or the timeout)
        return self.flatMap { result in
            promise.succeed(result)
            return promise.futureResult
        }.flatMapError { error in
            promise.fail(error)
            return promise.futureResult
        }
    }
}
