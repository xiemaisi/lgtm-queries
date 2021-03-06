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

/** A module. This is the top level element in an AST, corresponding to a source file. 
 * It is also a Scope; the scope of global variables. */
class Module extends Module_, Scope, AstNode {

    string toString() {
        result = this.getKind() + " " + this.getName()
        or
        /* No name is defined, which means that this is not on an import path. So it must be a script */
        not exists(this.getName()) and this.getKind() = "Module" and 
        result = "Script " + this.getFile().getShortName()
    }

    /** The enclosing scope of this module (always none) */
    Scope getScope() {
        none()
    }

    /** Gets the statements forming the body of this module */
    StmtList getBody() {
        result = Module_.super.getBody()
    }

    /** Gets the nth statement of this module */
    Stmt getStmt(int n) {
        result = Module_.super.getStmt(n)
    }

    /** Gets a top-level statement in this module */
    Stmt getAStmt() {
        result = Module_.super.getAStmt()
    }

    /** Gets the name of this module */
    string getName() {
        result = Module_.super.getName()
    }

    /** Gets this module */
    Module getEnclosingModule() {
        result = this
    }

    /** Gets the __init__ module of this module if the module is a package and it has an __init__ module */
    Module getInitModule() {
        /* this.isPackage() and */ result.getName() = this.getName() + ".__init__"
    }

    /** Whether this module is a package initializer */
    predicate isPackageInit() {
        this.getName().matches("%__init__") and not this.isPackage()
    }

    /** Gets a name exported by this module, that is the names that will be added to a namespace by 'from this-module import *'  */
    string getAnExport() {
        py_exports(this, result)
        or
        not this.(ImportTimeScope).definesName("__all__") and this.(ImportTimeScope).definesName(result)
    }

    /** Gets the source file for this module */
    File getFile() {
        py_module_path(this, result)
    }

    /** Whether this is a package */
    predicate isPackage() {
        exists(Module m | m.getPackage() = this)
    }

    /** Gets the package containing this module (or parent package if this is a package) */
    Module getPackage() {
        this.getName().matches("%.%") and
        result.getName() = getName().regexpReplaceAll("\\.[^.]*$", "")
    }

    /** Gets the metrics for this module */
    ModuleMetrics getMetrics() {
        result = this
    }

    /** Use ModuleObject.getAnImportedModule() instead.
     * Gets a module imported by this module */
    deprecated Module getAnImportedModule() {
        result.getName() = this.getAnImportedModuleName()
    }

    string getAnImportedModuleName() {
        exists(Import i | i.getEnclosingModule() = this | result = i.getAnImportedModuleName())
        or
        exists(ImportStar i | i.getEnclosingModule() = this | result = i.getImportedModuleName())
    }

    Location getLocation() {
        py_scope_location(result, this)
    }

    /** Gets a child module or package of this package */
    Module getSubModule(string name) {
        result.getPackage() = this and
        name = result.getName().regexpReplaceAll(".*\\.", "")
    }
  
    /** Whether name is declared in the __all__ list of this module */
    predicate declaredInAll(string name)
    {
        exists(AssignStmt a, GlobalVariable all | 
            a.defines(all) and a.getScope() = this and
            all.getId() = "__all__" and ((List)a.getValue()).getAnElt().strValue() = name
        )
    }

    AstNode getAChildNode() {
        result = this.getAStmt()
    }


}


