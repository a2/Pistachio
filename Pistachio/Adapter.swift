//
//  Adapter.swift
//  Pistachio
//
//  Created by Felix Jendrusch on 2/6/15.
//  Copyright (c) 2015 Felix Jendrusch. All rights reserved.
//

import LlamaKit

public protocol Adapter: ValueTransformer {
    typealias A: Model
    typealias B
    typealias E

    func encode(a: A) -> Result<B, E>
    func decode(a: A, from: B) -> Result<A, E>
}

public struct LazyAdapter<A: Model, B, E, T: Adapter where T.A == A, T.B == B, T.E == E>: Adapter {
    private let adapter: () -> T

    public init(adapter: @autoclosure () -> T) {
        self.adapter = adapter
    }

    public func encode(a: A) -> Result<B, E> {
        return adapter().encode(a)
    }

    public func decode(a: A, from: B) -> Result<A, E> {
        return adapter().decode(a, from: from)
    }

    public func transformedValue(value: A) -> Result<B, E> {
        return encode(value)
    }

    public func reverseTransformedValue(value: B) -> Result<A, E> {
        return decode(A.self(), from: value)
    }
}

public struct DictionaryAdapter<A: Model, B, E>: Adapter {
    private let specification: [String: Lens<Result<A, E>, Result<B, E>>]
    private let dictionaryTansformer: ValueTransformerOf<B, [String: B], E>

    public init(specification: [String: Lens<Result<A, E>, Result<B, E>>], dictionaryTansformer: ValueTransformerOf<B, [String: B], E>) {
        self.specification = specification
        self.dictionaryTansformer = dictionaryTansformer
    }

    public func encode(a: A) -> Result<B, E> {
        var dictionary = [String: B]()
        for (key, lens) in self.specification {
            switch get(lens, success(a)) {
            case .Success(let value):
                dictionary[key] = value.unbox
            case .Failure(let error):
                return failure(error.unbox)
            }
        }

        return dictionaryTansformer.reverseTransformedValue(dictionary)
    }

    public func decode(a: A, from: B) -> Result<A, E> {
        return dictionaryTansformer.transformedValue(from).flatMap { dictionary in
            var result: Result<A, E> = success(a)
            for (key, lens) in self.specification {
                if let value = dictionary[key] {
                    result = set(lens, result, success(value))
                    if !result.isSuccess { break }
                }
            }

            return result
        }
    }

    public func transformedValue(value: A) -> Result<B, E> {
        return encode(value)
    }

    public func reverseTransformedValue(value: B) -> Result<A, E> {
        return decode(A.self(), from: value)
    }
}

// MARK: - Fix

public func fix<A, B, E, T: Adapter where T.A == A, T.B == B, T.E == E>(f: LazyAdapter<A, B, E, T> -> T) -> T {
    return f(LazyAdapter(adapter: fix(f)))
}

// MARK: - Lift

public func lift<A, B, E, T: Adapter where T.A == A, T.B == B, T.E == E>(adapter: T, newReverseTransformedValue: @autoclosure () -> A) -> ValueTransformerOf<A, B, E> {
    let transformClosure: A -> Result<B, E> = { a in
        return adapter.encode(a)
    }

    let reverseTransformClosure: B -> Result<A, E> = { b in
        return adapter.decode(newReverseTransformedValue(), from: b)
    }

    return ValueTransformerOf(transformClosure: transformClosure, reverseTransformClosure: reverseTransformClosure)
}
