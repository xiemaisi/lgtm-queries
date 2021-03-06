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

/** Utilities to support queries about instance attribute accesses of
 * the form `self.attr`.
 */

import python

/** An attribute access where the left hand side of the attribute expression 
  * is `self`.
  */
class SelfAttribute extends Attribute {

    SelfAttribute() {
        self_attribute(this, _)
    }

    Class getClass() {
        self_attribute(this, result)
    }

}

/** Whether variable 'self' is the self variable in method 'method' */
private predicate self_variable(Function method, Variable self) {
    exists(FunctionObject fobj | fobj.getFunction() = method and fobj.isNormalMethod())
    and
    self.getAnAccess() = method.getArg(0)
}

/** Whether attribute is an access of the form `self.attr` in the body of the class 'cls' */
private predicate self_attribute(Attribute attr, Class cls) {
    exists(Function f, Variable self |
        self_variable(f, self) |
        self.getAnAccess() = attr.getObject() and
        cls = f.getScope()
    )
}

private predicate hasatttr_call(Call call, Expr object, Expr attr) {
    exists(GlobalVariable v, Name n |
        v.getId() = "hasattr" and call.getFunc() = n and n.getVariable() = v |
        object = call.getArg(0) and attr = call.getArg(1)
    )
}

/** Helper class for UndefinedClassAttribute.ql &amp; MaybeUndefinedClassAttribute.ql */
class SelfAttributeRead extends SelfAttribute {

    SelfAttributeRead() {
        this.getCtx() instanceof Load
    }

    predicate guardedByHasattr() {
        exists(Call c, Name self, StrConst attr |
            exists(If i | c = i.getTest()) and
            c.getAFlowNode().getBasicBlock().strictlyDominates(this.getAFlowNode().getBasicBlock()) and
            hasatttr_call(c, self, attr) and
            self.getVariable() = ((Name)this.getObject()).getVariable() and
            attr.getText() = this.getName()
        )
    }

    cached predicate locallyDefined() {
        exists(SelfAttributeStore store |
            this.getName() = store.getName() and 
            this.getScope() = store.getScope() |
            store.getAFlowNode().strictlyDominates(this.getAFlowNode())
        )
    }

}

class SelfAttributeStore extends SelfAttribute {

    SelfAttributeStore() {
        this.getCtx() instanceof Store
    }

    Expr getAssignedValue() {
        exists(Assign a | a.getATarget() = this |
            result = a.getValue()
        )
    }

}

private Object object_getattribute() {
    py_cmembers(theObjectType(), "__getattribute__", result)
}

private Object object_init() {
    py_cmembers(theObjectType(), "__init__", result)
}

/** Helper class for UndefinedClassAttribute.ql &amp; MaybeUndefinedClassAttribute.ql */
class CheckClass extends ClassObject {

    private predicate ofInterest() {
        not this.unknowableAttributes() and
        not this.getPyClass().isProbableMixin() and
        this.getPyClass().isPublic() and
        not this.getPyClass().getScope() instanceof Function and
        not this.probablyAbstract() and
        not this.declaresAttribute("__new__") and
        not this.selfDictAssigns() and
        not this.lookupAttribute("__getattribute__") != object_getattribute() and
        not this.hasAttribute("__getattr__") and
        not this.selfSetattr() and
        /* If class overrides object.__init__, but we can't resolve it to a Python function then give up */
        not exists(Object overriding_init |
                overriding_init = this.lookupAttribute("__init__") and
                overriding_init != object_init()
                |
                not overriding_init instanceof PyFunctionObject
            )
    }

    predicate alwaysDefines(string name) {
        auto_name(name) or
        this.hasAttribute(name) or
        this.getAnImproperSuperType().assignedInInit(name)
    }

    predicate sometimesDefines(string name) {
        this.alwaysDefines(name) or
        exists(SelfAttributeStore sa | sa.getClass() = this.getAnImproperSuperType().getPyClass() |
            name = sa.getName()
        )
    }

    private predicate selfDictAssigns() {
        exists(Assign a, SelfAttributeRead self_dict, Subscript sub | 
            self_dict.getName() = "__dict__" and
            ( 
              self_dict = sub.getObject() 
              or
              /* Indirect assignment via temporary variable */
              exists(SsaVariable v | 
                  v.getAUse() = sub.getObject().getAFlowNode() and 
                  v.getDefinition().(DefinitionNode).getValue() = self_dict.getAFlowNode()
              )
            ) and
            a.getATarget() = sub and
            exists(FunctionObject meth | meth = this.lookupAttribute(_) and a.getScope() = meth.getFunction())
        )
    }

    pragma [nomagic]
    private predicate monkeyPatched(string name) {
        exists(Attribute a |
             a.getCtx() instanceof Store and
             intermediate_points_to(a.getObject().getAFlowNode(), this, _) and a.getName() = name
        )
    }

    private predicate selfSetattr() {
      exists(Call c, Name setattr, Name self, Function method |
          ( method.getScope() = this.getPyClass() or 
            method.getScope() = this.getASuperType().getPyClass()
          ) and
          c.getScope() = method and
          c.getFunc() = setattr and
          setattr.getId() = "setattr" and
          c.getArg(0) = self and
          self.getId() = "self"
      )
    }

  predicate interestingUndefined(SelfAttributeRead a) {
      exists(string name | name = a.getName() |
          interestingContext(a, name) and
          not this.definedInBlock(a.getAFlowNode().getBasicBlock(), name)
      )
  }

  private predicate interestingContext(SelfAttributeRead a, string name) {
      name = a.getName() and
      this.ofInterest() and
      this.getPyClass() = a.getScope().getScope() and
      not a.locallyDefined() and
      not a.guardedByHasattr() and
      a.getScope().isPublic() and
      not this.monkeyPatched(name) and
      not attribute_assigned_in_method(lookupAttribute("setUp"), name)
  }

  private predicate probablyAbstract() {
      this.getName().matches("Abstract%")
      or
      this.isAbstract()
  }

  private pragma[nomagic] predicate definitionInBlock(BasicBlock b, string name) {
      exists(SelfAttributeStore sa | 
          sa.getAFlowNode().getBasicBlock() = b and sa.getName() = name and sa.getClass() = this.getPyClass()
      )
      or
      exists(FunctionObject method | this.lookupAttribute(_) = method |
          attribute_assigned_in_method(method, name) and
          b = method.getACall().getBasicBlock()
      )
  }

  private pragma[nomagic] predicate definedInBlock(BasicBlock b, string name) {
      // manual specialisation: this is only called from interestingUndefined,
      // so we can push the context in from there, which must apply to a
      // SelfAttributeRead in the same scope
      exists(SelfAttributeRead a | 
          a.getScope() = b.getScope() and name = a.getName() |
          interestingContext(a, name)
      )
      and
      this.definitionInBlock(b, name)
      or
      exists(BasicBlock prev | this.definedInBlock(prev, name) and prev.getASuccessor() = b)
  }

}

/* pragma [nomagic] */cached
predicate attribute_assigned_in_method(FunctionObject method, string name) {
    exists(SelfAttributeStore a | a.getScope() = method.getFunction() and a.getName() = name)
    or
    exists(ClassObject t, Call c, FunctionObject called, SelfAttribute a | 
        c.getScope() = method.getFunction() and
        c.getFunc() = a and t.lookupAttribute(_) = method and
        called = t.lookupAttribute(a.getName()) and
        attribute_assigned_in_method(called, name)
    )
}


private predicate auto_name(string name) {
  name = "__class__" or name = "__dict__"
}
