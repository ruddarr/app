//
//  ExistentialEquals.swift
//  Ruddarr
//
//  Created by Petr Šíma on 10/4/24.
//

import Foundation

// taken from https://forums.swift.org/t/why-cant-existential-types-be-compared/59118/3
public func equals(_ lhs: Any, _ rhs: Any) -> Bool {
  func open<A: Equatable>(_ lhs: A, _ rhs: Any) -> Bool {
    lhs == (rhs as? A)
  }

  guard let lhs = lhs as? any Equatable
  else { return false }

  return open(lhs, rhs)
}
