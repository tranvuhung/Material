/*
 * Copyright (C) 2015 - 2017, Daniel Dahan and CosmicMind, Inc. <http://cosmicmind.com>.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *	*	Redistributions of source code must retain the above copyright notice, this
 *		list of conditions and the following disclaimer.
 *
 *	*	Redistributions in binary form must reproduce the above copyright notice,
 *		this list of conditions and the following disclaimer in the documentation
 *		and/or other materials provided with the distribution.
 *
 *	*	Neither the name of CosmicMind nor the names of its
 *		contributors may be used to endorse or promote products derived from
 *		this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import EventKit

@objc(EventsReminderAuthorizationStatus)
public enum EventsReminderAuthorizationStatus: Int {
    case authorized
    case denied
}

@objc(EventsReminderPriority)
public enum EventsReminderPriority: Int {
    case none
    case high = 1
    case medium = 5
    case low = 9
}

@objc(EventsDelegate)
public protocol EventsDelegate {
    /**
     A delegation method that is executed when the Reminders status is updated.
     - Parameter events: A reference to the Reminders.
     - Parameter status: A reference to the EventReminderAuthorizationStatus.
     */
    @objc
    optional func events(events: Events, status: EventsReminderAuthorizationStatus)
    
    /**
     A delegation method that is executed when events authorization is authorized.
     - Parameter events: A reference to the Reminders.
     */
    @objc
    optional func eventsAuthorizedForReminders(events: Events)
    
    /**
     A delegation method that is executed when events authorization is denied.
     - Parameter events: A reference to the Reminders.
     */
    @objc
    optional func eventsDeniedForReminders(events: Events)
    
    /**
     A delegation method that is executed when a new calendar is created
     - Parameter events: A reference to the Reminders.
     - Parameter calendar: An optional reference to the calendar created.
     - Parameter error: An optional error if the calendar failed to be created.
     */
    @objc
    optional func events(events: Events, createdCalendar calendar: EKCalendar?, error: Error?)
    
    /**
     A delegation method that is executed when a new calendar is created.
     - Parameter events: A reference to the Reminders.
     - Parameter removed calendar: A reference to the calendar created.
     - Parameter error: An optional error if the calendar failed to be removed.
     */
    @objc
    optional func events(events: Events, removedCalendar calendar: EKCalendar, error: Error?)
    
    /**
     A delegation method that is executed when a new reminder is created.
     - Parameter events: A reference to the Reminders.
     - Parameter calendar: An optional reference to the reminder created.
     - Parameter error: An optional error if the reminder failed to be created.
     */
    @objc
    optional func events(events: Events, createdReminders reminder: EKReminder?, error: Error?)
    
    /**
     A delegation method that is executed when a new Reminders list is created
     - Parameter events: A reference to the Reminders.
     - Parameter deleted: A boolean describing if the operation succeeded or not.
     - Parameter error: An optional error if the reminder failed to be removed.
     */
    @objc
    optional func events(events: Events, removedReminders reminder: EKReminder, error: Error?)
}

@objc(Events)
open class Events: NSObject {
    /// A boolean indicating whether to commit or not.
    fileprivate var isCommitted = true
    
    /// A reference to the eventsStore.
    fileprivate let eventStore = EKEventStore()
    
    /// The current EventsReminderAuthorizationStatus.
    open var authorizationStatusForReminders: EventsReminderAuthorizationStatus {
        return .authorized == EKEventStore.authorizationStatus(for: .reminder) ? .authorized : .denied
    }
    
    /// A reference to a EventsDelegate.
    open weak var delegate: EventsDelegate?
    
    open func requestAuthorizationForReminders(_ completion: ((EventsReminderAuthorizationStatus) -> Void)? = nil) {
        eventStore.requestAccess(to: .reminder) { [weak self, completion = completion] (isAuthorized, _) in
            DispatchQueue.main.async { [weak self, completion = completion] in
                guard let s = self else {
                    return
                }
                
                guard isAuthorized else {
                    completion?(.denied)
                    s.delegate?.events?(events: s, status: .denied)
                    s.delegate?.eventsDeniedForReminders?(events: s)
                    return
                }
                
                completion?(.authorized)
                s.delegate?.events?(events: s, status: .authorized)
                s.delegate?.eventsAuthorizedForReminders?(events: s)
            }
        }
    }
}

extension Events {
    /// Begins a storage transaction.
    open func begin() {
        isCommitted = false
    }
    
    /// Resets the storage transaction state.
    open func reset() {
        isCommitted = true
    }
    
    /// Commits the storage transaction.
    open func commit(_ completion: ((Bool, Error?) -> Void)) {
        reset()
        
        var success = false
        var error: Error?
        
        do {
            try eventStore.commit()
            success = true
        } catch let e {
            error = e
        }
        
        completion(success, error)
    }
}

