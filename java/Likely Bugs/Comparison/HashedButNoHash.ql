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
 * @name Hashed value without hashCode definition
 * @description Classes that define an 'equals' method but no 'hashCode' method, and whose instances 
 *              are stored in a hashing data structure, can lead to unexpected results.
 * @kind problem
 * @problem.severity error
 */
import default
import Equality

/** A class that defines an `equals` method but no `hashCode` method. */
predicate eqNoHash(Class c) {
  exists(Method m | m = c.getAMethod() |
    m instanceof EqualsMethod and
    // If the inherited `equals` is a refining `equals`
    // then the superclass hash code is still valid.
    not m instanceof RefiningEquals
  ) and
  not c.getAMethod() instanceof HashCodeMethod and
  c.fromSource()
}

predicate hashingMethod(Method m) {
  exists(string name, string names |
    names = "add,contains,containsKey,get,put,remove" and
    name = names.splitAt(",") and
    m.getName() = name
  )
}

/** Whether `e` is an expression in which `t` is used in a hashing data structure. */
predicate usedInHash(RefType t, Expr e) {
  exists(RefType s | s.getName().matches("%Hash%") |
    exists(MethodAccess ma | 
      ma.getQualifier().getType() = s and
      ma.getArgument(0).getType() = t and
      e = ma and hashingMethod(ma.getMethod())
    )
    or exists(ConstructorCall cc |
      cc.getConstructedType() = s and
      s.(ParameterizedType).getTypeArgument(0) = t and
      cc = e
    )
  )
}

from RefType t, Expr e
where usedInHash(t, e) and
      eqNoHash(t.getSourceDeclaration())
select e, "Type '" + t.getName() + "' does not define hashCode(), "
          + "but is used in a hashing data-structure."
