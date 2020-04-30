//
//  TaskController.swift
//  BetterProfessor
//
//  Created by Chris Dobek on 4/29/20.
//  Copyright © 2020 Chris Dobek. All rights reserved.
//

import Foundation
import CoreData

class TaskController {
    
    
    // MARK: - Properties
    let baseURL = URL(string: "https://betterprofessortask.firebaseio.com/")!
    typealias CompletionHandler = (Result<Bool, NetworkError>) -> Void
    var apiController: APIController?
    
    init(){
        
        fetchTask()
    }
    
    var taskRep: [TaskRepresentation] = []
    
    
    func fetchTask(completion: @escaping ((Error?) -> Void) = { _ in }) {
        let requestURL = baseUrl.appendingPathExtension("json")
        
        URLSession.shared.dataTask(with: requestURL) { data, _, error in
            if let error = error {
                NSLog("Error fetching task from server: \(error)")
                completion(error)
                return
            }
            
            guard let data = data else {
                NSLog("No data returned from data task")
                completion(NSError())
                return
            }
            
            do {
                self.taskRep = try JSONDecoder().decode([String: TaskRepresentation].self, from: data).map({$0.value})
                //self.updateStudents(with: self.taskRep)
            } catch {
                NSLog("Error decoding JSON data when fetching student: \(error)")
                completion(error)
                return
            }
            
            completion(nil)
            
        }.resume()
    }
    
    func createTask(title: String, note: String, dueDate: String, student: String) {
        let task = Task(title: title, note: note, dueDate: dueDate, student: student)
              put(task: task)
              do {
                  try CoreDataStack.shared.save()
              } catch {
                  NSLog("Saving new student failed")
              }
          }
    
    func updateTask(task: Task, title: String, note: String, taskDueDate: String) {
        task.title = title
        task.note = note
        task.dueDate = taskDueDate
        put(task: task)
        do {
            try CoreDataStack.shared.save()
        } catch {
            NSLog("Saving edited student failed")
        }
    }
    
    func sendTaskToServer(task: Task, completion: @escaping CompletionHandler = { _ in }) {
        // Unwrapping
        guard let id = task.id,
            let title = task.title,
            let note = task.note,
            let date = task.dueDate,
            let student = task.student else {
                return
           }
           // Creating Representation
        let taskRepresentation = TaskRepresentation(id: id, title: title, note: note, dueDate: date, student: student)
           
           // RequestURL
           let requestURL = baseURL.appendingPathComponent(id).appendingPathExtension("json")
           
           var request = URLRequest(url: requestURL)
           request.httpMethod = "PUT"
           
           do {
               request.httpBody = try JSONEncoder().encode(taskRepresentation)
           } catch {
               print("Error encoding in SendToServer: \(error)")
               return
           }
           
           URLSession.shared.dataTask(with: request) { (data, response, error) in
               if let error = error {
                   NSLog("Error sending task to server: \(error)")
                   return
               }
               
               guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                   print("Bad response when fetching")
                   return
               }
               completion(.success(true))
           }.resume()
       }
    
    func delete(task: Task) {
        CoreDataStack.shared.mainContext.delete(task)
        do {
            deleteTaskFromServer(task: task)
            try CoreDataStack.shared.save()
        } catch {
            NSLog("Delete student failed")
        }
    }
    
    func deleteTaskFromServer(task: Task, completion: @escaping ((Error?) -> Void) = { _ in }) {
        guard let title = task.title else {
            NSLog("ID is nil when trying to delete student from server")
            completion(NSError())
            return
        }
        let requestURL = baseUrl.appendingPathComponent(title).appendingPathExtension("json")
        var request = URLRequest(url: requestURL)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { (data, _, error) in
        if let error = error {
            NSLog("Error deleting student from server: \(error)")
            completion(error)
            return
        }
        completion(nil)
        }.resume()
    }

    private func put(task: Task, completion: @escaping ((Error?) -> Void) = { _ in }){
        let title = task.title
        let requestURL = baseUrl.appendingPathComponent(title ?? " ").appendingPathExtension("json")
        var request = URLRequest(url: requestURL)
        request.httpMethod = "PUT"
        
        do {
            request.httpBody = try JSONEncoder().encode(title)
        } catch {
            NSLog("Error encoding in put method: \(error)")
            completion(error)
            return
        }
        URLSession.shared.dataTask(with: request) { data,_,error in
            if let error = error {
                NSLog("Error Putting student to server: \(error)")
                completion(error)
                return
            }
            completion(nil)
        }.resume()
    }
    
    func updateTasks(with representations: [TaskRepresentation]) {
        
        guard let apiController = apiController else {return}
        
        let taskWithIDs = representations.filter({$0.id != nil })
        let taskWithID = taskWithIDs.filter({$0.id == "\(apiController.bearer!)"})
        
        let idToFetch = taskWithID.compactMap({$0.id})
        let repByID = Dictionary(uniqueKeysWithValues: zip(idToFetch, taskWithID))
        var tasksToCreate = repByID
        
        
        let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id IN %@", idToFetch)
        let context = CoreDataStack.shared.container.newBackgroundContext()
        
        context.performAndWait {
            do {
                let existTasks = try context.fetch(fetchRequest)
                
                for task in existTasks {
                    guard let id = task.id else {continue}
                    guard let representation = repByID[id] else {continue}
                    self.update(task: task, with: representation)
                    tasksToCreate.removeValue(forKey: id)
                }
                for task in tasksToCreate.values {
                    Task(taskRepresentation: task, context: context)
                }
            } catch {
                NSLog("Error fetching student: \(error)")
            }
            do {
                try CoreDataStack.shared.save(context: context)
            } catch {
                NSLog("save failed when updating students")
            }
        }
        
    }
    
    private func update(task: Task, with rep: TaskRepresentation) {
        task.id = rep.id ?? UUID().uuidString
        task.title = rep.title
        task.note = rep.note
        task.dueDate = rep.dueDate
    }
}
