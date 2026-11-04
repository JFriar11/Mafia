//
//  ObserverManager.swift
//  Mafia
//
//  Created by Jack Friar on 10/23/25.
//

import Foundation
import FirebaseDatabase

/// Manages Firebase observers with automatic cleanup
final class ObserverManager {
    private var handles: [(ref: DatabaseReference, handle: DatabaseHandle)] = []
    
    /// Add an observer and track it for cleanup
    @discardableResult
    func observe(_ ref: DatabaseReference,
                 event: DataEventType = .value,
                 with block: @escaping (DataSnapshot) -> Void) -> DatabaseHandle {
        let handle = ref.observe(event, with: block)
        handles.append((ref: ref, handle: handle))
        return handle
    }
    
    /// Observe once (no cleanup needed, but included for consistency)
    func observeSingleEvent(_ ref: DatabaseReference,
                           event: DataEventType = .value,
                           with block: @escaping (DataSnapshot) -> Void) {
        ref.observeSingleEvent(of: event, with: block)
    }
    
    /// Remove a specific observer
    func removeObserver(ref: DatabaseReference, handle: DatabaseHandle) {
        ref.removeObserver(withHandle: handle)
        handles.removeAll { $0.ref == ref && $0.handle == handle }
    }
    
    /// Remove all observers
    func removeAllObservers() {
        for (ref, handle) in handles {
            ref.removeObserver(withHandle: handle)
        }
        handles.removeAll()
    }
    
    deinit {
        removeAllObservers()
    }
}
