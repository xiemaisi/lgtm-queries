// Copyright 2016 Semmle Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under
// the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the License for the specific language governing
// permissions and limitations under the License.

/**
 * External declarations described in Closure-style externs files.
 *
 * <p>
 * A declaration may either declare a type alias, a global variable or a member variable.
 * Member variables may either be static variables, meaning that they are directly attached
 * to a global object (typically a constructor function), or instance variables, meaning
 * that they are attached to the 'prototype' property of a constructor function.
 * </p>
 *
 * <p>
 * An example of a type alias declaration is
 * </p>
 *
 * <pre>
 * /** @typedef {String} *&#47;
 * var MyString;
 * </pre>
 *
 * <p>
 * Examples of a global variable declarations are
 * </p>
 *
 * <pre>
 * var Math = {};
 * function Object() {}
 * var Array = function() {};
 * </pre>
 *
 * <p>
 * Examples of static member variable declarations are
 * </p>
 * 
 * <pre>
 * Math.PI;
 * Object.keys = function(obj) {};
 * Array.isArray = function(arr) {};
 * </pre>
 *
 * <p>
 * Examples of instance member variable declarations are
 * </p>
 *
 * <pre>
 * Object.prototype.hasOwnProperty = function(p) {};
 * Array.prototype.length;
 * </pre>
 */

import AST

/** A declaration in an externs file. */
abstract class ExternalDecl extends ASTNode {
  /** Get the name of this declaration. */
  abstract string getName();

  /** Get the qualified name of this declaration. */
  abstract string getQualifiedName();

  string toString() {
    result = getQualifiedName()
  }
}

// helper predicate
private predicate hasTypedefAnnotation(Stmt s) {
  s.getDocumentation().getATag().getTitle() = "typedef"
}

/** A typedef declaration in an externs file. */
class ExternalTypedef extends ExternalDecl, VariableDeclarator {
  ExternalTypedef() {
    getBindingPattern() instanceof Identifier and
    inExternsFile() and
    hasTypedefAnnotation(getDeclStmt())
  }

  string getName() {
    result = getBindingPattern().(Identifier).getName()
  }

  string getQualifiedName() {
    result = getName()
  }

  string toString() { result = VariableDeclarator.super.toString() }
  CFGNode getFirstCFGNode() { result = VariableDeclarator.super.getFirstCFGNode() }
}

/** A variable or function declaration in an externs file. */
abstract class ExternalVarDecl extends ExternalDecl, ASTNode {
  /**
   * Get the initializer associated with this declaration, if any. This can be either
   * a function or an expression.
   */ 
  abstract ASTNode getInit();

  /**
   * Get the documentation comment associated with this declaration, if any.
   */
  abstract JSDoc getDocumentation();

  string toString() { result = ExternalDecl.super.toString() }
}

/** A global declaration of a function or variable in an externs file. */
abstract class ExternalGlobalDecl extends ExternalVarDecl {
  string getQualifiedName() {
    result = getName()
  }
}

/** A global function declaration in an externs file. */
class ExternalGlobalFunctionDecl extends ExternalGlobalDecl, FunctionDeclStmt {
  ExternalGlobalFunctionDecl() {
    inExternsFile()
  }

  /** Get the name of this declaration. */
  string getName() {
    result = FunctionDeclStmt.super.getName()
  }

  ASTNode getInit() {
    result = this
  }

  string toString() { result = FunctionDeclStmt.super.toString() }

  /** Get the JSDoc comment associated with this declaration, if any. */
  JSDoc getDocumentation() { result = FunctionDeclStmt.super.getDocumentation() }
}

/** A global variable delaration in an externs file. */
class ExternalGlobalVarDecl extends ExternalGlobalDecl, VariableDeclarator {
  ExternalGlobalVarDecl() {
    getBindingPattern() instanceof Identifier and
    inExternsFile() and
    // exclude type aliases
    not hasTypedefAnnotation(getDeclStmt())
  }

  string getName() {
    result = getBindingPattern().(Identifier).getName()
  }

  /** Get the initializer associated with this declaration, if any. */
  Expr getInit() {
    result = VariableDeclarator.super.getInit()
  }

  string toString() { result = VariableDeclarator.super.toString() }
  CFGNode getFirstCFGNode() { result = VariableDeclarator.super.getFirstCFGNode() }

  /** Get the JSDoc comment associated with this declaration, if any. */
  JSDoc getDocumentation() { result = VariableDeclarator.super.getDocumentation() }
}

/** A member variable declaration in an externs file. */
class ExternalMemberDecl extends ExternalVarDecl, ExprStmt {
  ExternalMemberDecl() {
    getParent() instanceof Externs and
    (getExpr() instanceof PropAccess or
     getExpr().(AssignExpr).getLhs() instanceof PropAccess)
  }

  /**
   * Get the property access describing the declared member.
   */
  PropAccess getProperty() {
    result = getExpr() or
    result = getExpr().(AssignExpr).getLhs()
  }

  Expr getInit() {
    result = getExpr().(AssignExpr).getRhs()
  }

  string getQualifiedName() {
    result = getProperty().getQualifiedName()
  }

