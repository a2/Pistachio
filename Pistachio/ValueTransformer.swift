//
//  ValueTransformer.swift
//  Pistachio
//
//  Created by Felix Jendrusch on 2/5/15.
//  Copyright (c) 2015 Felix Jendrusch. All rights reserved.
//

import LlamaKit

public protocol ValueTransformer {
    typealias A
    typealias B
    typealias E

    func transformedValue(value: A) -> Result<B, E>
    func reverseTransformedValue(value: B) -> Result<A, E>
}

public struct ValueTransformerOf<A, B, E>: ValueTransformer {
    private let transformClosure: A -> Result<B, E>
    private let reverseTransformClosure: B -> Result<A, E>

    public init(transformClosure: A -> Result<B, E>, reverseTransformClosure: B -> Result<A, E>) {
        self.transformClosure = transformClosure
        self.reverseTransformClosure = reverseTransformClosure
    }

    public func transformedValue(value: A) -> Result<B, E> {
        return self.transformClosure(value)
    }

    public func reverseTransformedValue(value: B) -> Result<A, E> {
        return self.reverseTransformClosure(value)
    }

    public func compose<C, V: ValueTransformer where V.A == B, V.B == C, V.E == E>(valueTransformer: V) -> ValueTransformerOf<A, C, E> {
        let transformClosure: A -> Result<C, E> = { a in
            return self.transformedValue(a).flatMap { b in valueTransformer.transformedValue(b) }
        }

        let reverseTransformClosure: C -> Result<A, E> = { c in
            return valueTransformer.reverseTransformedValue(c).flatMap { b in self.reverseTransformedValue(b) }
        }

        return ValueTransformerOf<A, C, E>(transformClosure: transformClosure, reverseTransformClosure: reverseTransformClosure)
    }
}

// MARK: - Flip

public func flip<A, B, E, V: ValueTransformer where V.A == A, V.B == B, V.E == E>(valueTransformer: V) -> ValueTransformerOf<B, A, E> {
    let transformClosure: B -> Result<A, E> = { b in
        return valueTransformer.reverseTransformedValue(b)
    }

    let reverseTransformClosure: A -> Result<B, E> = { a in
        return valueTransformer.transformedValue(a)
    }

    return ValueTransformerOf(transformClosure: transformClosure, reverseTransformClosure: reverseTransformClosure)
}

// MARK: - Compose

//public func compose<A, B, C, E, V: ValueTransformer, W: ValueTransformer where V.A == A, V.B == B, V.E == E, W.A == B, W.B == C, W.E == E>(left: V, right: W) -> ValueTransformerOf<A, C, E> {
//    let transformClosure: A -> Result<C, E> = { a in
//        return left.transformedValue(a).flatMap { b in right.transformedValue(b) }
//    }
//
//    let reverseTransformClosure: C -> Result<A, E> = { c in
//        return right.reverseTransformedValue(c).flatMap { b in left.reverseTransformedValue(b) }
//    }
//
//    return ValueTransformerOf(transformClosure: transformClosure, reverseTransformClosure: reverseTransformClosure)
//}
//
//infix operator >>> {
//    associativity right
//    precedence 170
//}
//
//public func >>> <A, B, C, E, V: ValueTransformer, W: ValueTransformer where V.A == A, V.B == B, V.E == E, W.A == B, W.B == C, W.E == E>(lhs: V, rhs: W) -> ValueTransformerOf<A, C, E> {
//    return compose(lhs, rhs)
//}
//
//infix operator <<< {
//    associativity right
//    precedence 170
//}
//
//public func <<< <A, B, C, E, V: ValueTransformer, W: ValueTransformer where V.A == B, V.B == C, V.E == E, W.A == A, W.B == B, W.E == E>(lhs: V, rhs: W) -> ValueTransformerOf<A, C, E> {
//    return compose(rhs, lhs)
//}

// MARK: - Lift

public func lift<A, B, E, V: ValueTransformer where V.A == A, V.B == B, V.E == E>(valueTransformer: V, defaultTransformedValue: @autoclosure () -> B) -> ValueTransformerOf<A?, B, E> {
    let transformClosure: A? -> Result<B, E> = { a in
        if let a = a {
            return valueTransformer.transformedValue(a)
        } else {
            return success(defaultTransformedValue())
        }
    }

    let reverseTransformClosure: B -> Result<A?, E> = { b in
        return valueTransformer.reverseTransformedValue(b).map { $0 }
    }

    return ValueTransformerOf(transformClosure: transformClosure, reverseTransformClosure: reverseTransformClosure)
}

public func lift<A, B, E, V: ValueTransformer where V.A == A, V.B == B, V.E == E>(valueTransformer: V) -> ValueTransformerOf<[A], [B], E> {
    let transformClosure: [A] -> Result<[B], E> = { xs in
        var result = [B]()
        for x in xs {
            switch valueTransformer.transformedValue(x) {
            case .Success(let value):
                result.append(value.unbox)
            case .Failure(let error):
                return failure(error.unbox)
            }
        }

        return success(result)
    }

    let reverseTransformClosure: [B] -> Result<[A], E> = { ys in
        var result = [A]()
        for y in ys {
            switch valueTransformer.reverseTransformedValue(y) {
            case .Success(let value):
                result.append(value.unbox)
            case .Failure(let error):
                return failure(error.unbox)
            }
        }

        return success(result)
    }

    return ValueTransformerOf(transformClosure: transformClosure, reverseTransformClosure: reverseTransformClosure)
}
