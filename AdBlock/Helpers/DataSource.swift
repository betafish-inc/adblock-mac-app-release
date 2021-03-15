/*******************************************************************************
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see {http://www.gnu.org/licenses/}.
 
 */

import Foundation

class DataSource<DataType> {
    var data: Observable<[DataType]> = Observable([])

    func add(_ new: DataType) {
        var newValue: [DataType] = data.get()
        newValue.append(new)
        data.set(newValue: newValue)
    }
    
    func add(_ new: [DataType]) {
        var newValue: [DataType] = data.get()
        newValue.append(contentsOf: new)
        data.set(newValue: newValue)
    }
    
    func insertAtStart(_ new: DataType) {
        var newValue: [DataType] = [new]
        newValue.append(contentsOf: data.get())
        data.set(newValue: newValue)
    }
    
    func filter(_ isIncluded: (DataType?) throws -> Bool) rethrows {
        var newValue: [DataType] = data.get()
        newValue = try newValue.filter(isIncluded)
        data.set(newValue: newValue)
    }
    
    func replace(_ new: [DataType]) {
        data.set(newValue: new)
    }
    
    func atRow(_ row: Int) -> DataType? {
        return row < data.get().count ? data.get()[row] : nil
    }
    
    func firstIndex(where predicate: (DataType?) throws -> Bool) rethrows -> Int? {
        return try data.get().firstIndex(where: predicate)
    }
    
    func addHandler<T: AnyObject>(target: T, handler: @escaping (T) -> (([DataType], [DataType])) -> Void) -> Disposable {
        return data.didChange.addHandler(target: target, handler: handler)
    }
}
