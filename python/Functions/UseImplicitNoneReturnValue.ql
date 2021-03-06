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
 * @name Use of the return value of a procedure
 * @description The return value of a procedure (a function that does not return a value) is used. This is confusing to the reader as the value (None) has no meaning.
 * @kind problem
 * @problem.severity warning
 */

import python
import Testing.Mox

predicate is_used(Call c) {
    exists(Expr outer | outer != c and outer.containsInScope(c) | outer instanceof Call or outer instanceof Attribute or outer instanceof Subscript)
    or
    exists(Stmt s | 
        c = s.getASubExpression() and
        not s instanceof ExprStmt and
        /* Ignore if a single return, as def f(): return g() is quite common. Covers implicit return in a lambda. */
        not (s instanceof Return and strictcount(Return r | r.getScope() = s.getScope()) = 1)
    )
}

from Call c, FunctionObject func
where is_used(c) and c.getFunc().refersTo(func) and func.getFunction().isProcedure() and 
/* Mox return objects have an `AndReturn` method */
not useOfMoxInModule(c.getEnclosingModule())
select c, "The result of '$@' is used even though it is always None.", func, func.getQualifiedName()
