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

import python


/** An (artificial) expression corresponding to a class definition.
 * It is recommended to use `ClassDef` instead.
 */
class ClassExpr extends ClassExpr_ {

    /** Gets the metaclass expression */
     Expr getMetaClass() {
        if major_version() = 3 then
            exists(Keyword metacls | this.getAKeyword() = metacls and metacls.getArg() = "metaclass" and result = metacls.getValue())
        else
            exists(Assign a | a = this.getInnerScope().getAStmt() and ((Name)a.getATarget()).getId() = "__metaclass__" and result = a.getValue())
    }

    Expr getASubExpression() {
       result = this.getABase() or
       result = this.getAKeyword().getValue() or
       result = this.getKwargs() or
       result = this.getStarargs()
    }

    Call getADecoratorCall() {
        result.getArg(0) = this or
        result.getArg(0) = this.getADecoratorCall()
    }

    /** Gets a decorator of this function expression */
    Expr getADecorator() {
        result = this.getADecoratorCall().getFunc()
    }

    AstNode getAChildNode() {
        result = this.getASubExpression()
        or
        result = this.getInnerScope()
    }

}

/** A class statement. Note that ClassDef extends Assign as a class definition binds the newly created class */
class ClassDef extends Assign {

    ClassDef() {
        /* This is an artificial assignment the rhs of which is a (possibly decorated) ClassExpr */
        exists(ClassExpr c | this.getValue() = c or this.getValue() = c.getADecoratorCall())
    }

    string toString() {
        result = "ClassDef"
    }

    /** Gets the class for this statement */
    Class getDefinedClass() {
        exists(ClassExpr c | 
            this.getValue() = c or this.getValue() = c.getADecoratorCall() | 
            result = c.getInnerScope()
        )
    }

}

/** The scope of a class. This is the scope of all the statements within the class definition */
class Class extends Class_, Scope, AstNode {

    /** Use getADecorator() instead of getDefinition().getADecorator() 
     *  Use getMetaClass() instead of getDefinition().getMetaClass()
     */
    deprecated ClassExpr getDefinition() {
        result = this.getParent()
    }

    /** Gets a defined init method of this class */
    Function getInitMethod() {
        result.getScope() = this and result.isInitMethod()
    }

    /** Gets a method defined in this class */
    Function getAMethod() {
        result.getScope() = this
    }

    Location getLocation() {
        py_scope_location(result, this)
    }

    /** Gets the scope (module, class or function) in which this class is defined */
    Scope getScope() {
        result = this.getParent().getScope()
    }

    string toString() {
        result = "Class " + this.getName()
    }

    /** Gets the statements forming the body of this class */
    StmtList getBody() {
        result = Class_.super.getBody()
    }

    /** Gets the nth statement in the class */
    Stmt getStmt(int index) {
        result = Class_.super.getStmt(index)
    }

    /** Gets a statement in the class */
    Stmt getAStmt() {
        result = Class_.super.getAStmt()
    }

    /** Gets the name used to define this class */
    string getName() {
        result = Class_.super.getName()
    }

    predicate hasSideEffects() {
        any()
    }

    /** Whether this is probably a mixin (has 'mixin' or similar in name or docstring) */
    predicate isProbableMixin() {
        (this.getName().toLowerCase().matches("%mixin%")
         or
         this.getDocString().getText().toLowerCase().matches("%mixin%")
         or
         this.getDocString().getText().toLowerCase().matches("%mix-in%")
        )
    }

    AstNode getAChildNode() {
        result = this.getAStmt()
    }

    Expr getADecorator() {
        result = this.getParent().getADecorator()
    }

    /** Gets the metaclass expression */
     Expr getMetaClass() {
        result = this.getParent().getMetaClass()
    }

    /** Gets the ClassObject corresponding to this class */
    ClassObject getClassObject() {
        result.getOrigin() = this.getParent()
    }

    /** Gets the nth base of this class definition. */
    Expr getBase(int index) {
        result = this.getParent().getBase(index)
    }

    /** Gets a base of this class definition. */
    Expr getABase() {
        result = this.getParent().getABase()
    }
    
    /** Gets the metrics for this class */
    ClassMetrics getMetrics() {
        result = this
    }

    /** Gets the qualified name for this class.
     * Should return the same name as the `__qualname__` attribute on classes in Python 3.
     */
    string getQualifiedName() {
        this.getScope() instanceof Module and result = this.getName()
        or
        exists(string enclosing_name |
            enclosing_name = this.getScope().(Function).getQualifiedName()
            or
            enclosing_name = this.getScope().(Class).getQualifiedName() |
            result = enclosing_name + "." + this.getName()
        )
    }

}