extension Events {
    /**
     Creates a predicate for the events Array of calendars.
     - Parameter in calendars: An optional Array of EKCalendars.
     */
    open func predicateForReminders(in calendars: [EKCalendar]) -> NSPredicate {
        return eventStore.predicateForReminders(in: calendars)
    }
    
    /**
     Creates a predicate for the events Array of calendars that
     are incomplete and have a given start and end date.
     - Parameter starting: A Date.
     - Parameter ending: A Date.
     - Parameter calendars: An optional Array of [EKCalendar].
     */
    open func predicateForIncompleteReminders(starting: Date, ending: Date, calendars: [EKCalendar]? = nil) -> NSPredicate {
        return eventStore.predicateForIncompleteReminders(withDueDateStarting: starting, ending: ending, calendars: calendars)
    }
    
    /**
     Creates a predicate for the events Array of calendars that
     are completed and have a given start and end date.
     - Parameter starting: A Date.
     - Parameter ending: A Date.
     - Parameter calendars: An optional Array of [EKCalendar].
     */
    open func predicateForCompletedReminders(starting: Date, ending: Date, calendars: [EKCalendar]? = nil) -> NSPredicate {
        return eventStore.predicateForCompletedReminders(withCompletionDateStarting: starting, ending: ending, calendars: calendars)
    }
}

extension Events {
    /**
     A method for retrieving reminder calendars in alphabetical order.
     - Parameter completion: A completion call back
     */
    open func fetchCalendarsForReminders(_ completion: @escaping ([EKCalendar]) -> Void) {
        DispatchQueue.global(qos: .default).async { [weak self, completion = completion] in
            guard let s = self else {
                return
            }
            
            let calendar = s.eventStore.calendars(for: .reminder).sorted(by: { (a, b) -> Bool in
                return a.title < b.title
            })
            
            DispatchQueue.main.async { [calendar = calendar, completion = completion] in
                completion(calendar)
            }
        }
    }
    
    /**
     A method for retrieving events with a predicate in date sorted order.
     - Parameter predicate: A NSPredicate.
     - Parameter completion: A completion call back.
     - Returns: A fetch events request identifier.
     */
    @discardableResult
    open func fetchReminders(matching predicate: NSPredicate, completion: @escaping ([EKReminder]) -> Void) -> Any {
        return eventStore.fetchReminders(matching: predicate, completion: { [completion = completion] (events) in
            DispatchQueue.main.async { [completion = completion] in
                completion(events ?? [])
            }
        })
    }
    
    /**
     Fetch all the events in a given Array of calendars.
     - Parameter in calendars: An Array of EKCalendars.
     - Parameter completion: A completion call back.
     - Returns: A fetch events request identifier.
     */
    @discardableResult
    open func fetchReminders(in calendars: [EKCalendar], completion: @escaping ([EKReminder]) -> Void) -> Any {
        return fetchReminders(matching: predicateForReminders(in: calendars), completion: completion)
    }
    
    /**
     Fetch all the events in a given Array of calendars that
     are incomplete, given a start and end date.
     - Parameter starting: A Date.
     - Parameter ending: A Date.
     - Parameter calendars: An Array of EKCalendars.
     - Parameter completion: A completion call back.
     - Returns: A fetch events request identifier.
     */
    @discardableResult
    open func fetchIncompleteReminders(starting: Date, ending: Date, calendars: [EKCalendar]? = nil, completion: @escaping ([EKReminder]) -> Void) -> Any {
        return fetchReminders(matching: predicateForIncompleteReminders(starting: starting, ending: ending, calendars: calendars), completion: completion)
    }
    
    /**
     Fetch all the events in a given Array of calendars that
     are completed, given a start and end date.
     - Parameter starting: A Date.
     - Parameter ending: A Date.
     - Parameter calendars: An Array of EKCalendars.
     - Parameter completion: A completion call back.
     - Returns: A fetch events request identifier.
     */
    @discardableResult
    open func fetchCompletedReminders(starting: Date, ending: Date, calendars: [EKCalendar]? = nil, completion: @escaping ([EKReminder]) -> Void) -> Any {
        return fetchReminders(matching: predicateForCompletedReminders(starting: starting, ending: ending, calendars: calendars), completion: completion)
    }
    
    /**
     Cancels an active events request.
     - Parameter _ identifier: An identifier.
     */
    open func cancelFetchRequest(_ identifier: Any) {
        eventStore.cancelFetchRequest(identifier)
    }
}

