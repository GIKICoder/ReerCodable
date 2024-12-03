//
//  Copyright © 2020 winddpan.
//  Copyright © 2024 reers.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import SwiftSyntax

extension VariableDeclSyntax {
    var isLazy: Bool {
        return modifiers.contains { $0.name.trimmedDescription == "lazy" }
    }
    
    var isStoredProperty: Bool {
        if modifiers.contains(where: { $0.name.trimmedDescription == "static" }) {
            return false
        }
        guard let binding = bindings.last else { return false }
        guard let accessor = binding.accessorBlock?.accessors else { return true }
        switch accessor {
        case .accessors(let accessorDeclListSyntax):
            for accessor in accessorDeclListSyntax {
                switch accessor.accessorSpecifier.tokenKind {
                case .keyword(.willSet), .keyword(.didSet):
                    break
                default:
                    return false
                }
            }
            return true
        case .getter:
            return false
        }
    }
    
    var isOptional: Bool {
        guard let binding = bindings.first else { return false }
        if let typeSyntax = binding.typeAnnotation?.type {
            if typeSyntax.is(OptionalTypeSyntax.self) {
                return true
            } else if typeSyntax.trimmedDescription.hasPrefix("Optional<") {
                return true
            }
        }
        
        guard let initializer = binding.initializer?.value else { return false }
        if initializer.trimmedDescription.hasPrefix("Optional<")
           || initializer.trimmedDescription.hasPrefix("Optional(") {
            return true
        }
        
        return false
    }
    
    var name: String? {
        guard
            let binding = bindings.first,
            let pattern = binding.pattern.as(IdentifierPatternSyntax.self)
        else { return nil }
        return pattern.identifier.text
    }
    
    var type: String? {
        guard let binding = bindings.first else { return nil }
        if let typeSyntax = binding.typeAnnotation?.type {
            return typeSyntax.trimmedDescription
        }
        if let initExpr = binding.initializer?.value {
            if initExpr.is(BooleanLiteralExprSyntax.self) {
                return "Bool"
            } else if initExpr.is(IntegerLiteralExprSyntax.self) {
                return "Int"
            } else if initExpr.is(FloatLiteralExprSyntax.self) {
                return "Double"
            } else if initExpr.is(StringLiteralExprSyntax.self) {
                return "String"
            } else if let arrayExpr = initExpr.as(ArrayExprSyntax.self),
                      let firstElement = arrayExpr.elements.first?.expression {
                if firstElement.is(BooleanLiteralExprSyntax.self) {
                    return "[Bool]"
                } else if firstElement.is(IntegerLiteralExprSyntax.self) {
                    return "[Int]"
                } else if firstElement.is(FloatLiteralExprSyntax.self) {
                    return "[Double]"
                } else if firstElement.is(StringLiteralExprSyntax.self) {
                    return "[String]"
                }
            } else if let funcExpr = initExpr.as(FunctionCallExprSyntax.self) {
                if let calledExpr = funcExpr.calledExpression.as(DeclReferenceExprSyntax.self) {
                    return calledExpr.trimmedDescription
                } else if let arrayType = extractArrayType(from: funcExpr) {
                    return arrayType
                } else if let dictType = extractDictType(from: funcExpr) {
                    return dictType
                }
            }
        }
        return nil
    }
    
    var initExpr: String? {
        return bindings.first?.initializer?.value.trimmedDescription
    }
}

extension VariableDeclSyntax {
    private func extractArrayType(from syntax: FunctionCallExprSyntax) -> String? {
        guard
            let arrayExpr = syntax.calledExpression.as(ArrayExprSyntax.self),
            let firstElement = arrayExpr.elements.first,
            let declRef = firstElement.expression.as(DeclReferenceExprSyntax.self)
        else {
            return nil
        }
        
        return "[\(declRef.baseName.text)]"
    }
    
    private func extractDictType(from syntax: FunctionCallExprSyntax) -> String? {
        guard
            let dictExpr = syntax.calledExpression.as(DictionaryExprSyntax.self),
            case .elements(let elements) = dictExpr.content,
            let firstElement = elements.first
        else {
            return nil
        }
        
        let keyType: String
        if let keyDeclRef = firstElement.key.as(DeclReferenceExprSyntax.self) {
            keyType = keyDeclRef.baseName.text
        } else {
            return nil
        }
        
        let valueType: String
        if let valueTypeExpr = firstElement.value.as(TypeExprSyntax.self),
           let identifierType = valueTypeExpr.type.as(IdentifierTypeSyntax.self) {
            valueType = identifierType.name.text
        } else if let valueDeclRef = firstElement.value.as(DeclReferenceExprSyntax.self) {
            valueType = valueDeclRef.baseName.text
        } else if let optionalChain = firstElement.value.as(OptionalChainingExprSyntax.self),
                  let declRef = optionalChain.expression.as(DeclReferenceExprSyntax.self) {
            valueType = declRef.baseName.text + "?"
        } else {
            return nil
        }
        
        return "[\(keyType): \(valueType)]"
    }
}
