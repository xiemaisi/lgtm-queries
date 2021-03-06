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
 * @name Inconsistent synchronization for field
 * @description If a field is mostly accessed in a synchronized context, but occasionally accessed
 *              in a non-synchronized way, the non-synchronized accesses may lead to race
 *              conditions.
 * @kind problem
 * @problem.severity error
 * @cwe 662
 */
import default

predicate withinInitializer(Expr e) {
  e.getEnclosingCallable().hasName("<clinit>") or
  e.getEnclosingCallable() instanceof Constructor
}

predicate locallySynchronized(MethodAccess ma) {
  ma.getEnclosingStmt().getParent+() instanceof SynchronizedStmt
}

predicate hasUnsynchronizedCall(Method m) {
  (m.isPublic() and not m.isSynchronized())
  or
  exists(MethodAccess ma, Method caller | ma.getMethod() = m and caller = ma.getEnclosingCallable() |
    hasUnsynchronizedCall(caller) and
    not caller.isSynchronized() and
    not locallySynchronized(ma)
  )
}

predicate withinLocalSynchronization(Expr e) {
  e.getEnclosingCallable().isSynchronized() or
  e.getEnclosingStmt().getParent+() instanceof SynchronizedStmt
}

class MyField extends Field {
  MyField() {
    this.fromSource() and
    not this.isFinal() and
    not this.isVolatile() and 
    not this.getDeclaringType() instanceof EnumType
  }
  
  int getNumSynchedAccesses() {
  	result = count(Expr synched | synched = this.getAnAccess() and withinLocalSynchronization(synched))
  }
  
  int getNumAccesses() {
  	result = count(this.getAnAccess())
  }
  
  float getPercentSynchedAccesses() {
  	result = (float)this.getNumSynchedAccesses() / this.getNumAccesses()
  }
}

from MyField f, Expr e, int percent
where 
  e = f.getAnAccess() 
  and not withinInitializer(e) 
  and not withinLocalSynchronization(e) 
  and hasUnsynchronizedCall(e.getEnclosingCallable())
  and f.getNumSynchedAccesses() > 0
  and percent = (f.getPercentSynchedAccesses() * 100).floor()
  and percent > 80
select e, "Unsynchronized access to $@, but " + percent.toString() + "% of accesses to this field are synchronized.",
       f, f.getDeclaringType().getName() + "." + f.getName()