extension Events {
    /**
     A method for creating new Reminders calendar.
     - Parameter calendar title: the name of the list.
     - Parameter completion: An optional completion call back.
     */
    open func createCalendarForReminders(title: String, completion: ((EKCalendar?, Error?) -> Void)? = nil) {
        DispatchQueue.global(qos: .default).async { [weak self, completion = completion] in
            guard let s = self else {
                return
            }
            
            let calendar = EKCalendar(for: .reminder, eventStore: s.eventStore)
            calendar.title = title
            
            calendar.source = s.eventStore.defaultCalendarForNewReminders().source
                    
            var success = false
            var error: Error?
            
            do {
                try s.eventStore.saveCalendar(calendar, commit: s.isCommitted)
                success = true
            } catch let e {
                error = e
            }
            
            DispatchQueue.main.async { [weak self, completion = completion] in
                guard let s = self else {
                    return
                }
                
                completion?(success ? calendar : nil, error)
                s.delegate?.events?(events: s, createdCalendar: success ? calendar : nil, error: error)
            }
        }
    }
    
    /**
     A method for removing existing calendar,
     - Parameter calendar identifier: The EKCalendar identifier String.
     - Parameter completion: An optional completion call back.
     */
    open func removeCalendar(identifier: String, completion: ((Bool, Error?) -> Void)? = nil) {
        DispatchQueue.global(qos: .default).async { [weak self, completion = completion] in
            guard let s = self else {
                return
            }
            
            var success = false
            var error: Error?
            
            guard let calendar = s.eventStore.calendar(withIdentifier: identifier) else {
                var userInfo = [String: Any]()
                userInfo[NSLocalizedDescriptionKey] = "[Material Error: Cannot remove calendar with identifier \(identifier).]"
                userInfo[NSLocalizedFailureReasonErrorKey] = "[Material Error: Cannot remove calendar with identifier \(identifier).]"
                error = NSError(domain: "com.cosmicmind.material.events", code: 0001, userInfo: userInfo)
                
                completion?(success, error)
                return
            }
            
            do {
                try s.eventStore.removeCalendar(calendar, commit: s.isCommitted)
                success = true
            } catch let e {
                error = e
            }
            
            DispatchQueue.main.async { [weak self, completion = completion] in
                guard let s = self else {
                    return
                }
                
                completion?(success, error)
                s.delegate?.events?(events: s, removedCalendar: calendar, error: error)
            }
        }
    }
}

extension Events {    
    // FIX ME: Should we use the calendar identifier here instead of the title for finding the right cal?
    /**
     A method for adding a new reminder to an optionally existing list.
     if the list does not exist it will be added to the default events list.
     - Parameter completion: optional A completion call back
     */
    open func createReminder(title: String, calendar: EKCalendar, startDateComponents: DateComponents? = nil, dueDateComponents: DateComponents? = nil, priority: EventsReminderPriority? = .none, notes: String?, completion: ((EKReminder?, Error?) -> Void)? = nil) {
        DispatchQueue.global(qos: .default).async { [weak self, calendar = calendar, completion = completion] in
            guard let s = self else {
                return
            }
            
            let reminder = EKReminder(eventStore: s.eventStore)
            reminder.title = title
            reminder.calendar = calendar
            reminder.startDateComponents = startDateComponents
            reminder.dueDateComponents = dueDateComponents
            reminder.priority = priority?.rawValue ?? EventsReminderPriority.none.rawValue
            reminder.notes = notes
            
            var success = false
            var error: Error?
            
            do {
                try s.eventStore.save(reminder, commit: s.isCommitted)
                success = true
            } catch let e {
                error = e
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let s = self else {
                    return
                }
                
                completion?(success ? reminder : nil, error)
                s.delegate?.events?(events: s, createdReminders: success ? reminder : nil, error: error)
            }
        }
    }

    /**
     A method for removing existing reminder,
     - Parameter reminder identifier: The EKReminders identifier String.
     - Parameter completion: An optional completion call back.
     */
    open func removeReminder(identifier: String, completion: ((Bool, Error?) -> Void)? = nil) {
        DispatchQueue.global(qos: .default).async { [weak self, completion = completion] in
            guard let s = self else {
                return
            }
            
            var success = false
            var error: Error?
            
            guard let reminder = s.eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
                var userInfo = [String: Any]()
                userInfo[NSLocalizedDescriptionKey] = "[Material Error: Cannot remove calendar with identifier \(identifier).]"
                userInfo[NSLocalizedFailureReasonErrorKey] = "[Material Error: Cannot remove calendar with identifier \(identifier).]"
                error = NSError(domain: "com.cosmicmind.material.events", code: 0001, userInfo: userInfo)
                
                completion?(success, error)
                return
            }
            
            do {
                try s.eventStore.remove(reminder, commit: s.isCommitted)
                success = true
            } catch let e {
                error = e
            }
            
            DispatchQueue.main.async { [weak self, completion = completion] in
                guard let s = self else {
                    return
                }
                
                completion?(success, error)
                s.delegate?.events?(events: s, removedReminders: reminder, error: error)
            }
        }
    }
}