  string getName() {
    result = getProperty().getPropertyName()
  }

  /**
   * Get the name of the base type to which the member declared by this declaration belongs.
   */
  string getBaseName() {
    none()
  }

  /**
   * Get the base type to which the member declared by this declaration belongs.
   */
  ExternalType getDeclaringType() {
    result.getQualifiedName() = getBaseName()
  }

  string toString() { result = ExprStmt.super.toString() }

  /** Get the documentation comment associated with this declaration, if any. */
  JSDoc getDocumentation() { result = ExprStmt.super.getDocumentation() }
}

/**
 * A static member variable declaration in an externs file.
 *
 * <p>
 * This captures declarations of the form <code>A.f;</code>, and declarations
 * with initializers of the form <code>A.f = {};</code>.
 * </p>
 */
class ExternalStaticMemberDecl extends ExternalMemberDecl {
  ExternalStaticMemberDecl() {
    getProperty().getBase() instanceof Identifier
  }

  string getBaseName() {
    result = getProperty().getBase().(Identifier).getName()
  }
}

/**
 * An instance member variable declaration in an externs file.
 *
 * <p>
 * This captures declarations of the form <code>A.prototype.f;</code>, and declarations
 * with initializers of the form <code>A.prototype.f = {};</code>.
 * </p>
 */
class ExternalInstanceMemberDecl extends ExternalMemberDecl {
  ExternalInstanceMemberDecl() {
    exists (PropAccess outer, PropAccess inner |
      outer = getProperty() and inner = outer.getBase() |
      inner.getBase() instanceof Identifier and
      inner.getPropertyName() = "prototype"
    )
  }

  string getBaseName() {
    result = getProperty().getBase().(PropAccess).getBase().(Identifier).getName()
  }
}

/**
 * A function or object defined in an externs file.
 */
class ExternalEntity extends ASTNode {
  ExternalEntity() {
    exists (ExternalVarDecl d | d.getInit() = this)
  }

  /** Get the variable declaration to which this entity belongs. */
  ExternalVarDecl getDecl() {
    result.getInit() = this
  }
}

/**
 * A function defined in an externs file.
 */
class ExternalFunction extends ExternalEntity, Function {
  /**
   * Does the last parameter of this external function have a rest parameter type annotation?
   */
  predicate isVarArgs() {
    exists (SimpleParameter lastParm, JSDocParamTag pt |
      lastParm = this.getParameter(this.getNumParameter()-1) and
      pt = getDecl().getDocumentation().getATag() and
      pt.getName() = lastParm.getName() and
      pt.getType() instanceof JSDocRestParameterTypeExpr
    )
  }
}

/**
 * A <code>@constructor</code> tag.
 */
class ConstructorTag extends JSDocTag {
  ConstructorTag() { getTitle() = "constructor" }
}

/** A JSDoc tag that refers to a named type. */
abstract library class NamedTypeReferent extends JSDocTag {
  /** Get the name of the type to which this tag refers. */
  string getTarget() {
    result = getType().(JSDocNamedTypeExpr).getName() or
    result = getType().(JSDocAppliedTypeExpr).getHead().(JSDocNamedTypeExpr).getName()
  }
}

/**
 * An <code>@implements</code> tag.
 */
class ImplementsTag extends NamedTypeReferent {
  ImplementsTag() { getTitle() = "implements" }
}

/**
 * An <code>@extends</code> tag.
 */
class ExtendsTag extends NamedTypeReferent {
  ExtendsTag() { getTitle() = "extends" }
}

/**
 * A constructor or interface function defined in an externs file.
 */
abstract class ExternalType extends ExternalGlobalFunctionDecl {
  /** Get a type which this type extends. */
  ExternalType getAnExtendedType() {
    getDocumentation().getATag().(ExtendsTag).getTarget() = result.getQualifiedName()
  }

  /** Get a type which this type implements. */
  ExternalType getAnImplementedType() {
    getDocumentation().getATag().(ImplementsTag).getTarget() = result.getQualifiedName()
  }

  /** Get a supertype of this type. */
  ExternalType getASupertype() {
    result = getAnExtendedType() or result = getAnImplementedType()
  }

  /** Get the declaration of a member of this type. */
  ExternalMemberDecl getAMember() {
    result.getDeclaringType() = this
  }
}

/**
 * A constructor function defined in an externs file.
 */
class ExternalConstructor extends ExternalType {
  ExternalConstructor() {
    getDocumentation().getATag() instanceof ConstructorTag
  }
}

/**
 * An interface function defined in an externs file.
 */
class ExternalInterface extends ExternalType {
  ExternalInterface() {
    getDocumentation().getATag().getTitle() = "interface"
  }
}

/**
 * Externs definition for the Function object.
 */
class FunctionExternal extends ExternalConstructor {
  FunctionExternal() {
    getName() = "Function"
  }
}

/**
 * Externs definition for the Object object.
 */
class ObjectExternal extends ExternalConstructor {
  ObjectExternal() {
    getName() = "Object"
  }
}

/**
 * Externs definition for the Array object.
 */
class ArrayExternal extends ExternalConstructor {
  ArrayExternal() {
    getName() = "Array"
  }
}
